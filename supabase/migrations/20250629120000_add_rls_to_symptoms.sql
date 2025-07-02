ALTER TABLE public.symptoms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own symptoms" ON public.symptoms FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own symptoms" ON public.symptoms FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own symptoms" ON public.symptoms FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own symptoms" ON public.symptoms FOR DELETE USING (auth.uid() = user_id);