-- Module 03.1 admission isolation regression. Runs entirely within a rollback.
-- Uses existing auth.users IDs only as FK identities; no passwords or emails.
BEGIN;
DO $test$
DECLARE
  admin_a uuid;
  admin_b uuid;
  school_a uuid;
  school_b uuid;
  admission_a uuid;
  seen integer;
  denied boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
      WHERE schemaname='public' AND tablename='school_admissions'
        AND policyname='admission_mfa_required' AND permissive='RESTRICTIVE')
  THEN RAISE EXCEPTION 'MFA policy must be restrictive'; END IF;
  IF has_table_privilege('anon','public.school_admissions','SELECT')
     OR has_table_privilege('authenticated','public.school_admissions','DELETE')
  THEN RAISE EXCEPTION 'Unsafe admissions grants'; END IF;

  SELECT id INTO admin_a FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT id INTO admin_b FROM auth.users WHERE id<>admin_a
    ORDER BY created_at LIMIT 1;
  IF admin_a IS NULL OR admin_b IS NULL THEN
    RAISE EXCEPTION 'Two existing users required for isolation test';
  END IF;

  INSERT INTO public.schools(slug,name,lifecycle_status)
    VALUES ('admissions-test-a-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),
      'Admissions Security Test A','active') RETURNING id INTO school_a;
  INSERT INTO public.schools(slug,name,lifecycle_status)
    VALUES ('admissions-test-b-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),
      'Admissions Security Test B','active') RETURNING id INTO school_b;
  INSERT INTO public.school_memberships(school_id,user_id,role,membership_status)
    VALUES (school_a,admin_a,'school_admin','active'),
      (school_b,admin_b,'school_admin','active');

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',admin_a,'role','authenticated','aal','aal2')::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  INSERT INTO public.school_admissions
    (school_id,student_first_name,student_last_name,grade_applied,guardian_full_name,guardian_phone)
    VALUES(school_a,'Test','Learner','Grade 4','Test Guardian','+1234567890')
    RETURNING id INTO admission_a;
  SELECT count(*) INTO seen FROM public.school_admissions
    WHERE school_id=school_a AND id=admission_a;
  IF seen<>1 THEN RAISE EXCEPTION 'Admin A cannot see own admission'; END IF;
  SELECT count(*) INTO seen FROM public.school_admissions WHERE school_id=school_b;
  IF seen<>0 THEN RAISE EXCEPTION 'Admin A can see another school'; END IF;

  denied:=false;
  BEGIN
    INSERT INTO public.school_admissions
      (school_id,student_first_name,student_last_name,grade_applied,guardian_full_name,guardian_phone)
      VALUES(school_b,'Intruder','Learner','Grade 4','Test Guardian','+1234567890');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Cross-school insert permitted'; END IF;

  denied:=false;
  BEGIN
    UPDATE public.school_admissions SET school_id=school_b WHERE id=admission_a;
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Cross-school reassignment permitted'; END IF;

  UPDATE public.school_admissions SET status='admitted' WHERE id=admission_a;
  SELECT count(*) INTO seen FROM public.school_admissions
    WHERE id=admission_a AND status='admitted';
  IF seen<>1 THEN RAISE EXCEPTION 'Approval failed'; END IF;
  denied:=false;
  BEGIN
    UPDATE public.school_admissions SET status='rejected' WHERE id=admission_a;
  EXCEPTION WHEN check_violation THEN denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'Final decision was mutable'; END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',admin_b,'role','authenticated','aal','aal2')::text,true);
  SELECT count(*) INTO seen FROM public.school_admissions WHERE id=admission_a;
  IF seen<>0 THEN RAISE EXCEPTION 'Admin B sees school A student'; END IF;

  -- Revoke B's school membership, even a matching requested school_id must fail.
  EXECUTE 'RESET ROLE';
  UPDATE public.school_memberships SET membership_status='revoked'
    WHERE school_id=school_b AND user_id=admin_b;
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO seen FROM public.schools WHERE id=school_b;
  IF seen<>0 THEN RAISE EXCEPTION 'Revoked admin can still see school'; END IF;
  EXECUTE 'RESET ROLE';
END;
$test$;
ROLLBACK;