# EduSync — Original Requirements, Questions, Answers, Approval Decisions, and New Questions

**Reconstructed on:** 12 November 2026  
**Project:** EduSync / School OS SaaS  
**Purpose:** A decision register and product-questionnaire reference, not a claim that all features are implemented or production-ready.

## Source and interpretation rules

1. The original 18–19 September 2026 discussion was reconstructed from `Chat_2026-11-12.pdf` (*Branch · School App Requirements Questions*, 351 pages, 64 messages) and the fuller `ChatGPT-School App Requirements Questions-20260928-1624.md` export. The markdown export continues into later September database design work.
2. Later design decisions were checked against the supplied October chat exports and the project conversation history available in this conversation. Some October/November choices appear only in shared project chat history, so they are marked as such.
3. **CONFIRMED** means the user explicitly answered or approved. **PROPOSED** means the assistant suggested it but the specific rule was not decisively accepted. **LATER REFINED** means later project decisions added more specific rules. **OPEN** means missing or contradictory evidence. **SUPERSEDED / REVISIT** marks an older choice challenged by a later one.
4. Approval of a contract, design, documentation or GitHub task **does not prove** that it has been deployed or runtime-tested. Do not confuse source discussions with a fresh repository audit.
5. Where a numbered response says merely “Yes” to a compound question, the answer is summarized conservatively. Sub-elements not clearly settled are flagged for further approval.

## Executive decision record

- **Product:** configurable school operating system for Play Group/Nursery through Grade 12, with school-defined classes, sections, campuses and academic years. Whether post-Grade-12 *college* courses are in the first commercial scope was not separately frozen.
- **Architecture originally approved:** reusable Flutter app, SQL/migrations, RLS/storage/configuration and deployment instructions; initially **one Supabase project/database per customer school**, with multiple campuses inside that school. In November 2026 the user began actively considering **one shared Supabase project for all customer schools using `school_id`**. **This is a proposed architectural change, not an approval to treat old isolated-project SQL as shared-tenant safe.**
- **Five engines:** Data, Permission, Workflow, Automation, AI — user selected modern School Operating System (B).
- **Security:** person distinct from login/account, custom live permission+scope model, approval before designated sensitive changes, independent reviewer where specified, retained audit/history, no role label alone conferring privileges.
- **Students:** complete academic/enrollment/status/roll history; family and emergency-contact relationships; separate current projections from historical facts; controlled corrections.
- **Finance:** flexible fees, discounts and installments; verified bank/wallet evidence; permanent financial transactions and receipts; reversal/correction not destructive deletion; generated PDFs downloaded on demand rather than stored routinely.
- **Delivery:** Flutter Windows desktop `.exe` and Android originally selected; offline support, English first, multi-currency, internationalization-ready.
- **Future/enabled distinctions:** some modules such as inventory, GPS tracking, biometrics, device attendance and WhatsApp were deliberately deferred, although database extensibility was desired.

---

## Part I — Initial module questionnaire (18 September 2026, sections A–AN)

The original questionnaire had **40 module headings (A–AN)** with many subquestions. These tables summarize the user’s response; they do not turn every proposed feature in the assistant’s opening questionnaire into a guaranteed V1 deliverable.

| Ref | Original question/domain | Recorded answer and approval status |
|---|---|---|
| A | Institution type, grades, year, campuses | **CONFIRMED:** customizable Play Group/Nursery–Grade 12; configurable grades/sections; years and histories retained; named multiple campuses. Initial choice between school-only and college scope was ambiguous. |
| B | Users, roles, custom permissions | **CONFIRMED:** Owner, Super Admin, Principal, Vice Principal, Admin, Accountant, HR, Teachers, Coordinator, Librarian, Transport, Driver, Nurse, Students, Parents/Guardians, Security, Maintenance, Exam Controller, initially IT/Admin. Permission and approval engine. |
| C | Student profile, family, status | **CONFIRMED:** identified student, photo, identity and contact data, family, class/section/roll and status; one family account can see multiple children; staff may also be parents; historical statuses retained. |
| D | Admissions | **CONFIRMED:** application, checks, tests/interviews where configured, approval, finance clearance, enrollment and documents/identifiers. **LATER REFINED:** school-led offers, optional admin-approved test skips; failed tests cannot be bypassed; finance clearance mandatory. |
| E | Classes/sections/promotion | **CONFIRMED:** sections, rooms, capacities, timetables, student lists, controlled promotion/repeat/special decisions with history. |
| F | Subjects/curriculum | **CONFIRMED:** school-configured subjects, compulsory/optional/elective structure; different curricula and grading. **LATER REFINED:** curriculum publication and elective-history rules. |
| G | Teachers | **CONFIRMED:** employee profile, qualifications, role assignments, subjects/sections, salary/leave/attendance, dedicated dashboard. |
| H | Attendance | **CONFIRMED:** daily/subject/period reporting ambitions; manual and QR card attendance selected. **LATER REFINED:** initial morning and optionally post-break checkpoints; full biometric/RFID/NFC were not V1 commitments. |
| I | Timetable | **CONFIRMED:** class/subject/teacher/room scheduling and conflict checks; automatic generation with manual adjustment. |
| J | Homework/assignments | **CONFIRMED:** homework, worksheets, projects, quizzes, online tests, uploads, marks, submission, feedback, due/late handling, parent notification. |
| K | Exams/results | **CONFIRMED:** flexible exams, components, grading/GPA/averages/rank, teacher entry, report cards; controlled verification/publication/correction. |
| L | Fees/finance | **CONFIRMED:** fee types, grade/campus/student/year structures, discounts, cash/bank/wallet payments with evidence, partial/advance payments, overdue controls, receipts. |
| M | Parent portal | **CONFIRMED:** children's attendance/results/homework/fees/calendar/etc.; payment proof, leave, messaging, documents, notifications. |
| N | Student portal | **CONFIRMED:** own dashboard for subjects, assignments, results, attendance, learning content, schedules, fees/notices. |
| O | Notifications/communications | **CONFIRMED:** in-app, push, email and event/scheduled messages; WhatsApp later. |
| P | Internal messaging | **CONFIRMED through follow-up:** retained conversations with role-scoped search and access; an admin can clear conversation history subject to the later deletion/audit policy. |
| Q | Library | **CONFIRMED:** basic book issue/return/purchase/borrowing/payment history for students and teachers. |
| R | Transport | **CONFIRMED:** buses, drivers, routes, stops, assignment, fees/attendance; live GPS later. |
| S | Hostel | **CONFIRMED:** optional hostel/building/floor/room/bed, student assignment, fee and visit records. |
| T | Medical | **CONFIRMED:** health/allergy/vaccination/incidents/medication/emergency facts with restricted access. |
| U | Inventory | **DEFERRED:** user explicitly said “For inventory not now.” |
| V | HR/employees | **CONFIRMED:** complete employees, attendance, leave, payroll, contracts, qualifications, jobs, departments and designations. |
| W | Payroll | **CONFIRMED:** base pay, allowances, overtime, bonus, deductions, loan/tax/net/payslip; monthly payroll selected later. |
| X | Leave | **CONFIRMED:** student and employee requests with configurable approval stages. |
| Y | Calendar/events | **CONFIRMED:** exams, holidays, meetings, trips, functions, birthdays, deadlines and notifications. |
| Z | Certificates/documents | **CONFIRMED:** generate ID cards, admission letters, result/transfer/character certificates, fee receipts and payslips on demand. Do not persist every generated PDF in storage. |
| AA | AI features | **CONFIRMED as product vision:** teacher assistant, tutor, question generator, results/attendance analysis, early warning, parent/school assistant; access-controlled and phased. |
| AB | Analytics | **CONFIRMED:** role-specific school/principal/teacher/accountant/parent/student dashboards and metrics. |
| AC | Reports | **CONFIRMED:** exports/reports, custom filters, appropriate school permissions; exact availability per role remains configurable. |
| AD | Audit/security | **CONFIRMED:** action audit, change reason, approvals, controlled deletion, restricted records. |
| AE | Languages | **CONFIRMED:** English first; future localization possible. |
| AF | Currency | **CONFIRMED:** PKR, SAR, USD and configurable additional currencies. |
| AG | Online payments | **CONFIRMED initial approach:** record payments and let parent submit bank/wallet transaction evidence; no immediate full payment-gateway requirement. |
| AH | Platforms | **CONFIRMED initial approach:** Flutter Android + Windows desktop `.exe`; web was discussed earlier and should be re-confirmed for the current commercial product. |
| AI | Offline | **CONFIRMED:** offline functionality with sync, encryption and conflicts; precise initial offline write scope still merits confirmation. |
| AJ | Multi-school/SaaS | **CHANGED OVER TIME:** initially reusable one-school deployment; then commercial SaaS with a project per school; **November 2026: shared-project + school_id idea under evaluation**, not frozen. |
| AK | Customization | **CONFIRMED:** school name/logo/configuration, academics, grading, fees, branding; initially some changes handled by a developer, later much more admin-configurable. |
| AL | Automation | **CONFIRMED:** event-driven flows for attendance, fees, results, notifications, promotions with control/audit. |
| AM | Advanced future | **FUTURE:** AI expansion, biometrics, face recognition, QR/RFID devices, GPS, IoT, integrations, advanced analytics. |
| AN | First version | **CONFIRMED concept:** do not build one giant monolith in one step; stage the modules, beginning with secure Foundation and core domains. Exact commercial MVP modules were never conclusively frozen in the original exchange. |

---

## Part II — The 100 numbered pre-database questions and answers (18–19 September 2026)

### Questions 1–49, asked after the initial A–AN round

| # | Question | Answer from the discussion |
|---|---|---|
| Q1 | School profile fields? | Yes: name, short name/code, logo, address, country, contact, website, principal/registration/tax, timezone, date format, currency and academic settings. |
| Q2 | Separate data per campus? | Yes. Main/Girls/Junior/etc. campuses have own classes, sections, rooms, teachers, students, attendance, timetable, fees, library and exams; action scopes are campus-specific. |
| Q3 | Can students transfer campuses? | Yes; preserve the full earlier campus/class/section placement history. |
| Q4 | Retain enrollment history instead of overwriting current class? | Yes; academic year, class, section, roll, status and campus history remain available. |
| Q5 | Separate student UUID, serial, admission ID? | Yes; student numbers and formats can be configured by school. |
| Q6 | Family relationship model for multiple children and guardians? | Yes; parent/family structure shared across siblings; later user specified one shared Family login where intended. |
| Q7 | Same parent visibility for father/mother/guardian? | Yes, shared parent access to child fees, attendance, results, homework, etc.; actual authority must be explicitly linked. |
| Q8 | Bank/wallet payment proof flow? | Yes; parent submits transaction details/screenshot for authorized staff verification before treating the payment as verified. |
| Q9 | Fee modification requires a reasoned request and approval? | Yes; recurring or long-term student discounts also supported. No direct unauthorized changes. |
| Q10 | Never delete financial transactions; use reversal/correction? | Yes; preserve permanent financial history. |
| Q11 | Automatic fee invoices vs accountant-triggered generation? | User chose accountant-triggered invoice generation for all or selected students; PDFs generated on demand, not automatically stored in a bucket. |
| Q12 | Monthly/quarterly/half-yearly/yearly/custom billing? | Yes; school can configure frequencies including monthly, half-yearly or yearly. |
| Q13 | Manual discounts and rule-based discount policies? | Both: custom discounts plus scholarship/policy discounts. |
| Q14 | Configurable sibling discounts? | Yes, optional; different schools can enable or disable. |
| Q15 | Apply advance payments to future fees? | Yes. |
| Q16 | How to handle overpayments? | All four options requested: carry as credit, refund, allow both, or authorized administrator decision; exact transaction controls need implementation rules. |
| Q17 | Attendance corrections require approval? | Yes, an authorized correction/approval flow; exact same-day vs older record cutoff was not finally specified here. |
| Q18 | QR attendance as well as manual? | Yes, both; teacher-led scan/entry. |
| Q19 | QR anti-fraud/photo checks in first version? | No, defer extra anti-fraud methods to later. |
| Q20 | Teachers covering multiple subjects/classes/sections/campuses? | Yes; assignment governs which students and activities each teacher can access. |
| Q21 | One class teacher with separate subject teachers? | Originally user suggested one subject/teacher per specific grade; later confirmed different teachers by section and subjects; 2026 D1 model explicitly supports PRIMARY/CO_TEACHER/SUBSTITUTE, subject to constraints. |
| Q22 | Automatic timetable generation with manual adjustments? | Yes, automatically generated and editable. |
| Q23 | Custom per-subject theory/practical marks structures? | Yes, some subjects may have components and some may not. |
| Q24 | School-defined grading scale? | Yes, fully configurable. |
| Q25 | Class/section/grade/campus rankings; disable ranking? | Yes, allow all, selected combinations or none. |
| Q26 | Approvals for result/marks corrections? | Yes; submit edit request, review, approve, then modify. |
| Q27 | Lock published results and retain revisions? | Yes, publication/finalization locks with controlled correction flow. |
| Q28 | Homework automatically visible to assigned pupils and parents? | Yes. |
| Q29 | Online exams in app? | Yes as a supported module/roadmap; exact exam security and schedule not fully frozen. |
| Q30 | Library borrowing and purchases? | Yes; basic acquisition/borrow/payment/return history. |
| Q31 | Make hostel module optional? | Yes. |
| Q32 | Restricted medical access? | Yes; medical facts need authorized visibility. |
| Q33 | Monthly/hourly/daily payroll? | Monthly only initially. |
| Q34 | Employee attendance and overtime? | Overtime and bonuses supported; manual deductions with reason. Staff-attendance status model retained. |
| Q35 | Salary changes require approval? | Yes. |
| Q36 | Student/employee leave and configurable leave types/approval? | Yes. |
| Q37 | Which notification channels? | Push, in-app, email initially; WhatsApp later. SMS was not selected in the answer. |
| Q38 | Per-user notification center with read/unread/history? | Yes. |
| Q39 | Generated PDFs vs uploaded files? | Upload essential photo, birth and employee/contract evidence to private storage; compress to about 1 MB max. Generate result cards/invoices as needed rather than storing each PDF. |
| Q40 | Audit who/what/when/reason/old-new facts? | Yes, comprehensive audit logging. |
| Q41 | Reusable approval workflow engine? | Yes. |
| Q42 | AI as separate permission-aware capability? | Yes; AI should not bypass data access or workflow rules. |
| Q43 | Global search for authorized users? | Yes, with role/scope permissions. |
| Q44 | Customizable dashboards? | Yes. |
| Q45 | Windows app or browser app? | Windows `.exe` selected. Android also selected; later Flutter web support needs explicit current-scope confirmation. |
| Q46 | Offline functionality? | Yes; attendance as early offline use, with synchronization and other offline functions to be designed. |
| Q47 | Backup and disaster recovery? | Yes. |
| Q48 | Reusable deployment scripts to a new school? | Yes; first preserve SQL/config/steps for repeatable school installations. SaaS model evolved after this answer. |
| Q49 | First-version modular scope vs all at once? | User preferred a phased V3-inclusive roadmap, proper relational design and further feature discussions rather than one giant build. |

### Questions 50–100, asked in the follow-up round

| # | Question | Answer from the discussion |
|---|---|---|
| Q50 | Authentication: how do users log in? | Email or administrator-created username; also allow configurable school-generated ID. Specific phone/SSO factors were not finally selected. |
| Q51 | One person with multiple roles? | Yes; a teacher can also be a parent without becoming a duplicate human identity. |
| Q52 | Shared parents account or separate logins? | Shared Family account / one login for family access was selected for the original product concept. |
| Q53 | Identify which parent made a shared-account action? | User preferred context/display such as Father/Mother/Guardian depending on the family situation; **exact person-level accountability for shared credentials is unresolved**. |
| Q54 | Campus-level view vs action scope? | Yes: school-level users can view broad information if granted; teachers/admins cannot perform actions in an unassigned campus. |
| Q55 | What attendance can teachers record? | At morning opening, by first class teacher; optionally after break or both. Not arbitrary attendance across all periods by every teacher. |
| Q56 | Different subject teachers in different sections? | Yes; Mathematics in one section may have a different teacher from Mathematics in another. |
| Q57 | Different subject teachers within one section? | Yes; one section has a class teacher and may have separate subject teachers. |
| Q58 | Custom academic-year start and end dates? | Yes. |
| Q59 | Multiple school years visible at once? | Yes; optionally switch to one active academic-year view while retaining past years. |
| Q60 | Keep history after student profile changes? | Yes, prior and current information retained according to the history rules. |
| Q61 | Keep student status transitions? | Yes. |
| Q62 | Configurable admissions steps? | Yes; verification, test or interview can be skipped by approved policy. Later DB-03 added strong rules concerning FAILED tests and independent admin skip approval. |
| Q63 | Admission number format? | Yes: school prefix + session/year + padded serial; example `MPS-2026-00001`; max suggested serial width 8 digits. |
| Q64 | Roll number policy? | School-defined numeric start such as 1/100/1000; later DB-01 approved automatic initial allocation and authorized manual correction, and DB-02 approved policy revision controls. |
| Q65 | Class capacity control? | Yes, with controlled authorized override; the September answer mentioned Admin/Accountant; later contracts require specific capacity_override permission and evidence. |
| Q66 | Promotion through auditable process? | Yes; retain old enrollment and create next-year enrollment / approved repeat decision. |
| Q67 | Subject categories and per-class settings? | Yes; compulsory, optional and elective configuration per school. |
| Q68 | Different curricula by class/campus/year? | Yes. |
| Q69 | Student electives and optional-subject choices? | Yes. |
| Q70 | Unlimited exam types per academic year? | Yes; tests, homework, practices, midterms, finals, etc. |
| Q71 | Reusable exam templates? | Yes. |
| Q72 | Who enters and publishes marks/results? | Teachers, admins, accountant or Super Admin may upload where granted; **Exam Controller reviews before publishing**, including analytics, errors and requested corrections. |
| Q73 | Should generated invoice PDFs be stored? | No; retain financial rows and generate PDFs on demand. |
| Q74 | Invoice identifier format? | Yes, `INV-YYYY-MM-number` was selected as example. |
| Q75 | Permanent verified payment receipt? | Yes, permanent receipt identity and financial evidence. |
| Q76 | Bank/wallet proof verification? | Yes. |
| Q77 | Detect duplicate bank/wallet payments? | Yes. |
| Q78 | Payroll run format/frequency? | Yes, monthly payroll; labeled `MM-YYYY` in the answer. |
| Q79 | Salary changes automatically step annually? | School-defined interval (yearly or months), optional manual edits, automatic increment can be disabled. |
| Q80 | Configurable leave approval chain? | Yes; school may choose Teacher, Coordinator, Principal, or multi-step chains. |
| Q81 | Compress uploaded documents? | Yes. |
| Q82 | Organized private file storage/folders? | Yes. |
| Q83 | Immediate/scheduled/event-triggered notifications? | All three. |
| Q84 | Initial email provider? | Email with app password initially; later provider/Google Workspace integration could be added. |
| Q85 | Initial push technology? | User declined Firebase/FCM as suggested and said “use entrig”; term is unclear in the export and **needs clarification**. |
| Q86 | Offline conflict resolution? | Accepted recommendation: detect conflicts and resolve rather than silently overwrite records. |
| Q87 | Encrypt locally cached offline data? | Yes. |
| Q88 | Backups of data/configuration/files? | Yes, all. |
| Q89 | Multi-school preparedness? | September answer switched to commercial multi-school SaaS discussion; later accepted one Supabase organization with separate school projects. **November shared-project idea changes this design choice and is not yet approved as a complete migration contract**. |
| Q90 | AI follows normal permissions? | Yes; no AI bypass. |
| Q91 | Store AI conversation history? | Yes; authorized administrators may clear history, subject to retention/security rules. |
| Q92 | Permission-filtered global search? | Yes; parent cannot search another student. |
| Q93 | Who can read audit logs? | Role/scoped restrictions; no unrestricted audit access for all staff. |
| Q94 | Deletion policy for business data? | Yes; archive/correction/reversal for normal and sensitive data, never ordinary destructive deletion of financial/history/audit records. |
| Q95 | School owner vs Super Admin privileges? | School owner and Super Admin have broad read/write; owner may delegate selected permissions to accountants/admins, not teachers/parents merely because of label. |
| Q96 | Need dedicated IT/Admin role? | No — user later rejected need for separate IT/Admin role; this supersedes initial inclusion. |
| Q97 | Principal operational plus review permissions? | Yes, as explicitly granted. |
| Q98 | Should Super Admin be audited and sensitive deletion require approval? | Yes; audit applies even to Super Admin, with reasoned approval for sensitive history/removal operations. |
| Q99 | Future localization while English only initially? | Yes. |
| Q100 | Traditional ERP or modern School OS? | Selected **B: modern School Operating System**, with five core engines: Data, Permission, Workflow, Automation, AI. |

---

## Part III — Explicit follow-up approvals and their practical meaning

### 18–19 September 2026: product baseline

| Approximate date | Explicit decision | Implication / limitation |
|---|---|---|
| 18 Sept | Grades, campuses, academic years, profiles, user roles, attendance, finance, portals, exams, HR/payroll, library, hostel, transport and AI proposals were answered in detail. | Established original requirements; future and optional items remain phased. |
| 19 Sept | Q1–Q49 were answered. | Locked campus boundaries, family model, finance integrity, generated-document strategy, result approvals, backup, offline and reports. |
| 19 Sept | Q50–Q100 were answered. | Locked identity/role separation, access boundaries, current-year/history, custom IDs, result publication and five-engine School OS philosophy. |
| 19 Sept | User explicitly changed course: “so we will go for SaaS implementation.” | Commercial distribution became an approved product goal. |
| 19 Sept | User chose **Option A** after discussion of deployment under one Supabase organization. | **At that time** the interpretation was one Supabase organization hosting a separate project/database for each customer school; not shared tenancy in one project. |
| 21 Sept | User emphasized that biometric or camera attendance would be added later. | Keep extension points but do not assume V1 device integration. |
| 22–27 Sept | User accepted staged design, repository documentation, immutable Foundation gates, validation and staging-first processes. | Engineering workflow: contract → change → independent audit/CI → freeze → next gate. These were work authorizations, not new student/business permissions. |

### 28 September–4 October 2026: D1 product/security and domain-operation approvals

The following are captured from the supplied September/October exports. For detailed operation-by-operation SQL signatures, use the repository's frozen decision and review documents; a one-paragraph chat summary is **not a substitute** for those technical contracts.

| Date | Approved decision or contract | Key rule frozen/selected |
|---|---|---|
| 28 Sept | D1-01, D1-02, D1-05 and D1-06 curriculum, class, roll and capacity design progressed through D1B0. | Subject catalog and flexible curriculum; **Class/Grade + optional academic stage/category**; school-configurable persistent or academic-year roll-number policy; both class and section capacities; override needs explicit permission, reason and audit, with **no automatic Accountant permission merely because of job title**. Further detailed rules later refined in DB-01/02/04. |
| 28 Sept | D1-03, D1-04, D1-07 and D1-08 group approved. | **At most one ordinary active PRIMARY enrollment** per Student; campus/class/section transfers and promotion preserve placement history. Student status lifecycle includes ACTIVE, SUSPENDED, WITHDRAWN, TRANSFERRED, GRADUATED, EXPELLED, DECEASED, ALUMNI; re-enrollment from eligible departed statuses is a controlled new enrollment, not history overwrite. Source D1B0 decision register remains authoritative for other numbered subchoices. |
| 28 Sept | **D1-09A, D1-10 and Emergency Contact** (all three) approved. | Separate family relationship / portal access; Student disclosure classes: **Roster, Profile, Restricted Identity, Sensitive/Special**. Emergency Contact does **not** grant FAMILY authority. |
| 28 Sept | Four Employee/Teacher choices approved together. | **PRIMARY / CO_TEACHER / SUBSTITUTE** assignment kinds; configurable Department/Designation not equivalent to authorization; effective-dated Employee Campus Affiliation not equivalent to a grant; Teacher is an Employee capability, not another Person identity. |
| 28 Sept | Employee domain split approved. | Employee record, employment periods, qualifications, experience, org affiliations and teaching relationships are distinct historical concepts. |
| 28 Sept | D1B3B disclosure defaults approved verbatim. | FAMILY emergency contact has a **separate family-safe current read** with limited fields; student self Restricted Identity denied; teacher PROFILE limited to separately granted **class-teacher** scope; historical reads require separate current authority and are not implied. |
| 28 Sept | D1B4 P1 reviewer model approved. | Operation-specific reviewer permissions; no unrestricted generic approval permission or role-name-based approval bypass. |
| 28 Sept | Deployment bootstrap actor approved. | Deploy/install identity restricted to bootstrap duties; no implicit end-user roles or business grants. |
| 29 Sept | `D1_REVIEWER_ROLE_SCOPE` selection approved. | Reviewer must have configured reviewer role, permission and matching current scope; Person separation from requester. |
| 29 Sept | Workflow design five-question selection: **Yes, Yes, C, No, No** approved. | Exact five choices are recorded in their original approval context; notably explicit apply rather than auto-applying after final approval. The other four should be read against the exact five-question proposal, not inferred from the compressed yes/no answer alone. |
| 1 Oct | `employee.create` semantic recommendation approved. | Employee construction based on existing Person and approved employment-period model rather than duplicating mutable joining dates. |
| 1 Oct | Effect 16 `teaching.class_assignment.change` approved. | Current/future ADD/END/CORRECT **P0**; retroactive CORRECT **P2 independent approval**; one Class Teacher per Section; no self-assignment; employment/capability validation; exact ALL/CAMPUS/SECTION scope. |
| 1–2 Oct | Effect 17 `teaching.subject_assignment.change` approved. | `PRIMARY`, `CO_TEACHER`, bounded `SUBSTITUTE`; one overlapping PRIMARY per Section+Subject, legitimate co-teachers, no self-assignment; retroactive correction approval; exact Subject context. |
| 2 Oct | Effect 18 Employee Restricted Identity contract approved. | Restricted identity history, limited authorization, current multi-campus policy convergence and privacy-aware audit; no broad identity disclosure. |
| 2–3 Oct | Effect 19 Employee Qualification history contract approved. | ADD creates lineage, CORRECT appends successor, ARCHIVE is terminal, no reason-only fake revision; P1 DIRECT/APPROVAL, cross-campus policy convergence. |
| 3 Oct | Effect 20 Employee Experience contract (eight rules) approved. | Experience history lineage, archive separate from actual employment end date, bounded date checks, no-op rejection, privacy-redacted evidence; P1. |
| 3 Oct | Effects 21–25 product contracts approved in successive design gates. | Employee/student restricted/special/status, status correction and enrollment/re-enrollment behaviors were resolved in their respective gates; status does not silently rewrite enrollment history, and valid re-enrollment may atomically return status to ACTIVE. |
| 3 Oct | Effect 28 Emergency Contact design approved (28 points). | Separate retained emergency contacts, current access and explicit audit; emergency contacts grant no portal authority. |
| 3 Oct | Effect 29 `family.manage` approved. | CREATE, RELABEL, ARCHIVE; archived Family cannot be relabeled; archive does **not** silently revoke existing child access or grant new access. |
| 4 Oct | Effect 30 `family.relationship.change` approved. | Family relationship history separate from FAMILY authority; explicit primary replacement; close only child-access portions losing their final lawful relationship basis; P1. |
| 4 Oct | Effects 31–35 family membership/access, Department and Designation contracts approved in sequence. | Exact operation-specific, history-preserving, audited changes. Their individual table/locking contracts are defined in the corresponding later freeze records rather than this summary. |

**Careful distinction:** Some historical assistant replies use “FROZEN” for a statically accepted `.sql.draft` operation after CI that tested the **Foundation**, not the draft's runtime behavior. Later D1 acceptance testing was a separate workstream. A design PASS must never be represented as a production deployment approval.

### October 2026: DB-01 to DB-04 explicit decisions recorded in project discussions

| Workstream | Explicitly approved choice | Impact |
|---|---|---|
| **DB-01 Student Roll** | **Option A**: automatic **initial** roll-number generation, with **authorized manual correction afterward**. | Neither manual-only assignment nor unrestricted overwrite; retained reservations, uniqueness, history and controlled `student.roll.correct`. |
| **DB-02 Roll Policy** | A school administrator may request a starting-roll-number change (e.g., 1000 → 2000); independent reviewer approval precedes actual application. | I08 request → I09 independent review → I10 apply only after rechecking old policy and live authority. PR #154 was described as draft/unmerged in the 24 Oct project handoff; do not infer current merge status without inspecting the repo. |
| **DB-03 Admissions: P4-D01** | **Option A**: authorized examiner decides `PASSED`/`FAILED`; numeric marks optional. | Pass/fail classification need not depend on numeric score. |
| **DB-03 Admissions: P5-D01** | Original “Option A” about accepted offer / verified handoff approved, **then clarified by the user**: admission offers are handled directly by the school, not parents. | School staff confirm offers; parent is not an offer-approval actor. |
| **DB-03 Admissions: test skip** | Administration can request skipping a test, but **FAILED cannot be bypassed**. | Skipping a requirement is not equivalent to overriding failed results. |
| **DB-03 Admissions: ADMIN-SKIP-AUTH** | **Option B**: independent approval from a second authorized reviewer. | Prevent unilateral administration test skipping. |
| **DB-03 Admissions: finance** | Finance authorization/clearance required before enrollment creates Student. | Admission fee waiver or tuition discount possible before admission, plus authorized post-admission fee changes. |
| **DB-04 Curriculum CUR-01** | Reject overlapping school-wide and campus-specific curricula **without implicit precedence**. | The conflict must be corrected, not silently resolved by choosing campus or school. |
| **DB-04 Curriculum CUR-03** | Approved **BF-1** finalization evidence and **B-M1** group-maximum semantics. | Approved in documentation first; do not infer SQL implementation from the decision alone. |
| **DB-04** | Approved **T1 + M1 + S1 + F1 + H1** CUR-01 rules in one decision. | Five selected policy variants as recorded in DB-04 workstream; refer to its decision register for exact definitions. |
| **Storage** | **Supabase Storage preferred** over a separate default file service. | Private purpose-bound files and limited metadata access; on-demand PDFs not generally stored. |

### November 2026: commercial SaaS architecture is an active new decision gate

- **1 Nov:** user asked to make public GitHub repository private to protect the project. This is a repository-access choice, not a schema/data-model approval.
- **3 Nov:** user requested security audit and evaluated migration from per-school Supabase projects to one project for all schools.
- **10 Nov:** user proposed **one project with one schema per school** as a subscription-time provisioning pattern and asked whether it is best; this was a question, not approval.
- **11 Nov:** user said another project already uses **one Supabase project for all schools with `school_id`**, and wanted the EduSync customer-purchase/onboarding/settings idea transferable to that architecture. This establishes the newer design direction for that other project, but does not by itself approve a full EduSync migration or database refactor.
- **12 Nov:** this request asks for retrospective questions/answers and approvals. No new architecture is being approved by requesting this report.

---

## Part IV — Items that changed, are contradictory, or still lack an exact decision

| Issue | Earlier decision | Later direction or unresolved question |
|---|---|---|
| **Customer tenancy** | One customer school = one Supabase project/database; multiple campuses within. | Shared Supabase project with `school_id` contemplated for another product; per-school schema idea also discussed. **Needs explicit architecture freeze before coding.** |
| **Institution type** | Questionnaire listed school, college, and both; core grade scope ended at Grade 12. | Decide whether true post-secondary college programs are in V1/V2. |
| **Parent login auditability** | One shared father/mother/guardian login for a Family. | If two adults share credentials, exact actor cannot be proved. Consider individual authentication with linked family view, preserving convenient unified access. |
| **Teacher subject cardinality** | Early response suggested one teacher per subject in a specific grade. | Later design explicitly supports Section+Subject PRIMARY / CO_TEACHER / SUBSTITUTE. **Later approved contract controls.** |
| **Attendance granularity** | Initial module listed daily, period and subject attendance. | Follow-up specified morning first-teacher checkpoint, optionally after break. V1 attendance event granularity should be frozen. |
| **IT/Admin role** | Listed among initial roles. | Q96 later says no separate IT/Admin. |
| **Windows vs web** | Windows `.exe` and Android initially selected; web later discussed. | Current browser/mobile/Windows deliverable matrix should be confirmed. |
| **Push provider** | User rejected default FCM wording and said “entrig.” | Exact technology/provider unknown in the transcript. |
| **Fee invoice generation** | Early options included automation. | User selected accountant-triggered, on-demand PDF, not bucket storage. Later scheduled invoice data creation remains a distinct choice. |
| **School owner / super admin** | Both broad privileges initially. | Current engine is default-deny live grants with independent approvals for specified operations; labels must not imply direct bypass. |
| **Retention/delete** | User occasionally said admins may clear histories/chat to free space. | Finance, audit, enrollment and approved historical records must remain protected. Define lawful retention/erasure exception separately from ordinary UI deletion. |
| **Commercial activation** | Early focus: copy application, execute SQL and configure school. | Modern self-service SaaS requires onboarding, billing, subscription, tenant isolation, suspension, export and account recovery decisions. |

---

## Part V — Additional questions for the next product/database approval round

**All questions below are new proposals. NONE is automatically approved by this report.** The `NEW-` IDs allow us to approve choices without reopening the original Q1–Q100 numbering.

### A. SaaS tenancy and data isolation

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-001 | Will EduSync itself adopt a **shared-project, shared-schema, `school_id` on every tenant row** architecture, or is that architecture only for the other product? | **OPEN** |
| NEW-002 | If shared: can one legal customer own multiple schools, with separate school_id values under a customer/account hierarchy? | **OPEN** |
| NEW-003 | Should every user have school memberships with explicit per-school role/scopes, rather than a single global school_id in Auth metadata? | **OPEN** |
| NEW-004 | Can the same teacher work in two separately owned customer schools? Can a parent view children across schools with one login? | **OPEN** |
| NEW-005 | What RLS invariants and cross-tenant RPC tests must pass before accepting the shared-project architecture? | **OPEN** |
| NEW-006 | How should cross-tenant unique usernames, admission numbers, invoices and school codes be namespaced? | **OPEN** |
| NEW-007 | Which data, if any, is global SaaS/platform data (plans, customers, billing) versus protected tenant school data? | **OPEN** |
| NEW-008 | Can one school ever move from shared DB to its own dedicated Supabase project while preserving all history and IDs? | **OPEN** |
| NEW-009 | How will tenant export, restoration, deletion, disaster recovery and legal hold work without affecting other schools? | **OPEN** |
| NEW-010 | Who may operate privileged platform support tools, and how will temporary support access be approved, time-limited and audited? | **OPEN** |

### B. Signup, commercial purchase and provisioning

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-011 | Who is legally purchasing: school owner, principal, company operator, district, college group, or reseller? | **OPEN** |
| NEW-012 | Which identity, VAT/GST/NTN, registration and ownership-verification fields are compulsory at signup in each country? | **OPEN** |
| NEW-013 | Is the first account the legal owner, operational Super Admin, or a temporary onboarding administrator? | **OPEN** |
| NEW-014 | Will schools receive a trial, demo with sample data, paid-only activation, or manually approved subscription? | **OPEN** |
| NEW-015 | How is trial abuse prevented without collecting unnecessary personal information? | **OPEN** |
| NEW-016 | What plans are offered (student-based, staff-based, campus-based, flat fee, modular add-ons, usage limits)? | **OPEN** |
| NEW-017 | Are monthly and annual subscriptions supported and how are proration, upgrades, downgrades and renewals handled? | **OPEN** |
| NEW-018 | Which payment processors are used for the **school’s SaaS subscription**, distinct from parent-to-school fee payments? | **OPEN** |
| NEW-019 | Does provisioned school data become ACTIVE before payment confirmation or only after a verified billing event? | **OPEN** |
| NEW-020 | Who configures DNS/subdomain, school code, initial campus, academic year, currency and default role templates? | **OPEN** |
| NEW-021 | Can the school bring an existing domain/branding and can white-labeling be sold as an add-on? | **OPEN** |
| NEW-022 | What is the grace-period, read-only mode, suspended mode and reactivation process for overdue SaaS bills? | **OPEN** |

### C. School structure and operations

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-023 | What is the formal difference between a school, campus, branch, department and academic program? | **OPEN** |
| NEW-024 | Do curricula/class offerings belong to a school globally, campus, academic year, grade or a published version? | **OPEN** |
| NEW-025 | Can a student be concurrently enrolled at multiple campuses or must exactly one PRIMARY enrollment be active? | **OPEN** |
| NEW-026 | What rules govern campus closure/merger while students, staff and finance history remain? | **OPEN** |
| NEW-027 | Can the school create a new grade or rename one without rewriting historical report cards? | **OPEN** |
| NEW-028 | How do class/section capacities interact with future enrollments, waitlists and withdrawn students? | **OPEN** |
| NEW-029 | Can timetable changes be effective-dated and versioned, and who may override conflicts? | **OPEN** |
| NEW-030 | What is the approved attendance-taking window: morning once, morning+after break, or per period; how are absence corrections handled? | **OPEN** |
| NEW-031 | What is the time-zone and business-day rule for a school spanning more than one country/campus? | **OPEN** |
| NEW-032 | Who can close the academic year, reopen it by exception, and publish the next-year promotion batch? | **OPEN** |

### D. Admissions, families and student privacy

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-033 | Can applicant records exist before a parent login, and who is the verified applicant/contact? | **OPEN** |
| NEW-034 | What if admission payment proof arrives after an accepted seat has expired? | **OPEN** |
| NEW-035 | How do sibling relations, step-parents, custody restrictions, guardianship and court orders affect portal access? | **OPEN** |
| NEW-036 | Should father/mother/guardian have **individual Auth accounts** linked to one Family view, replacing the historically proposed shared password? | **OPEN** |
| NEW-037 | Who approves emergency pickup rights, and why must they stay separate from “Emergency Contact” and family relationships? | **OPEN** |
| NEW-038 | What consent model applies to minor student photos, medical records, biometric attendance and AI processing? | **OPEN** |
| NEW-039 | Can student self-service expose restricted identity only after age/authority verification? | **OPEN** |
| NEW-040 | How should school-to-school transfers handle selective disclosure and consent? | **OPEN** |
| NEW-041 | How are duplicate applicants/students detected without unsafe global identity searches across schools? | **OPEN** |
| NEW-042 | What is the allowed correction process for DOB, name, nationality, gender and national ID, including legal evidence? | **OPEN** |

### E. Fees, accounting, refunds and payments

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-043 | Will there be double-entry school accounting or only school-fee receivables and a separate expense register? | **OPEN** |
| NEW-044 | Are fee schedules effective-dated and published, and what happens to already-billed installments when a rate changes? | **OPEN** |
| NEW-045 | How exactly do overlapping scholarships and discounts combine (priority, cap, stacking and eligibility)? | **OPEN** |
| NEW-046 | Are discounts prospective only or allowed retroactively with separate approval and adjustment evidence? | **OPEN** |
| NEW-047 | How are partial payment allocations prioritized when there are multiple outstanding invoices? | **OPEN** |
| NEW-048 | Who approves a refund and to what original payment method; how are refunds reconciled? | **OPEN** |
| NEW-049 | How are duplicate or fraudulent bank/wallet proofs detected, reviewed and escalated? | **OPEN** |
| NEW-050 | Should fees be booked in school local currency with optional display conversion, and which rate source is used? | **OPEN** |
| NEW-051 | What tax/invoice/legal receipt rules vary by country, and who configures the fiscal year? | **OPEN** |
| NEW-052 | What does an accountant have authority to publish or adjust independently versus through a finance-approver workflow? | **OPEN** |

### F. Permissions, audits and security

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-053 | Which actions require no approval, configurable P1 review, or mandatory independent P2 approval? | **OPEN** |
| NEW-054 | Can the school owner approve a sensitive request they initiated through another role? (Recommended no.) | **OPEN** |
| NEW-055 | Which permissions are available to tenants versus only the SaaS platform team? | **OPEN** |
| NEW-056 | Will approved changes auto-apply or require separately authorized explicit Apply per operation? | **OPEN** |
| NEW-057 | How are stale approvals invalidated if a student, policy, fee or reviewer grant changes before apply? | **OPEN** |
| NEW-058 | What evidence may enter broad audit/outbox logs, and which sensitive values must stay only in protected tables? | **OPEN** |
| NEW-059 | What retention/export policy applies to security audits, request reasons, chats, documents and AI transcripts? | **OPEN** |
| NEW-060 | What actions trigger reauthentication or MFA (owner transfer, payment configuration, data export, mass deletion)? | **OPEN** |
| NEW-061 | How are platform service credentials rotated and isolated, and are any client-visible service-role keys prohibited? | **OPEN** |
| NEW-062 | Who is authorized to review RLS and tenant isolation in an independent pre-production security audit? | **OPEN** |

### G. Academic results, staff, AI and sync

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-063 | Can students appeal marks, and who receives an appeal without allowing direct marks overwrite? | **OPEN** |
| NEW-064 | What is the complete result publication chain and can it differ by school policy? | **OPEN** |
| NEW-065 | Can substitutions and co-teaching alter who may enter marks, without changing the official primary teacher? | **OPEN** |
| NEW-066 | What are the payroll cut-off dates, retroactive salary corrections and loan/deduction limits? | **OPEN** |
| NEW-067 | Can former employees request exports/corrections to their HR records; how is access verified? | **OPEN** |
| NEW-068 | What exact data may AI summarize or use for prompts, and can schools opt out of third-party model processing? | **OPEN** |
| NEW-069 | Will AI answers be treated as suggestions only, with no direct authority to approve fees, attendance or admissions? | **OPEN** |
| NEW-070 | What offline records can be edited on multiple devices and what conflict types require human review? | **OPEN** |
| NEW-071 | What are maximum offline retention, encryption key handling, device revocation and forced-logout rules? | **OPEN** |
| NEW-072 | Which integrations are V1 versus future: biometric attendance, camera attendance, SMS, WhatsApp, payment gateways, bus GPS? | **OPEN** |

### H. Launch and migration gates

| New ID | Question awaiting school/product-owner decision | Decision / selected option |
|---|---|---|
| NEW-073 | What exact paid MVP modules and country launch target must be complete before the first customer starts using the app? | **OPEN** |
| NEW-074 | What data import format supports historical students, guardians, fee balances, attendance and results from existing systems? | **OPEN** |
| NEW-075 | What acceptance tests must pass for tenant isolation, finance reconciliation, history and approval races? | **OPEN** |
| NEW-076 | Will test/staging datasets be synthetic, and how will schools validate migration without exposing child information? | **OPEN** |
| NEW-077 | Who may authorize production migrations, rollback, database cutovers and customer data restore? | **OPEN** |
| NEW-078 | What are uptime/backup recovery targets (RPO/RTO), support hours and incident notification commitments? | **OPEN** |
| NEW-079 | What setup tasks are completed by the customer versus EduSync staff versus automated onboarding? | **OPEN** |
| NEW-080 | What school settings are editable in-app and which require privileged developer/platform changes? | **OPEN** |
| NEW-081 | What contract terms govern data controller/processor roles, sub-processors, exit/export and data ownership? | **OPEN** |
| NEW-082 | When will the shared-database migration be independently approved after security, cost, and multi-tenant benchmark tests? | **OPEN** |

---

## Part VI — Recommended order for new approvals (not yet decisions)

1. **Freeze customer-tenancy architecture first**: shared project + shared schema + school_id *versus* a project per school. Do **not** combine shared-schema RLS with per-school PostgreSQL schemas by assumption.
2. Define the customer organization, school, campus, user membership and platform billing boundaries. Decide whether customer group and school are different entities.
3. Freeze onboarding, subscription state machine, school activation/suspension and support access before building self-service signup.
4. Freeze tenant-aware permission evaluation, storage/object-path isolation, audit fields, idempotency boundaries, disaster recovery and data-export requirements.
5. Then update the existing D1/DB-01–04 contracts and acceptance tests **as a separately approved migration project**. Do not silently transplant project-per-school SQL into a shared project.
6. Reconfirm commercial MVP scope, app platforms, parent authentication and sensitive data processing before inviting paying customers.

### Suggested decision-record format for future conversations

```text
Decision ID: NEW-001
Question: ...
Selected option: A / B / C / custom
Exact rule: ...
Example: ...
Security/history consequences: ...
Approver: Product owner
Date: YYYY-MM-DD
Status: PROPOSED -> APPROVED -> IMPLEMENTED -> RUNTIME TESTED -> RELEASED
Supersedes (if applicable): ...
Affected modules/tables/RPCs/tests: ...
```

**End of reconstructed decision register.**