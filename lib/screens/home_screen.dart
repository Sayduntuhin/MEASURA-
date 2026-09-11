import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'job_history_screen.dart';
import 'job_setup_screen.dart';
import 'qa_dashboard_screen.dart';
import 'scan_web_qr_screen.dart';
import 'upload_spec_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    QaDashboardScreen(),
    JobHistoryView(),
  ];

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
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.straighten_rounded,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MEASURA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 18,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  _currentIndex == 0 ? 'QA Histogram & Summary' : 'Inspection Jobs',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.slateNavy.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryBlue),
            tooltip: 'Scan Garment Spec PDF',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UploadSpecScreen()),
              );
            },
          ),
          if (user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(user!.photoURL!),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.deepNavy),
            tooltip: 'Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            onSelected: (value) async {
              switch (value) {
                case 'link_web':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanWebQrScreen()),
                  );
                  break;
                case 'logout':
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
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'link_web',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue, size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Link Web Device',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.outTolRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.outTolRed, size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.outTolRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
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
            onTap: () => _showNewInspectionOptions(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'New Inspection',
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: AppColors.surfaceWhite,
        indicatorColor: AppColors.selectedBlueLight,
        elevation: 2,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primaryBlue),
            label: 'Histogram & Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_rounded),
            selectedIcon: Icon(Icons.format_list_bulleted_rounded, color: AppColors.primaryBlue),
            label: 'All Jobs',
          ),
        ],
      ),
    );
  }

  void _showNewInspectionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Start Quality Inspection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you want to conduct this measurement session:',
                style: TextStyle(fontSize: 13, color: AppColors.slateNavy),
              ),
              const SizedBox(height: 18),

              // Option 1: Scan Spec PDF & Digital 5-Sample Grid (New Feature!)
              Material(
                color: const Color(0xFFEFF6FF),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
                  ),
                  title: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Scan Spec Sheet PDF',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.deepNavy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inTolGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Upload tech pack PDF to auto-create the 5-sample digital measurement form',
                    style: TextStyle(fontSize: 12, color: AppColors.slateNavy),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryBlue),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UploadSpecScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Traditional Manual QA Job
              Material(
                color: AppColors.cardFill,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slateNavy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.deepNavy, size: 24),
                  ),
                  title: const Text(
                    'Manual QA Job',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.deepNavy),
                  ),
                  subtitle: const Text(
                    'Enter style details manually and record deviation tallies for histogram analytics',
                    style: TextStyle(fontSize: 12, color: AppColors.slateNavy),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.slateNavy),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JobSetupScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
