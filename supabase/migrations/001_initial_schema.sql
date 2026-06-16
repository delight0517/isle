CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  island_theme TEXT DEFAULT 'classic' CHECK (island_theme IN ('classic','dark','minimal')),
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.interest_tags (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  tag_name TEXT NOT NULL,
  weight FLOAT DEFAULT 0.5 CHECK (weight BETWEEN 0 AND 1),
  color_hex TEXT DEFAULT '#2B4A8C',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, tag_name)
);

CREATE TABLE public.shelves (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  interest_tag_id UUID REFERENCES public.interest_tags ON DELETE SET NULL,
  icon_emoji TEXT DEFAULT '📚',
  is_public BOOLEAN DEFAULT true,
  position_x INTEGER DEFAULT 0,
  position_y INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('youtube','brunch','rss')),
  channel_id TEXT NOT NULL,
  channel_name TEXT NOT NULL,
  channel_thumbnail TEXT,
  notify_topics TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, platform, channel_id)
);

CREATE TABLE public.archives (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  shelf_id UUID REFERENCES public.shelves ON DELETE SET NULL,
  url TEXT NOT NULL,
  title TEXT NOT NULL,
  thumbnail_url TEXT,
  source_type TEXT DEFAULT 'article' CHECK (source_type IN ('youtube','brunch','article','other')),
  source_channel_id TEXT,
  is_read BOOLEAN DEFAULT false,
  is_public BOOLEAN DEFAULT true,
  tags TEXT[] DEFAULT '{}',
  archived_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE TABLE public.follows (
  follower_id UUID REFERENCES public.profiles ON DELETE CASCADE,
  following_id UUID REFERENCES public.profiles ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE TABLE public.feed_cache (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  content_url TEXT NOT NULL,
  title TEXT NOT NULL,
  thumbnail_url TEXT,
  source_type TEXT,
  channel_id TEXT,
  channel_name TEXT,
  channel_avatar TEXT,
  detected_topics TEXT[] DEFAULT '{}',
  relevance_score FLOAT DEFAULT 0,
  published_at TIMESTAMPTZ,
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interest_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shelves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (is_public OR auth.uid()=id);
CREATE POLICY "profiles_modify" ON public.profiles FOR ALL USING (auth.uid()=id);
CREATE POLICY "tags_own"        ON public.interest_tags FOR ALL USING (auth.uid()=user_id);
CREATE POLICY "shelves_select"  ON public.shelves FOR SELECT USING (is_public OR auth.uid()=user_id);
CREATE POLICY "shelves_modify"  ON public.shelves FOR ALL USING (auth.uid()=user_id);
CREATE POLICY "subs_own"        ON public.subscriptions FOR ALL USING (auth.uid()=user_id);
CREATE POLICY "archives_select" ON public.archives FOR SELECT USING (is_public OR auth.uid()=user_id);
CREATE POLICY "archives_modify" ON public.archives FOR ALL USING (auth.uid()=user_id);
CREATE POLICY "follows_select"  ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_modify"  ON public.follows FOR ALL USING (auth.uid()=follower_id);
CREATE POLICY "feed_own"        ON public.feed_cache FOR ALL USING (auth.uid()=user_id);

-- 인덱스
CREATE INDEX idx_archives_user  ON public.archives(user_id, archived_at DESC);
CREATE INDEX idx_archives_shelf ON public.archives(shelf_id);
CREATE INDEX idx_feed_user      ON public.feed_cache(user_id, relevance_score DESC);
CREATE INDEX idx_shelves_user   ON public.shelves(user_id);

-- 신규 유저 프로필 자동 생성
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, avatar_url)
  VALUES (
    NEW.id,
    LOWER(SPLIT_PART(NEW.email,'@',1)) || '_' || SUBSTR(NEW.id::text,1,4),
    COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email,'@',1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
