import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/measurement_point.dart';
import '../models/reading.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Digital replica of the paper "Measurement Findings Summary":
/// one tally row per measurement point across all deviation
/// buckets, plus computed stats (mean deviation, pass/fail vs
/// the job's tolerance).
class JobSummaryScreen extends StatelessWidget {
  final Job job;

  const JobSummaryScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          job.style.isEmpty ? 'Job Summary' : '${job.style} Summary',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Reading>>(
        stream: firestore.watchReadings(job.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            );
          }
          final readings = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(),
              const SizedBox(height: 18),
              const Text(
                'Point-by-Point Findings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 12),
              for (final point in MeasurementPoint.values) ...[
                _measurementBlock(context, point, readings),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 20, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Job Specifications',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _infoItem('Style', job.style),
              _infoItem('PO', job.po),
              _infoItem('Pattern No.', job.patternNo),
              _infoItem('Sample Unit', job.sampleUnit),
              _infoItem('Size Set', job.sizeSet),
              _infoItem('Tolerance', '±${formatDeviation(job.tolerance)}"'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.slateNavy.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }

  Widget _measurementBlock(
    BuildContext context,
    MeasurementPoint point,
    List<Reading> allReadings,
  ) {
    final stats =
        MeasurementStats.fromReadings(point, allReadings, job.tolerance);
    final matching =
        allReadings.where((r) => r.measurementPoint == point).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stats.count > 0 && !stats.passes
              ? AppColors.failRed.withValues(alpha: 0.4)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.deepNavy,
                ),
              ),
              if (stats.count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stats.passes
                        ? AppColors.passGreen.withValues(alpha: 0.12)
                        : AppColors.failRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats.passes
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 15,
                        color: stats.passes
                            ? AppColors.passGreen
                            : AppColors.failRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stats.passes ? 'PASS' : 'OUT OF TOL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: stats.passes
                              ? AppColors.passGreen
                              : AppColors.failRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Tally row — count of pieces at each deviation bucket.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kDeviationBuckets.map((bucket) {
                final count =
                    matching.where((r) => r.deviation == bucket).length;
                final isZero = bucket == 0;
                return Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: count > 0
                          ? AppColors.primaryBlue
                          : AppColors.borderLight,
                    ),
                    color: count > 0
                        ? AppColors.selectedBlueLight
                        : (isZero
                            ? AppColors.cardFill
                            : AppColors.surfaceWhite),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatDeviation(bucket),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isZero ? FontWeight.w800 : FontWeight.w600,
                          color: count > 0
                              ? AppColors.primaryBlue
                              : AppColors.slateNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count > 0 ? '$count' : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: count > 0
                              ? AppColors.primaryBlue
                              : AppColors.slateNavy.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sample: ${stats.count} pcs   ·   Mean: ${stats.meanDeviation.toStringAsFixed(3)}"   ·   Within Tol: ${stats.withinTolerance}/${stats.count}'
              '${stats.count == 0 ? '' : ' (${(stats.passRate * 100).toStringAsFixed(0)}%)'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slateNavy.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
