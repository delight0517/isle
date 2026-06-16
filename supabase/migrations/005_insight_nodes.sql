-- Living Knowledge Identity — Edge Function `insight_extractor` 저장소
CREATE TABLE IF NOT EXISTS public.insight_nodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  video_id text NOT NULL,
  video_url text NOT NULL,
  title text,
  channel_name text,
  thumbnail_url text,
  user_memo text,
  core_keyword text,
  ai_summary text,
  ai_summary_lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  transcript_excerpt text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, video_id)
);

CREATE INDEX IF NOT EXISTS insight_nodes_user_created_idx
  ON public.insight_nodes (user_id, created_at DESC);

ALTER TABLE public.insight_nodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "insight_nodes_select_own"
  ON public.insight_nodes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "insight_nodes_insert_own"
  ON public.insight_nodes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "insight_nodes_update_own"
  ON public.insight_nodes FOR UPDATE
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.insight_nodes IS 'Isle insight_extractor — CC+LLM per user/video';
