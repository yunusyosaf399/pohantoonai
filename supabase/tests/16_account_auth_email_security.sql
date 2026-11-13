-- Module 02.5 read-only security smoke. Safe on the existing live project.
DO $test$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.oid, c.relname, c.relrowsecurity
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname IN ('account_auth_email_config','account_auth_email_notifications')
  LOOP
    IF NOT r.relrowsecurity THEN
      RAISE EXCEPTION 'RLS is disabled on %', r.relname;
    END IF;
    IF has_table_privilege('anon',r.oid,'SELECT') OR
       has_table_privilege('authenticated',r.oid,'SELECT') OR
       has_table_privilege('authenticated',r.oid,'INSERT') OR
       has_table_privilege('authenticated',r.oid,'UPDATE') THEN
      RAISE EXCEPTION 'Client has access to privileged %', r.relname;
    END IF;
    IF NOT has_table_privilege('service_role',r.oid,'SELECT') THEN
      RAISE EXCEPTION 'Service role cannot read %', r.relname;
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public'
        AND c.relname IN ('account_auth_email_config','account_auth_email_notifications')) <> 2
  THEN RAISE EXCEPTION 'Notification tables missing'; END IF;

  IF has_function_privilege('anon',
       'public.reserve_account_auth_email(uuid,uuid)','EXECUTE') OR
     has_function_privilege('authenticated',
       'public.reserve_account_auth_email(uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'A normal client can reserve an email'; END IF;

  IF NOT has_function_privilege('service_role',
       'public.reserve_account_auth_email(uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Edge Function cannot reserve emails'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname='public'
      AND tablename='account_auth_email_notifications'
      AND indexname='account_auth_email_one_welcome_per_user') THEN
    RAISE EXCEPTION 'One-welcome unique index missing';
  END IF;
END;
$test$;
