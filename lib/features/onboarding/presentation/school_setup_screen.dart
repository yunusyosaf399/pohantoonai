import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../auth/presentation/school_campus_illustration.dart';
import '../data/school_setup_repository.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 3: applicant-owned information, not a provisioned school.
class SchoolSetupScreen extends StatefulWidget {
  const SchoolSetupScreen({
    super.key,
    required this.plan,
    required this.repository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
    required this.onContinue,
    this.accountEmail,
  });
  final OnboardingPlanOffer plan;
  final SchoolSetupRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;
  final ValueChanged<SchoolSetupDraft> onContinue;
  final String? accountEmail;

  @override
  State<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends State<SchoolSetupScreen> {
  static const fieldNames = [
    'schoolName','legalName','registration','year','website',
    'contactName','contactPosition','contactEmail','contactPhone',
    'region','city','address','students','campuses','teachers','staff',
    'board','curriculum','otherCountry','otherZone','otherCurrency',
    'otherLowest','otherHighest',
  ];
  final Map<String,TextEditingController> fields = {
    for (final name in fieldNames) name: TextEditingController(),
  };

  static const countries = <String,String>{
    'AF':'Afghanistan','AU':'Australia','BD':'Bangladesh','CA':'Canada',
    'CN':'China','EG':'Egypt','FR':'France','DE':'Germany','IN':'India',
    'ID':'Indonesia','IR':'Iran','IQ':'Iraq','IE':'Ireland','IT':'Italy',
    'JP':'Japan','JO':'Jordan','KZ':'Kazakhstan','KE':'Kenya',
    'KW':'Kuwait','MY':'Malaysia','NP':'Nepal','NZ':'New Zealand',
    'NG':'Nigeria','OM':'Oman','PK':'Pakistan','PS':'Palestine',
    'PH':'Philippines','QA':'Qatar','RU':'Russia','SA':'Saudi Arabia',
    'ZA':'South Africa','KR':'South Korea','ES':'Spain','LK':'Sri Lanka',
    'TH':'Thailand','TR':'Türkiye','AE':'United Arab Emirates',
    'GB':'United Kingdom','US':'United States','UZ':'Uzbekistan',
    'VN':'Vietnam','YE':'Yemen','OTHER':'Other (enter ISO code)',
  };
  static const zones = <String,String>{
    'UTC':'UTC (±00:00)',
    'Asia/Kabul':'Asia/Kabul (UTC+04:30)',
    'Asia/Riyadh':'Asia/Riyadh (UTC+03:00)',
    'Asia/Karachi':'Asia/Karachi (UTC+05:00)',
    'Asia/Dubai':'Asia/Dubai (UTC+04:00)',
    'Asia/Bangkok':'Asia/Bangkok (UTC+07:00)',
    'Asia/Kolkata':'Asia/Kolkata (UTC+05:30)',
    'Asia/Tokyo':'Asia/Tokyo (UTC+09:00)',
    'Europe/London':'Europe/London',
    'Europe/Paris':'Europe/Paris',
    'Africa/Cairo':'Africa/Cairo',
    'America/New_York':'America/New_York',
    'America/Los_Angeles':'America/Los_Angeles',
    'Australia/Sydney':'Australia/Sydney',
    'OTHER':'Other IANA time zone',
  };
  static const currencies = <String,String>{
    'USD':'USD — US Dollar','SAR':'SAR — Saudi Riyal',
    'AFN':'AFN — Afghan Afghani','PKR':'PKR — Pakistani Rupee',
    'AED':'AED — UAE Dirham','EUR':'EUR — Euro',
    'GBP':'GBP — British Pound','INR':'INR — Indian Rupee',
    'THB':'THB — Thai Baht','CNY':'CNY — Chinese Yuan',
    'OTHER':'Other ISO currency',
  };
  static const grades = [
    'Pre-K','Kindergarten',
    'Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6',
    'Grade 7','Grade 8','Grade 9','Grade 10','Grade 11','Grade 12',
    'Undergraduate','Graduate','OTHER',
  ];
  static const suggestedLanguages = [
    'Arabic','Dari','English','French','Hindi','Mandarin',
    'Pashto','Portuguese','Spanish','Thai','Turkish','Urdu',
  ];

  bool loading = true;
  bool saving = false;
  bool dirty = false;
  bool loaded = false;
  String? error;
  String? schoolType;
  String? countryCode;
  String timezone = 'UTC';
  String currency = 'USD';
  String? lowestGrade;
  String? highestGrade;
  final Set<String> languages = {};

  TextEditingController controller(String key) => fields[key]!;
  String? value(String key) {
    final t = controller(key).text.trim();
    return t.isEmpty ? null : t;
  }
  int? number(String key) => int.tryParse(value(key) ?? '');
  String? get finalCountry => countryCode == 'OTHER'
      ? value('otherCountry')?.toUpperCase() : countryCode;
  String get finalZone => timezone == 'OTHER'
      ? (value('otherZone') ?? 'UTC') : timezone;
  String get finalCurrency => currency == 'OTHER'
      ? (value('otherCurrency')?.toUpperCase() ?? '') : currency;
  String? gradeValue(String? grade,String other) =>
      grade == 'OTHER' ? value(other) : grade;

  @override
  void initState() {
    super.initState();
    for (final c in fields.values) {
      c.addListener(_changed);
    }
    _load();
  }
  void _changed() {
    if (!loading) dirty = true;
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final existing = await widget.repository.load();
      if (!mounted) return;
      if (existing != null) _restore(existing);
      setState(() { loading = false; loaded = true; dirty = false; });
    } catch (_) {
      if (mounted) setState(() {
        loading = false;
        loaded = false;
        error = 'Could not load your saved school details. '
            'Please retry before editing.';
      });
    }
  }

  void _restore(SchoolSetupDraft d) {
    void put(String k,Object? v) => controller(k).text = v?.toString() ?? '';
    put('schoolName',d.schoolName); put('legalName',d.legalSchoolName);
    put('registration',d.registrationLicenseNumber);
    put('year',d.establishedYear); put('website',d.websiteUrl);
    put('contactName',d.contactName); put('contactPosition',d.contactPosition);
    put('contactEmail',d.contactEmail); put('contactPhone',d.contactPhone);
    put('region',d.region); put('city',d.city);
    put('address',d.streetAddress); put('students',d.estimatedStudents);
    put('campuses',d.campusCount); put('teachers',d.estimatedTeachers);
    put('staff',d.estimatedNonTeachingStaff);
    put('board',d.educationBoard); put('curriculum',d.curriculum);
    schoolType = d.schoolType;
    countryCode = countries.containsKey(d.countryCode)
        ? d.countryCode : d.countryCode == null ? null : 'OTHER';
    if (countryCode == 'OTHER') put('otherCountry',d.countryCode);
    timezone = zones.containsKey(d.timezone) ? d.timezone : 'OTHER';
    if (timezone == 'OTHER') put('otherZone',d.timezone);
    currency = currencies.containsKey(d.currencyCode)
        ? d.currencyCode : 'OTHER';
    if (currency == 'OTHER') put('otherCurrency',d.currencyCode);
    lowestGrade = grades.contains(d.lowestGrade)
        ? d.lowestGrade : d.lowestGrade == null ? null : 'OTHER';
    highestGrade = grades.contains(d.highestGrade)
        ? d.highestGrade : d.highestGrade == null ? null : 'OTHER';
    if (lowestGrade == 'OTHER') put('otherLowest',d.lowestGrade);
    if (highestGrade == 'OTHER') put('otherHighest',d.highestGrade);
    languages..clear()..addAll(d.teachingLanguages);
  }

  SchoolSetupDraft _draft(bool ready) => SchoolSetupDraft(
    schoolName:value('schoolName'), legalSchoolName:value('legalName'),
    schoolType:schoolType, registrationLicenseNumber:value('registration'),
    establishedYear:number('year'), websiteUrl:value('website'),
    contactName:value('contactName'),contactPosition:value('contactPosition'),
    contactEmail:value('contactEmail'),contactPhone:value('contactPhone'),
    countryCode:finalCountry,region:value('region'),city:value('city'),
    streetAddress:value('address'),timezone:finalZone,
    currencyCode:finalCurrency,estimatedStudents:number('students'),
    campusCount:number('campuses'),estimatedTeachers:number('teachers'),
    estimatedNonTeachingStaff:number('staff'),
    educationBoard:value('board'),curriculum:value('curriculum'),
    lowestGrade:gradeValue(lowestGrade,'otherLowest'),
    highestGrade:gradeValue(highestGrade,'otherHighest'),
    teachingLanguages:languages.toList()..sort(),readyForReview:ready,
  );

  List<String> _inputErrors() {
    final issues = <String>[];
    for (final key in ['year','students','campuses','teachers','staff']) {
      if (value(key) != null && int.tryParse(value(key)!) == null) {
        issues.add('Enter a whole number in the '+key+' field.');
      }
    }
    if (value('website') != null &&
        !value('website')!.startsWith('https://')) {
      issues.add('Website must use https://');
    }
    final email = value('contactEmail');
    if (email != null && !RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(email)) {
      issues.add('Enter a valid school contact email.');
    }
    if (countryCode == 'OTHER' &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(finalCountry ?? '')) {
      issues.add('Use a two-letter ISO country code.');
    }
    if (currency == 'OTHER' &&
        !RegExp(r'^[A-Z]{3}$').hasMatch(finalCurrency)) {
      issues.add('Use a three-letter ISO currency code.');
    }
    if (timezone == 'OTHER' && value('otherZone') == null) {
      issues.add('Enter an IANA time zone, e.g., Asia/Kabul.');
    }
    if (number('year') != null &&
        (number('year')! < 1700 || number('year')! > 2200)) {
      issues.add('Year established is outside the supported range.');
    }
    return issues;
  }

  Future<void> _save(bool ready) async {
    if (saving || !loaded) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _draft(ready);
    final issues = [
      ..._inputErrors(),
      if (ready) ...draft.reviewErrors(
        studentLimit:widget.plan.studentLimit,
        campusLimit:widget.plan.campusLimit,
        staffLimit:widget.plan.staffLimit),
    ];
    if (issues.isNotEmpty) {
      setState(() => error = issues.toSet().join('\n'));
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      final saved = await widget.repository.save(draft);
      if (!mounted) return;
      setState(() => dirty = false);
      if (ready) {
        widget.onContinue(saved);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('School setup draft saved.')));
      }
    } catch (err) {
      if (!mounted) return;
      final detail = err is PostgrestException ? err.message : '';
      setState(() => error =
          detail.contains('exceeds your selected plan')
            ? 'Your estimated students, campuses or staff exceed the '
              'selected plan. Please edit them or change your plan.'
            : err is AuthException
                ? 'Your session expired. Sign in again.'
                : 'Could not save the draft. Check your input and '
                  'internet connection, then retry.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _back() async {
    if (!dirty) { widget.onBack(); return; }
    final leave = await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Leave school setup?'),
        content:const Text('You have unsaved information. Save Draft '
          'to keep it before going back.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Stay')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Discard changes')),
        ]),
    );
    if (leave == true && mounted) widget.onBack();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }

