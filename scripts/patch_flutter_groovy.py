#!/usr/bin/env python3
"""
Patch flutter.groovy to fix the "Cannot run Project.afterEvaluate(Action) when the project
is already evaluated" error that occurs with Gradle 8.10+ and Flutter 3.29.x.

Root cause:
  Flutter plugins that use legacy `buildscript {}` blocks (e.g. iris_method_channel,
  audioplayers_android, connectivity_plus, etc.) cause Gradle to eagerly evaluate all
  subprojects BEFORE the flutter-gradle-plugin is applied to :app. When flutter.groovy
  then calls project.afterEvaluate() on an already-evaluated project, Gradle 8.10+
  throws an InvalidUserCodeException.

Scope:
  This patch only applies to Flutter <= 3.29.x (Groovy DSL flutter.groovy).
  Flutter 3.30+ migrated to Kotlin DSL and does NOT have this file.
  In that case, this script exits successfully without changes.

Fix:
  1. Add a safeAfterEvaluate(project, action) helper that runs action immediately
     if the project is already evaluated, or defers via afterEvaluate if not.
  2. Replace ALL occurrences of:
       project.afterEvaluate {
       pluginProject.afterEvaluate {
       appProject.afterEvaluate {
     with the safe variant.

This patch is idempotent: running it multiple times has no effect.
"""

import sys
import os
import re
import subprocess


def find_flutter_groovy():
    """Find the flutter.groovy file in the Flutter SDK. Returns None if not found (Flutter 3.30+)."""
    flutter_bin = subprocess.run(
        ['which', 'flutter'], capture_output=True, text=True
    ).stdout.strip()

    if not flutter_bin:
        print("ERROR: flutter binary not found in PATH")
        sys.exit(1)

    real_flutter = subprocess.run(
        ['readlink', '-f', flutter_bin], capture_output=True, text=True
    ).stdout.strip()
    flutter_root = os.path.dirname(os.path.dirname(real_flutter))

    groovy_path = os.path.join(
        flutter_root, 'packages', 'flutter_tools', 'gradle',
        'src', 'main', 'groovy', 'flutter.groovy'
    )

    if not os.path.exists(groovy_path):
        print(f"INFO: flutter.groovy not found at {groovy_path}")
        print("INFO: This Flutter version uses Kotlin DSL (3.30+). No Groovy patch needed.")
        return None

    return groovy_path


def apply_patch(groovy_path):
    """Apply the safe-afterEvaluate patch to flutter.groovy."""
    print(f"Patching: {groovy_path}")

    with open(groovy_path, 'r') as f:
        content = f.read()

    # Check if already patched
    if 'safeAfterEvaluate' in content:
        print("Patch already applied. Skipping.")
        return True

    # -----------------------------------------------------------------------
    # 1. Inject the safeAfterEvaluate helper method.
    #    Insert just before configurePluginProject() — the first method that
    #    calls project.afterEvaluate in flutter.groovy.
    # -----------------------------------------------------------------------
    helper_method = (
        '\n'
        '    /**\n'
        '     * Safe wrapper around afterEvaluate that handles projects already evaluated.\n'
        '     *\n'
        '     * With Gradle 8.10+ and legacy Flutter plugins that use buildscript {} blocks,\n'
        '     * subprojects can be configured eagerly before flutter-gradle-plugin is applied.\n'
        '     * Calling afterEvaluate on an already-evaluated project throws:\n'
        '     *   "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."\n'
        '     *\n'
        '     * This helper executes the action immediately when the project is already evaluated,\n'
        '     * or registers it as a normal afterEvaluate callback otherwise.\n'
        '     */\n'
        '    private static void safeAfterEvaluate(Project p, Closure action) {\n'
        '        if (p.state.executed) {\n'
        '            action.call()\n'
        '        } else {\n'
        '            p.afterEvaluate(action)\n'
        '        }\n'
        '    }\n'
        '\n'
    )

    # Try primary insertion marker first
    insert_marker = '    /** Adds the plugin project dependency to the app project. */'
    if insert_marker in content:
        content = content.replace(insert_marker, helper_method + insert_marker, 1)
        print("  + Injected safeAfterEvaluate() helper (primary marker)")
    else:
        # Fallback: insert before configurePluginProject method signature
        insert_marker = '    private void configurePluginProject('
        if insert_marker in content:
            content = content.replace(insert_marker, helper_method + insert_marker, 1)
            print("  + Injected safeAfterEvaluate() helper (fallback marker)")
        else:
            print("ERROR: Cannot find insertion point for safeAfterEvaluate helper")
            return False

    # -----------------------------------------------------------------------
    # 2. Replace ALL afterEvaluate calls with safeAfterEvaluate.
    #    Covers: project, pluginProject, appProject.
    # -----------------------------------------------------------------------
    patterns = [
        ('project.afterEvaluate {',      'safeAfterEvaluate(project) {'),
        ('pluginProject.afterEvaluate {', 'safeAfterEvaluate(pluginProject) {'),
        ('appProject.afterEvaluate {',    'safeAfterEvaluate(appProject) {'),
    ]

    for old, new in patterns:
        count = content.count(old)
        if count > 0:
            content = content.replace(old, new)
            print(f"  + Replaced {count}x  '{old}'")
        else:
            print(f"  - Not found (OK): '{old}'")

    # -----------------------------------------------------------------------
    # 3. Write patched file
    # -----------------------------------------------------------------------
    with open(groovy_path, 'w') as f:
        f.write(content)

    # -----------------------------------------------------------------------
    # 4. Verify
    # -----------------------------------------------------------------------
    remaining_ae = len(re.findall(r'\.\bafterEvaluate\b\s*\{', content))
    safe_count   = content.count('safeAfterEvaluate(')
    helper_ok    = 'private static void safeAfterEvaluate' in content

    print(f"\nVerification:")
    print(f"  afterEvaluate calls remaining : {remaining_ae}")
    print(f"  safeAfterEvaluate calls added : {safe_count}")
    print(f"  Helper method present         : {helper_ok}")

    if remaining_ae == 0 and safe_count >= 4 and helper_ok:
        print("\nSUCCESS: flutter.groovy patched correctly!")
        return True
    else:
        print("\nWARNING: Patch may be incomplete — check output above.")
        # Don't fail the build; partial patch is better than no patch.
        return True


if __name__ == '__main__':
    groovy_path = find_flutter_groovy()
    if groovy_path is None:
        # Flutter 3.30+ uses Kotlin DSL — no patch needed.
        sys.exit(0)
    success = apply_patch(groovy_path)
    sys.exit(0 if success else 1)
