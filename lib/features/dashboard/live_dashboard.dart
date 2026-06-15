import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/firebase_service.dart';
import '../shared/qr_code_page.dart';
import 'widgets/session_control_tab.dart';
import 'widgets/data_upload_tab.dart';
import 'widgets/rekap_penilaian_tab.dart';
import 'widgets/certificate_tab.dart';
import 'widgets/signed_contracts_tab.dart';
import 'widgets/manage_profile_groups_tab.dart';
import 'widgets/manage_biometrics_tab.dart';
import 'widgets/pretest_posttest_input_tab.dart';
import 'widgets/system_reports_tab.dart';

class LiveDashboard extends ConsumerStatefulWidget {
  const LiveDashboard({super.key});

  @override
  ConsumerState<LiveDashboard> createState() => _LiveDashboardState();
}

class _LiveDashboardState extends ConsumerState<LiveDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configStreamProvider);
    final reportsAsync = ref.watch(systemReportsStreamProvider);
    final reportCount = reportsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('MAI Sektor', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.tealAccent,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.settings_remote), text: 'Kontrol Sesi'),
            const Tab(icon: Icon(Icons.qr_code), text: 'Kode QR'),
            const Tab(icon: Icon(Icons.people), text: 'Data & File Upload'),
            const Tab(icon: Icon(Icons.assessment), text: 'Rekap Penilaian'),
            const Tab(icon: Icon(Icons.card_membership), text: 'Sertifikat'),
            const Tab(
              icon: Icon(Icons.assignment_turned_in),
              text: 'Kontrak Belajar',
            ),
            const Tab(icon: Icon(Icons.assignment), text: 'Pre/Post-Test'),
            const Tab(
              icon: Icon(Icons.manage_accounts),
              text: 'Kelola Profil & Kelompok',
            ),
            const Tab(icon: Icon(Icons.fingerprint), text: 'Kelola Biometrik'),
            Tab(
              icon: const Icon(Icons.bug_report),
              text: reportCount > 0 ? 'Laporan Masalah ($reportCount)' : 'Laporan Masalah',
            ),
          ],
        ),
      ),
      body: configAsync.when(
        data: (config) {
          if (config == null) {
            return const Center(
              child: Text(
                "Sistem belum di-setup.",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              SessionControlTab(config: config),
              const QrCodePage(),
              const DataUploadTab(),
              RekapPenilaianTab(config: config),
              CertificateTab(config: config),
              const SignedContractsTab(),
              const PretestPosttestInputTab(),
              ManageProfileAndGroupsTab(config: config),
              const ManageBiometricsTab(),
              const SystemReportsTab(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Error: $e", style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
