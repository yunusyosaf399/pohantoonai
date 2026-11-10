# Proposed Database Table Catalog — For Approval

> **Status:** [Awaiting Owner Approval] · **Version:** 0.1 · **Prepared:** 2026-11-10  
> **Target:** `yunusyosaf399/pohantoonai`, single Supabase project / many independent school tenants.  
> **Source:** [EduSync feature catalog](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/requirements/FEATURE_CATALOG_AND_STATUS.md), [EduSync database coverage matrix](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/database/DATABASE_COMPLETION_MATRIX.md), and [new architecture](database_schema.md).

## Decision requested

Review **383 candidate application tables in 30 domains**. The catalog is deliberately comprehensive, including deferred and optional features. **Proposed names are not yet approved, created, migrated or deployed.** Approval of this catalog means agreement to an overall feature/data vocabulary, **not** approval to deploy every table in one giant migration.

**Not in this document:** SQL columns/types, functions, triggers, RLS policies, exception/error codes, relationships/foreign keys, indexes, RPCs, Flutter UI behavior, migration execution. Those are separate later design and implementation steps. Supabase-managed `auth.users`, `storage.objects` and other managed tables are **not duplicates** in this catalog.

**Recommendation for parallel work:** (A) Freeze candidate table names with owner approval; (B) database session prepares **small batches of base tables + core tenant keys** in an isolated, non-exposed development schema; (C) Flutter session builds feature-first screens and data models against a **versioned mock repository contract**; (D) once safe authenticated APIs, RLS, cross-school checks and required relationships exist, switch Flutter from mocks to live Supabase. **Do not expose raw tenant data without RLS**, even in a shared development project; table creation alone does not confer app access. Insecure scaffolding must never be promoted to shared staging/production.

### Priority meanings

| Tier | Meaning | When to create |
|---|---|---|
| **P0 — Foundation** | Schools, identities, settings, students, enrollments, academic skeleton and personnel | First approved, ordered base-table batches |
| **P1 — Product feature** | Admissions, curriculum, teaching, attendance, learning, exams, finance, payroll, documents, communications and workflows | Subsequent bounded module batches, after shared names are frozen |
| **P2 — Optional / future** | Library, transport, hostel, medical, AI, inventory and integrations | **Catalog now, defer physical tables** until the module and its product requirements are approved |

> Priority is a **default per domain**, not a promise to create all tables in that domain at once. Individual table decisions may be marked `KEEP`, `MERGE`, `RENAME` or `DEFER` during review. School business data will eventually use `school_id`; truly global SaaS catalog data is a documented exception. The constraint details belong in the next schema phase.

## Summary

| Group | Domain | Tier | Candidates | Approval |
|---|---|---|---:|---|
| 01 | [SaaS platform & subscriptions](#group-01) | P0 | 13 | [Pending] |
| 02 | [Accounts, membership & roles](#group-02) | P0 | 12 | [Pending] |
| 03 | [School configuration & campuses](#group-03) | P0 | 13 | [Pending] |
| 04 | [Academic structure](#group-04) | P0 | 12 | [Pending] |
| 05 | [Admissions](#group-05) | P1 | 13 | [Pending] |
| 06 | [Students & profiles](#group-06) | P0 | 12 | [Pending] |
| 07 | [Families & guardians](#group-07) | P0 | 10 | [Pending] |
| 08 | [Student enrollments & promotion](#group-08) | P0 | 10 | [Pending] |
| 09 | [Staff, employees & personnel](#group-09) | P0 | 14 | [Pending] |
| 10 | [Curriculum, subjects & teaching](#group-10) | P1 | 13 | [Pending] |
| 11 | [Calendar, periods & timetable](#group-11) | P1 | 13 | [Pending] |
| 12 | [Student attendance](#group-12) | P1 | 11 | [Pending] |
| 13 | [Homework & classroom learning](#group-13) | P1 | 12 | [Pending] |
| 14 | [Online quizzes & tests](#group-14) | P1 | 12 | [Pending] |
| 15 | [Exams, grading & results](#group-15) | P1 | 17 | [Pending] |
| 16 | [Fee configuration, charges & invoices](#group-16) | P1 | 16 | [Pending] |
| 17 | [Payments, balances & accounts](#group-17) | P1 | 17 | [Pending] |
| 18 | [Employee attendance & leave](#group-18) | P1 | 13 | [Pending] |
| 19 | [Salary & payroll](#group-19) | P1 | 15 | [Pending] |
| 20 | [Library](#group-20) | P2 | 12 | [Pending] |
| 21 | [Transport & vehicles](#group-21) | P2 | 13 | [Pending] |
| 22 | [Hostel & boarding](#group-22) | P2 | 11 | [Pending] |
| 23 | [Medical & student wellbeing](#group-23) | P2 | 12 | [Pending] |
| 24 | [Documents & file registry](#group-24) | P1 | 13 | [Pending] |
| 25 | [Announcements & communications](#group-25) | P1 | 14 | [Pending] |
| 26 | [Approvals, activity & automation records](#group-26) | P1 | 15 | [Pending] |
| 27 | [Reporting & dashboard configuration](#group-27) | P1 | 9 | [Pending] |
| 28 | [AI learning & assistants](#group-28) | P2 | 10 | [Pending] |
| 29 | [Inventory, suppliers & maintenance](#group-29) | P2 | 13 | [Pending] |
| 30 | [Integrations, offline & migration](#group-30) | P2 | 13 | [Pending] |
| **Total** | **30 domains** | — | **383** | **[Pending]** |

**Candidate count by tier:** P0 96 · P1 203 · P2 84.

## Complete candidate list

<a id="group-01"></a>

### 01. SaaS platform & subscriptions — P0 (13)

- [ ] **01.01** `schools` — Tenant root.
- [ ] **01.02** `platform_operators` — SaaS operator accounts.
- [ ] **01.03** `school_onboarding_requests` — Prospective school registration.
- [ ] **01.04** `subscription_plans` — Versioned plan catalog.
- [ ] **01.05** `subscription_plan_features` — Plan feature catalog.
- [ ] **01.06** `school_subscriptions` — School subscription state.
- [ ] **01.07** `subscription_periods` — Renewal and billing periods.
- [ ] **01.08** `subscription_charges` — SaaS invoices/charges.
- [ ] **01.09** `subscription_transactions` — Verified SaaS payments.
- [ ] **01.10** `school_entitlements` — Effective purchased capabilities.
- [ ] **01.11** `school_usage_snapshots` — Metered SaaS usage.
- [ ] **01.12** `school_subscription_events` — Subscription history.
- [ ] **01.13** `school_support_requests` — Customer support cases.

<a id="group-02"></a>

### 02. Accounts, membership & roles — P0 (12)

- [ ] **02.01** `user_profiles` — Supabase Auth-linked public profile.
- [ ] **02.02** `people` — Person anchor.
- [ ] **02.03** `school_memberships` — Account enrollment in schools.
- [ ] **02.04** `school_invitations` — Staff/parent invitations.
- [ ] **02.05** `school_roles` — Tenant-defined roles.
- [ ] **02.06** `permission_definitions` — Application permission vocabulary.
- [ ] **02.07** `role_permissions` — Role-permission assignments.
- [ ] **02.08** `membership_role_assignments` — A user's multiple school roles.
- [ ] **02.09** `membership_permission_scopes` — Role grant scope records.
- [ ] **02.10** `user_login_aliases` — School-aware usernames.
- [ ] **02.11** `identity_binding_history` — Auth identity link history.
- [ ] **02.12** `school_access_requests` — Requests to join school.

<a id="group-03"></a>

### 03. School configuration & campuses — P0 (13)

- [ ] **03.01** `school_profiles` — School configuration.
- [ ] **03.02** `school_addresses` — Official and campus addresses.
- [ ] **03.03** `school_contacts` — Contact directory.
- [ ] **03.04** `school_branding` — School logos and appearance.
- [ ] **03.05** `school_settings` — Current configuration.
- [ ] **03.06** `school_setting_revisions` — Historical settings.
- [ ] **03.07** `campuses` — School campus sites.
- [ ] **03.08** `campus_buildings` — Campus buildings.
- [ ] **03.09** `campus_rooms` — Rooms and room types.
- [ ] **03.10** `room_resources` — Room equipment.
- [ ] **03.11** `school_module_settings` — Enabled modules.
- [ ] **03.12** `school_number_sequences` — Configurable number generation.
- [ ] **03.13** `school_localization_settings` — Locale and formatting preferences.

<a id="group-04"></a>

### 04. Academic structure — P0 (12)

- [ ] **04.01** `academic_years` — School years.
- [ ] **04.02** `academic_terms` — Semesters and terms.
- [ ] **04.03** `education_levels` — Configurable level structure.
- [ ] **04.04** `class_definitions` — School class catalog.
- [ ] **04.05** `class_offerings` — Class offered in a year.
- [ ] **04.06** `section_offerings` — Actual class sections.
- [ ] **04.07** `section_capacity_revisions` — Capacity history.
- [ ] **04.08** `section_room_assignments` — Classroom placement history.
- [ ] **04.09** `student_groups` — Study and activity groups.
- [ ] **04.10** `student_group_memberships` — Membership in student groups.
- [ ] **04.11** `academic_grading_levels` — Display-grade scale names.
- [ ] **04.12** `academic_year_transitions` — Year rollover plans.

<a id="group-05"></a>

### 05. Admissions — P1 (13)

- [ ] **05.01** `admission_cycles` — Enrollment intake windows.
- [ ] **05.02** `admission_forms` — Application form versions.
- [ ] **05.03** `admission_form_fields` — Custom form fields.
- [ ] **05.04** `admission_applications` — Applicant submissions.
- [ ] **05.05** `admission_applicants` — Applicant identities.
- [ ] **05.06** `admission_applicant_contacts` — Guardian contact submitted.
- [ ] **05.07** `admission_stage_templates` — Configurable workflow stages.
- [ ] **05.08** `admission_stage_events` — Stage completion and skips.
- [ ] **05.09** `admission_assessments` — Admission test outcomes.
- [ ] **05.10** `admission_interviews` — Interview outcomes.
- [ ] **05.11** `admission_offers` — Offers and deadlines.
- [ ] **05.12** `admission_decisions` — Formal acceptance or rejection.
- [ ] **05.13** `admission_handoffs` — Student creation handoff.

<a id="group-06"></a>

### 06. Students & profiles — P0 (12)

- [ ] **06.01** `students` — Student identity.
- [ ] **06.02** `student_private_details` — Sensitive student fields.
- [ ] **06.03** `student_addresses` — Student residence history.
- [ ] **06.04** `student_contacts` — Student contact channels.
- [ ] **06.05** `student_status_history` — Active and past status.
- [ ] **06.06** `student_identity_documents` — ID document metadata.
- [ ] **06.07** `student_profile_photos` — Profile photo history.
- [ ] **06.08** `student_emergency_contacts` — Approved emergency contacts.
- [ ] **06.09** `student_notes` — Authorized student notes.
- [ ] **06.10** `student_custom_fields` — School-defined profile field types.
- [ ] **06.11** `student_custom_values` — Student field values.
- [ ] **06.12** `student_language_preferences` — Student language choices.

<a id="group-07"></a>

### 07. Families & guardians — P0 (10)

- [ ] **07.01** `families` — School family group.
- [ ] **07.02** `family_accounts` — Shared family login identity.
- [ ] **07.03** `family_account_memberships` — Who can use family identity.
- [ ] **07.04** `guardians` — Individual guardian records.
- [ ] **07.05** `student_guardian_relationships` — Child-to-guardian historical links.
- [ ] **07.06** `guardian_child_access` — Granted child-portal visibility.
- [ ] **07.07** `guardian_contact_preferences` — Guardian contact selections.
- [ ] **07.08** `student_pickup_authorizations` — Approved pickup persons.
- [ ] **07.09** `family_relationship_change_requests` — Proposed relationship changes.
- [ ] **07.10** `guardian_custody_notices` — Restricted custody disclosures.

<a id="group-08"></a>

### 08. Student enrollments & promotion — P0 (10)

- [ ] **08.01** `student_enrollments` — School-year enrollment records.
- [ ] **08.02** `enrollment_section_assignments` — Section allocation history.
- [ ] **08.03** `enrollment_roll_assignments` — Roll number history.
- [ ] **08.04** `enrollment_roll_policies` — Roll number rules.
- [ ] **08.05** `enrollment_status_events` — Enrollment state changes.
- [ ] **08.06** `enrollment_transfers` — Cross-section/campus moves.
- [ ] **08.07** `enrollment_promotion_decisions` — Promotion and repetition.
- [ ] **08.08** `enrollment_withdrawals` — Exits and reasons.
- [ ] **08.09** `enrollment_capacity_holds` — Reserved places.
- [ ] **08.10** `student_subject_enrollments` — Individual subject selections.

<a id="group-09"></a>

### 09. Staff, employees & personnel — P0 (14)

- [ ] **09.01** `employees` — Staff identity and employment.
- [ ] **09.02** `employee_private_details` — Sensitive employment information.
- [ ] **09.03** `employee_contacts` — Staff contact information.
- [ ] **09.04** `employee_emergency_contacts` — Staff emergency numbers.
- [ ] **09.05** `departments` — School department catalog.
- [ ] **09.06** `designations` — School job titles.
- [ ] **09.07** `employee_job_assignments` — Position timeline.
- [ ] **09.08** `employee_campus_assignments` — Campus work affiliations.
- [ ] **09.09** `employee_contracts` — Employment contracts.
- [ ] **09.10** `employee_contract_revisions` — Contract history.
- [ ] **09.11** `employee_qualifications` — Qualifications.
- [ ] **09.12** `employee_experience` — Prior experience.
- [ ] **09.13** `employee_certifications` — Licenses and credentials.
- [ ] **09.14** `employee_performance_reviews` — HR reviews.

<a id="group-10"></a>

### 10. Curriculum, subjects & teaching — P1 (13)

- [ ] **10.01** `subjects` — School subject catalog.
- [ ] **10.02** `subject_categories` — Subject classification.
- [ ] **10.03** `curriculum_plans` — Curriculum families.
- [ ] **10.04** `curriculum_revisions` — Yearly curriculum snapshots.
- [ ] **10.05** `curriculum_subjects` — Curriculum subjects.
- [ ] **10.06** `subject_offerings` — Year/class subject delivery.
- [ ] **10.07** `elective_groups` — Choice groups.
- [ ] **10.08** `student_elective_choices` — Selected options.
- [ ] **10.09** `subject_prerequisites` — Required prior subjects.
- [ ] **10.10** `teacher_subject_qualifications` — Teacher permitted subject areas.
- [ ] **10.11** `class_teacher_assignments` — Section class teachers.
- [ ] **10.12** `subject_teacher_assignments` — Teacher subject-section assignments.
- [ ] **10.13** `teaching_assignment_history` — Teaching change history.

<a id="group-11"></a>

### 11. Calendar, periods & timetable — P1 (13)

- [ ] **11.01** `school_calendar_events` — School-wide events.
- [ ] **11.02** `calendar_event_audiences` — Intended groups.
- [ ] **11.03** `school_holidays` — School holiday dates.
- [ ] **11.04** `term_calendar_days` — Term day overrides.
- [ ] **11.05** `day_schedule_templates` — Working-day patterns.
- [ ] **11.06** `period_definitions` — Bell times and periods.
- [ ] **11.07** `teacher_availability` — Teacher schedule restrictions.
- [ ] **11.08** `timetable_versions` — Timetable publication versions.
- [ ] **11.09** `timetable_entries` — Scheduled lessons.
- [ ] **11.10** `room_bookings` — Room reservations.
- [ ] **11.11** `teacher_substitutions` — Cover teachers.
- [ ] **11.12** `timetable_generation_runs` — Automatic timetable proposals.
- [ ] **11.13** `timetable_change_requests` — Schedule changes.

<a id="group-12"></a>

### 12. Student attendance — P1 (11)

- [ ] **12.01** `student_attendance_policies` — School attendance rules.
- [ ] **12.02** `attendance_session_templates` — Daily capture patterns.
- [ ] **12.03** `student_attendance_sessions` — Official attendance sessions.
- [ ] **12.04** `attendance_roster_snapshots` — Roster at capture.
- [ ] **12.05** `student_attendance_marks` — Official student marks.
- [ ] **12.06** `attendance_capture_events` — Manual/QR/device source submissions.
- [ ] **12.07** `student_attendance_corrections` — Correction history.
- [ ] **12.08** `student_attendance_excuses` — Absence explanation.
- [ ] **12.09** `qr_attendance_challenges` — QR attendance challenge metadata.
- [ ] **12.10** `attendance_summary_snapshots` — Calculated attendance summaries.
- [ ] **12.11** `attendance_daily_closures` — Locked attendance days.

<a id="group-13"></a>

### 13. Homework & classroom learning — P1 (12)

- [ ] **13.01** `lesson_plans` — Teacher lesson planning.
- [ ] **13.02** `learning_units` — Grouped curriculum lessons.
- [ ] **13.03** `learning_resources` — Attached learning materials.
- [ ] **13.04** `homework_assignments` — Teacher assignments.
- [ ] **13.05** `homework_recipients` — Assigned students.
- [ ] **13.06** `homework_submissions` — Student responses.
- [ ] **13.07** `homework_feedback` — Teacher review and feedback.
- [ ] **13.08** `project_groups` — Project collaboration teams.
- [ ] **13.09** `project_group_members` — Group membership.
- [ ] **13.10** `rubric_definitions` — Assessment rubrics.
- [ ] **13.11** `rubric_criteria` — Rubric dimensions.
- [ ] **13.12** `student_learning_progress` — Progress against objectives.

<a id="group-14"></a>

### 14. Online quizzes & tests — P1 (12)

- [ ] **14.01** `question_banks` — Reusable question pools.
- [ ] **14.02** `question_bank_items` — Versioned questions.
- [ ] **14.03** `question_options` — MCQ / true-false choices.
- [ ] **14.04** `question_tags` — Question taxonomy.
- [ ] **14.05** `online_test_definitions` — Quiz configuration.
- [ ] **14.06** `online_test_versions` — Published quiz revisions.
- [ ] **14.07** `online_test_questions` — Question instances.
- [ ] **14.08** `online_test_assignments` — Eligible participants.
- [ ] **14.09** `online_test_attempts` — Individual attempts.
- [ ] **14.10** `online_test_answers` — Student submitted answers.
- [ ] **14.11** `online_test_scores` — Objective/manual scored result.
- [ ] **14.12** `online_test_proctor_events` — Attempt integrity markers.

<a id="group-15"></a>

### 15. Exams, grading & results — P1 (17)

- [ ] **15.01** `exam_types` — Configurable examination types.
- [ ] **15.02** `exam_sessions` — Exam periods.
- [ ] **15.03** `exam_schedules` — Exam dates and rooms.
- [ ] **15.04** `exam_assessments` — Actual assessment tasks.
- [ ] **15.05** `exam_components` — Theory/practical components.
- [ ] **15.06** `exam_candidate_entries` — Eligible students.
- [ ] **15.07** `mark_entries` — Assessed marks.
- [ ] **15.08** `mark_entry_revisions` — Mark corrections.
- [ ] **15.09** `grading_schemes` — School grading systems.
- [ ] **15.10** `grade_band_definitions` — Mark to grade bands.
- [ ] **15.11** `gpa_policies` — GPA calculation versions.
- [ ] **15.12** `passing_policies` — Passing criteria.
- [ ] **15.13** `result_calculation_runs` — Reproducible computations.
- [ ] **15.14** `result_publications` — Published result batches.
- [ ] **15.15** `student_result_snapshots` — Historical result states.
- [ ] **15.16** `result_corrections` — Reviewed changes after publish.
- [ ] **15.17** `student_promotion_results` — Final progression outcomes.

<a id="group-16"></a>

### 16. Fee configuration, charges & invoices — P1 (16)

- [ ] **16.01** `fee_types` — School charge categories.
- [ ] **16.02** `fee_structures` — Fee plan families.
- [ ] **16.03** `fee_structure_versions` — Effective fee rules.
- [ ] **16.04** `fee_structure_lines` — Configured amounts.
- [ ] **16.05** `fee_assignments` — Fee applicability to students/groups.
- [ ] **16.06** `billing_periods` — Fee billing cycles.
- [ ] **16.07** `student_fee_charges` — Actual owed amounts.
- [ ] **16.08** `student_charge_adjustments` — Changes to assessed fees.
- [ ] **16.09** `discount_policies` — Discount calculation rules.
- [ ] **16.10** `student_discounts` — Student discount awards.
- [ ] **16.11** `scholarship_programs` — Scholarship schemes.
- [ ] **16.12** `student_scholarships` — Scholarship awards.
- [ ] **16.13** `late_fee_policies` — Late charge rules.
- [ ] **16.14** `invoices` — Issued invoices.
- [ ] **16.15** `invoice_lines` — Invoice charge details.
- [ ] **16.16** `invoice_revisions` — Immutable invoice changes.

<a id="group-17"></a>

### 17. Payments, balances & accounts — P1 (17)

- [ ] **17.01** `payment_evidence` — Unverified payment proof.
- [ ] **17.02** `payment_verifications` — Review of submitted proof.
- [ ] **17.03** `student_payments` — Confirmed payments.
- [ ] **17.04** `payment_allocations` — Amounts applied to charges.
- [ ] **17.05** `student_credit_accounts` — Advance/overpayment balances.
- [ ] **17.06** `student_credit_movements` — Credit ledger.
- [ ] **17.07** `payment_refunds` — Refund records.
- [ ] **17.08** `payment_reversals` — Reversal histories.
- [ ] **17.09** `student_payment_receipts` — Issued official receipts.
- [ ] **17.10** `finance_bank_accounts` — School payment receiving accounts.
- [ ] **17.11** `cash_registers` — Cash collection points.
- [ ] **17.12** `cash_register_sessions` — Cashier opening/closing.
- [ ] **17.13** `finance_reconciliation_batches` — Bank reconciliation windows.
- [ ] **17.14** `finance_reconciliation_items` — Matched transaction lines.
- [ ] **17.15** `general_ledger_accounts` — Optional chart of accounts.
- [ ] **17.16** `journal_entries` — Optional accounting movements.
- [ ] **17.17** `journal_entry_lines` — Optional double-entry lines.

<a id="group-18"></a>

### 18. Employee attendance & leave — P1 (13)

- [ ] **18.01** `employee_work_shifts` — Available shifts.
- [ ] **18.02** `employee_shift_assignments` — Shift schedule records.
- [ ] **18.03** `employee_attendance_sessions` — Daily staff attendance.
- [ ] **18.04** `employee_attendance_marks` — Present/absent/time marks.
- [ ] **18.05** `employee_attendance_corrections` — Staff time correction history.
- [ ] **18.06** `employee_overtime_requests` — Extra work requests.
- [ ] **18.07** `leave_types` — Leave catalog.
- [ ] **18.08** `leave_policy_versions` — Effective leave entitlement rules.
- [ ] **18.09** `employee_leave_balances` — Accrued leave.
- [ ] **18.10** `employee_leave_requests` — Time-off applications.
- [ ] **18.11** `student_leave_requests` — Student leave applications.
- [ ] **18.12** `leave_decisions` — Leave approval outcomes.
- [ ] **18.13** `leave_calendar_entries` — Approved leave calendar blocks.

<a id="group-19"></a>

### 19. Salary & payroll — P1 (15)

- [ ] **19.01** `salary_structures` — Compensation templates.
- [ ] **19.02** `employee_compensation` — Current salary arrangements.
- [ ] **19.03** `employee_compensation_revisions` — Pay-change history.
- [ ] **19.04** `payroll_component_types` — Allowances/deductions.
- [ ] **19.05** `payroll_periods` — Pay cycles.
- [ ] **19.06** `payroll_runs` — Monthly payroll batches.
- [ ] **19.07** `payroll_run_employees` — Employee payroll snapshots.
- [ ] **19.08** `payroll_run_components` — Per-employee pay details.
- [ ] **19.09** `payroll_adjustments` — Manual payroll corrections.
- [ ] **19.10** `payroll_approvals` — Payroll signoff.
- [ ] **19.11** `payroll_disbursements` — Payments sent to employees.
- [ ] **19.12** `employee_salary_advances` — Salary advances.
- [ ] **19.13** `employee_loans` — Employee loans.
- [ ] **19.14** `employee_loan_repayments` — Loan repayments.
- [ ] **19.15** `payslip_issuances` — Issued payslip receipts.

<a id="group-20"></a>

### 20. Library — P2 (12)

- [ ] **20.01** `library_titles` — Book and resource titles.
- [ ] **20.02** `library_authors` — Author catalog.
- [ ] **20.03** `library_title_authors` — Multi-author mappings.
- [ ] **20.04** `library_categories` — Shelf taxonomy.
- [ ] **20.05** `library_publishers` — Publisher records.
- [ ] **20.06** `library_copies` — Physical book copies.
- [ ] **20.07** `library_loans` — Borrow and return lifecycle.
- [ ] **20.08** `library_loan_renewals` — Due-date extensions.
- [ ] **20.09** `library_reservations` — Book holds.
- [ ] **20.10** `library_acquisitions` — New purchases/donations.
- [ ] **20.11** `library_fines` — Overdue/loss charges.
- [ ] **20.12** `library_inventory_checks` — Stocktake verification.

<a id="group-21"></a>

### 21. Transport & vehicles — P2 (13)

- [ ] **21.01** `transport_vehicles` — Bus/van fleet.
- [ ] **21.02** `transport_drivers` — Approved drivers.
- [ ] **21.03** `transport_vehicle_assignments` — Driver vehicle history.
- [ ] **21.04** `transport_routes` — Route definitions.
- [ ] **21.05** `transport_route_versions` — Route revisions.
- [ ] **21.06** `transport_stops` — Pickup/drop stops.
- [ ] **21.07** `transport_route_stops` — Stop ordering and timing.
- [ ] **21.08** `student_transport_assignments` — Student transport eligibility.
- [ ] **21.09** `transport_trip_schedules` — Planned trips.
- [ ] **21.10** `transport_trips` — Actual journeys.
- [ ] **21.11** `transport_boarding_events` — Boarding and dropoff history.
- [ ] **21.12** `vehicle_maintenance_records` — Vehicle service history.
- [ ] **21.13** `transport_gps_points` — Future telemetry coordinates.

<a id="group-22"></a>

### 22. Hostel & boarding — P2 (11)

- [ ] **22.01** `hostels` — Hostel sites.
- [ ] **22.02** `hostel_buildings` — Boarding blocks.
- [ ] **22.03** `hostel_floors` — Building floors.
- [ ] **22.04** `hostel_rooms` — Bedrooms.
- [ ] **22.05** `hostel_beds` — Individual beds.
- [ ] **22.06** `hostel_allocations` — Student occupancy periods.
- [ ] **22.07** `hostel_attendance` — Night check-ins.
- [ ] **22.08** `hostel_visitors` — Visitor visits.
- [ ] **22.09** `hostel_leave_permissions` — Approved temporary absences.
- [ ] **22.10** `hostel_incidents` — Boarding incidents.
- [ ] **22.11** `hostel_inspections` — Room inspection results.

<a id="group-23"></a>

### 23. Medical & student wellbeing — P2 (12)

- [ ] **23.01** `student_health_profiles` — Sensitive health summary.
- [ ] **23.02** `student_health_conditions` — Diagnosed/known conditions.
- [ ] **23.03** `student_allergies` — Allergy records.
- [ ] **23.04** `student_vaccinations` — Vaccination history.
- [ ] **23.05** `student_medications` — Medication schedules.
- [ ] **23.06** `medical_encounters` — Clinic encounters.
- [ ] **23.07** `medical_incidents` — School health incidents.
- [ ] **23.08** `medical_treatment_events` — Treatment history.
- [ ] **23.09** `medical_consents` — Care permissions.
- [ ] **23.10** `student_vital_readings` — Health observations.
- [ ] **23.11** `counseling_sessions` — Sensitive wellbeing encounters.
- [ ] **23.12** `clinic_stock_movements` — Clinic supply movement.

<a id="group-24"></a>

### 24. Documents & file registry — P1 (13)

- [ ] **24.01** `file_objects` — Provider-neutral file metadata.
- [ ] **24.02** `file_upload_intents` — Authorized upload staging.
- [ ] **24.03** `file_purpose_catalog` — Known business file purposes.
- [ ] **24.04** `file_domain_links` — File connection to business record.
- [ ] **24.05** `document_templates` — Editable document templates.
- [ ] **24.06** `document_template_versions` — Versioned print templates.
- [ ] **24.07** `document_issuances` — Certificates/cards/letters issued.
- [ ] **24.08** `document_verification_tokens` — Publicly verifiable issued records.
- [ ] **24.09** `document_share_grants` — Time-bounded document sharing.
- [ ] **24.10** `file_storage_movements` — Storage lifecycle history.
- [ ] **24.11** `student_id_cards` — Issued student cards.
- [ ] **24.12** `employee_id_cards` — Issued employee cards.
- [ ] **24.13** `file_storage_usage` — Storage usage aggregation.

<a id="group-25"></a>

### 25. Announcements & communications — P1 (14)

- [ ] **25.01** `announcement_posts` — Published school messages.
- [ ] **25.02** `announcement_audiences` — Who should see an announcement.
- [ ] **25.03** `notification_templates` — Message templates.
- [ ] **25.04** `notifications` — In-app notifications.
- [ ] **25.05** `notification_recipients` — Exact recipient list.
- [ ] **25.06** `notification_preferences` — Channel opt-ins.
- [ ] **25.07** `notification_delivery_attempts` — Delivery status.
- [ ] **25.08** `message_threads` — Parent/teacher conversations.
- [ ] **25.09** `message_participants` — Thread membership.
- [ ] **25.10** `messages` — Individual messages.
- [ ] **25.11** `message_attachments` — Files on messages.
- [ ] **25.12** `push_device_tokens` — Mobile notification endpoints.
- [ ] **25.13** `parent_teacher_meetings` — PTM sessions.
- [ ] **25.14** `meeting_appointments` — Booked meeting slots.

<a id="group-26"></a>

### 26. Approvals, activity & automation records — P1 (15)

- [ ] **26.01** `approval_policies` — Named approval workflows.
- [ ] **26.02** `approval_policy_versions` — Workflow changes.
- [ ] **26.03** `approval_steps` — Configured approval stages.
- [ ] **26.04** `approval_requests` — Submitted workflow items.
- [ ] **26.05** `approval_decisions` — Approver outcomes.
- [ ] **26.06** `approval_transition_history` — Immutable workflow transitions.
- [ ] **26.07** `command_receipts` — Idempotent business operation receipts.
- [ ] **26.08** `audit_events` — School business change history.
- [ ] **26.09** `domain_events` — Committed business events.
- [ ] **26.10** `outbox_messages` — Pending external notifications.
- [ ] **26.11** `outbox_delivery_attempts` — Delivery attempts.
- [ ] **26.12** `automation_rules` — Configured automations.
- [ ] **26.13** `automation_rule_versions` — Versioned automation logic.
- [ ] **26.14** `scheduled_actions` — Future work orders.
- [ ] **26.15** `scheduled_action_runs` — Execution outcomes.

<a id="group-27"></a>

### 27. Reporting & dashboard configuration — P1 (9)

- [ ] **27.01** `report_definitions` — Saved report designs.
- [ ] **27.02** `report_filters` — User-created reusable filters.
- [ ] **27.03** `report_schedules` — Recurring report schedules.
- [ ] **27.04** `report_runs` — Generated report records.
- [ ] **27.05** `data_export_jobs` — CSV/Excel/PDF export requests.
- [ ] **27.06** `dashboard_layouts` — Configurable dashboard layouts.
- [ ] **27.07** `dashboard_widgets` — Dashboard components.
- [ ] **27.08** `daily_school_metrics` — Precomputed per-school summaries.
- [ ] **27.09** `student_progress_snapshots` — Historical analytics snapshots.

<a id="group-28"></a>

### 28. AI learning & assistants — P2 (10)

- [ ] **28.01** `ai_assistant_profiles` — Assistant personalities by role.
- [ ] **28.02** `ai_conversations` — Chat sessions.
- [ ] **28.03** `ai_messages` — Messages and metadata.
- [ ] **28.04** `ai_conversation_feedback` — User ratings.
- [ ] **28.05** `ai_usage_records` — Token and cost usage.
- [ ] **28.06** `ai_knowledge_sources` — Permitted content sources.
- [ ] **28.07** `ai_knowledge_documents` — Indexed school-owned document references.
- [ ] **28.08** `ai_prompt_template_versions` — Template history.
- [ ] **28.09** `ai_student_support_signals` — Early warning indicators.
- [ ] **28.10** `ai_model_evaluation_runs` — Quality and safety evaluation.

<a id="group-29"></a>

### 29. Inventory, suppliers & maintenance — P2 (13)

- [ ] **29.01** `asset_categories` — School asset taxonomy.
- [ ] **29.02** `school_assets` — Registered assets.
- [ ] **29.03** `asset_assignments` — Custodian/history.
- [ ] **29.04** `inventory_products` — Stock keeping units.
- [ ] **29.05** `inventory_locations` — Storeroom locations.
- [ ] **29.06** `inventory_stock_movements` — Stock ledger.
- [ ] **29.07** `suppliers` — Supplier directory.
- [ ] **29.08** `purchase_requests` — Procurement requests.
- [ ] **29.09** `purchase_orders` — Approved purchases.
- [ ] **29.10** `goods_receipts` — Received merchandise.
- [ ] **29.11** `stock_counts` — Stock checks.
- [ ] **29.12** `maintenance_tickets` — Repair requests.
- [ ] **29.13** `maintenance_work_orders` — Assigned work.

<a id="group-30"></a>

### 30. Integrations, offline & migration — P2 (13)

- [ ] **30.01** `integration_providers` — External service types.
- [ ] **30.02** `integration_connections` — School integration configuration.
- [ ] **30.03** `integration_external_ids` — Foreign ID mappings.
- [ ] **30.04** `integration_sync_runs` — External sync summaries.
- [ ] **30.05** `integration_inbox_events` — External webhook inbox.
- [ ] **30.06** `registered_devices` — QR/RFID/camera endpoint inventory.
- [ ] **30.07** `device_capture_events` — Untrusted raw device captures.
- [ ] **30.08** `offline_device_registrations` — Authorized offline clients.
- [ ] **30.09** `offline_sync_batches` — Client sync batches.
- [ ] **30.10** `offline_sync_conflicts` — Conflicting offline updates.
- [ ] **30.11** `data_import_jobs` — Bulk import requests.
- [ ] **30.12** `data_import_rows` — Row-by-row import outcomes.
- [ ] **30.13** `legacy_migration_id_map` — Old project/table IDs to new UUIDs.

## Deliberate exclusions and consolidation notes

- **No duplicate Auth schema:** `auth.users` is Supabase-managed; `user_profiles` is application-owned profile information.
- **No separate tables per role dashboard:** Parent, Student, Teacher, Accountant and School Owner get different views of authorized records, not duplicate copies of student/accounting data.
- **No separate QR/manual/biometric attendance truths:** captured events converge on the same canonical attendance records. Future devices are P2.
- **No stored PDF by default:** invoices, receipts, report cards and certificates can be generated from structured records; persist only issuances/templates and approved original uploads.
- **No automatic deletion on plan downgrade:** document storage and business history are retention-managed.
- **Not every catalog item is necessary at MVP:** choose a small vertical slice of P0 to validate school setup → admission/enrollment → teaching → attendance → parent view.
- **Workflow receipts/audit rows are ordinary business/operational tables in this list.** Their policies, functions and enforcement are **not** designed here.

## Approval checklist and next design gates

- [ ] **CAT-01** Accept or revise the domain breakdown (01–30).
- [ ] **CAT-02** Review P0 table names for school creation, accounts, campuses, academic structure, students, families, enrollment and staff.
- [ ] **CAT-03** Decide any P1 tables to bring into the first demo slice, and which P2 features to defer.
- [ ] **CAT-04** Resolve `MERGE` / `RENAME` / `DEFER` proposals and publish an approved catalog version.
- [ ] **CAT-05** Approve the first physical schema batch **separately** (table columns/types and primary keys).
- [ ] **CAT-06** Apply first batch only to a safe isolated development environment; verify the actual catalog.
- [ ] **CAT-07** Expose live Flutter reads/writes only *after* appropriate schema relationships, Auth/RLS and permission tests pass.

**Owner approval is not implied by document creation.** Until CAT-01–CAT-04 are explicitly accepted, all table names are provisional. Change control: any later table addition/rename requires a catalog revision, coordinated schema migration and Flutter contract update; never silently change a name used by another independent session.
