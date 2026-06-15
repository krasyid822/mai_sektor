// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../../shared/signature_helper.dart';
import '../dashboard_controller.dart';

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
    final pdf = pw.Document();

    pw.MemoryImage? headerImage;
    pw.MemoryImage? footerImage;
    try {
      final headerData = await rootBundle.load('assets/kop_surat/header.png');
      headerImage = pw.MemoryImage(headerData.buffer.asUint8List());
    } catch (_) {}
    try {
      final footerData = await rootBundle.load('assets/kop_surat/footer.png');
      footerImage = pw.MemoryImage(footerData.buffer.asUint8List());
    } catch (_) {}

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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 4),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (headerImage != null)
                  pw.Image(headerImage, height: 50, fit: pw.BoxFit.contain),
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
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          "Kepala Sekolah,",
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
                      ],
                    ),
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
                          _sanitizePdfText(config.kadivNama ?? "Kadiv MAI"),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (footerImage != null)
                  pw.Image(footerImage, height: 30, fit: pw.BoxFit.contain),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!config.rekapSigned) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 64),
              SizedBox(height: 24),
              Text(
                "Sertifikat Belum Diterbitkan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Sertifikat kelulusan otomatis dibuat jika rekapitulasi penilaian sudah ditandatangani oleh Kepala Sekolah di tab 'Rekap Penilaian'.",
                style: TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toSet();
    final controller = ref.read(dashboardControllerProvider.notifier);
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];
    final resumeScores = ref.watch(resumeScoresStreamProvider).value ?? {};

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
          );
          final total = scores['total'] ?? 0.0;
          return total >= config.nilaiMinimum;
        }).toList();

        if (passedParticipants.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "Tidak ada peserta yang memenuhi kriteria kelulusan (nilai >= batas minimum).",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  final allSigned = hasKepsek && hasWalikelas && hasKadiv;

                  return ListTile(
                    title: Text(
                      Identity.displayName(id, participantsOnly),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Status Ttd: (Kepsek: ${hasKepsek ? '✓' : '✗'}, Walikelas: ${hasWalikelas ? '✓' : '✗'}, Kadiv: ${hasKadiv ? '✓' : '✗'})",
                      style: TextStyle(
                        color: allSigned ? Colors.tealAccent : Colors.white60,
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: Icon(allSigned ? Icons.download : Icons.lock),
                      label: const Text("Unduh Sertifikat (PDF)"),
                      onPressed: allSigned
                          ? () => _generateCertificatePDF(
                              ref,
                              id,
                              participantsOnly,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }
}
