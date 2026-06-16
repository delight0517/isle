-- 크리에이티브 분석: 영상별 내러티브 JSON 캐시 (Edge Function → 공유)
CREATE TABLE IF NOT EXISTS public.video_analyses (
  video_id text PRIMARY KEY,
  title text,
  channel_name text,
  narrative_json jsonb NOT NULL,
  source text NOT NULL DEFAULT 'edge',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS video_analyses_updated_idx ON public.video_analyses (updated_at DESC);

ALTER TABLE public.video_analyses ENABLE ROW LEVEL SECURITY;

-- 누구나 캐시된 분석 읽기 (비용 절감)
CREATE POLICY "video_analyses_select_all"
  ON public.video_analyses FOR SELECT
  USING (true);

-- 쓰기는 service_role(Edge Function)만
CREATE POLICY "video_analyses_insert_service"
  ON public.video_analyses FOR INSERT
  WITH CHECK (false);

CREATE POLICY "video_analyses_update_service"
  ON public.video_analyses FOR UPDATE
  USING (false);

COMMENT ON TABLE public.video_analyses IS 'Isle creative analytics — shared narrative cache';
