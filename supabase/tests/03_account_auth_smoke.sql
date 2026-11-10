-- Module 01.1 read-only security smoke checks.
-- Expected: 2 rows, 6 policies, no anonymous table access,
-- authenticated SELECT/INSERT/UPDATE only, zero DELETE grants.
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       (SELECT count(*) FROM pg_policies p
        WHERE p.schemaname = 'public' AND p.tablename = c.relname) AS policy_count,
       has_table_privilege('anon', c.oid, 'SELECT') AS anon_can_select,
       has_table_privilege('anon', c.oid, 'INSERT') AS anon_can_insert,
       has_table_privilege('authenticated', c.oid, 'SELECT') AS signed_in_can_select,
       has_table_privilege('authenticated', c.oid, 'INSERT') AS signed_in_can_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') AS signed_in_can_update,
       has_table_privilege('authenticated', c.oid, 'DELETE') AS signed_in_can_delete
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r'
  AND c.relname IN ('user_profiles','user_preferences')
ORDER BY c.relname;

SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname='public'
  AND tablename IN ('user_profiles','user_preferences')
ORDER BY tablename, policyname;

-- Theme cannot be an arbitrary value; read the deployed CHECK constraint.
SELECT conrelid::regclass AS table_name, pg_get_constraintdef(oid) AS rule
FROM pg_constraint
WHERE conrelid='public.user_preferences'::regclass AND contype='c';
