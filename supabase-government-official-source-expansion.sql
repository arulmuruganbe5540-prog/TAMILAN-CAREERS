-- TAMILAN CAREERS: add direct recruitment pages for better official-source coverage.
-- Safe to run more than once. This only adds source URLs; it does not publish jobs.
insert into public.government_notice_sources
  (id, authority, scope, state, base_url, enabled)
values
  ('ibps-other-recruitment','IBPS Other Ongoing Recruitments','central',null,'https://www.ibps.in/index.php/recruitment/',true),
  ('upsc-recruitment-advertisements','UPSC Recruitment Advertisements','central',null,'https://www.upsc.gov.in/recruitment/recruitment-advertisement',true),
  ('upsc-recruitment-tests','UPSC Recruitment Tests Notices','central',null,'https://cms.upsc.gov.in/recruitment-tests/notice/',true),
  ('tnpsc-press-releases','TNPSC Official Press Releases','state','Tamil Nadu','https://www.tnpsc.gov.in/English/Press_releases.aspx',true),
  ('tnpsc-groupiv-2026','TNPSC Group IV Notification 11/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=7a880763-80dc-4c3a-bbbe-81b6a3a75a87',true),
  ('tnpsc-groupii-2026','TNPSC Group II and IIA Notification 07/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=89113de0-6a0e-4d47-a409-c84fb04ef33e',true),
  ('tnpsc-groupi-2026','TNPSC Group I Notification 05/2026','state','Tamil Nadu','https://www.tnpsc.gov.in/web/examdashboard/index.aspx?notid=33aa5415-6205-4ae9-842e-212d62d088f1',true)
on conflict (id) do update set
  authority=excluded.authority,
  scope=excluded.scope,
  state=excluded.state,
  base_url=excluded.base_url,
  updated_at=now();


-- Historical archive and result pages for one-year backfill and ongoing monitoring.
insert into public.government_notice_sources (id, authority, scope, state, base_url, enabled)
values
('upsc-exam-notification-archive','UPSC Examination Notification Archives','central',NULL,'https://www.upsc.gov.in/exams-related-info/exam-notification/archives',true),
('upsc-recruitment-advertisements','UPSC Recruitment Advertisements Archive','central',NULL,'https://www.upsc.gov.in/recruitment/recruitment-advertisement',true),
('upsc-recruitment-results','UPSC Recruitment Test Results','central',NULL,'https://cms.upsc.gov.in/recruitment-tests/results/',true),
('ssc-notice-archives','Staff Selection Commission Notice Archives','central',NULL,'https://ssc.gov.in/home/archives',true),
('tnpsc-exam-dashboard','TNPSC Exam Dashboard and Results','state','Tamil Nadu','https://tnpsc.gov.in/English/Examdashboard.aspx/English/DResultView.aspx',true),
('mrb-results','Tamil Nadu Medical Services Recruitment Board Results','state','Tamil Nadu','https://www.mrb.tn.gov.in/content.php?dept_id=ODAw&lang=MQ%3D%3D&menu_id=MjI0',true)
on conflict (id) do update set authority=excluded.authority, scope=excluded.scope, state=excluded.state, base_url=excluded.base_url, updated_at=now();
