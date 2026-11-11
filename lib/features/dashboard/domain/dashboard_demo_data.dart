/// Illustrative design fixtures ONLY. Never confuse with actual school data.
/// Live tenant tables are read-only and currently contain no provisioned
/// schools. Demo data is deliberately separate from production repositories.
class DemoTrendSeries {
  const DemoTrendSeries(this.id, this.title, this.subtitle,
      this.values, this.labels, this.suffix);
  final String id, title, subtitle, suffix;
  final List<double> values;
  final List<String> labels;
}

const demoTrends = <DemoTrendSeries>[
  DemoTrendSeries('enrollment','Student enrollment',
    'Growth over the last six months',
    [1148,1178,1201,1200,1235,1248],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],' students'),
  DemoTrendSeries('attendance','Attendance trend',
    'Daily presence over the last six months',
    [91.0,92.2,92.1,93.8,93.7,94.6],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],'%'),
  DemoTrendSeries('admissions','Admissions growth',
    'New students admitted every month',
    [26,31,29,37,41,48],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],' admissions'),
  DemoTrendSeries('fees','Fee collections',
    'Monthly collections in thousands of AFN',
    [630,665,710,730,799,842],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],'K AFN'),
  DemoTrendSeries('staff','Staff growth',
    'Teachers and administrative staff',
    [76,77,79,82,84,86],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],' staff'),
  DemoTrendSeries('capacity','Classroom utilization',
    'Occupancy percentage by month',
    [63,67,70,72,74,78],
    ['Jun','Jul','Aug','Sep','Oct','Nov'],'%'),
];

class DemoActivity {
  const DemoActivity(this.initials,this.name,this.detail,this.status,this.when);
  final String initials,name,detail,status,when;
}

const recentDemoAdmissions = <DemoActivity>[
  DemoActivity('SA','Sarah Ahmed','Grade 7 · Submitted today','In review','Today'),
  DemoActivity('MK','Mohammad Khan','Grade 5 · Yesterday','Approved','Yesterday'),
  DemoActivity('FH','Fatima Habib','Grade 9 · 9 Nov','In review','9 Nov'),
  DemoActivity('AR','Aisha Rahimi','Grade 6 · 8 Nov','Approved','8 Nov'),
  DemoActivity('ZT','Zahir Tariq','Grade 8 · 7 Nov','In review','7 Nov'),
  DemoActivity('NS','Nadia Safi','Grade 4 · 6 Nov','Approved','6 Nov'),
];

const recentDemoApprovals = <DemoActivity>[
  DemoActivity('MK','Mohammad Khan','New admission · Grade 5','Approved','Today'),
  DemoActivity('AR','Aisha Rahimi','New admission · Grade 6','Approved','Yesterday'),
  DemoActivity('NS','Nadia Safi','New admission · Grade 4','Approved','9 Nov'),
  DemoActivity('OE','Omar Ehsan','Staff request · Science','Approved','8 Nov'),
  DemoActivity('SA','Sarah Ahmed','Document verification','Pending','7 Nov'),
  DemoActivity('HL','Husna Latif','Admission document','Approved','6 Nov'),
];
