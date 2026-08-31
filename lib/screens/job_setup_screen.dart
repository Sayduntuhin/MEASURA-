import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'measurement_entry_screen.dart';

class JobSetupScreen extends StatefulWidget {
  const JobSetupScreen({super.key});

  @override
  State<JobSetupScreen> createState() => _JobSetupScreenState();
}

class _JobSetupScreenState extends State<JobSetupScreen> {
  final _styleController = TextEditingController();
  final _poController = TextEditingController();
  final _patternNoController = TextEditingController();
  final _sampleUnitController = TextEditingController();
  final _sizeSetController = TextEditingController();
  final _toleranceController = TextEditingController(text: '0.25');
  DateTime _date = DateTime.now();
  bool _saving = false;

  final List<double> _presetTolerances = [0.125, 0.25, 0.375, 0.5];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _createJob() async {
    if (_styleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Style name.')),
      );
      return;
    }

    setState(() => _saving = true);
    final firestore = context.read<FirestoreService>();
    final user = context.read<AuthService>().currentUser;
    try {
      final job = await firestore.createJob(
        style: _styleController.text.trim(),
        po: _poController.text.trim(),
        patternNo: _patternNoController.text.trim(),
        sampleUnit: _sampleUnitController.text.trim(),
        sizeSet: _sizeSetController.text.trim(),
        date: _date,
        tolerance: double.tryParse(_toleranceController.text) ?? 0.25,
        createdBy: user?.email ?? user?.uid ?? 'unknown',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MeasurementEntryScreen(job: job),
        ),
      );
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
        title: const Text('New QA Job'),
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
                                  color:
                                      AppColors.slateNavy.withValues(alpha: 0.6),
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
            ElevatedButton(
              onPressed: _saving ? null : _createJob,
              child: Text(_saving ? 'Creating QA Job...' : 'Start Measuring'),
            ),
          ],
        ),
      ),
    );
  }
}
