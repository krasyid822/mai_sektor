import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/firebase_service.dart';
import '../shared/qr_code_page.dart';
import 'widgets/session_control_tab.dart';
import 'widgets/data_upload_tab.dart';
import 'widgets/rekap_penilaian_tab.dart';
import 'widgets/certificate_tab.dart';
import 'widgets/signed_contracts_tab.dart';
import 'widgets/tests_tab.dart';
import 'widgets/manage_profile_groups_tab.dart';
import 'widgets/manage_biometrics_tab.dart';

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
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Dasbor Utama Kepala Sekolah - MAI Sektor',
          style: TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.tealAccent,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.settings_remote), text: 'Kontrol Sesi'),
            Tab(icon: Icon(Icons.qr_code), text: 'Kode QR'),
            Tab(icon: Icon(Icons.people), text: 'Data & File Upload'),
            Tab(icon: Icon(Icons.assessment), text: 'Rekap Penilaian'),
            Tab(icon: Icon(Icons.card_membership), text: 'Sertifikat'),
            Tab(icon: Icon(Icons.assignment_turned_in), text: 'Kontrak Belajar'),
            Tab(icon: Icon(Icons.assignment), text: 'Pre/Post-Test'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Kelola Profil & Kelompok'),
            Tab(icon: Icon(Icons.fingerprint), text: 'Kelola Biometrik'),
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
              const TestsTab(),
              ManageProfileAndGroupsTab(config: config),
              const ManageBiometricsTab(),
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
