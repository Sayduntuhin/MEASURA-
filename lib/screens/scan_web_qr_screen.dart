import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/qr_auth_service.dart';
import '../theme/app_theme.dart';

class ScanWebQrScreen extends StatefulWidget {
  const ScanWebQrScreen({super.key});

  @override
  State<ScanWebQrScreen> createState() => _ScanWebQrScreenState();
}

class _ScanWebQrScreenState extends State<ScanWebQrScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.startsWith('measura://auth')) {
        _handleQrPayload(raw);
        break;
      }
    }
  }

  void _handleQrPayload(String payload) async {
    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      final uri = Uri.parse(payload);
      final sessionId = uri.queryParameters['session'];
      final token = uri.queryParameters['token'];

      if (sessionId == null || token == null) {
        throw 'Invalid QR code format.';
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'You must be signed in on your phone first.';
      }

      // Show confirmation sheet
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                child: const Icon(Icons.laptop_chromebook_rounded, color: AppColors.primaryBlue, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log in to MEASURA Web?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.deepNavy),
              ),
              const SizedBox(height: 8),
              Text(
                'Logging in with account: ${user.email ?? user.uid}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.slateNavy, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Link Device', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

      if (confirmed == true) {
        final success = await QrAuthService.approveSession(
          sessionId: sessionId,
          secretToken: token,
          userId: user.uid,
          userEmail: user.email ?? 'inspector@measura.app',
          displayName: user.displayName ?? user.email,
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.inTolGreen,
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Web device linked successfully! Check your browser.'),
                ],
              ),
            ),
          );
          Navigator.pop(context);
          return;
        } else {
          throw 'This QR code has expired or is invalid. Please refresh the web screen.';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.outTolRed, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _controller.start();
      }
    }
  }

  void _showManualCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Session Code', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Paste Session URL or Code',
            hintText: 'measura://auth?session=...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleQrPayload(codeCtrl.text.trim());
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Link Web Device', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Enter code manually',
            onPressed: _showManualCodeDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Scan QR'),
            Tab(icon: Icon(Icons.devices_rounded), text: 'Linked Devices'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Camera Scanner View
          _buildScannerTab(),

          // TAB 2: Active Linked Devices
          _buildLinkedDevicesTab(user?.uid ?? ''),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            return Container(
              color: Colors.black,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Not Ready',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please restart the app build to link the camera plugin (${error.errorCode.name}).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Dark viewfinder overlay
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at the QR code on web.measura.app',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkedDevicesTab(String userId) {
    if (userId.isEmpty) {
      return const Center(child: Text('Sign in to view linked devices', style: TextStyle(color: Colors.white70)));
    }

    return StreamBuilder<List<QrAuthSession>>(
      stream: QrAuthService.listenToUserLinkedDevices(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }

        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.devices_other_rounded, size: 48, color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Linked Devices',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use the Scan QR tab to connect MEASURA Web on your desktop or laptop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ACTIVE WEB SESSIONS (${devices.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final dev = devices[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.computer_rounded, color: AppColors.primaryBlue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.deviceInfo,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Linked: ${dev.approvedAt?.toLocal().toString().substring(0, 16) ?? "Active"}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.outTolRed),
                            tooltip: 'Log out device',
                            onPressed: () => QrAuthService.revokeSession(dev.sessionId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              FilledButton.tonal(
                onPressed: () => QrAuthService.logoutAllWebSessions(userId),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.outTolRed.withValues(alpha: 0.15),
                  foregroundColor: AppColors.outTolRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Log Out of All Web Sessions', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }
}
