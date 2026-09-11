import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'measurement_entry_screen.dart';

class JobSetupScreen extends StatefulWidget {
  final Job? existingJob;

  const JobSetupScreen({super.key, this.existingJob});

  @override
  State<JobSetupScreen> createState() => _JobSetupScreenState();
}

class _JobSetupScreenState extends State<JobSetupScreen> {
  late final TextEditingController _styleController;
  late final TextEditingController _poController;
  late final TextEditingController _patternNoController;
  late final TextEditingController _sampleUnitController;
  late final TextEditingController _sizeSetController;
  late final TextEditingController _toleranceController;
  late DateTime _date;
  bool _saving = false;

  final List<double> _presetTolerances = [0.125, 0.25, 0.375, 0.5];

  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    final job = widget.existingJob;
    _styleController = TextEditingController(text: job?.style ?? '');
    _poController = TextEditingController(text: job?.po ?? '');
    _patternNoController = TextEditingController(text: job?.patternNo ?? '');
    _sampleUnitController = TextEditingController(text: job?.sampleUnit ?? '');
    _sizeSetController = TextEditingController(text: job?.sizeSet ?? '');
    _toleranceController =
        TextEditingController(text: (job?.tolerance ?? 0.25).toString());
    _date = job?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _styleController.dispose();
    _poController.dispose();
    _patternNoController.dispose();
    _sampleUnitController.dispose();
    _sizeSetController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveJob() async {
    if (_styleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Style name.')),
      );
      return;
    }

    setState(() => _saving = true);
    final firestore = context.read<FirestoreService>();
    final user = context.read<AuthService>().currentUser;
    final tolerance = double.tryParse(_toleranceController.text) ?? 0.25;

    try {
      if (_isEditing) {
        await firestore.updateJob(
          jobId: widget.existingJob!.id,
          style: _styleController.text.trim(),
          po: _poController.text.trim(),
          patternNo: _patternNoController.text.trim(),
          sampleUnit: _sampleUnitController.text.trim(),
          sizeSet: _sizeSetController.text.trim(),
          date: _date,
          tolerance: tolerance,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully.')),
        );
        Navigator.of(context).pop();
      } else {
        final job = await firestore.createJob(
          userId: user?.uid ?? '',
          style: _styleController.text.trim(),
          po: _poController.text.trim(),
          patternNo: _patternNoController.text.trim(),
          sampleUnit: _sampleUnitController.text.trim(),
          sizeSet: _sizeSetController.text.trim(),
          date: _date,
          tolerance: tolerance,
          createdBy: user?.email ?? user?.uid ?? 'unknown',
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MeasurementEntryScreen(job: job),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTolerance = double.tryParse(_toleranceController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit QA Job' : 'New QA Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _styleController,
                    decoration: const InputDecoration(
                      labelText: 'Style Name / Code *',
                      hintText: 'e.g. Slim Fit Denim 501',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _poController,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Order (PO)',
                      hintText: 'e.g. PO-8921',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _patternNoController,
                    decoration: const InputDecoration(
                      labelText: 'Pattern No.',
                      hintText: 'e.g. PTN-04B',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _sampleUnitController,
                    decoration: const InputDecoration(
                      labelText: 'Sample Unit',
                      hintText: 'e.g. Unit 3 / Factory A',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _sizeSetController,
                    decoration: const InputDecoration(
                      labelText: 'Size Set / Pilot Run',
                      hintText: 'e.g. Size 32 - Pilot 1',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tolerance (Inches)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _presetTolerances.map((tol) {
                      final isSelected = selectedTolerance == tol;
                      final label = tol == 0.125
                          ? '± 1/8"'
                          : (tol == 0.25
                              ? '± 1/4"'
                              : (tol == 0.375 ? '± 3/8"' : '± 1/2"'));
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.selectedBlueLight,
                        backgroundColor: AppColors.cardFill,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.deepNavy,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _toleranceController.text = tol.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _toleranceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Custom Tolerance value (decimal inches)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.primaryBlue),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inspection Date',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.slateNavy
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 54,
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
                  onTap: _saving ? null : _saveJob,
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEditing ? Icons.check_circle_rounded : Icons.straighten_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isEditing ? 'Save Changes' : 'Start Measuring',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
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
}
