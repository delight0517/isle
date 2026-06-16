-- 피드 캐시 오래된 항목 정리 (7일 이상)
CREATE OR REPLACE FUNCTION public.cleanup_old_feed()
RETURNS void AS $$
BEGIN
  DELETE FROM public.feed_cache
  WHERE fetched_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
