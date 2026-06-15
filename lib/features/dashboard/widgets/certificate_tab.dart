// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../../shared/signature_helper.dart';
import '../dashboard_controller.dart';

/// Generates a unique verification code for a certificate.
/// Format: MAI-XXXX-XXXX-XXXX where X is alphanumeric.
String _generateVerificationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  String part(int len) =>
      List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
  return 'MAI-${part(4)}-${part(4)}-${part(4)}';
}

/// Builds a security border pattern: repeating verification code fragments
/// arranged to form a decorative rectangular border at the very edge of the page.
pw.Widget _buildSecurityBorder({
  required String code,
  required double pageWidth,
  required double pageHeight,
}) {
  // The code repeated as a pattern string
  final pattern = '$code  ';
  final patternLen = pattern.length;

  // Estimate how many repeats fit along each edge
  // Using a rough character width estimate
  const charWidth = 5.5; // approximate width of each char in points
  const charHeight = 10.0; // approximate height of each line

  final horizontalRepeats = ((pageWidth) / (patternLen * charWidth)).ceil() + 1;
  final verticalRepeats = ((pageHeight) / (patternLen * charWidth)).ceil() + 1;

  // Build horizontal lines (top and bottom)
  String horizontalLine = '';
  for (int i = 0; i < horizontalRepeats; i++) {
    horizontalLine += pattern;
  }

  // Build vertical lines (left and right) - we'll use rotated text
  String verticalLine = '';
  for (int i = 0; i < verticalRepeats; i++) {
    verticalLine += pattern;
  }

  return pw.Stack(
    children: [
      // Top border line (at very top edge)
      pw.Positioned(
        top: 0,
        left: 0,
        child: pw.SizedBox(
          width: pageWidth,
          child: pw.Text(
            horizontalLine,
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.teal300,
              letterSpacing: 1,
            ),
            textAlign: pw.TextAlign.left,
          ),
        ),
      ),
      // Bottom border line (at very bottom edge)
      pw.Positioned(
        bottom: 0,
        left: 0,
        child: pw.SizedBox(
          width: pageWidth,
          child: pw.Text(
            horizontalLine,
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.teal300,
              letterSpacing: 1,
            ),
            textAlign: pw.TextAlign.left,
          ),
        ),
      ),
      // Left border line (rotated 90 degrees, at very left edge)
      pw.Positioned(
        top: charHeight,
        left: 0,
        child: pw.Transform(
          alignment: pw.Alignment.topLeft,
          transform: Matrix4.rotationZ(90 * 3.14159 / 180),
          child: pw.SizedBox(
            width: pageHeight - 2 * charHeight,
            child: pw.Text(
              verticalLine,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.teal300,
                letterSpacing: 1,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ),
      ),
      // Right border line (rotated -90 degrees, at very right edge)
      pw.Positioned(
        top: charHeight,
        right: 0,
        child: pw.Transform(
          alignment: pw.Alignment.topRight,
          transform: Matrix4.rotationZ(-90 * 3.14159 / 180),
          child: pw.SizedBox(
            width: pageHeight - 2 * charHeight,
            child: pw.Text(
              verticalLine,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.teal300,
                letterSpacing: 1,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ),
      ),
    ],
  );
}

class CertificateTab extends ConsumerWidget {
  final AppConfig config;

  const CertificateTab({super.key, required this.config});

  String _sanitizePdfText(String text) {
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  Future<void> _generateCertificatePDF(
    WidgetRef ref,
    Identity participant,
    List<Identity> allParticipants,
  ) async {
    // Generate a unique verification code for this certificate
    // Must be before pw.Document() so it can be passed as keywords metadata
    final verificationCode = _generateVerificationCode();

    final pdf = pw.Document(keywords: verificationCode);

    pw.MemoryImage? kepsekSigImage;
    pw.MemoryImage? kadivSigImage;
    pw.MemoryImage? walikelasSigImage;

    String? kepsekBase64 = config.kepsekSignatureBase64;
    if (kepsekBase64 != null && kepsekBase64.isNotEmpty) {
      if (kepsekBase64.startsWith('{')) {
        kepsekBase64 = SignatureHelper.parse(kepsekBase64).imageBase64;
      }
      try {
        if (!kepsekBase64.startsWith('data:')) {
          kepsekBase64 = 'data:image/png;base64,$kepsekBase64';
        }
        final uriData = Uri.parse(kepsekBase64).data;
        if (uriData != null) {
          kepsekSigImage = pw.MemoryImage(uriData.contentAsBytes());
        }
      } catch (_) {}
    }

    String? kadivBase64 = config.kadivSignatureBase64;
    if (kadivBase64 != null && kadivBase64.isNotEmpty) {
      if (kadivBase64.startsWith('{')) {
        kadivBase64 = SignatureHelper.parse(kadivBase64).imageBase64;
      }
      try {
        if (!kadivBase64.startsWith('data:')) {
          kadivBase64 = 'data:image/png;base64,$kadivBase64';
        }
        final uriData = Uri.parse(kadivBase64).data;
        if (uriData != null) {
          kadivSigImage = pw.MemoryImage(uriData.contentAsBytes());
        }
      } catch (_) {}
    }

    final groups = ref.read(groupsStreamProvider).value ?? [];
    final participantGroup = groups.cast<Group?>().firstWhere(
      (g) => g!.participants.contains(participant.name),
      orElse: () => null,
    );

    // Look up walikelas NIM from identities collection
    final allIdentities = ref.read(identitiesStreamProvider).value ?? [];
    String? walikelasNim;
    if (participantGroup != null) {
      final walikelasIdentity = allIdentities.cast<Identity?>().firstWhere(
        (id) => id!.name == participantGroup.walikelas,
        orElse: () => null,
      );
      walikelasNim = walikelasIdentity?.nim;
    }

    String? walikelasBase64 = participantGroup?.walikelasSignatureBase64;
    if (walikelasBase64 != null && walikelasBase64.isNotEmpty) {
      if (walikelasBase64.startsWith('{')) {
        walikelasBase64 = SignatureHelper.parse(walikelasBase64).imageBase64;
      }
      try {
        if (!walikelasBase64.startsWith('data:')) {
          walikelasBase64 = 'data:image/png;base64,$walikelasBase64';
        }
        final uriData = Uri.parse(walikelasBase64).data;
        if (uriData != null) {
          walikelasSigImage = pw.MemoryImage(uriData.contentAsBytes());
        }
      } catch (_) {}
    }

    final pageWidth = PdfPageFormat.a4.landscape.width;
    final pageHeight = PdfPageFormat.a4.landscape.height;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Security border with repeating verification code (at page edges)
              _buildSecurityBorder(
                code: verificationCode,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
              ),
              // Main content
              pw.Positioned(
                top: 16,
                left: 16,
                right: 16,
                bottom: 16,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.SizedBox(height: 8),
                    // Title
                    pw.Column(
                      children: [
                        pw.Text(
                          "SERTIFIKAT KELULUSAN",
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Diberikan kepada:",
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          _sanitizePdfText(
                            Identity.displayName(participant, allParticipants),
                          ),
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _sanitizePdfText(
                            "Telah dinyatakan LULUS dalam program MAI Sektor kepengurusan ${config.kepengurusanTahun}.",
                          ),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    // Signature row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              config.kadivIsKepsek
                                  ? "Kepala Sekolah & Kepala Divisi MAI,"
                                  : "Kepala Sekolah,",
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                            pw.SizedBox(height: 4),
                            if (kepsekSigImage != null)
                              pw.Container(
                                width: 80,
                                height: 30,
                                child: pw.Image(kepsekSigImage),
                              ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _sanitizePdfText(config.kepalaSekolahNama),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            if (config.kepalaSekolahNim != null &&
                                config.kepalaSekolahNim!.isNotEmpty)
                              pw.Text(
                                "NIM. ${_sanitizePdfText(config.kepalaSekolahNim!)}",
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              "Wali Kelas,",
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                            pw.SizedBox(height: 4),
                            if (walikelasSigImage != null)
                              pw.Container(
                                width: 80,
                                height: 30,
                                child: pw.Image(walikelasSigImage),
                              ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _sanitizePdfText(
                                participantGroup?.walikelas ?? "Wali Kelas",
                              ),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            if (walikelasNim != null && walikelasNim.isNotEmpty)
                              pw.Text(
                                "NIM. ${_sanitizePdfText(walikelasNim)}",
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                        // Kepala Divisi column - hidden when Kadiv merangkap Kepsek
                        if (!config.kadivIsKepsek)
                          pw.Column(
                            children: [
                              pw.Text(
                                "Kepala Divisi MAI,",
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                              pw.SizedBox(height: 4),
                              if (kadivSigImage != null)
                                pw.Container(
                                  width: 80,
                                  height: 30,
                                  child: pw.Image(kadivSigImage),
                                ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                _sanitizePdfText(
                                  config.kadivNama ?? "Kadiv MAI",
                                ),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              // Kadiv NIM not available in current data model
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save verification code to Firestore for authenticity checking
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.saveCertificateRecord(
        CertificateRecord(
          verificationCode: verificationCode,
          participantName: participant.name,
          kepengurusanTahun: config.kepengurusanTahun,
        ),
      );
    } catch (_) {
      // Non-critical; certificate is still generated
    }

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toSet();
    final controller = ref.read(dashboardControllerProvider.notifier);
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];
    final resumeScores = ref.watch(resumeScoresStreamProvider).value ?? {};

    // Dummy participant for preview / testing (clearly fake data)
    final dummyParticipant = Identity(name: "TEST-001", nim: "000");
    final dummyParticipants = [dummyParticipant];

    return identitiesAsync.when(
      data: (idents) {
        final participantsOnly = idents
            .where((id) => participantNames.contains(id.name))
            .toList();

        final passedParticipants = participantsOnly.where((p) {
          final scores = controller.calculateParticipantScores(
            participant: p,
            evaluations: evaluations,
            tests: tests,
            attendances: attendances,
            uploadedFiles: uploadedFiles,
            resumeScores: resumeScores,
            config: config,
          );
          final total = scores['total'] ?? 0.0;
          return total >= config.nilaiMinimum;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Preview / Test Certificate (always visible with dummy data) ---
              const Text(
                "Preview / Test Sertifikat",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Bagian ini menampilkan simulasi penerbitan sertifikat menggunakan data dummy untuk preview dan testing.",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white.withOpacity(0.08),
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    Identity.displayName(dummyParticipant, dummyParticipants),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Status Ttd: (Kepsek: ✓, Walikelas: ✓, Kadiv: ✓)",
                    style: TextStyle(color: Colors.tealAccent),
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Cetak Sertifikat (PDF)"),
                    onPressed: () => _generateCertificatePDF(
                      ref,
                      dummyParticipant,
                      dummyParticipants,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              // --- Real Certificate Issuance Section ---
              if (!config.rekapSigned)
                _buildLockedSection()
              else if (passedParticipants.isEmpty)
                _buildNoPassedSection()
              else ...[
                const Text(
                  "Penerbitan Sertifikat Peserta Lulus",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: passedParticipants.length,
                  itemBuilder: (context, index) {
                    final id = passedParticipants[index];
                    final participantGroup = groups.cast<Group?>().firstWhere(
                      (g) => g!.participants.contains(id.name),
                      orElse: () => null,
                    );

                    final hasKepsek =
                        config.kepsekSignatureBase64 != null &&
                        config.kepsekSignatureBase64!.isNotEmpty;
                    final hasWalikelas =
                        participantGroup?.walikelasSignatureBase64 != null &&
                        participantGroup!.walikelasSignatureBase64!.isNotEmpty;
                    final hasKadiv =
                        config.kadivSignatureBase64 != null &&
                        config.kadivSignatureBase64!.isNotEmpty;
                    final allSigned =
                        hasKepsek &&
                        hasWalikelas &&
                        (config.kadivIsKepsek || hasKadiv);

                    return Card(
                      color: Colors.white.withOpacity(0.08),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          Identity.displayName(id, participantsOnly),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          config.kadivIsKepsek
                              ? "Status Ttd: (Kepsek: ${hasKepsek ? '✓' : '✗'}, Walikelas: ${hasWalikelas ? '✓' : '✗'})"
                              : "Status Ttd: (Kepsek: ${hasKepsek ? '✓' : '✗'}, Walikelas: ${hasWalikelas ? '✓' : '✗'}, Kadiv: ${hasKadiv ? '✓' : '✗'})",
                          style: TextStyle(
                            color: allSigned
                                ? Colors.tealAccent
                                : Colors.white60,
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          icon: Icon(allSigned ? Icons.download : Icons.lock),
                          label: const Text("Cetak Sertifikat (PDF)"),
                          onPressed: allSigned
                              ? () => _generateCertificatePDF(
                                  ref,
                                  id,
                                  participantsOnly,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              // --- Certificate Authenticity Verification ---
              _buildVerificationSection(context),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildLockedSection() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 48),
            SizedBox(height: 16),
            Text(
              "Sertifikat Belum Diterbitkan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Sertifikat kelulusan otomatis dibuat jika rekapitulasi penilaian\nsudah ditandatangani oleh Kepala Sekolah di tab 'Rekap Penilaian'.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPassedSection() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.blueAccent, size: 48),
            SizedBox(height: 16),
            Text(
              "Belum Ada Peserta Lulus",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Tidak ada peserta yang memenuhi kriteria kelulusan\n(nilai >= batas minimum).",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Certificate Authenticity Verification ---

  Widget _buildVerificationSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.shade700, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.tealAccent.shade200, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Verifikasi Keaslian Sertifikat",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Unggah file sertifikat (PDF) untuk memverifikasi keasliannya. "
            "File hanya diproses di memori browser dan tidak diunggah ke server.",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _CertificateVerifier(config: config),
        ],
      ),
    );
  }
}

class _CertificateVerifier extends ConsumerStatefulWidget {
  final AppConfig config;
  const _CertificateVerifier({required this.config});

  @override
  ConsumerState<_CertificateVerifier> createState() =>
      _CertificateVerifierState();
}

class _CertificateVerifierState extends ConsumerState<_CertificateVerifier> {
  String? _fileName;
  List<int>? _fileBytes;
  bool _isVerifying = false;
  String? _resultMessage;
  bool? _isValid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File picker button
        ElevatedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file),
          label: Text(_fileName ?? "Pilih File Sertifikat (PDF)"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
          ),
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 8),
          Text(
            "File: $_fileName (${_fileBytes != null ? '${(_fileBytes!.length / 1024).toStringAsFixed(1)} KB' : '?'})",
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _verifyCertificate,
            icon: _isVerifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified),
            label: Text(
              _isVerifying ? "Memverifikasi..." : "Verifikasi Sertifikat",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        if (_resultMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isValid == true
                  ? Colors.green.shade900.withOpacity(0.3)
                  : _isValid == false
                  ? Colors.red.shade900.withOpacity(0.3)
                  : Colors.grey.shade800.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isValid == true
                    ? Colors.green
                    : _isValid == false
                    ? Colors.red
                    : Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isValid == true
                      ? Icons.check_circle
                      : _isValid == false
                      ? Icons.cancel
                      : Icons.info,
                  color: _isValid == true
                      ? Colors.green
                      : _isValid == false
                      ? Colors.red
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resultMessage!,
                    style: TextStyle(
                      color: _isValid == true
                          ? Colors.green.shade200
                          : _isValid == false
                          ? Colors.red.shade200
                          : Colors.grey.shade300,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile() async {
    // Use a file input element to pick a PDF from browser memory
    final input = html.FileUploadInputElement()..accept = '.pdf';
    input.click();

    await input.onChange.first;
    if (input.files!.isEmpty) return;

    final file = input.files![0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    await reader.onLoadEnd.first;
    final bytes = reader.result as List<int>;

    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _resultMessage = null;
      _isValid = null;
    });
  }

  Future<void> _verifyCertificate() async {
    if (_fileBytes == null) return;

    setState(() {
      _isVerifying = true;
      _resultMessage = null;
      _isValid = null;
    });

    try {
      // Decode PDF bytes as Latin-1 (ISO-8859-1) which never throws,
      // then search for the MAI-XXXX-XXXX-XXXX pattern in the PDF info dictionary
      // (/Keywords field). The info dictionary is stored uncompressed in the PDF,
      // unlike content streams which are compressed with FlateDecode.
      // PDFs contain binary data, so utf8.decode would fail with "missing extension byte".
      final content = const Latin1Codec().decode(
        Uint8List.fromList(_fileBytes!),
      );
      // Look for "/Keywords (MAI-XXXX-XXXX-XXXX)" in the uncompressed PDF info dict
      final pattern = RegExp(r'/Keywords\s*\(([A-Z0-9-]+)\)');
      final match = pattern.firstMatch(content);

      if (match != null) {
        final foundCode = match.group(1)!;
        // Validate the code matches the expected MAI-XXXX-XXXX-XXXX format
        if (!RegExp(
          r'^MAI-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$',
        ).hasMatch(foundCode)) {
          setState(() {
            _isValid = false;
            _resultMessage =
                "❌ Sertifikat TIDAK TERVERIFIKASI — Kode verifikasi tidak ditemukan. "
                "Sertifikat ini mungkin bukan dari sistem MAI Sektor atau telah dimodifikasi.";
          });
          return;
        }

        // Cross-check against Firestore records
        final firebaseService = ref.read(firebaseServiceProvider);
        final record = await firebaseService.getCertificateRecord(foundCode);

        if (record != null) {
          setState(() {
            _isValid = true;
            _resultMessage =
                "✅ Sertifikat ASLI — Kode Verifikasi: $foundCode\n"
                "Atas nama: ${record.participantName}\n"
                "Kepengurusan: ${record.kepengurusanTahun}\n"
                "Diterbitkan: ${record.issuedAt.toLocal().toString().substring(0, 16)}";
          });
        } else {
          setState(() {
            _isValid = false;
            _resultMessage =
                "⚠️ Kode verifikasi ditemukan ($foundCode), tetapi tidak terdaftar "
                "di database. Sertifikat ini mungkin bukan dari sistem MAI Sektor "
                "atau telah dimodifikasi.";
          });
        }
      } else {
        setState(() {
          _isValid = false;
          _resultMessage =
              "❌ Sertifikat TIDAK TERVERIFIKASI — Kode verifikasi tidak ditemukan. "
              "Sertifikat ini mungkin bukan dari sistem MAI Sektor atau telah dimodifikasi.";
        });
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _resultMessage = "Gagal membaca file: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }
}
