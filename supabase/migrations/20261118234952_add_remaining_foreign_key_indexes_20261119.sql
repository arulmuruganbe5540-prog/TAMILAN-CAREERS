-- Add the ten foreign-key indexes found missing by the live Supabase performance advisor.
-- Additive and safe to rerun.
create index if not exists community_post_comments_user_id_idx on public.community_post_comments(user_id);
create index if not exists community_post_reactions_user_id_idx on public.community_post_reactions(user_id);
create index if not exists community_posts_created_by_idx on public.community_posts(created_by);
create index if not exists community_settings_updated_by_idx on public.community_settings(updated_by);
create index if not exists job_exam_attempts_job_id_idx on public.job_exam_attempts(job_id);
create index if not exists job_exam_attempts_question_set_id_idx on public.job_exam_attempts(question_set_id);
create index if not exists job_exam_question_sets_job_id_idx on public.job_exam_question_sets(job_id);
create index if not exists job_exam_resources_created_by_idx on public.job_exam_resources(created_by);
create index if not exists job_reports_reporter_user_id_idx on public.job_reports(reporter_user_id);
create index if not exists job_reports_reviewed_by_idx on public.job_reports(reviewed_by);
