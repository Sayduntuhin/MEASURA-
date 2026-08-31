import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/measurement_point.dart';
import '../models/reading.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deviation_button_grid.dart';
import 'job_summary_screen.dart';

/// The core MEASURA entry screen: pick a measurement point,
/// then tap a deviation value per garment piece measured.
class MeasurementEntryScreen extends StatefulWidget {
  final Job job;

  const MeasurementEntryScreen({super.key, required this.job});

  @override
  State<MeasurementEntryScreen> createState() =>
      _MeasurementEntryScreenState();
}

class _MeasurementEntryScreenState extends State<MeasurementEntryScreen> {
  MeasurementPoint _selectedPoint = MeasurementPoint.waist;

  Future<void> _record(double value) async {
    final firestore = context.read<FirestoreService>();
    await firestore.addReading(
      jobId: widget.job.id,
      measurementPoint: _selectedPoint,
      deviation: value,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded ${formatDeviation(value)}" for ${_selectedPoint.label}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(milliseconds: 900),
          backgroundColor: AppColors.deepNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job.style.isEmpty ? 'Measurement Entry' : widget.job.style,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'PO ${widget.job.po} · Tol ±${widget.job.tolerance}"',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slateNavy.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_rounded, color: AppColors.primaryBlue),
            tooltip: 'View summary report',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobSummaryScreen(job: widget.job),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<List<Reading>>(
        stream: firestore.watchReadings(widget.job.id),
        builder: (context, snapshot) {
          final readings = snapshot.data ?? [];
          final selectedCount = readings
              .where((r) => r.measurementPoint == _selectedPoint)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Measurement Point',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.selectedBlueLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedCount recorded',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _measurementPointGrid(readings),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 20),
              DeviationButtonGrid(
                onSelected: _record,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _measurementPointGrid(List<Reading> allReadings) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MeasurementPoint.values.map((point) {
        final selected = point == _selectedPoint;
        final count = allReadings.where((r) => r.measurementPoint == point).length;

        return SizedBox(
          width: 110,
          height: 54,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selectedPoint = point),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryBlue : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primaryBlue : AppColors.borderLight,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    point.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                  if (count > 0)
                    Text(
                      '$count pcs',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.slateNavy.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
