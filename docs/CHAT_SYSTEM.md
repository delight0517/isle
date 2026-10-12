# 채팅 시스템 — 모아  (GENERATED, 손대지 말 것)

> spec v1.2.0 · 전파일 2026-07-06

이 앱의 채팅 시스템은 **공용 단일 명세**를 따른다. 직접 규칙을 여기 쓰지 말 것.

- 명세(SSOT): `_chat_system/CHAT_SPEC.md`
- 용어 사전: `_chat_system/GLOSSARY.md`
- 공용 코퍼스: `_chat_system/fixtures/corpus.json`

## 이 앱에서 손댈 파일
- **parser**: `lib/core/ai/block_chat/block_chat_parser.dart`
- **executor**: `lib/core/ai/block_chat/block_chat_executor.dart`
- **transcript**: `lib/core/ai/block_chat/block_chat_transcript_service.dart`
- **models**: `lib/core/ai/block_chat/block_chat_models.dart`
- **scenarios**: `lib/core/ai/block_chat/block_chat_daily_scenarios.dart`
- **ui**: `lib/features/ai/presentation/block_chat_screen.dart`
- **presetService**: `lib/core/block/premade_block_pack_service.dart`
- **genreService**: `lib/core/youtube/channel_genre_ai_service.dart`
- **quickReplyUi**: `lib/features/ai/presentation/widgets/block_chat_quick_reply_bar.dart`
- **financeCatalog**: `lib/core/block_schedule/schedule_app_target_catalog.dart`
- **suggestionEngine**: `lib/core/ai/suggestion/block_suggestion_engine.dart`
- **sharedPresetService**: `lib/core/block/shared_block_preset_service.dart`
- **dailyInsight**: `lib/core/content/daily_addiction_insight_service.dart`

## 이 앱의 현재 규약 (표준과 다르면 GLOSSARY 어댑터로 변환)
- weekday: 0=월 1=화 2=수 3=목 4=금 5=토 6=일 (0-based, 월요일 시작)
- time: end_hour/end_minute + start_hour/start_minute
- commandModel: action-verb
- note: cage 와 forked. parser 가 이미 drift 되어 있으므로 변경 시 diff 확인 필수.
