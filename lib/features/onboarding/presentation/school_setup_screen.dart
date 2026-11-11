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
    this.initialSection,
  });
  final OnboardingPlanOffer plan;
  final SchoolSetupRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;
  final ValueChanged<SchoolSetupDraft> onContinue;
  final String? accountEmail;
  /// Opens the matching card when an Edit action is chosen in Step 4.
  final String? initialSection;

  @override
  State<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends State<SchoolSetupScreen> {
  static const fieldNames = [
    'schoolName','legalName','registration','year','website',
    'contactName','contactPosition','contactEmail','contactPhone',
    'region','city','address','postalCode','students','campuses','teachers','staff',
    'board','curriculum','otherCountry','otherZone','otherCurrency',
    'otherLowest','otherHighest',
  ];
  final Map<String, GlobalKey> sectionKeys = {
    'identity': GlobalKey(),
    'contact': GlobalKey(),
    'location': GlobalKey(),
    'academics': GlobalKey(),
  };
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
  final ScrollController scroll = ScrollController();
  void showTopError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(0,
          duration:const Duration(milliseconds:300),
          curve:Curves.easeOut);
      }
    });
  }
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
    if (loading) return;
    dirty = true;
    if (error != null && mounted) {
      setState(() => error = null);
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final existing = await widget.repository.load();
      if (!mounted) return;
      if (existing != null) _restore(existing);
      setState(() { loading = false; loaded = true; dirty = false; });
      if (widget.initialSection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final target = sectionKeys[widget.initialSection]?.currentContext;
          if (target != null) {
            Scrollable.ensureVisible(target,
              alignment: 0.08,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut);
          }
        });
      }
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
    put('address',d.streetAddress); put('postalCode',d.postalCode);
    put('students',d.estimatedStudents);
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
    streetAddress:value('address'),postalCode:value('postalCode'),
    timezone:finalZone,
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
      showTopError();
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
      showTopError();
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
    scroll.dispose();
    for (final c in fields.values) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B2025)
          : const Color(0xFFF4F9FA),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, outer) {
          final desktop = outer.maxWidth >= 1250;
          return Row(children: [
            if (desktop)
              SizedBox(width: 300, child: _sidebar()),
            Expanded(child: SingleChildScrollView(
              controller:scroll,
              key: Key(desktop
                  ? 'school-setup-desktop-layout'
                  : 'school-setup-mobile-layout'),
              padding: EdgeInsets.fromLTRB(desktop ? 30 : 18, 22,
                  desktop ? 30 : 18, 38),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(desktop),
                    const SizedBox(height: 22),
                    Text('STEP 3 OF 6 · SCHOOL SETUP',
                      key: const Key('school-setup-progress-label'),
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800,letterSpacing: .9)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: const LinearProgressIndicator(
                        value: 3 / 6, minHeight: 8)),
                    const SizedBox(height: 26),
                    Text('Tell us about your school',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: desktop ? 34 : 29,
                            fontWeight: FontWeight.w800,height: 1.14)),
                    const SizedBox(height: 8),
                    Text('Start with essential details now. Optional details '
                      'can be completed later and reviewed before submission.',
                      style: TextStyle(height: 1.48,color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 22),
                    _notices(),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      _errorBox(), const SizedBox(height: 16),
                    ],
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(52),
                        child: Center(child: CircularProgressIndicator(
                          key: Key('school-setup-loading'))))
                    else if (!loaded)
                      Center(child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry loading draft')))
                    else ...[
                      _formCards(),
                      const SizedBox(height: 29),
                      _footer(),
                    ],
                  ],
                ),
              )),
            )),
          ]);
        }),
      ),
    );
  }

  Widget _topBar(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      IconButton(key:const Key('school-setup-back-top'),
        onPressed:_back, tooltip:'Back to your plans',
        icon:const Icon(Icons.arrow_back)),
      if (!desktop) ...[
        const SizedBox(width: 5),
        ClipRRect(borderRadius:BorderRadius.circular(8),
          child:Image.asset('assets/app_logo/app_icon.jpeg',
            width:34,height:34,fit:BoxFit.cover)),
        const SizedBox(width: 8),
        const Expanded(child:Text('Pohantoon AI',
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
      ] else const Spacer(),
      AppearanceSettingsButton(
        mode:widget.themeMode,onChanged:widget.onThemeChanged),
      const SizedBox(width: 8),
      Tooltip(
        message:widget.accountEmail ?? 'Signed-in account',
        child:CircleAvatar(
          backgroundColor:colors.primaryContainer,
          child:Icon(Icons.person_outline,color:colors.primary)),
      ),
    ]);
  }

  Widget _sidebar() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding:const EdgeInsets.fromLTRB(24,34,24,24),
      decoration:BoxDecoration(
        color:dark?const Color(0xFF0D3B35):const Color(0xFFE5F5F0),
        border:Border(right:BorderSide(color:colors.outlineVariant))),
      child:ListView(children:[
        Row(children:[
          Image.asset('assets/app_logo/app_icon.jpeg',width:50,height:50),
          const SizedBox(width:12),
          const Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('Pohantoon AI',style:TextStyle(
                fontSize:19,fontWeight:FontWeight.w800)),
              Text('Smarter School Management,\nPowered by AI',
                style:TextStyle(fontSize:10)),
            ])),
        ]),
        const SizedBox(height:44),
        const SchoolCampusIllustration(),
        const SizedBox(height:36),
        const Divider(),
        for (final step in const [
          ('Account Connected','Sign in securely',1),
          ('Choose Your Plan','Choose a subscription plan',2),
          ('School Information','Tell us about your school',3),
          ('Application Review','Review your details',4),
          ('Subscription Payment','After approval',5),
          ('School Dashboard','Set up your workspace',6),
        ])
          Container(
            margin:const EdgeInsets.only(top:10),
            padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
            decoration:BoxDecoration(
              color:step.$3==3
                  ? colors.primary.withValues(alpha:.13)
                  : Colors.transparent,
              borderRadius:BorderRadius.circular(12)),
            child:Row(children:[
              CircleAvatar(radius:15,
                backgroundColor:step.$3<3
                    ? colors.primary
                    : step.$3==3?colors.primaryContainer:colors.surface,
                child:step.$3<3
                    ? Icon(Icons.check,size:16,color:colors.onPrimary)
                    : Text(step.$3.toString(),style:TextStyle(
                        color:colors.primary,fontWeight:FontWeight.w700))),
              const SizedBox(width:11),
              Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(step.$1,style:TextStyle(fontSize:13,
                    fontWeight:step.$3==3?FontWeight.w800:FontWeight.w600)),
                  Text(step.$2,style:TextStyle(fontSize:10,
                    color:colors.onSurfaceVariant)),
                ])),
            ]),
          ),
      ]),
    );
  }

  Widget _notices() {
    final info=_notice(Icons.info_outline,
      'Recommended setup: essential + optional details. '
      'No payment is charged at this stage.');
    final plan=_notice(Icons.workspace_premium_outlined,
      'Selected plan: '+widget.plan.name+'\n'+widget.plan.summaryLimits);
    return LayoutBuilder(builder:(context,size) =>
      size.maxWidth>=850
        ? Row(children:[
            Expanded(child:info),
            const SizedBox(width:16),
            Expanded(child:plan),
          ])
        : Column(children:[
            info,const SizedBox(height:12),plan,
          ]),
    );
  }

  Widget _notice(IconData icon,String message) {
    final colors=Theme.of(context).colorScheme;
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Container(
      width:double.infinity,
      constraints:const BoxConstraints(minHeight:68),
      padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(
        color:dark?const Color(0xFF154339):const Color(0xFFE3F5EF),
        borderRadius:BorderRadius.circular(13),
        border:Border.all(color:colors.primary.withValues(alpha:.20))),
      child:Row(children:[
        Icon(icon,size:26,color:colors.primary),
        const SizedBox(width:12),
        Expanded(child:Text(message,
          style:const TextStyle(fontSize:13,height:1.42))),
      ]),
    );
  }

  Widget _errorBox()=>Container(
    key:const Key('school-setup-error'),
    padding:const EdgeInsets.all(16),
    decoration:BoxDecoration(
      color:Theme.of(context).colorScheme.errorContainer,
      borderRadius:BorderRadius.circular(12)),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.error_outline,
        color:Theme.of(context).colorScheme.error),
      const SizedBox(width:10),
      Expanded(child:Text(error!,style:TextStyle(
        color:Theme.of(context).colorScheme.onErrorContainer))),
    ]),
  );

  Widget _formCards() {
    final cards=<Widget>[
      _card('School Identity',Icons.apartment_outlined,[
        _text('School name','schoolName',
          hint:'Enter school name',mandatory:true),
        _text('Legal school name','legalName',
          hint:'Enter legal school name'),
        _choice('School type',schoolType,const {
          'public':'Public School','private':'Private School',
          'international':'International School',
          'nonprofit':'Nonprofit School','other':'Other',
        },(v)=>setState(() { schoolType=v;dirty=true; }),mandatory:true),
        _text('Registration / License No.','registration',
          hint:'Enter registration or license number'),
        _text('Year established','year',
          hint:'e.g., 2010',numeric:true),
        _text('Website','website',
          hint:'https://www.yourschool.edu'),
      ]),
      _card('Primary Contact',Icons.person_outline,[
        _text('Contact name','contactName',
          hint:'Enter contact name',mandatory:true),
        _text('Position / Role','contactPosition',
          hint:'e.g., Principal, Administrator'),
        _text('School contact email','contactEmail',
          hint:'Enter school contact email',mandatory:true),
        _text('Phone','contactPhone',
          hint:'e.g., +1 234 567 8900'),
      ],account:true),
      _card('Location & Preferences',Icons.location_on_outlined,[
        _choice('Country',countryCode,countries,
          (v)=>setState(() { countryCode=v;dirty=true; }),mandatory:true),
        if (countryCode=='OTHER')
          _text('Country ISO code','otherCountry',
            hint:'e.g., BT',mandatory:true),
        _text('State / Province','region',
          hint:'Enter state or province'),
        _text('City','city',hint:'Enter city',mandatory:true),
        _text('Address','address',hint:'Enter school address'),
        _text('Postal code','postalCode',hint:'Optional postal or ZIP code'),
        _choice('Time zone',timezone,zones,
          (v)=>setState(() { timezone=v??'UTC';dirty=true; })),
        if (timezone=='OTHER')
          _text('IANA time zone','otherZone',
            hint:'e.g., Asia/Kabul'),
        _choice('Preferred currency',currency,currencies,
          (v)=>setState(() { currency=v??'USD';dirty=true; })),
        if (currency=='OTHER')
          _text('Currency ISO code','otherCurrency',hint:'e.g., BTN'),
      ]),
      _card('Academics & Capacity',Icons.layers_outlined,[
        _text('Estimated students','students',
          hint:'e.g., 1500',numeric:true,mandatory:true),
        _text('Number of campuses','campuses',
          hint:'e.g., 5',numeric:true,mandatory:true),
        _text('Estimated teachers','teachers',
          hint:'e.g., 120',numeric:true),
        _text('Non-teaching staff','staff',
          hint:'e.g., 30',numeric:true),
        _text('Education board','board',
          hint:'e.g., International Baccalaureate'),
        _text('Curriculum','curriculum',
          hint:'e.g., IB Diploma Programme'),
        _choice('Lowest grade',lowestGrade,{
          for(final g in grades)
            g:g=='OTHER'?'Other grade':g,
        },(v)=>setState(() { lowestGrade=v;dirty=true; })),
        if(lowestGrade=='OTHER')
          _text('Other lowest grade','otherLowest'),
        _choice('Highest grade',highestGrade,{
          for(final g in grades)
            g:g=='OTHER'?'Other grade':g,
        },(v)=>setState(() { highestGrade=v;dirty=true; })),
        if(highestGrade=='OTHER')
          _text('Other highest grade','otherHighest'),
        _languageSelector(),
      ]),
    ];
    return LayoutBuilder(builder:(context,bounds) {
      if (bounds.maxWidth<900) {
        return Column(children:[
          for (final card in cards) ...[
            card,const SizedBox(height:15),
          ],
        ]);
      }
      return Column(children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:cards[0]),
          const SizedBox(width:16),
          Expanded(child:cards[1]),
        ]),
        const SizedBox(height:16),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:cards[2]),
          const SizedBox(width:16),
          Expanded(child:cards[3]),
        ]),
      ]);
    });
  }

  Widget _card(String title,IconData icon,List<Widget> items,
      {bool account=false}) {
    final colors=Theme.of(context).colorScheme;
    final dark=Theme.of(context).brightness==Brightness.dark;
    final section = switch(title) {
      'School Identity' => 'identity',
      'Primary Contact' => 'contact',
      'Location & Preferences' => 'location',
      _ => 'academics',
    };
    return Container(
      key: sectionKeys[section],
      padding:const EdgeInsets.all(18),
      decoration:BoxDecoration(
        color:dark?const Color(0xFF122D31):Colors.white,
        borderRadius:BorderRadius.circular(16),
        border:Border.all(color:colors.outlineVariant),
        boxShadow:[
          if (!dark) BoxShadow(
            color:Colors.black.withValues(alpha:.035),
            blurRadius:12,offset:const Offset(0,4)),
        ],
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Row(children:[
            CircleAvatar(
              radius:20,
              backgroundColor:colors.primaryContainer,
              child:Icon(icon,color:colors.primary,size:22)),
            const SizedBox(width:11),
            Expanded(child:Text(title,style:const TextStyle(
              fontSize:18,fontWeight:FontWeight.w800))),
          ]),
          const SizedBox(height:17),
          if (account) ...[
            _labelled('Signed-in account email',child:TextFormField(
              key:const Key('school-account-email'),
              enabled:false,
              initialValue:widget.accountEmail??'Signed-in account',
              decoration:const InputDecoration(
                prefixIcon:Icon(Icons.lock_outline),isDense:true,
                contentPadding:EdgeInsets.symmetric(
                  horizontal:12,vertical:12)))),
            const SizedBox(height:13),
          ],
          LayoutBuilder(builder:(context,bounds) {
            final columns=bounds.maxWidth>=300?2:1;
            final fieldWidth=(bounds.maxWidth-(columns-1)*12)/columns;
            return Wrap(spacing:12,runSpacing:14,children:[
              for(final item in items)
                SizedBox(width:fieldWidth,child:item),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _text(String label,String field,{
    String? hint,bool numeric=false,bool mandatory=false,
  }) => _labelled(label,mandatory:mandatory,child:TextField(
    key:Key('school-field-'+field),
    controller:controller(field),
    enabled:!saving,
    keyboardType:numeric?TextInputType.number
      :field=='contactEmail'?TextInputType.emailAddress
      :field=='website'?TextInputType.url:TextInputType.text,
    textInputAction:TextInputAction.next,
    maxLength:switch(field) {
      'schoolName'=>180,'legalName'=>220,'website'=>500,
      'address'=>500,'contactEmail'=>254,'postalCode'=>32,_=>120,
    },
    decoration:InputDecoration(
      hintText:hint,counterText:'',isDense:true,
      contentPadding:const EdgeInsets.symmetric(
        horizontal:12,vertical:13)),
  ));

  Widget _choice(String label,String? selected,
      Map<String,String> options,ValueChanged<String?> changed,
      {bool mandatory=false}) =>
    _labelled(label,mandatory:mandatory,
      child:DropdownButtonFormField<String>(
        key:Key('school-select-'+label.toLowerCase().replaceAll(' ','-')),
        value:selected,
        isExpanded:true,
        hint:Text('Select '+label.toLowerCase(),
          overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:12)),
        decoration:const InputDecoration(
          isDense:true,
          contentPadding:EdgeInsets.symmetric(
            horizontal:12,vertical:12)),
        items:[
          for(final entry in options.entries)
            DropdownMenuItem<String>(
              value:entry.key,
              child:Text(entry.value,
                overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:12))),
        ],
        onChanged:saving?null:changed,
      ));

  Widget _labelled(String label,{
    required Widget child,bool mandatory=false,
  }) => Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[
      Text.rich(TextSpan(children:[
        TextSpan(text:label,style:const TextStyle(
          fontSize:12.5,fontWeight:FontWeight.w700)),
        TextSpan(
          text:mandatory?' *':' (optional)',
          style:TextStyle(
            color:mandatory?Theme.of(context).colorScheme.error
              :Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize:11)),
      ])),
      const SizedBox(height:6),
      child,
    ],
  );

  Future<void> _editLanguages() async {
    final picked=<String>{...languages};
    final custom=TextEditingController();
    final changed=await showDialog<Set<String>>(
      context:context,
      builder:(ctx)=>StatefulBuilder(
        builder:(ctx,refresh)=>AlertDialog(
          title:const Text('Teaching languages'),
          content:SizedBox(
            width:350,
            child:SingleChildScrollView(
              child:Column(
                mainAxisSize:MainAxisSize.min,
                children:[
                  for (final name in suggestedLanguages)
                    CheckboxListTile(
                      dense:true,title:Text(name),
                      value:picked.contains(name),
                      onChanged:(checked)=>refresh(() {
                        if(checked==true) {
                          picked.add(name);
                        } else {
                          picked.remove(name);
                        }
                      })),
                  TextField(
                    controller:custom,
                    decoration:const InputDecoration(
                      labelText:'Other language',
                      hintText:'Enter another teaching language')),
                ],
              ),
            ),
          ),
          actions:[
            TextButton(
              onPressed:()=>Navigator.pop(ctx),
              child:const Text('Cancel')),
            FilledButton(
              onPressed:() {
                final extra=custom.text.trim();
                if(extra.isNotEmpty) picked.add(extra);
                if(picked.length<=15) Navigator.pop(ctx,picked);
              },
              child:const Text('Apply')),
          ],
        ),
      ),
    );
    custom.dispose();
    if(changed==null||!mounted)return;
    setState(() {
      languages..clear()..addAll(changed);
      dirty=true;
    });
  }

  Widget _languageSelector()=>_labelled('Teaching languages',
    child:InkWell(
      key:const Key('school-teaching-languages'),
      onTap:saving?null:_editLanguages,
      child:Container(
        constraints:const BoxConstraints(minHeight:46),
        padding:const EdgeInsets.all(8),
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(10),
          border:Border.all(
            color:Theme.of(context).colorScheme.outlineVariant)),
        child:Wrap(
          spacing:5,runSpacing:3,
          crossAxisAlignment:WrapCrossAlignment.center,
          children:[
            if(languages.isEmpty)
              const Padding(
                padding:EdgeInsets.all(4),
                child:Text('Select languages',
                  style:TextStyle(fontSize:12))),
            for(final language in languages)
              Chip(
                label:Text(language,
                  style:const TextStyle(fontSize:11)),
                visualDensity:VisualDensity.compact),
            const Icon(Icons.arrow_drop_down,size:21),
          ],
        ),
      ),
    ));

  Widget _footer() {
    final busy=saving || loading;
    final save=OutlinedButton.icon(
      key:const Key('school-save-draft'),
      onPressed:busy?null:()=>_save(false),
      icon:const Icon(Icons.save_outlined),
      label:const Text('Save Draft'));
    final back=OutlinedButton.icon(
      key:const Key('school-setup-back-bottom'),
      onPressed:busy?null:_back,
      icon:const Icon(Icons.arrow_back),
      label:const Text('Back'));
    final next=FilledButton.icon(
      key:const Key('school-continue-review'),
      onPressed:busy?null:()=>_save(true),
      iconAlignment:IconAlignment.end,
      icon:busy
        ? const SizedBox(width:16,height:16,
            child:CircularProgressIndicator(strokeWidth:2))
        : const Icon(Icons.arrow_forward),
      label:const Text('Continue to Review'));
    return LayoutBuilder(builder:(context,size) {
      if(size.maxWidth<650) {
        return Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            next,
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:save),
              const SizedBox(width:10),
              Expanded(child:back),
            ]),
            const SizedBox(height:12),
            Text('Save a draft and continue later.',
              textAlign:TextAlign.center,
              style:TextStyle(fontSize:12,
                color:Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        );
      }
      return Row(children:[
        save,const SizedBox(width:12),back,
        const Spacer(),
        Text('Save a draft and continue later.',
          style:TextStyle(fontSize:12,
            color:Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width:14),next,
      ]);
    });
  }
}
