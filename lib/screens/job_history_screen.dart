import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/measurement_point.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'job_setup_screen.dart';
import 'job_summary_screen.dart';
import 'measurement_entry_screen.dart';

/// Helper to show a modern confirmation dialog for deleting a job
Future<bool> showDeleteJobConfirmation(BuildContext context, Job job) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: AppColors.failRed, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Delete QA Job?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete "${job.style.isEmpty ? 'Untitled Style' : job.style}" (PO: ${job.po})?\n\nAll recorded measurement readings and findings for this job will be permanently removed.',
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: AppColors.slateNavy.withValues(alpha: 0.85),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slateNavy),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.failRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Delete Job', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Helper to show a confirmation dialog for signing out
Future<bool> showSignOutConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: AppColors.primaryBlue, size: 24),
          SizedBox(width: 10),
          Text(
            'Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to sign out of your MEASURA session on this device?',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.slateNavy.withValues(alpha: 0.85),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slateNavy),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class JobHistoryScreen extends StatelessWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.straighten_rounded,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'MEASURA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 20,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        actions: [
          if (user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(user!.photoURL!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirmed = await showSignOutConfirmation(context);
              if (confirmed && context.mounted) {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryBlue,
              Color(0xFF0284C7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JobSetupScreen()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'New QA Job',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: const JobHistoryView(),
    );
  }
}

/// Standalone Embeddable View of Job History with Swiping & Search
class JobHistoryView extends StatefulWidget {
  const JobHistoryView({super.key});

  @override
  State<JobHistoryView> createState() => _JobHistoryViewState();
}

class _JobHistoryViewState extends State<JobHistoryView> {
  String _searchQuery = '';

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
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
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
                      'Please allow read/write in Firebase Console > Firestore > Rules tab.\n\n${snapshot.error}',
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
        final allJobs = snapshot.data!;
        final jobs = _searchQuery.isEmpty
            ? allJobs
            : allJobs.where((j) {
                final query = _searchQuery.toLowerCase();
                return j.style.toLowerCase().contains(query) ||
                    j.po.toLowerCase().contains(query) ||
                    j.patternNo.toLowerCase().contains(query);
              }).toList();

        if (allJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.selectedBlueLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.content_paste_outlined,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No QA jobs recorded yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "New Job" to create your first measurement tally sheet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slateNavy.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Search Bar & Swipe Hint
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by style, PO, or pattern...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.slateNavy.withValues(alpha: 0.5),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
              ),
            ),

            // Hint Banner for Swiping
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe right to edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slateNavy.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Swipe left to delete',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slateNavy.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_back_rounded, size: 12, color: AppColors.failRed),
                    ],
                  ),
                ],
              ),
            ),

            // Job List with Dismissible Actions
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final job = jobs[index];

                  return Dismissible(
                    key: Key(job.id),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        // Swipe Left: Delete with confirmation
                        final confirmed = await showDeleteJobConfirmation(context, job);
                        if (confirmed) {
                          try {
                            await firestore.deleteJob(job.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Job "${job.style.isEmpty ? 'Untitled Style' : job.style}" deleted.'),
                                  backgroundColor: AppColors.slateNavy,
                                ),
                              );
                            }
                            return true;
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Delete failed: $e'),
                                  backgroundColor: AppColors.failRed,
                                ),
                              );
                            }
                            return false;
                          }
                        }
                        return false;
                      } else if (direction == DismissDirection.startToEnd) {
                        // Swipe Right: Edit Job
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JobSetupScreen(existingJob: job),
                          ),
                        );
                        return false; // Don't remove card
                      }
                      return false;
                    },
                    // Swipe Right Background (Edit)
                    background: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Edit Job',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Swipe Left Background (Delete)
                    secondaryBackground: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.failRed,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Delete Job',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
                        ],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepNavy.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MeasurementEntryScreen(job: job),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.style.isEmpty ? '(Untitled Style)' : job.style,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.deepNavy,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.selectedBlueLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '±${formatDeviation(job.tolerance)}"',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'PO: ${job.po}  ·  Pattern: ${job.patternNo}  ·  Size: ${job.sizeSet}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.slateNavy.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateFormat.format(job.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slateNavy.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFEFF6FF),
                                              Color(0xFFDBEAFE),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => JobSummaryScreen(job: job),
                                                ),
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.analytics_rounded,
                                                    size: 15,
                                                    color: AppColors.primaryBlue,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Summary',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primaryBlue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
