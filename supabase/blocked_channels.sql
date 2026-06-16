-- Supabase SQL Editor에서 1회 실행 (Google 로그인 + 차단 목록 동기화)
create table if not exists public.blocked_channels (
  user_id uuid not null references auth.users (id) on delete cascade,
  channel_id text not null,
  channel_name text not null default '',
  blocked_at timestamptz not null default now(),
  primary key (user_id, channel_id)
);

alter table public.blocked_channels enable row level security;

create policy "Users manage own blocked channels"
  on public.blocked_channels
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
