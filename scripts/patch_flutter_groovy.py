#!/usr/bin/env python3
"""
Patch flutter.groovy to fix two incompatibilities between Flutter 3.29.x and
Gradle 8.10 + AGP 8.7.x when third-party plugins use legacy buildscript{} blocks.

Problem 1 — afterEvaluate on already-evaluated project
  Legacy plugins (iris_method_channel, audioplayers_android, etc.) have
  buildscript{} blocks that force eager evaluation of subprojects.  With
  Gradle 8.10+ this causes afterEvaluate() to be called on an already-evaluated
  project, throwing InvalidUserCodeException.

Problem 2 — "too late to add new build types"
  When a plugin project is already evaluated (same root cause), AGP 8.7+ has
  finalised the build-type DSL.  Any attempt to add a new build type (e.g.
  "profile") via  pluginProject.android.buildTypes { "profile" {} }  throws
  IllegalStateException: "It is too late to add new build types".
  The same can happen for the main app project's buildTypes block inside apply().

Fix:
  1. Inject a safeAfterEvaluate(project, action) helper that runs action
     immediately if the project is already evaluated, or defers via
     afterEvaluate if not.
  2. Replace ALL occurrences of:
       project.afterEvaluate {
       pluginProject.afterEvaluate {
       appProject.afterEvaluate {
     with the safe variant.
  3. Wrap EVERY  *.android.buildTypes { ... }  call that adds new build types
     in a try/catch so that "too late" errors are silently ignored (the build
     type already exists, so nothing is lost).

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
        print("INFO: This Flutter version (3.30+) uses Kotlin DSL — no patch needed.")
        sys.exit(0)

    return groovy_path


# ---------------------------------------------------------------------------
# Helper Groovy code injected once near the top of the FlutterPlugin class
# ---------------------------------------------------------------------------
SAFE_AFTER_EVALUATE_HELPER = (
    '\n'
    '    /**\n'
    '     * Safely schedule an action after a project is evaluated.\n'
    '     * If the project is already evaluated, the action is run immediately.\n'
    '     * Injected by patch_flutter_groovy.py to fix Gradle 8.10 + AGP 8.7 incompatibility.\n'
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

HELPER_MARKER = 'private static void safeAfterEvaluate(Project p, Closure action)'

# ---------------------------------------------------------------------------
# afterEvaluate replacements
# ---------------------------------------------------------------------------
AFTER_EVALUATE_REPLACEMENTS = [
    ('project.afterEvaluate {',       'safeAfterEvaluate(project) {'),
    ('pluginProject.afterEvaluate {', 'safeAfterEvaluate(pluginProject) {'),
    ('appProject.afterEvaluate {',    'safeAfterEvaluate(appProject) {'),
]

# ---------------------------------------------------------------------------
# Pattern A: pluginProject.android.buildTypes { "${buildType.name}" {} }
# 12-space indented, inside addEmbeddingDependencyToPlugin closure
# ---------------------------------------------------------------------------
BUILDTYPES_PLUGIN_OLD = (
    '            pluginProject.android.buildTypes {\n'
    '                "${buildType.name}" {}\n'
    '            }'
)
BUILDTYPES_PLUGIN_NEW = (
    '            try {\n'
    '                pluginProject.android.buildTypes {\n'
    '                    "${buildType.name}" {}\n'
    '                }\n'
    '            } catch (Exception ignored) {\n'
    '                // AGP 8.7+ may have already finalised the build-type DSL.\n'
    '                // The build type already exists, so this is safe to ignore.\n'
    '            }'
)
BUILDTYPES_PLUGIN_MARKER = 'try {\n                pluginProject.android.buildTypes {'

# ---------------------------------------------------------------------------
# Pattern B: project.android.buildTypes { profile { ... } release { ... } }
# 8-space indented, inside apply() method
# ---------------------------------------------------------------------------
BUILDTYPES_APP_OLD = (
    '        project.android.buildTypes {\n'
    '            // Add profile build type.\n'
    '            profile {\n'
    '                initWith(debug)\n'
    '                if (it.hasProperty("matchingFallbacks")) {\n'
    '                    matchingFallbacks = ["debug", "release"]\n'
    '                }\n'
    '            }\n'
    '            // TODO(garyq): Shrinking is only false for multi apk split aot builds, where shrinking is not allowed yet.\n'
    '            // This limitation has been removed experimentally in gradle plugin version 4.2, so we can remove\n'
    '            // this check when we upgrade to 4.2+ gradle. Currently, deferred components apps may see\n'
    '            // increased app size due to this.\n'
    '            if (shouldShrinkResources(project)) {\n'
    '                release {\n'
    '                    // Enables code shrinking, obfuscation, and optimization for only\n'
    '                    // your project\'s release build type.\n'
    '                    minifyEnabled(true)\n'
    '                    // Enables resource shrinking, which is performed by the Android Gradle plugin.\n'
    '                    // The resource shrinker can\'t be used for libraries.\n'
    '                    shrinkResources(isBuiltAsApp(project))\n'
    '                    // Fallback to `android/app/proguard-rules.pro`.\n'
    '                    // This way, custom Proguard rules can be configured as needed.\n'
    '                    proguardFiles(project.android.getDefaultProguardFile("proguard-android-optimize.txt"), flutterProguardRules, "proguard-rules.pro")\n'
    '                }\n'
    '            }\n'
    '        }'
)
BUILDTYPES_APP_NEW = (
    '        try {\n'
    '            project.android.buildTypes {\n'
    '                // Add profile build type.\n'
    '                profile {\n'
    '                    initWith(debug)\n'
    '                    if (it.hasProperty("matchingFallbacks")) {\n'
    '                        matchingFallbacks = ["debug", "release"]\n'
    '                    }\n'
    '                }\n'
    '                // TODO(garyq): Shrinking is only false for multi apk split aot builds, where shrinking is not allowed yet.\n'
    '                // This limitation has been removed experimentally in gradle plugin version 4.2, so we can remove\n'
    '                // this check when we upgrade to 4.2+ gradle. Currently, deferred components apps may see\n'
    '                // increased app size due to this.\n'
    '                if (shouldShrinkResources(project)) {\n'
    '                    release {\n'
    '                        // Enables code shrinking, obfuscation, and optimization for only\n'
    '                        // your project\'s release build type.\n'
    '                        minifyEnabled(true)\n'
    '                        // Enables resource shrinking, which is performed by the Android Gradle plugin.\n'
    '                        // The resource shrinker can\'t be used for libraries.\n'
    '                        shrinkResources(isBuiltAsApp(project))\n'
    '                        // Fallback to `android/app/proguard-rules.pro`.\n'
    '                        // This way, custom Proguard rules can be configured as needed.\n'
    '                        proguardFiles(project.android.getDefaultProguardFile("proguard-android-optimize.txt"), flutterProguardRules, "proguard-rules.pro")\n'
    '                    }\n'
    '                }\n'
    '            }\n'
    '        } catch (Exception ignored) {\n'
    '            // AGP 8.7+ may have already finalised the build-type DSL.\n'
    '            // The profile build type already exists, so this is safe to ignore.\n'
    '        }'
)
BUILDTYPES_APP_MARKER = 'try {\n            project.android.buildTypes {'


def patch_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    report = []

    # ------------------------------------------------------------------
    # 1. Inject safeAfterEvaluate helper (idempotent)
    # ------------------------------------------------------------------
    if HELPER_MARKER not in content:
        inject_before = '    @Override\n    void apply(Project project) {'
        if inject_before in content:
            content = content.replace(
                inject_before,
                SAFE_AFTER_EVALUATE_HELPER + '    @Override\n    void apply(Project project) {',
                1
            )
            report.append('+ Injected safeAfterEvaluate() helper')
        else:
            inject_before2 = '    private void configurePluginProject('
            if inject_before2 in content:
                content = content.replace(
                    inject_before2,
                    SAFE_AFTER_EVALUATE_HELPER + inject_before2,
                    1
                )
                report.append('+ Injected safeAfterEvaluate() helper (fallback)')
            else:
                print("ERROR: Cannot find injection point for safeAfterEvaluate helper")
                sys.exit(1)
    else:
        report.append('= safeAfterEvaluate() helper already present (idempotent)')

    # ------------------------------------------------------------------
    # 2. Replace afterEvaluate calls
    # ------------------------------------------------------------------
    for old, new in AFTER_EVALUATE_REPLACEMENTS:
        count = content.count(old)
        if count > 0:
            content = content.replace(old, new)
            report.append(f'+ Replaced {count}x  \'{old}\'')

    # ------------------------------------------------------------------
    # 3. Wrap pluginProject.android.buildTypes in try/catch (Pattern A)
    # ------------------------------------------------------------------
    if BUILDTYPES_PLUGIN_MARKER not in content:
        if BUILDTYPES_PLUGIN_OLD in content:
            content = content.replace(BUILDTYPES_PLUGIN_OLD, BUILDTYPES_PLUGIN_NEW, 1)
            report.append('+ Wrapped pluginProject.android.buildTypes in try/catch')
        else:
            report.append('WARNING: pluginProject.android.buildTypes pattern not found — skipped')
    else:
        report.append('= pluginProject.android.buildTypes already wrapped (idempotent)')

    # ------------------------------------------------------------------
    # 4. Wrap project.android.buildTypes { profile ... } in try/catch (Pattern B)
    # ------------------------------------------------------------------
    if BUILDTYPES_APP_MARKER not in content:
        if BUILDTYPES_APP_OLD in content:
            content = content.replace(BUILDTYPES_APP_OLD, BUILDTYPES_APP_NEW, 1)
            report.append('+ Wrapped project.android.buildTypes (profile/release) in try/catch')
        else:
            report.append('WARNING: project.android.buildTypes pattern not found — skipped')
    else:
        report.append('= project.android.buildTypes already wrapped (idempotent)')

    # ------------------------------------------------------------------
    # 5. Write back only if changed
    # ------------------------------------------------------------------
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched: {path}")
    else:
        print(f"No changes needed: {path}")

    # ------------------------------------------------------------------
    # 6. Verification report
    # ------------------------------------------------------------------
    print()
    for line in report:
        print(f'  {line}')
    print()

    remaining_ae  = len(re.findall(r'\.\bafterEvaluate\b\s*\{', content))
    safe_ae       = content.count('safeAfterEvaluate(')
    helper_ok     = HELPER_MARKER in content
    plugin_try_ok = BUILDTYPES_PLUGIN_MARKER in content
    app_try_ok    = BUILDTYPES_APP_MARKER in content

    print(f'  afterEvaluate calls remaining : {remaining_ae}')
    print(f'  safeAfterEvaluate calls added : {safe_ae}')
    print(f'  Helper method present         : {helper_ok}')
    print(f'  pluginProject.buildTypes try  : {plugin_try_ok}')
    print(f'  project.buildTypes try        : {app_try_ok}')

    if remaining_ae > 0:
        print(f'\nWARNING: {remaining_ae} afterEvaluate call(s) still present — check manually.')

    if not helper_ok:
        print('\nERROR: safeAfterEvaluate helper was not injected!')
        sys.exit(1)

    if not plugin_try_ok or not app_try_ok:
        print('\nWARNING: One or more buildTypes try/catch wrappers missing.')

    print('\nPatch complete.')


def main():
    groovy_path = find_flutter_groovy()
    print(f"Found flutter.groovy: {groovy_path}")
    patch_file(groovy_path)


if __name__ == '__main__':
    main()
