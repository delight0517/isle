# analyze_video

Isle 크리에이티브 분석 Edge Function.

## Secrets (Supabase Dashboard → Edge Functions)

- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (자동)
- `OPENAI_API_KEY` + optional `OPENAI_MODEL`
- 또는 `ANTHROPIC_API_KEY` + optional `ANTHROPIC_MODEL`

## Deploy

```bash
cd isle
supabase db push   # migration 004
supabase functions deploy analyze_video
```

## Request

```json
{ "videoId": "dQw4w9WgXcQ", "title": "…", "channelName": "…", "durationSeconds": 212 }
```
