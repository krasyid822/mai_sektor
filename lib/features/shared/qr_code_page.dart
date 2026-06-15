// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'firebase_service.dart';
import 'package:web_geolocator/web_geolocator.dart';

/// A dedicated page that displays all QR codes (Session + per-Walikelas Qudwah Rooms)
/// with download buttons for each.
class QrCodePage extends ConsumerStatefulWidget {
  const QrCodePage({super.key});

  @override
  ConsumerState<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends ConsumerState<QrCodePage> {
  // GlobalKeys for capturing QR widgets as images
  final GlobalKey _sessionQrKey = GlobalKey();
  final Map<String, GlobalKey> _qudwahQrKeys = {};

  bool _isDownloadingSession = false;
  final Set<String> _downloadingQudwah = {};
  
  bool _enableGeolocation = false;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _radiusController = TextEditingController();
  bool _isInitialized = false;

  String get _baseUri => html.window.location.origin;

  String get _sessionUrl => "$_baseUri/#/session";

  String _qudwahUrl(String walikelas) =>
      "$_baseUri/#/qudwah?walikelas=${Uri.encodeComponent(walikelas)}";

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final configAsync = ref.watch(configStreamProvider);
    final config = configAsync.value;

    if (config != null && !_isInitialized) {
      _enableGeolocation = config.enableGeolocation;
      _latController.text = config.targetLatitude.toString();
      _lonController.text = config.targetLongitude.toString();
      _radiusController.text = config.targetRadius.toString();
      _isInitialized = true;
    }

    ref.listen<AsyncValue<AppConfig?>>(configStreamProvider, (prev, next) {
      final nextConfig = next.value;
      if (nextConfig != null) {
        setState(() {
          _enableGeolocation = nextConfig.enableGeolocation;
          _latController.text = nextConfig.targetLatitude.toString();
          _lonController.text = nextConfig.targetLongitude.toString();
          _radiusController.text = nextConfig.targetRadius.toString();
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Kode QR', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- SESSION QR ----
            _buildSectionHeader(
              icon: Icons.wifi_tethering,
              title: 'QR Code Sesi',
              subtitle: 'Digunakan peserta dan dewan guru untuk bergabung ke sesi aktif',
            ),
            const SizedBox(height: 16),
            _buildSessionQrCard(),
            const SizedBox(height: 32),
            _buildGeolocationCard(config),
            const SizedBox(height: 40),

            // ---- QUDWAH ROOM QRs ----
            _buildSectionHeader(
              icon: Icons.meeting_room,
              title: 'QR Code Room Qudwah',
              subtitle:
                  'Setiap Wali Kelas memiliki QR room sendiri untuk Qudwah',
            ),
            const SizedBox(height: 16),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const Card(
                    color: Color(0xFF1E293B),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Belum ada kelompok kelas kecil.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: groups.map((group) {
                    // Ensure a GlobalKey exists for this group
                    _qudwahQrKeys.putIfAbsent(
                      group.walikelas,
                      () => GlobalKey(),
                    );
                    return _buildQudwahQrCard(group);
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),
              error: (e, _) => Card(
                color: const Color(0xFF1E293B),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Gagal memuat data kelompok: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.tealAccent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Session QR Card ----
  Widget _buildSessionQrCard() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: RepaintBoundary(
                key: _sessionQrKey,
                child: QrImageView(
                  data: _sessionUrl,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // URL
            SelectableText(
              _sessionUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Download Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isDownloadingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isDownloadingSession ? 'Mengunduh...' : 'Download QR Code',
                ),
                onPressed: _isDownloadingSession
                    ? null
                    : () => _downloadQrImage(
                        _sessionQrKey,
                        'qr_sesi_peserta.png',
                        onStart: () {
                          setState(() => _isDownloadingSession = true);
                        },
                        onDone: () {
                          setState(() => _isDownloadingSession = false);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Qudwah QR Card per Walikelas ----
  Widget _buildQudwahQrCard(Group group) {
    final isDownloading = _downloadingQudwah.contains(group.walikelas);
    final qrUrl = _qudwahUrl(group.walikelas);

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Small QR preview
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RepaintBoundary(
                    key: _qudwahQrKeys[group.walikelas],
                    child: QrImageView(
                      data: qrUrl,
                      version: QrVersions.auto,
                      size: 100.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.walikelas,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.participants.length} peserta',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        qrUrl,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Download button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                  foregroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.tealAccent,
                        ),
                      )
                    : const Icon(Icons.download, size: 20),
                label: Text(
                  isDownloading
                      ? 'Mengunduh...'
                      : 'Download QR - ${group.walikelas}',
                ),
                onPressed: isDownloading
                    ? null
                    : () => _downloadQrImage(
                        _qudwahQrKeys[group.walikelas]!,
                        'qr_qudwah_${group.walikelas.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.png',
                        onStart: () {
                          setState(
                            () => _downloadingQudwah.add(group.walikelas),
                          );
                        },
                        onDone: () {
                          setState(
                            () => _downloadingQudwah.remove(group.walikelas),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Captures a RepaintBoundary widget as a PNG image and triggers a download.
  Future<void> _downloadQrImage(
    GlobalKey repaintKey,
    String filename, {
    required VoidCallback onStart,
    required VoidCallback onDone,
  }) async {
    try {
      onStart();

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengambil gambar QR.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        onDone();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        onDone();
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final base64Str = base64Encode(pngBytes);

      // Trigger download via AnchorElement
      final anchor =
          html.AnchorElement(href: 'data:image/png;base64,$base64Str')
            ..download = filename
            ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename berhasil diunduh.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      onDone();
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocationAsTarget() async {
    try {
      final hasPermission = await LocationService.handlePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Izin lokasi ditolak!")),
          );
        }
        return;
      }
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _latController.text = position.latitude.toString();
        _lonController.text = position.longitude.toString();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengambil lokasi: $e")),
        );
      }
    }
  }

  Future<void> _saveGeolocationSettings(AppConfig config) async {
    final lat = double.tryParse(_latController.text) ?? 0.0;
    final lon = double.tryParse(_lonController.text) ?? 0.0;
    final rad = double.tryParse(_radiusController.text) ?? 100.0;

    try {
      await ref.read(firebaseServiceProvider).saveConfig(
        AppConfig(
          activeMode: config.activeMode,
          kepalaSekolahNama: config.kepalaSekolahNama,
          kepengurusanTahun: config.kepengurusanTahun,
          bobotKelasBesar: config.bobotKelasBesar,
          bobotRoomQudwah: config.bobotRoomQudwah,
          bobotTugas: config.bobotTugas,
          nilaiMinimum: config.nilaiMinimum,
          kepsekSignatureBase64: config.kepsekSignatureBase64,
          kadivNama: config.kadivNama,
          kadivSignatureBase64: config.kadivSignatureBase64,
          activeMateri: config.activeMateri,
          kepalaSekolahNim: config.kepalaSekolahNim,
          kadivNim: config.kadivNim,
          kadivIsKepsek: config.kadivIsKepsek,
          enableGeolocation: _enableGeolocation,
          targetLatitude: lat,
          targetLongitude: lon,
          targetRadius: rad,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pengaturan Geolocation berhasil disimpan!"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan pengaturan: $e")),
        );
      }
    }
  }

  Widget _buildGeolocationCard(AppConfig? config) {
    if (config == null) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.tealAccent, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Pencegah Kecurangan Geolocation",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _enableGeolocation,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: (val) async {
                    setState(() {
                      _enableGeolocation = val;
                    });
                    await _saveGeolocationSettings(config);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Jika diaktifkan, pengguna di luar radius yang ditentukan akan diblokir dari pengisian form absensi, kontrak, dan evaluasi.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (_enableGeolocation) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Latitude Target",
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lonController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Longitude Target",
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Radius Toleransi (Meter)",
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _fetchCurrentLocationAsTarget,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text("Gunakan Lokasi Saya"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _saveGeolocationSettings(config),
                child: const Text(
                  "SIMPAN PENGATURAN GEOLOCATION",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
