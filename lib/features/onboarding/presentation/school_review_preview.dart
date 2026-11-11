import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 4 handoff: read-only review, without an approval or payment action.
/// Actual application submission and operator review are a separate module.
class SchoolReviewPreview extends StatelessWidget {
  const SchoolReviewPreview({
    super.key,
    required this.draft,
    required this.plan,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
  });
  final SchoolSetupDraft draft;
  final OnboardingPlanOffer plan;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(
        title:const Text('Pohantoon AI · Application Review'),
        actions:[AppearanceSettingsButton(
          mode:themeMode,onChanged:onThemeChanged)]),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:740),
        child:ListView(padding:const EdgeInsets.all(22),children:[
          const Text('STEP 4 OF 6 · APPLICATION REVIEW',
            style:TextStyle(fontWeight:FontWeight.w800,
              fontSize:12,letterSpacing:1)),
          const SizedBox(height:12),
          const LinearProgressIndicator(value:4/6,minHeight:8),
          const SizedBox(height:24),
          Text('Review your school information',
            key:const Key('school-review-preview-title'),
            style:Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight:FontWeight.w800)),
          const SizedBox(height:9),
          Text('Your details are safely saved. Review the information '
            'before the future application-submission step.',
            style:TextStyle(color:colors.onSurfaceVariant)),
          const SizedBox(height:22),
          Card(child:Padding(
            padding:const EdgeInsets.all(18),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                _row('Selected plan',plan.name),
                _row('School name',draft.schoolName),
                _row('School type',draft.schoolType),
                _row('Legal name',draft.legalSchoolName),
                _row('License/registration',draft.registrationLicenseNumber),
                _row('School contact',draft.contactName),
                _row('School contact email',draft.contactEmail),
                _row('Phone',draft.contactPhone),
                _row('Country',draft.countryCode),
                _row('City',draft.city),
                _row('Region',draft.region),
                _row('Time zone',draft.timezone),
                _row('Currency',draft.currencyCode),
                _row('Estimated students',draft.estimatedStudents?.toString()),
                _row('Campuses',draft.campusCount?.toString()),
                _row('Teachers',draft.estimatedTeachers?.toString()),
                _row('Non-teaching staff',draft.estimatedNonTeachingStaff?.toString()),
                _row('Education board',draft.educationBoard),
                _row('Curriculum',draft.curriculum),
                _row('Lowest / Highest grade',
                  (draft.lowestGrade??'—')+' / '+(draft.highestGrade??'—')),
                _row('Teaching languages',draft.teachingLanguages.join(', ')),
              ],
            ),
          )),
          const SizedBox(height:16),
          Container(
            padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(
              color:colors.primaryContainer.withValues(alpha:.6),
              borderRadius:BorderRadius.circular(12)),
            child:const Text(
              'This is a review preview only. No application was submitted, '
              'no subscription was activated, and no school was created.')),
          const SizedBox(height:22),
          FilledButton.icon(
            key:const Key('school-review-edit'),
            onPressed:onBack,
            icon:const Icon(Icons.arrow_back),
            label:const Text('Back to edit school information')),
        ]),
      ))),
    );
  }

  Widget _row(String name,String? value) => Padding(
    padding:const EdgeInsets.symmetric(vertical:9),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:175,child:Text(name,
        style:const TextStyle(fontWeight:FontWeight.w700))),
      const SizedBox(width:10),
      Expanded(child:Text(value==null||value.trim().isEmpty?'—':value)),
    ]),
  );
}
