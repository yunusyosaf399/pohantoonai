import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/dashboard_demo_data.dart';

/// Reusable six-series analytics carousel. Every panel is independently
/// auto-advanced after 10 seconds; hover or fullscreen pauses the ticker.
class RotatingAnalyticsPanel extends StatefulWidget {
  const RotatingAnalyticsPanel({
    super.key,
    this.initialChart = 'enrollment',
    this.onChartSelected,
  });
  final String initialChart;
  final ValueChanged<String>? onChartSelected;

  @override
  State<RotatingAnalyticsPanel> createState() => _RotatingAnalyticsPanelState();
}

class _RotatingAnalyticsPanelState extends State<RotatingAnalyticsPanel> {
  Timer? timer;
  bool hovering = false;
  bool fullscreen = false;
  late int index;

  @override
  void initState() {
    super.initState();
    index = math.max(0,
      demoTrends.indexWhere((s) => s.id == widget.initialChart));
    _start();
  }

  void _start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !hovering && !fullscreen) {
        setState(() => index = (index + 1) % demoTrends.length);
      }
    });
  }

  void _choose(int delta) {
    setState(() => index =
      (index + delta + demoTrends.length) % demoTrends.length);
    widget.onChartSelected?.call(demoTrends[index].id);
    _start();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    setState(() => fullscreen = true);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(demoTrends[index].title,
                style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                key: const Key('close-fullscreen-trend'),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close full screen',
                icon: const Icon(Icons.close)),
            ]),
            const Text('DEMO DATA · Illustrative chart only'),
            const SizedBox(height: 24),
            Expanded(child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: TrendChart(series: demoTrends[index])))),
          ]),
        ))),
    );
    if (mounted) {
      setState(() => fullscreen = false);
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = demoTrends[index];
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) {
        setState(() => hovering = false);
        _start();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(series.title,
                key: const Key('dashboard-current-trend'),
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(series.subtitle, style: TextStyle(
                fontSize: 12, color: colors.onSurfaceVariant)),
            ],
          )),
          IconButton(
            key: const Key('dashboard-trend-previous'),
            tooltip: 'Previous analytics',
            onPressed: () => _choose(-1),
            icon: const Icon(Icons.chevron_left)),
          IconButton(
            key: const Key('dashboard-trend-next'),
            tooltip: 'Next analytics',
            onPressed: () => _choose(1),
            icon: const Icon(Icons.chevron_right)),
          IconButton(
            key: const Key('dashboard-trend-fullscreen'),
            tooltip: 'Full-screen analytics',
            onPressed: _openFullscreen,
            icon: const Icon(Icons.fullscreen)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: TrendChart(
          key: ValueKey(series.id), series: series)),
        const SizedBox(height: 10),
        Row(children: [
          CircleAvatar(radius: 4,backgroundColor: colors.primary),
          const SizedBox(width: 7),
          const Text('Demo analytics · 10-second rotation',
            style: TextStyle(fontSize: 11)),
          const Spacer(),
          Text((index + 1).toString() + '/' +
            demoTrends.length.toString(),
            style: TextStyle(
              fontSize: 11,color: colors.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key,required this.series});
  final DemoTrendSeries series;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: series.title + ': ' +
        series.values.map((n) => n.toStringAsFixed(1)).join(', '),
      child: Column(children: [
        Expanded(child: CustomPaint(
          key: const Key('dashboard-trend-chart'),
          painter: _TrendPainter(series.values,primary,
            textColor.withValues(alpha:.4)),
          child: const SizedBox.expand(),
        )),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final m in series.labels)
              Text(m,style: TextStyle(
                color: textColor,fontSize: 10)),
          ],
        ),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values,this.accent,this.gridColor);
  final List<double> values;
  final Color accent,gridColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10 || size.height < 10 || values.length < 2) return;
    const pad = 14.0;
    final h = size.height - pad * 2;
    final w = size.width - pad * 2;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final extra = math.max(1.0,(maxValue-minValue)*.25);
    final lo = minValue-extra, hi = maxValue+extra;
    for (var k=0;k<4;k++) {
      final y = pad+h*k/3;
      canvas.drawLine(Offset(pad,y),Offset(pad+w,y),
        Paint()..color=gridColor..strokeWidth=0.7);
    }
    Offset point(int i) => Offset(
      pad + w*i/(values.length-1),
      pad + h*(1-(values[i]-lo)/(hi-lo)));
    final stroke = Path()..moveTo(point(0).dx,point(0).dy);
    for (var i=1;i<values.length;i++) {
      final prev=point(i-1),current=point(i);
      final mid=(prev.dx+current.dx)/2;
      stroke.cubicTo(mid,prev.dy,mid,current.dy,
        current.dx,current.dy);
    }
    final area = Path.from(stroke)
      ..lineTo(point(values.length-1).dx,pad+h)
      ..lineTo(pad,pad+h)..close();
    canvas.drawPath(area, Paint()
      ..shader=LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[accent.withValues(alpha:.22),
          accent.withValues(alpha:.008)]).createShader(
            Rect.fromLTWH(0,0,size.width,size.height)));
    canvas.drawPath(stroke,Paint()
      ..color=accent..strokeWidth=3
      ..strokeCap=StrokeCap.round
      ..style=PaintingStyle.stroke);
    final end=point(values.length-1);
    canvas.drawCircle(end,5,Paint()..color=accent);
    canvas.drawCircle(end,2,Paint()..color=Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
    old.accent != accent || old.values != values ||
    old.gridColor != gridColor;
}

/// Rotates each admissions/approvals list every 10s. A hover pauses the
/// timer, and View all opens a fully scrollable list of all demo entries.
class RotatingActivityPanel extends StatefulWidget {
  const RotatingActivityPanel({
    super.key,
    required this.title,
    required this.entries,
    required this.panelKey,
  });
  final String title, panelKey;
  final List<DemoActivity> entries;

  @override
  State<RotatingActivityPanel> createState() =>
      _RotatingActivityPanelState();
}

class _RotatingActivityPanelState extends State<RotatingActivityPanel> {
  Timer? timer;
  bool hovering = false;
  int page = 0;
  int get pages => math.max(1,(widget.entries.length/3).ceil());

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:10),(_) {
      if (mounted && !hovering) {
        setState(() => page=(page+1)%pages);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _viewAll() async {
    timer?.cancel();
    await showDialog<void>(
      context:context,
      builder:(ctx)=>Dialog.fullscreen(
        child:Scaffold(
          appBar:AppBar(
            title:Text('All ' + widget.title),
            actions:[IconButton(
              icon:const Icon(Icons.close),
              onPressed:()=>Navigator.pop(ctx))]),
          body:ListView(
            padding:const EdgeInsets.all(22),
            children:[
              const Text('DEMO DATA · No live approvals are changed here.'),
              const SizedBox(height:20),
              for(final item in widget.entries)
                _activityRow(item),
            ],
          ),
        ),
      ),
    );
    if (mounted) _start();
  }

  Widget _activityRow(DemoActivity item) {
    final colors=Theme.of(context).colorScheme;
    return Padding(
      padding:const EdgeInsets.symmetric(vertical:10),
      child:Row(children:[
        CircleAvatar(
          backgroundColor:colors.primaryContainer,
          child:Text(item.initials,style:TextStyle(
            fontSize:11,fontWeight:FontWeight.w800,
            color:colors.primary))),
        const SizedBox(width:10),
        Expanded(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(item.name,style:const TextStyle(
              fontSize:12,fontWeight:FontWeight.w800)),
            Text(item.detail,style:TextStyle(
              fontSize:11,color:colors.onSurfaceVariant)),
          ])),
        const SizedBox(width:7),
        Chip(
          label:Text(item.status,style:const TextStyle(fontSize:10)),
          visualDensity:VisualDensity.compact),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    final start=page*3;
    final items=widget.entries.skip(start).take(3);
    return MouseRegion(
      onEnter:(_)=>setState(()=>hovering=true),
      onExit:(_){setState(()=>hovering=false);_start();},
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Row(children:[
            Expanded(child:Text(widget.title,style:const TextStyle(
              fontWeight:FontWeight.w800,fontSize:16))),
            TextButton.icon(
              key:Key('dashboard-view-all-' + widget.panelKey),
              onPressed:_viewAll,
              label:const Text('View all'),
              icon:const Icon(Icons.arrow_forward,size:14),
              iconAlignment:IconAlignment.end),
          ]),
          Text('Latest activity · illustrative',
            style:TextStyle(fontSize:11,
              color:colors.onSurfaceVariant)),
          const SizedBox(height:8),
          for(final item in items)
            _activityRow(item),
          const Spacer(),
          Row(mainAxisAlignment:MainAxisAlignment.end,children:[
            IconButton(
              key:Key('dashboard-previous-' + widget.panelKey),
              onPressed:(){
                setState(()=>page=(page-1+pages)%pages);_start();
              },
              icon:const Icon(Icons.chevron_left)),
            Text((page+1).toString() + '/' + pages.toString(),
              style:const TextStyle(fontSize:11)),
            IconButton(
              key:Key('dashboard-next-' + widget.panelKey),
              onPressed:(){
                setState(()=>page=(page+1)%pages);_start();
              },
              icon:const Icon(Icons.chevron_right)),
          ]),
        ],
      ),
    );
  }
}
