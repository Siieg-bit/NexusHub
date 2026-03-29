# Agora Integration Notes

## Current State
- `agora_rtc_engine: ^6.3.1` is in pubspec.yaml (low-level SDK)
- `agora_uikit` is NOT in pubspec.yaml (user wants to add it)
- `call_service.dart` uses `agora_rtc_engine` directly with `_agoraAppId = 'YOUR_AGORA_APP_ID'`
- `call_screen.dart` uses `agora_rtc_engine` directly (AgoraVideoView, VideoViewController)
- DB tables: `call_sessions`, `call_participants` already exist (migration 013)

## User Credentials
- App ID: SEU_AGORA_APP_ID_AQUI
- Customer ID: 99677d89f5814f3f8dbc4f768d68a855
- Key: 99677d89f5814f3f8dbc4f768d68a855
- Secret: SEU_AGORA_APP_CERTIFICATE_AQUI

## Decision
The user provided `agora_uikit` sample code. Two options:
1. Replace agora_rtc_engine with agora_uikit (simpler but less control)
2. Keep agora_rtc_engine + add agora_uikit as secondary (conflicts possible)

Best approach: Keep current architecture (agora_rtc_engine) since call_screen.dart is already 
fully implemented with custom UI, controls, audio levels, etc. Just plug in the real App ID 
and implement token generation. The agora_uikit approach is simpler but our custom UI is better.

## Plan
1. Set real App ID in call_service.dart
2. Add Agora token server (Edge Function) using App Certificate for production tokens
3. Ensure call_screen.dart works with real credentials
4. Wire call buttons in chat_room_screen.dart
