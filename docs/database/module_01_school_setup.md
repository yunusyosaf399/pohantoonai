# Module 01.3 — School Setup (Step 3 of 6)

> **Target:** Pohantoon AI, single Supabase development project `umlzqlbakfwzgadafhyy` in YouPro School.  
> **Implementation date:** 2026-11-11.  
> **Database:** **Deployed**, recorded migration `20261111064830` (`secure_school_setup_drafts_and_plan_capacity`).  
> **Flutter:** Responsive school-information form committed for Android/iOS, tablet and desktop/Web; **compilation and device visual tests still pending** due GitHub Actions billing/runner admission blocker.

## User journey

```text
Step 1: Google/email Supabase Auth
    ↓
Step 2: select an active plan
    → saves public.onboarding_plan_selections[user_id]
    ↓
Step 3: school details
    → loads own public.school_setup_drafts[user_id] if present
    → Save Draft: even incomplete information stored as draft
    → Continue to Review: required fields, format and capacity checks
    → server rejects forged account, invalid fields and plan overages
    → saves ready_for_review (NOT submitted/approved)
    ↓
Step 4: responsive Application Review with section-level Edit buttons
    → accuracy checkbox and server-verified review acknowledgement
    → Go to Payment opens safe Step 5 preview
    → operator submission/review and real payment NOT YET IMPLEMENTED
```

**Neither Step 3 nor Step 4 creates a school, accepts payment, activates a plan, grants tenant access or submits a review application.** The user-facing review step is deliberately labelled preview until its own server-side submission workflow exists.

## Reference UX implemented

Six supplied references established a common light/dark visual system: mobile form cards, tablet-responsive sections, full-window desktop form, and desktop sidebar with six onboarding stages. Actual Flutter uses adaptive layout rather than separate per-platform pages.

- Four sections: School Identity, Primary Contact, Location & Preferences, Academics & Capacity.
- Step 3 of 6 progress, selected-plan summary (live data), information banner clarifying no payment.
- Authenticated account email displayed **read-only**, not entered as a business contact email.
- Editable contact email and optional alternate contact information.
- Required fields visibly marked; optional fields clearly indicated.
- Country dropdown plus **Other ISO code**, global time zones plus custom IANA zone, multi-currency options plus custom ISO code.
- Editable education board/curriculum for international school systems; grade ranges and multi-select teaching languages with a custom language entry.
- Save Draft / Back / Continue to Review; unsaved-change warning, loading/retry and safe error messages.
- Same existing `ThemeController` Light, Dark, System support across devices.

## Field groups in the database

All fields are in **one** owner-scoped draft table. This is intentional: pending applicants do not yet have a `school_id` or campuses, so splitting these drafts across production `schools` / `campuses` / `students` tables would create incomplete tenants.

| UI section | Columns of `public.school_setup_drafts` | Required to advance |
|---|---|---|
| Identity | `school_name`, `legal_school_name`, `school_type`, `registration_license_number`, `established_year`, `website_url` | school name and type |
| Primary Contact | `contact_name`, `contact_position`, `contact_email`, `contact_phone` | contact name and school email |
| Location | `country_code`, `region`, `city`, `street_address`, `postal_code`, `timezone`, `currency_code` | country and city; timezone/currency have safe defaults |
| Academics | `estimated_students`, `campus_count`, `estimated_teachers`, `estimated_non_teaching_staff`, `education_board`, `curriculum`, `lowest_grade`, `highest_grade`, `teaching_languages` | student estimate (positive) and campus count (at least 1) |
| Internal state | `user_id`, `draft_status`, `created_at`, `updated_at` | owner-only auth ID and controlled status |

`contact_email` is the school's official contact address; the Google/email login identity remains in managed Supabase Auth. We do **not** copy or trust user-editable JWT metadata for authorization.

## Integrity and least privilege

SQL source: [`supabase/schema/05_school_setup_drafts.sql`](../../supabase/schema/05_school_setup_drafts.sql).

- Primary key `user_id`, with foreign key to `public.onboarding_plan_selections.user_id`. This means there must be a saved Step 2 choice before a Step 3 draft exists.
- RLS enabled, only `authenticated` receives `SELECT/INSERT/UPDATE`; **no anon grants**, no `DELETE`.
- Three owner-row policies compare `user_id = (select auth.uid())` on read/write. An authenticated stranger cannot insert, read or update a different person's draft.
- `school_setup_draft_validate()` is a **SECURITY INVOKER** trigger with a fixed empty search path and revoked direct EXECUTE. It stamps server timestamps, then checks the chosen active plan's student, campus and total staff limits when status is `ready_for_review`.
- Required-field, enum, email/HTTPS, numeric, ISO code and length checks are independently enforced in PostgreSQL. Saving an incomplete draft is allowed; marking it ready is not.
- `school_setup_draft_reset_on_plan_change()` automatically clears `ready_for_review` when Step 2 plan changes. The saved information is not lost, but must be revalidated.
- No public SECURITY DEFINER RPC, no service-role key in Flutter, no server-side webhook or Edge Function needed for draft CRUD.
- Review-ready status does **not** represent approval, payment, or provisioned tenant status. Later Step 4 approval/promotion will use a separate protected server-side transaction, not a direct client update to private `platform` tables.

## Error paths and edge cases

- Loading a draft fails: retry action is shown and the form remains disabled; existing data is never silently overwritten.
- User saves incomplete identity or address: accepted as `draft`, with no false approval.
- User attempts review without required inputs: validation summary, no network write.
- Student/campus/staff counts exceed selected plan: local warning and independent server rejection; user may edit estimates or choose another plan.
- Invalid email, year, website, currency code or ISO country code: validation feedback.
- A stale/expired user session: no plan or draft access.
- Network save failure: user stays in Step 3 with a retry message; no false success.
- Unsaved inputs and back: an explicit discard warning.
- Switching to a smaller plan after review-ready: resets the state to draft, preserving entered information.
- User deletion or withdrawal of selected plan: cascading dependent draft ownership; no stranded `school_id` record.
- Country/time zone/board/curriculum: global and extensible; no assumption that all schools follow one country or language.

## Live verification

- [x] Database migration applied to existing single project.
- [x] Draft table RLS enabled; authenticated grants `SELECT, INSERT, UPDATE` only, no anonymous grant.
- [x] SQL test run against simulated authenticated user, inside `BEGIN ... ROLLBACK`:
  - incomplete draft saved,
  - missing essential fields blocked at review stage,
  - forged user ID denied,
  - over-plan student estimate blocked,
  - valid review-ready draft accepted,
  - changing plans reset status back to draft.
- [x] Test transaction rolled back; no fake school application left in production-like records.
- [ ] Flutter analyze/widget tests written, but not executed in this session (GitHub Actions blocked at job admission by billing).
- [ ] Real device layout tests for 320px mobile, iPhone, tablet, Windows, Web and Google/email login.
- [ ] Step 4 explicit submission workflow, audit trail, attachments, idempotency, operator review and school provisioning.

## Source files

- [`lib/features/onboarding/domain/school_setup_draft.dart`](../../lib/features/onboarding/domain/school_setup_draft.dart)
- [`lib/features/onboarding/data/school_setup_repository.dart`](../../lib/features/onboarding/data/school_setup_repository.dart)
- [`lib/features/onboarding/presentation/school_setup_screen.dart`](../../lib/features/onboarding/presentation/school_setup_screen.dart)
- [`lib/features/onboarding/presentation/school_review_preview.dart`](../../lib/features/onboarding/presentation/school_review_preview.dart)
- [`test/onboarding/school_setup_test.dart`](../../test/onboarding/school_setup_test.dart)
- [`test/onboarding/plan_app_navigation_test.dart`](../../test/onboarding/plan_app_navigation_test.dart)
- [`supabase/tests/05_school_setup_security.sql`](../../supabase/tests/05_school_setup_security.sql)

**Next:** The [Step 4 review screen and own-account acknowledgement](module_01_application_review.md) are now implemented. Step 5 requires a verified payment provider and protected billing/server workflow; operator approval remains a separate unimplemented module. The Step 3 draft's ready marker is not an approval decision.

### Step 4 reference compatibility — postal code

Additional migration [`supabase/schema/07_school_setup_postal_code.sql`](../../supabase/schema/07_school_setup_postal_code.sql) adds a nullable postal code of at most 32 characters so the School Location review shows genuine persisted user data, rather than synthetic sample addresses. Deployed as `20261111120829` and verified in the live schema without touching prior draft records.


### School logo addition — 2026-11-11

[Private logo schema](../../supabase/schema/09_school_logo_storage.sql) deployed as migration 20261111125611. Step 3 now has an owner-only Choose/Replace/Remove logo field, with path persisted on the applicant school draft. Supported types: JPEG, PNG, WebP up to 2 MiB. Upload uses a private bucket, and preview uses a short-lived signed URL. Only saved draft path persists, not image bytes; adding/changing requires saving the form, and edits made from the Step 6 profile menu require a new Step 4 review. See [dashboard implementation contract](module_02_school_dashboard.md).
