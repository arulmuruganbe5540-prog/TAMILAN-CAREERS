-- TAMILAN CAREERS: indexes for uncovered foreign keys
-- Safe to rerun. These indexes support joins and parent-row updates/deletes.
-- They do not change row visibility or application behavior.

create index if not exists admin_job_post_reviews_published_job_id_idx on public.admin_job_post_reviews(published_job_id);
create index if not exists admin_job_post_reviews_reviewed_by_idx on public.admin_job_post_reviews(reviewed_by);
create index if not exists candidate_education_country_id_idx on public.candidate_education(country_id);
create index if not exists candidate_experience_country_id_idx on public.candidate_experience(country_id);
create index if not exists candidate_languages_language_code_idx on public.candidate_languages(language_code);
create index if not exists candidate_preferences_preferred_country_id_idx on public.candidate_preferences(preferred_country_id);
create index if not exists candidate_preferences_salary_currency_idx on public.candidate_preferences(salary_currency);
create index if not exists company_invitations_accepted_user_id_idx on public.company_invitations(accepted_user_id);
create index if not exists company_invitations_invited_by_idx on public.company_invitations(invited_by);
create index if not exists external_job_candidates_reviewed_by_idx on public.external_job_candidates(reviewed_by);
create index if not exists external_job_candidates_source_id_idx on public.external_job_candidates(source_id);
create index if not exists government_notice_reviews_verified_by_idx on public.government_notice_reviews(verified_by);
create index if not exists job_alerts_salary_currency_idx on public.job_alerts(salary_currency);
create index if not exists job_application_status_history_changed_by_idx on public.job_application_status_history(changed_by);
create index if not exists job_applications_resume_id_idx on public.job_applications(resume_id);
create index if not exists job_categories_parent_category_id_idx on public.job_categories(parent_category_id);
create index if not exists job_interviews_created_by_idx on public.job_interviews(created_by);
create index if not exists job_locations_job_id_idx on public.job_locations(job_id);
create index if not exists job_match_notification_logs_job_alert_id_idx on public.job_match_notification_logs(job_alert_id);
create index if not exists job_match_notification_logs_job_match_result_id_idx on public.job_match_notification_logs(job_match_result_id);
create index if not exists job_match_results_resume_id_idx on public.job_match_results(resume_id);
create index if not exists job_offers_created_by_idx on public.job_offers(created_by);
create index if not exists job_seeker_profiles_current_country_id_idx on public.job_seeker_profiles(current_country_id);
create index if not exists jobs_created_by_idx on public.jobs(created_by);
create index if not exists jobs_source_id_idx on public.jobs(source_id);
create index if not exists resume_extraction_reviews_extracted_data_id_idx on public.resume_extraction_reviews(extracted_data_id);
create index if not exists resume_extraction_reviews_resume_id_idx on public.resume_extraction_reviews(resume_id);
create index if not exists tc_interview_invitations_application_id_idx on public.tc_interview_invitations(application_id);
create index if not exists tc_interview_invitations_invited_by_idx on public.tc_interview_invitations(invited_by);
create index if not exists tc_notifications_related_application_id_idx on public.tc_notifications(related_application_id);

-- Additional uncovered foreign keys found in the live Supabase performance advisor (19 Nov 2026).
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
