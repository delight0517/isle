CREATE TABLE public.pending_requests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  requester_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  target_user_id UUID REFERENCES public.profiles ON DELETE CASCADE NOT NULL,
  purpose TEXT NOT NULL,
  intro_message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (requester_id != target_user_id)
);

CREATE UNIQUE INDEX uq_pending_requests_active
ON public.pending_requests(requester_id, target_user_id)
WHERE status = 'pending';

CREATE INDEX idx_pending_requests_target ON public.pending_requests(target_user_id, created_at DESC);
CREATE INDEX idx_pending_requests_requester ON public.pending_requests(requester_id, created_at DESC);

ALTER TABLE public.pending_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pending_requests_select"
ON public.pending_requests
FOR SELECT
USING (auth.uid() = requester_id OR auth.uid() = target_user_id);

CREATE POLICY "pending_requests_insert"
ON public.pending_requests
FOR INSERT
WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "pending_requests_update"
ON public.pending_requests
FOR UPDATE
USING (auth.uid() = requester_id OR auth.uid() = target_user_id)
WITH CHECK (auth.uid() = requester_id OR auth.uid() = target_user_id);
