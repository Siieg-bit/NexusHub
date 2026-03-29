#!/usr/bin/env python3
"""
Adds RefreshIndicator to screens that need pull-to-refresh.

Strategy:
- For screens using FutureProvider/StateNotifier with ref.watch(), wrap the
  body's scrollable content with RefreshIndicator that invalidates providers.
- For screens that already have RefreshIndicator, skip them.
- For screens that are forms/editors (create, edit, settings), skip them.

Since each screen has unique structure, we'll use a targeted approach per file.
"""

import re
import os

# Files that should NOT get RefreshIndicator (forms, editors, settings, auth, etc.)
SKIP_FILES = {
    'login_screen.dart',
    'signup_screen.dart',
    'onboarding_screen.dart',
    'interest_wizard_screen.dart',
    'create_post_screen.dart',
    'create_community_screen.dart',
    'create_group_chat_screen.dart',
    'create_story_screen.dart',
    'edit_profile_screen.dart',
    'edit_community_profile_screen.dart',
    'edit_guidelines_screen.dart',
    'settings_screen.dart',
    'privacy_settings_screen.dart',
    'notification_settings_screen.dart',
    'blocked_users_screen.dart',
    'devices_screen.dart',
    'call_screen.dart',
    'screening_room_screen.dart',
    'story_viewer_screen.dart',
    'search_screen.dart',
    'check_in_screen.dart',
    'chat_room_screen.dart',  # Chat has its own realtime mechanism
    # Already have RefreshIndicator:
    'community_list_screen.dart',
    'explore_screen.dart',
    'acm_screen.dart',
    'flag_center_screen.dart',
    'live_screen.dart',
    'wiki_curator_review_screen.dart',
}

BASE = '/home/ubuntu/NexusHub/frontend/lib/features'

changes = 0

def process_file(filepath):
    """Add RefreshIndicator to a screen file."""
    global changes
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Skip if already has RefreshIndicator
    if 'RefreshIndicator' in content:
        return
    
    filename = os.path.basename(filepath)
    
    # Find providers used with ref.watch() to know what to invalidate
    providers = re.findall(r'ref\.watch\((\w+(?:Provider|Notifier)\w*)', content)
    if not providers:
        # Also check ref.read for stateful screens
        providers = re.findall(r'ref\.read\((\w+(?:Provider|Notifier)\w*)', content)
    
    # Deduplicate
    providers = list(dict.fromkeys(providers))
    
    if not providers:
        print(f"  SKIP {filename}: no providers found")
        return
    
    # Strategy: Find ListView/CustomScrollView/SingleChildScrollView in the body
    # and wrap with RefreshIndicator
    
    # For ConsumerWidget screens - find the body content
    # Look for patterns like: body: someAsync.when( or body: ListView(
    
    # Simple approach: find `body:` in Scaffold and wrap the content
    # We'll look for common patterns:
    
    # Pattern 1: body: someProvider.when(
    match = re.search(r'(body:\s*)(\w+\.when\()', content)
    if match:
        # This is an async provider pattern - wrap the whole body with RefreshIndicator
        # We need to find the provider variable name
        var_name = match.group(2).split('.')[0]
        
        # Find which provider this variable comes from
        provider_match = re.search(rf'final\s+{var_name}\s*=\s*ref\.watch\((\w+)', content)
        if provider_match:
            provider_name = provider_match.group(1)
            
            # Replace body: varName.when( with body: RefreshIndicator(onRefresh: ..., child: varName.when(
            # This is complex because we need to find the matching closing paren
            # Instead, let's just add a _refresh method and wrap
            
            # For ConsumerWidget, we can't easily add state. Instead wrap inline.
            # Actually, for .when() pattern, the data: callback usually returns a scrollable widget
            # Let's find the data: callback and wrap its return value
            
            print(f"  PATTERN1 {filename}: {provider_name} (async .when())")
            
            # Find `data: (xxx) {` or `data: (xxx) =>` inside the .when()
            # This is too complex for regex. Let's use a simpler approach.
    
    # Simpler approach: Add a _refresh helper method and wrap body content
    # For screens with ListView in body, wrap with RefreshIndicator
    
    # Let's check if it's a ConsumerStatefulWidget or ConsumerWidget
    is_stateful = 'ConsumerStatefulWidget' in content or 'StatefulWidget' in content
    is_consumer = 'ConsumerWidget' in content
    
    # For now, let's just add RefreshIndicator wrapping ListView/CustomScrollView
    # by finding the pattern and wrapping it
    
    # Find all provider names used in ref.watch
    watch_providers = re.findall(r'ref\.watch\((\w+)', content)
    watch_providers = list(dict.fromkeys(watch_providers))
    
    if not watch_providers:
        print(f"  SKIP {filename}: no ref.watch providers")
        return
    
    # Build invalidate calls
    invalidate_calls = '\n'.join(f'        ref.invalidate({p});' for p in watch_providers[:5])
    
    # For ConsumerWidget: we need to convert to use a helper
    # For ConsumerStatefulWidget: we can add a method
    
    # Approach: Find `body:` in the Scaffold and wrap with RefreshIndicator
    # Look for `body: ` followed by a widget
    
    body_match = re.search(r'(\s+)(body:\s*)', content)
    if not body_match:
        print(f"  SKIP {filename}: no body: found")
        return
    
    indent = body_match.group(1)
    body_start = body_match.start()
    body_keyword_end = body_match.end()
    
    # Find what comes after body:
    after_body = content[body_keyword_end:body_keyword_end+200]
    
    # Check if it's already wrapped in something complex
    # We'll wrap the entire body content with RefreshIndicator
    
    # Find the body value - it ends at the next top-level comma or closing paren
    # This is complex. Let's use a different approach.
    
    # Instead of trying to parse Dart AST, let's just add RefreshIndicator
    # around ListView/CustomScrollView where we find them in the body
    
    # Find ListView( or CustomScrollView( or SingleChildScrollView(
    scrollable_pattern = r'(ListView(?:\.builder|\.separated)?|CustomScrollView|SingleChildScrollView)\('
    scrollable_matches = list(re.finditer(scrollable_pattern, content))
    
    if not scrollable_matches:
        print(f"  SKIP {filename}: no scrollable widget found")
        return
    
    # Take the first scrollable that appears after a body: or Expanded(
    for sm in scrollable_matches:
        pos = sm.start()
        # Check context - is this in the body area?
        before = content[max(0, pos-200):pos]
        if 'body:' in before or 'Expanded(' in before or 'child:' in before:
            # Get the indentation
            line_start = content.rfind('\n', 0, pos) + 1
            current_indent = ''
            for ch in content[line_start:]:
                if ch in ' \t':
                    current_indent += ch
                else:
                    break
            
            widget_name = sm.group(1)
            
            # Determine if we're in a ConsumerWidget (has WidgetRef ref) or State (has ref directly)
            ref_prefix = 'ref' if is_stateful else 'ref'
            
            # Wrap: replace `ListView(` with `RefreshIndicator(onRefresh: () async { ... }, child: ListView(`
            # And we need to add a closing `)` after the ListView's closing `)`
            
            # Actually, this is very hard to do with regex because we need to find matching parens.
            # Let's use a simpler approach: just add RefreshIndicator around the body content.
            
            # NEW APPROACH: Find `body:` and the widget after it, then wrap
            # We'll find the body: line and add RefreshIndicator wrapper
            
            replacement = f'RefreshIndicator(\n{current_indent}  color: AppTheme.primaryColor,\n{current_indent}  onRefresh: () async {{\n'
            for p in watch_providers[:5]:
                replacement += f'{current_indent}    {ref_prefix}.invalidate({p});\n'
            replacement += f'{current_indent}    await Future.delayed(const Duration(milliseconds: 300));\n'
            replacement += f'{current_indent}  }},\n{current_indent}  child: {widget_name}('
            
            new_content = content[:pos] + replacement + content[pos + len(sm.group(0)):]
            
            # Now find the matching closing paren for this widget and add `)` after it
            # This is the hard part. Let's find it by counting parens.
            
            # Start from after the replacement
            search_start = pos + len(replacement)
            paren_count = 1  # We opened one paren with `widget_name(`
            i = search_start
            while i < len(new_content) and paren_count > 0:
                ch = new_content[i]
                if ch == '(':
                    paren_count += 1
                elif ch == ')':
                    paren_count -= 1
                elif ch == "'" or ch == '"':
                    # Skip strings
                    quote = ch
                    i += 1
                    while i < len(new_content) and new_content[i] != quote:
                        if new_content[i] == '\\':
                            i += 1  # skip escaped char
                        i += 1
                i += 1
            
            if paren_count == 0:
                # i is now right after the closing paren of the scrollable widget
                # Insert `,\n)` to close the RefreshIndicator
                close_pos = i
                new_content = new_content[:close_pos] + ',\n' + current_indent + ')' + new_content[close_pos:]
                
                with open(filepath, 'w') as f:
                    f.write(new_content)
                
                changes += 1
                print(f"  OK {filename}: wrapped {widget_name} with RefreshIndicator ({len(watch_providers)} providers)")
                return
            else:
                print(f"  FAIL {filename}: couldn't find matching paren for {widget_name}")
                return
    
    print(f"  SKIP {filename}: no suitable scrollable in body context")


# Process all screen files
for root, dirs, files in os.walk(BASE):
    for f in sorted(files):
        if f.endswith('_screen.dart') and f not in SKIP_FILES:
            filepath = os.path.join(root, f)
            print(f"Processing {f}...")
            process_file(filepath)

print(f"\nTotal changes: {changes}")
