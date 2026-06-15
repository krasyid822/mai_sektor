import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/firebase_service.dart';
import '../absensi/attendance_form.dart';
import '../test/test_form.dart';
import '../kontrak/kontrak_form.dart';
import '../shared/informative_splash_loading.dart';
import 'package:web_geolocator/web_geolocator.dart';
import '../shared/models.dart';
import '../shared/system_report_form.dart';

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

          final childWidget = () {
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
          }();

          if (config.activeMode == 'idle') {
            return childWidget;
          }

          return GeolocationGuard(
            config: config,
            child: childWidget,
          );
        },
        loading: () => const InformativeSplashLoading(
          statusMessage: "Menghubungkan ke sesi aktif...",
        ),
        error: (e, _) => Center(child: Text("Terjadi Kesalahan: $e", style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

class GeolocationGuard extends ConsumerStatefulWidget {
  final AppConfig config;
  final Widget child;

  const GeolocationGuard({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  ConsumerState<GeolocationGuard> createState() => _GeolocationGuardState();
}

class _GeolocationGuardState extends ConsumerState<GeolocationGuard> {
  bool _isLoading = true;
  bool _hasPermission = false;
  double? _currentDistance;
  bool _isWithinRange = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  @override
  void didUpdateWidget(covariant GeolocationGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.targetLatitude != widget.config.targetLatitude ||
        oldWidget.config.targetLongitude != widget.config.targetLongitude ||
        oldWidget.config.targetRadius != widget.config.targetRadius ||
        oldWidget.config.enableGeolocation != widget.config.enableGeolocation) {
      _checkLocation();
    }
  }

  Future<void> _checkLocation() async {
    if (!widget.config.enableGeolocation) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = true;
          _isWithinRange = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final hasPerm = await LocationService.handlePermission();
      if (!mounted) return;

      if (!hasPerm) {
        // Auto-report to system_reports first, then update state
        await ref.read(firebaseServiceProvider).reportSystemException(
          reporterName: 'GPS Blocked',
          role: 'peserta',
          formSource: 'Geolocation Guard - Izin Ditolak',
          exception: 'Izin akses lokasi browser ditolak oleh pengguna/perangkat.',
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
            _errorMessage = "Akses lokasi diperlukan untuk mencegah kecurangan absensi.";
          });
        }
        return;
      }

      final position = await LocationService.getCurrentLocation();
      final distance = LocationService.getDistance(
        position.latitude,
        position.longitude,
        widget.config.targetLatitude,
        widget.config.targetLongitude,
      );

      if (!mounted) return;

      final isWithin = distance <= widget.config.targetRadius;

      if (!isWithin) {
        await ref.read(firebaseServiceProvider).reportSystemException(
          reporterName: 'GPS Out of Range',
          role: 'peserta',
          formSource: 'Geolocation Guard - Diluar Area',
          exception: 'Pengguna terdeteksi diluar jangkauan: Jarak ${distance.toStringAsFixed(1)}m dari target (Toleransi: ${widget.config.targetRadius.toStringAsFixed(1)}m).',
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = true;
          _currentDistance = distance;
          _isWithinRange = isWithin;
        });
      }
    } catch (e, stack) {
      // Auto-report error first
      await ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: 'GPS Sensor Error',
        role: 'peserta',
        formSource: 'Geolocation Guard - Error Sensor GPS',
        exception: e,
        stackTrace: stack,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal mengambil lokasi: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.enableGeolocation) {
      return widget.child;
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 24),
              Text(
                "Memverifikasi Lokasi Anda...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                "Harap izinkan akses lokasi jika diminta browser",
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission || _errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, color: Colors.amberAccent, size: 64),
                const SizedBox(height: 24),
                const Text(
                  "Izin Lokasi Diperlukan",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? "Aktifkan GPS / izin lokasi di browser Anda untuk melanjutkan.",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _checkLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Coba Lagi", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 48),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                SystemReportForm(
                  getReporterName: () => '',
                  role: 'peserta',
                  formSource: 'Geolocation Guard (Izin Ditolak)',
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isWithinRange) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, color: Colors.redAccent, size: 64),
                const SizedBox(height: 24),
                const Text(
                  "Akses Dibatasi",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Anda terdeteksi berada di luar area pengerjaan / kehadiran yang sah.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (_currentDistance != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Jarak Anda: ${_currentDistance!.toStringAsFixed(1)} meter dari lokasi target (Toleransi: ${widget.config.targetRadius.toStringAsFixed(1)}m).",
                    style: const TextStyle(color: Colors.white30, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _checkLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Cek Ulang Lokasi", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 48),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                SystemReportForm(
                  getReporterName: () => '',
                  role: 'peserta',
                  formSource: 'Geolocation Guard (Diluar Area)',
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
