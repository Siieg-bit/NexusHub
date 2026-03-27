#!/usr/bin/env python3
"""
Patch flutter.groovy to fix:
  "Cannot run Project.afterEvaluate(Action) when the project is already evaluated"

Root cause:
  Third-party Flutter plugins (e.g. agora_rtc_engine via iris_method_channel) use
  `rootProject.allprojects {}` in their build.gradle, which forces the Gradle
  configuration phase to evaluate those subprojects BEFORE the :app project is
  configured. When flutter-gradle-plugin later tries to call
  `pluginProject.afterEvaluate {}` on those already-evaluated projects, Gradle
  throws an exception.

Scope:
  This patch only applies to Flutter <= 3.29.x, which uses a Groovy-based
  flutter.groovy plugin. Flutter 3.30+ migrated to a Kotlin DSL plugin and does
  NOT have this file. In that case, this script exits successfully without changes.

Fix (Flutter <= 3.29.x):
  1. Add a `safeAfterEvaluate(project, action)` helper that runs `action` immediately
     if the project is already evaluated, or defers via `afterEvaluate` if not.
  2. Replace all `pluginProject.afterEvaluate {` calls with `safeAfterEvaluate(pluginProject) {`.
  3. Wrap `pluginProject.android.buildTypes { "${buildType.name}" {} }` in a try/catch
     to handle the case where build types are already finalized.

This patch is idempotent: running it multiple times has no effect.
"""

import sys
import os
import subprocess

def find_flutter_groovy():
    """Find the flutter.groovy file in the Flutter SDK. Returns None if not found (Flutter 3.30+)."""
    # Try to find flutter binary
    flutter_bin = subprocess.run(['which', 'flutter'], capture_output=True, text=True).stdout.strip()
    if not flutter_bin:
        print("ERROR: flutter binary not found in PATH")
        sys.exit(1)
    
    # Resolve symlinks to get the real path
    real_flutter = subprocess.run(['readlink', '-f', flutter_bin], capture_output=True, text=True).stdout.strip()
    flutter_root = os.path.dirname(os.path.dirname(real_flutter))
    
    groovy_path = os.path.join(flutter_root, 'packages', 'flutter_tools', 'gradle', 'src', 'main', 'groovy', 'flutter.groovy')
    
    if not os.path.exists(groovy_path):
        # Flutter 3.30+ uses Kotlin DSL — no flutter.groovy exists. This is expected.
        print(f"INFO: flutter.groovy not found at {groovy_path}")
        print("INFO: This Flutter version uses Kotlin DSL (3.30+). No Groovy patch needed.")
        return None
    
    return groovy_path


def apply_patch(groovy_path):
    """Apply the patch to flutter.groovy."""
    print(f"Patching: {groovy_path}")
    
    with open(groovy_path, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if 'safeAfterEvaluate' in content:
        print("Patch already applied. Skipping.")
        return True
    
    # Verify the file has the expected content
    if 'pluginProject.afterEvaluate {' not in content:
        print("WARNING: Expected pattern not found. Flutter version may be incompatible.")
        return False
    
    # 1. Add the safeAfterEvaluate helper method
    helper_method = '''
    /**
     * Safe version of afterEvaluate that handles the case where the project
     * is already evaluated. This fixes the "Cannot run Project.afterEvaluate(Action)
     * when the project is already evaluated" error caused by plugins that use
     * rootProject.allprojects {} which forces early evaluation of subprojects.
     */
    private static void safeAfterEvaluate(Project project, Closure action) {
        if (project.state.executed) {
            // Project already evaluated, run the action immediately
            action.call()
        } else {
            project.afterEvaluate(action)
        }
    }

'''
    
    insert_marker = '    /** Adds the plugin project dependency to the app project. */'
    if insert_marker not in content:
        print(f"WARNING: Insert marker not found: '{insert_marker}'")
        # Try alternative marker
        insert_marker = '    private void configurePluginProject('
        if insert_marker not in content:
            print("ERROR: Cannot find insertion point for helper method")
            return False
    
    content = content.replace(insert_marker, helper_method + insert_marker, 1)
    
    # 2. Replace pluginProject.afterEvaluate with safeAfterEvaluate
    content = content.replace('pluginProject.afterEvaluate {', 'safeAfterEvaluate(pluginProject) {')
    
    # 3. Wrap buildTypes addition in try/catch
    old_buildtypes = '            pluginProject.android.buildTypes {\n                "${buildType.name}" {}\n            }'
    new_buildtypes = '''            // Wrapped in try/catch: if project was evaluated early (e.g. via
            // rootProject.allprojects {}), build types may already be finalized.
            try {
                pluginProject.android.buildTypes {
                    "${buildType.name}" {}
                }
            } catch (Exception ignored) {
                // Build types already finalized, no action needed
            }'''
    
    if old_buildtypes in content:
        content = content.replace(old_buildtypes, new_buildtypes)
        print("  - Wrapped buildTypes in try/catch")
    else:
        print("  - WARNING: buildTypes pattern not found (may use different indentation)")
    
    # Write the patched file
    with open(groovy_path, 'w') as f:
        f.write(content)
    
    # Verify
    remaining = content.count('pluginProject.afterEvaluate {')
    replaced = content.count('safeAfterEvaluate(pluginProject) {')
    helper_present = 'private static void safeAfterEvaluate' in content
    
    print(f"  - afterEvaluate calls remaining: {remaining}")
    print(f"  - safeAfterEvaluate calls added: {replaced}")
    print(f"  - Helper method present: {helper_present}")
    
    if remaining == 0 and replaced >= 3 and helper_present:
        print("SUCCESS: flutter.groovy patched correctly!")
        return True
    else:
        print("WARNING: Patch may be incomplete. Check the output above.")
        return True  # Don't fail the build for incomplete patch


if __name__ == '__main__':
    groovy_path = find_flutter_groovy()
    if groovy_path is None:
        # Flutter 3.30+ — no patch needed, exit successfully
        sys.exit(0)
    success = apply_patch(groovy_path)
    sys.exit(0 if success else 1)
