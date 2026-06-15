import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/firebase_service.dart';
import '../absensi/attendance_form.dart';
import '../test/test_form.dart';
import '../kontrak/kontrak_form.dart';
import '../shared/informative_splash_loading.dart';

class SessionRouter extends ConsumerWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: configAsync.when(
        data: (config) {
          if (config == null) {
            return const Center(
              child: Text(
                "Sistem Belum Siap. Silakan hubungi admin.",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          switch (config.activeMode) {
            case 'absensi':
              return const AttendanceForm();
            case 'pretest':
              return const TestForm(testType: 'pre');
            case 'posttest':
              return const TestForm(testType: 'post');
            case 'kontrak':
              return const KontrakForm();
            case 'idle':
            default:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_empty, color: Colors.tealAccent, size: 64),
                      const SizedBox(height: 24),
                      const Text(
                        "Sesi Belum Dimulai",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Harap tunggu instruksi selanjutnya dari Kepala Sekolah / Panitia di layar utama.",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
          }
        },
        loading: () => const InformativeSplashLoading(
          statusMessage: "Menghubungkan ke sesi aktif...",
        ),
        error: (e, _) => Center(child: Text("Terjadi Kesalahan: $e", style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}
