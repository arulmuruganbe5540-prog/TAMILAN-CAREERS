-- Optimize policies flagged by the Supabase Auth RLS initplan advisor.
-- This only wraps auth.uid() calls in scalar SELECTs; ownership predicates and policy roles stay unchanged.
do $$
declare
  p record;
  ddl text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (
        (coalesce(qual, '') like '%auth.uid()%' and coalesce(qual, '') not like '%SELECT auth.uid()%')
        or
        (coalesce(with_check, '') like '%auth.uid()%' and coalesce(with_check, '') not like '%SELECT auth.uid()%')
      )
  loop
    ddl := format('ALTER POLICY %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    if p.qual is not null then
      ddl := ddl || format(' USING (%s)', replace(p.qual, 'auth.uid()', '(select auth.uid())'));
    end if;
    if p.with_check is not null then
      ddl := ddl || format(' WITH CHECK (%s)', replace(p.with_check, 'auth.uid()', '(select auth.uid())'));
    end if;
    execute ddl;
  end loop;
end
$$;
