# insight_extractor

YouTube CC → LLM 인사이트 → `insight_nodes` 테이블.

## Secrets (Supabase Dashboard → Edge Functions)

- `ANTHROPIC_API_KEY` 또는 `OPENAI_API_KEY` (하나 이상)
- `SUPABASE_SERVICE_ROLE_KEY` (자동 주입)
- 선택: `ANTHROPIC_MODEL`, `OPENAI_MODEL`

## DB

`supabase/migrations/005_insight_nodes.sql` 적용 후 사용.

## Deploy

```bash
cd isle
supabase functions deploy insight_extractor --project-ref YOUR_REF
```

로컬 테스트:

```bash
supabase functions serve insight_extractor --env-file supabase/.env.local
```

## Body

```json
{ "videoUrl": "https://www.youtube.com/watch?v=...", "userMemo": "거친 메모" }
```

Authorization: `Bearer <user_jwt>` 필수.
