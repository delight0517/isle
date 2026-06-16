CREATE TABLE public.blocked_channels (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  channel_id TEXT NOT NULL,
  channel_name TEXT NOT NULL,
  blocked_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, channel_id)
);

ALTER TABLE public.blocked_channels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "blocked_channels_own"
  ON public.blocked_channels FOR ALL
  USING (auth.uid() = user_id);

CREATE INDEX idx_blocked_channels_user ON public.blocked_channels(user_id, blocked_at DESC);
