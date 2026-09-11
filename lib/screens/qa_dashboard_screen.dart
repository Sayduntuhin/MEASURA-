import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/measurement_point.dart';
import '../models/reading.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'job_setup_screen.dart';

class QaDashboardScreen extends StatefulWidget {
  const QaDashboardScreen({super.key});

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  String? _selectedJobId; // null means all jobs or latest
  MeasurementPoint? _selectedPoint; // null means all points
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month'

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final user = context.watch<AuthService>().currentUser;
    final dateFormat = DateFormat('MMM d, yyyy');

    return StreamBuilder<List<Job>>(
      stream: firestore.watchJobs(
        userId: user?.uid,
        userEmail: user?.email,
      ),
      builder: (context, jobSnapshot) {
        if (!jobSnapshot.hasData) {
          if (jobSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 48, color: Colors.orange),
                    const SizedBox(height: 14),
                    const Text(
                      'Firestore Permission Required',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.deepNavy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please set Firestore Rules to allow reads/writes in Firebase Console > Firestore > Rules tab.\n\n${jobSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.slateNavy.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        final jobs = jobSnapshot.data!;

        // Ensure _selectedJobId belongs to the current user's jobs
        if (jobs.isEmpty) {
          _selectedJobId = null;
        } else if (_selectedJobId == null || !jobs.any((j) => j.id == _selectedJobId)) {
          _selectedJobId = jobs.first.id;
        }

        final currentJob = jobs.where((j) => j.id == _selectedJobId).firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: jobs.isEmpty
              ? _buildEmptyState()
              : StreamBuilder<List<Reading>>(
                  stream: (_selectedJobId != null && jobs.any((j) => j.id == _selectedJobId))
                      ? firestore.watchReadings(_selectedJobId!)
                      : Stream.value(<Reading>[]),
                  builder: (context, readingSnapshot) {
                    final readings = readingSnapshot.data ?? [];
                    return _buildDashboardContent(
                      jobs: jobs,
                      currentJob: currentJob,
                      allReadings: readings,
                      dateFormat: dateFormat,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.selectedBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 52,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Measurement Data Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new QA inspection job and start recording measurements to view real-time histograms and findings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.slateNavy.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JobSetupScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Create First QA Job',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent({
    required List<Job> jobs,
    required Job? currentJob,
    required List<Reading> allReadings,
    required DateFormat dateFormat,
  }) {
    // 1. Apply Date Filter
    final now = DateTime.now();
    final filteredByDate = allReadings.where((r) {
      if (_dateFilter == 'today') {
        return r.recordedAt.year == now.year &&
            r.recordedAt.month == now.month &&
            r.recordedAt.day == now.day;
      } else if (_dateFilter == 'week') {
        final diff = now.difference(r.recordedAt).inDays;
        return diff <= 7;
      } else if (_dateFilter == 'month') {
        return r.recordedAt.year == now.year &&
            r.recordedAt.month == now.month;
      }
      return true;
    }).toList();

    // 2. Apply Point Filter
    final filteredReadings = _selectedPoint == null
        ? filteredByDate
        : filteredByDate
            .where((r) => r.measurementPoint == _selectedPoint)
            .toList();

    final tolerance = currentJob?.tolerance ?? 0.25;

    // 3. Compute Summary Statistics
    final totalCount = filteredReadings.length;
    final withinTolCount = filteredReadings
        .where((r) => r.deviation.abs() <= tolerance + 0.0001)
        .length;
    final outOfTolCount = totalCount - withinTolCount;
    final passRate = totalCount == 0 ? 0.0 : (withinTolCount / totalCount);

    final meanDeviation = totalCount == 0
        ? 0.0
        : filteredReadings.fold<double>(0.0, (sum, r) => sum + r.deviation) /
            totalCount;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Filter & Job Selector Header
          _buildJobAndFilterHeader(jobs, currentJob, dateFormat),

          const SizedBox(height: 16),

          // Point Selection Tabs
          _buildPointChips(),

          const SizedBox(height: 18),

          // Summary Metrics Cards
          _buildKpiGrid(
            totalCount: totalCount,
            withinTolCount: withinTolCount,
            outOfTolCount: outOfTolCount,
            passRate: passRate,
            meanDeviation: meanDeviation,
            tolerance: tolerance,
          ),

          const SizedBox(height: 20),

          // Excel-style Mmts Histogram Section (from user's sheet)
          _buildHistogramCard(
            readings: filteredReadings,
            tolerance: tolerance,
            pointLabel: _selectedPoint?.label.toUpperCase() ?? 'ALL MEASUREMENT POINTS',
          ),

          const SizedBox(height: 16),

          // Findings Summary Data Table (Matching Excel grid from screenshot)
          _buildFindingsDataTable(
            readings: filteredReadings,
            pointLabel: _selectedPoint?.label.toUpperCase() ?? 'TOTAL SAMPLE',
          ),
        ],
      ),
    );
  }

  Widget _buildJobAndFilterHeader(
    List<Job> jobs,
    Job? currentJob,
    DateFormat dateFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Dropdown Picker
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.selectedBlueLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Active QA Job:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedJobId,
                      items: jobs.map((job) {
                        return DropdownMenuItem<String>(
                          value: job.id,
                          child: Text(
                            '${job.style.isEmpty ? "No Style" : job.style} · PO ${job.po}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedJobId = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (currentJob != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _infoChip(Icons.pattern_rounded, 'Pattern: ${currentJob.patternNo}'),
                _infoChip(Icons.check_circle_outline, 'Tol: ±${formatDeviation(currentJob.tolerance)}"'),
                _infoChip(Icons.calendar_today_rounded, dateFormat.format(currentJob.date)),
              ],
            ),
          ],

          const Divider(height: 20, color: AppColors.surfaceSubtle),

          // Date Filter Segment
          Row(
            children: [
              Text(
                'Time Horizon: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slateNavy.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _dateFilterChip('all', 'All Time'),
                      _dateFilterChip('today', 'Today'),
                      _dateFilterChip('week', 'Last 7 Days'),
                      _dateFilterChip('month', 'This Month'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.slateNavy.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.slateNavy.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _dateFilterChip(String key, String label) {
    final isSelected = _dateFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.deepNavy,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryBlue,
        backgroundColor: AppColors.cardFill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _dateFilter = key);
          }
        },
      ),
    );
  }

  Widget _buildPointChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text(
                'All Points',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              selected: _selectedPoint == null,
              selectedColor: AppColors.deepNavy,
              labelStyle: TextStyle(
                color: _selectedPoint == null ? Colors.white : AppColors.deepNavy,
              ),
              backgroundColor: AppColors.surfaceWhite,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _selectedPoint == null
                      ? AppColors.deepNavy
                      : AppColors.borderLight,
                ),
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedPoint = null);
              },
            ),
          ),
          ...MeasurementPoint.values.map((point) {
            final isSelected = _selectedPoint == point;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  point.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryBlue,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.deepNavy,
                ),
                backgroundColor: AppColors.surfaceWhite,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.borderLight,
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedPoint = point);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required int totalCount,
    required int withinTolCount,
    required int outOfTolCount,
    required double passRate,
    required double meanDeviation,
    required double tolerance,
  }) {
    return Row(
      children: [
        Expanded(
          child: _kpiMetricCard(
            title: 'PASS RATE',
            value: totalCount == 0 ? '0%' : '${(passRate * 100).toStringAsFixed(1)}%',
            subtitle: '$withinTolCount / $totalCount in spec',
            color: passRate >= 0.9
                ? AppColors.passGreen
                : (passRate >= 0.75 ? Colors.orange : AppColors.failRed),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiMetricCard(
            title: 'SAMPLE COUNT',
            value: '$totalCount pcs',
            subtitle: 'Tolerance: ±${formatDeviation(tolerance)}"',
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiMetricCard(
            title: 'MEAN DEV',
            value: '${meanDeviation >= 0 ? "+" : ""}${meanDeviation.toStringAsFixed(3)}"',
            subtitle: '$outOfTolCount out of tol',
            color: outOfTolCount == 0 ? AppColors.passGreen : AppColors.failRed,
          ),
        ),
      ],
    );
  }

  Widget _kpiMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slateNavy.withValues(alpha: 0.65),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.slateNavy.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Excel-style Histogram Card matching user's image with exact percentages on top of bars
  Widget _buildHistogramCard({
    required List<Reading> readings,
    required double tolerance,
    required String pointLabel,
  }) {
    final totalSamples = readings.length;

    // Display buckets focusing on the central ±3/4" or full range
    const displayBuckets = [
      -0.75,
      -0.625,
      -0.5,
      -0.375,
      -0.25,
      -0.125,
      0.0,
      0.125,
      0.25,
      0.375,
      0.5,
      0.625,
      0.75,
    ];

    // Compute distribution counts & percentages
    final Map<double, int> counts = {};
    for (final b in displayBuckets) {
      counts[b] = 0;
    }
    for (final r in readings) {
      final closest = displayBuckets.reduce(
        (a, b) => (a - r.deviation).abs() < (b - r.deviation).abs() ? a : b,
      );
      counts[closest] = (counts[closest] ?? 0) + 1;
    }

    final maxCount = counts.values.isEmpty ? 1 : counts.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mmts Histogram',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepNavy,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      pointLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'Tolerance: ±${formatDeviation(tolerance)}"',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Histogram Chart Area
          SizedBox(
            height: 200,
            child: totalSamples == 0
                ? Center(
                    child: Text(
                      'No readings recorded for this point/job.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slateNavy.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: displayBuckets.map((bucket) {
                        final count = counts[bucket] ?? 0;
                        final percent =
                            totalSamples == 0 ? 0.0 : (count / totalSamples) * 100;
                        final isWithinTol =
                            bucket.abs() <= tolerance + 0.0001;
                        final isZero = bucket == 0;

                        final barHeight = maxCount == 0
                            ? 0.0
                            : (count / maxCount) * 120.0;

                        // Sleek charcoal/slate bar matching Excel screenshot
                        final barColor = isWithinTol
                            ? (isZero
                                ? const Color(0xFF1E293B) // Dark charcoal
                                : const Color(0xFF475569)) // Slate
                            : AppColors.failRed;

                        return Container(
                          width: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Percentage label on top of bar (exactly like screenshot)
                              Text(
                                '${percent.round()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: percent > 0
                                      ? AppColors.deepNavy
                                      : AppColors.slateNavy.withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Bar
                              Container(
                                height: barHeight.clamp(2.0, 120.0),
                                width: 22,
                                decoration: BoxDecoration(
                                  color: percent > 0
                                      ? barColor
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),

                              // Base line
                              Container(
                                height: 1.5,
                                color: AppColors.borderLight,
                                margin: const EdgeInsets.only(top: 2, bottom: 4),
                              ),

                              // Deviation Label below bar
                              Text(
                                formatDeviation(bucket),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isZero
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: isZero
                                      ? AppColors.primaryBlue
                                      : AppColors.deepNavy,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Findings Summary Data Table (Matching the lower portion of user's Excel sheet)
  Widget _buildFindingsDataTable({
    required List<Reading> readings,
    required String pointLabel,
  }) {
    final totalSamples = readings.length;
    const displayBuckets = [
      -0.75,
      -0.5,
      -0.375,
      -0.25,
      -0.125,
      0.0,
      0.125,
      0.25,
      0.375,
      0.5,
      0.75,
    ];

    final Map<double, int> counts = {};
    for (final b in displayBuckets) {
      counts[b] = 0;
    }
    for (final r in readings) {
      final closest = displayBuckets.reduce(
        (a, b) => (a - r.deviation).abs() < (b - r.deviation).abs() ? a : b,
      );
      counts[closest] = (counts[closest] ?? 0) + 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.grid_on_rounded,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pointLabel · FINDINGS BREAKDOWN',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.deepNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Excel-styled Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(54),
                border: TableBorder.all(
                  color: AppColors.borderLight,
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  // Row 1: Orange/Peach Header with Deviations
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEDD5), // Peach/orange tint like excel
                    ),
                    children: [
                      _tableHeaderCell('MMTS'),
                      ...displayBuckets.map(
                        (b) => _tableHeaderCell(formatDeviation(b)),
                      ),
                    ],
                  ),

                  // Row 2: Counts
                  TableRow(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceWhite,
                    ),
                    children: [
                      _tableCell('COUNT', isBold: true),
                      ...displayBuckets.map((b) {
                        final c = counts[b] ?? 0;
                        return _tableCell(
                          c > 0 ? '$c' : '0',
                          isBold: c > 0,
                          color: c > 0 ? AppColors.deepNavy : AppColors.slateNavy.withValues(alpha: 0.4),
                        );
                      }),
                    ],
                  ),

                  // Row 3: Percentages
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                    ),
                    children: [
                      _tableCell('%', isBold: true),
                      ...displayBuckets.map((b) {
                        final c = counts[b] ?? 0;
                        final p = totalSamples == 0 ? 0 : ((c / totalSamples) * 100).round();
                        return _tableCell(
                          '$p%',
                          isBold: p > 0,
                          color: p > 0 ? AppColors.primaryBlue : AppColors.slateNavy.withValues(alpha: 0.4),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF9A3412), // Deep burnt orange text
        ),
      ),
    );
  }

  Widget _tableCell(
    String text, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? AppColors.deepNavy,
        ),
      ),
    );
  }
}
