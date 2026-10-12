-- 프리셋 공유 코드 (3앱: 4vpn / cage / 모아 공유)
-- flutter 앱은 supabase/migrations/007_shared_presets.sql 로 복사되어 적용됨.
-- 4vpn(Swift)은 같은 Supabase 프로젝트에 REST 로 접근.
-- 페이로드는 기존 PremadeBlockPackEntry(kind/pattern/note) 포맷 그대로 재사용 —
-- 새 공유 포맷을 발명하지 않는다.

create table if not exists shared_block_presets (
  id                uuid primary key default gen_random_uuid(),
  share_code        text unique not null,  -- 6~8자 사람이 입력 가능한 짧은 코드
  creator_app_id    text not null check (creator_app_id in ('4vpn','cage','moa')),
  creator_user_id   uuid,
  preset_name       text not null,
  entries           jsonb not null,        -- [{pattern, kind, note?}] — PremadeBlockPackEntry[]
  include_schedule  boolean not null default false,  -- 사용자가 시간 포함 여부 선택
  schedule_json     jsonb,                 -- include_schedule=true 일 때만 사용
  created_at        timestamptz not null default now()
);
create index if not exists idx_shared_block_presets_code on shared_block_presets(share_code);

-- RLS: 공유 코드로 누구나 조회 가능(친구가 코드 입력해 가져오는 흐름).
-- 생성은 인증된 사용자만, 본인 것만 쓸 수 있음.
alter table shared_block_presets enable row level security;

create policy "shared_block_presets_select"
  on shared_block_presets for select
  using (true);

create policy "shared_block_presets_insert"
  on shared_block_presets for insert
  with check (auth.uid() = creator_user_id);
