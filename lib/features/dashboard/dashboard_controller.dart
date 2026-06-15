// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/signature_helper.dart';

class DashboardState {
  final bool isPlaying;
  final double volume;
  final String currentTrack;
  final double bobotKelasBesar;
  final double bobotRoomQudwah;
  final double bobotTugas;
  final double nilaiMin;
  final String testFilterQuery;
  final String? selectedTeacherForNewParticipant;

  DashboardState({
    this.isPlaying = false,
    this.volume = 0.5,
    this.currentTrack = "Nasyid Perjuangan - Harapan Ummah",
    this.bobotKelasBesar = 40.0,
    this.bobotRoomQudwah = 40.0,
    this.bobotTugas = 20.0,
    this.nilaiMin = 75.0,
    this.testFilterQuery = '',
    this.selectedTeacherForNewParticipant,
  });

  DashboardState copyWith({
    bool? isPlaying,
    double? volume,
    String? currentTrack,
    double? bobotKelasBesar,
    double? bobotRoomQudwah,
    double? bobotTugas,
    double? nilaiMin,
    String? testFilterQuery,
    String? Function()? selectedTeacherForNewParticipant,
  }) {
    return DashboardState(
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      currentTrack: currentTrack ?? this.currentTrack,
      bobotKelasBesar: bobotKelasBesar ?? this.bobotKelasBesar,
      bobotRoomQudwah: bobotRoomQudwah ?? this.bobotRoomQudwah,
      bobotTugas: bobotTugas ?? this.bobotTugas,
      nilaiMin: nilaiMin ?? this.nilaiMin,
      testFilterQuery: testFilterQuery ?? this.testFilterQuery,
      selectedTeacherForNewParticipant: selectedTeacherForNewParticipant != null
          ? selectedTeacherForNewParticipant()
          : this.selectedTeacherForNewParticipant,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  html.AudioElement? _audioElement;
  final List<String> playlist = [
    "Nasyid Perjuangan - Harapan Ummah",
    "Instrumental Shalawat - Kedamaian Hati",
    "Mars MAI Sektor - Semangat Dakwah",
  ];
  final Map<String, String> _trackUrls = {
    "Nasyid Perjuangan - Harapan Ummah":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "Instrumental Shalawat - Kedamaian Hati":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
    "Mars MAI Sektor - Semangat Dakwah":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
  };

  @override
  DashboardState build() {
    _audioElement = html.AudioElement()..loop = true;

    // Initialize config if already loaded
    final config = ref.read(configStreamProvider).value;
    final initialBobotKelasBesar = config?.bobotKelasBesar ?? 40.0;
    final initialBobotRoomQudwah = config?.bobotRoomQudwah ?? 40.0;
    final initialBobotTugas = config?.bobotTugas ?? 20.0;
    final initialNilaiMin = config?.nilaiMinimum ?? 75.0;

    _updateAudioSource(
      "Nasyid Perjuangan - Harapan Ummah",
      0.5,
      isPlaying: false,
    );

    ref.onDispose(() {
      _audioElement?.pause();
      _audioElement = null;
    });

    return DashboardState(
      bobotKelasBesar: initialBobotKelasBesar,
      bobotRoomQudwah: initialBobotRoomQudwah,
      bobotTugas: initialBobotTugas,
      nilaiMin: initialNilaiMin,
    );
  }

  void _updateAudioSource(
    String track,
    double volume, {
    required bool isPlaying,
  }) {
    if (_audioElement == null) return;
    final url = _trackUrls[track];
    if (url != null) {
      _audioElement!.src = url;
      _audioElement!.volume = volume;
      if (isPlaying) {
        _audioElement!.play();
      }
    }
  }

  void togglePlay() {
    if (_audioElement == null) return;
    final nextPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextPlaying);
    if (nextPlaying) {
      _audioElement!.play();
    } else {
      _audioElement!.pause();
    }
  }

  void changeTrack(String track) {
    state = state.copyWith(currentTrack: track);
    _updateAudioSource(track, state.volume, isPlaying: state.isPlaying);
  }

  void skipTrack(bool forward) {
    final index = playlist.indexOf(state.currentTrack);
    final nextIndex = forward
        ? (index + 1) % playlist.length
        : (index - 1) % playlist.length;
    changeTrack(playlist[nextIndex]);
  }

  void updateVolume(double volume) {
    state = state.copyWith(volume: volume);
    _audioElement?.volume = volume;
  }

  Future<void> updateWeights({
    double? bobotKelasBesar,
    double? bobotRoomQudwah,
    double? bobotTugas,
    double? nilaiMin,
  }) async {
    state = state.copyWith(
      bobotKelasBesar: bobotKelasBesar ?? state.bobotKelasBesar,
      bobotRoomQudwah: bobotRoomQudwah ?? state.bobotRoomQudwah,
      bobotTugas: bobotTugas ?? state.bobotTugas,
      nilaiMin: nilaiMin ?? state.nilaiMin,
    );

    // Validate total bobot is 100%
    final totalBobot =
        state.bobotKelasBesar + state.bobotRoomQudwah + state.bobotTugas;
    if ((totalBobot - 100.0).abs() > 0.01) {
      // Log warning — UI will show the indicator from rekap_penilaian_tab
      debugPrint(
        '⚠️ PERINGATAN BOBOT: Total bobot ${totalBobot.toStringAsFixed(1)}% tidak sama dengan 100%! '
        '(Kelas Besar: ${state.bobotKelasBesar}%, '
        'Room Qudwah: ${state.bobotRoomQudwah}%, '
        'Tugas: ${state.bobotTugas}%)',
      );
    }

    // Save updated weights and minimum score to Firestore global config
    final currentConfig = ref.read(configStreamProvider).value;
    if (currentConfig != null) {
      final updatedConfig = AppConfig(
        activeMode: currentConfig.activeMode,
        kepalaSekolahNama: currentConfig.kepalaSekolahNama,
        kepengurusanTahun: currentConfig.kepengurusanTahun,
        bobotKelasBesar: state.bobotKelasBesar,
        bobotRoomQudwah: state.bobotRoomQudwah,
        bobotTugas: state.bobotTugas,
        nilaiMinimum: state.nilaiMin,
        kepsekSignatureBase64: currentConfig.kepsekSignatureBase64,
        kadivNama: currentConfig.kadivNama,
        kadivSignatureBase64: currentConfig.kadivSignatureBase64,
        activeMateri: currentConfig.activeMateri,
        rekapSigned: currentConfig.rekapSigned,
        kepalaSekolahNim: currentConfig.kepalaSekolahNim,
      );
      await ref.read(firebaseServiceProvider).saveConfig(updatedConfig);
    }
  }

  void updateTestFilterQuery(String query) {
    state = state.copyWith(testFilterQuery: query);
  }

  void selectTeacherForNewParticipant(String? teacher) {
    state = state.copyWith(selectedTeacherForNewParticipant: () => teacher);
  }

  /// The 4 materi for Kelas Besar.
  static const List<String> kMateriList = [
    'Urgensi Membina',
    'Al Qudwah Qobla Dakwah',
    'Manajemen Mentoring Aktif',
    'Seni Menyentuh Hati',
  ];

  Map<String, double> calculateParticipantScores({
    required Identity participant,
    required List<RoomQudwahEvaluation> evaluations,
    required List<Test> tests,
    required List<Attendance> attendances,
    required List<String> uploadedFiles,
    required Map<String, double> resumeScores,
    List<TestScore> testScores = const [],
  }) {
    // --- Kelas Besar: 4 materi, each with pre+post average ---
    double kelasBesarTotal = 0.0;
    int kbMateriCount = 0;
    final Map<String, double> materiScores = {};

    for (final materi in kMateriList) {
      final ts = testScores
          .where(
            (t) => t.participantName == participant.name && t.materi == materi,
          )
          .toList();

      double preScore = 0.0;
      double postScore = 0.0;
      int preCount = 0;
      int postCount = 0;

      for (final t in ts) {
        if (t.pretestScore != null) {
          preScore += t.pretestScore!;
          preCount++;
        }
        if (t.posttestScore != null) {
          postScore += t.posttestScore!;
          postCount++;
        }
      }

      // If no scores at all for this materi, set to 0
      if (preCount == 0 && postCount == 0) {
        materiScores[materi] = 0.0;
        continue;
      }

      final preAvg = preCount > 0 ? preScore / preCount : 0.0;
      final postAvg = postCount > 0 ? postScore / postCount : 0.0;

      // Average of pre and post for this materi
      double materiAvg = 0.0;
      int components = 0;
      if (preCount > 0) {
        materiAvg += preAvg;
        components++;
      }
      if (postCount > 0) {
        materiAvg += postAvg;
        components++;
      }
      if (components > 0) {
        materiAvg /= components;
      }

      materiScores[materi] = materiAvg;
      kelasBesarTotal += materiAvg;
      kbMateriCount++;
    }

    // Kelas Besar score is average of materi that have actual scores
    // If no materi has scores at all, kelasBesarScore = 0
    final kelasBesarScore = kbMateriCount > 0
        ? kelasBesarTotal / kbMateriCount
        : 0.0;

    // --- Room Qudwah ---
    final participantEvals = evaluations.where(
      (e) => e.peserta == participant.name,
    );
    double roomQudwahScore = 0.0;
    if (participantEvals.isNotEmpty) {
      double totalEvalScore = 0.0;
      for (final eval in participantEvals) {
        if (eval.scores.isNotEmpty) {
          final criteriaAverage =
              eval.scores.values.reduce((a, b) => a + b) / eval.scores.length;
          totalEvalScore += criteriaAverage;
        } else {
          totalEvalScore += 100.0;
        }
      }
      roomQudwahScore = totalEvalScore / participantEvals.length;
    }

    // --- Tugas ---
    final hasResume =
        uploadedFiles.contains('resume-${participant.name}') ||
        uploadedFiles.contains('retyping-${participant.name}');
    final customScore = resumeScores[participant.name];
    double tugasScore = customScore ?? (hasResume ? 100.0 : 0.0);

    // --- Total ---
    final total =
        (kelasBesarScore * state.bobotKelasBesar / 100) +
        (roomQudwahScore * state.bobotRoomQudwah / 100) +
        (tugasScore * state.bobotTugas / 100);

    return {
      'kelasBesar': kelasBesarScore,
      'roomQudwah': roomQudwahScore,
      'tugas': tugasScore,
      'total': total,
      // Individual materi scores
      'materi_Urgensi Membina': materiScores['Urgensi Membina'] ?? 0.0,
      'materi_Al Qudwah Qobla Dakwah':
          materiScores['Al Qudwah Qobla Dakwah'] ?? 0.0,
      'materi_Manajemen Mentoring Aktif':
          materiScores['Manajemen Mentoring Aktif'] ?? 0.0,
      'materi_Seni Menyentuh Hati': materiScores['Seni Menyentuh Hati'] ?? 0.0,
    };
  }

  String _sanitizePdfText(String text) {
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  pw.Widget _pdfHeaderCell(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFFFFFFFF),
        ),
      ),
    );
  }

  pw.Widget _pdfGroupHeaderCell(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF1ABC9C),
        ),
      ),
    );
  }

  pw.Widget _pdfSubHeaderCell(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColor.fromInt(0x33FFFFFF), width: 0.5),
          right: pw.BorderSide(color: PdfColor.fromInt(0x33FFFFFF), width: 0.5),
        ),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF1ABC9C),
        ),
      ),
    );
  }

  pw.Widget _pdfDataCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7)),
    );
  }

  Future<void> downloadRekapPDF({
    required List<Identity> participants,
    required List<RoomQudwahEvaluation> evals,
    required List<Test> tests,
    required AppConfig config,
    List<TestScore> testScores = const [],
  }) async {
    final pdf = pw.Document();
    final attendances = ref.read(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.read(filesStreamProvider).value ?? [];
    final resumeScores = ref.read(resumeScoresStreamProvider).value ?? {};

    pw.MemoryImage? headerImage;
    pw.MemoryImage? footerImage;
    try {
      final headerData = await rootBundle.load(
        'assets/kop_surat/header_landscape.png',
      );
      headerImage = pw.MemoryImage(headerData.buffer.asUint8List());
    } catch (_) {}
    try {
      final footerData = await rootBundle.load('assets/kop_surat/footer.png');
      footerImage = pw.MemoryImage(footerData.buffer.asUint8List());
    } catch (_) {}

    // Load kepala sekolah signature image if signed
    pw.MemoryImage? kepsekSigImage;
    if (config.rekapSigned) {
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
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: headerImage != null
            ? (context) => pw.Center(
                child: pw.Container(
                  height: 40,
                  child: pw.Image(headerImage!, fit: pw.BoxFit.contain),
                ),
              )
            : null,
        footer: footerImage != null
            ? (context) => pw.Center(
                child: pw.Container(
                  height: 30,
                  child: pw.Image(footerImage!, fit: pw.BoxFit.contain),
                ),
              )
            : null,
        build: (pw.Context context) => [
          pw.Text(
            "REKAP PENILAIAN MAI SEKTOR",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _sanitizePdfText(
              "Kepala Sekolah: ${config.kepalaSekolahNama} | Tahun: ${config.kepengurusanTahun}",
            ),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          // Single table with all participants — two-level header
          if (participants.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFCCCCCC),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(120),
                1: const pw.FixedColumnWidth(50),
                2: const pw.FixedColumnWidth(50),
                3: const pw.FixedColumnWidth(50),
                4: const pw.FixedColumnWidth(50),
                5: const pw.FixedColumnWidth(80),
                6: const pw.FixedColumnWidth(60),
                7: const pw.FixedColumnWidth(55),
                8: const pw.FixedColumnWidth(65),
              },
              children: [
                // Header Row 1: Group headers (9 cells, no colspan — pdf TableRow doesn't support it)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF2C3E50),
                  ),
                  children: [
                    _pdfHeaderCell('Nama'),
                    _pdfGroupHeaderCell('Kelas Besar'),
                    _pdfGroupHeaderCell(''),
                    _pdfGroupHeaderCell(''),
                    _pdfGroupHeaderCell(''),
                    _pdfHeaderCell('Room Qudwah'),
                    _pdfHeaderCell('Tugas'),
                    _pdfHeaderCell('Total'),
                    _pdfHeaderCell('Status'),
                  ],
                ),
                // Header Row 2: Sub-columns
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF34495E),
                  ),
                  children: [
                    pw.Container(), // empty under Nama
                    _pdfSubHeaderCell('1'),
                    _pdfSubHeaderCell('2'),
                    _pdfSubHeaderCell('3'),
                    _pdfSubHeaderCell('4'),
                    pw.Container(), // empty under Room Qudwah
                    pw.Container(), // empty under Tugas
                    pw.Container(), // empty under Total
                    pw.Container(), // empty under Status
                  ],
                ),
                // Data rows
                ...participants.map((p) {
                  final scores = calculateParticipantScores(
                    participant: p,
                    evaluations: evals,
                    tests: tests,
                    attendances: attendances,
                    uploadedFiles: uploadedFiles,
                    resumeScores: resumeScores,
                    testScores: testScores,
                  );
                  final m1 = scores['materi_Urgensi Membina'] ?? 0.0;
                  final m2 = scores['materi_Al Qudwah Qobla Dakwah'] ?? 0.0;
                  final m3 = scores['materi_Manajemen Mentoring Aktif'] ?? 0.0;
                  final m4 = scores['materi_Seni Menyentuh Hati'] ?? 0.0;
                  final rq = scores['roomQudwah'] ?? 0.0;
                  final tg = scores['tugas'] ?? 0.0;
                  final total = scores['total'] ?? 0.0;
                  final status = total >= state.nilaiMin
                      ? "LULUS"
                      : "TIDAK LULUS";
                  return pw.TableRow(
                    children: [
                      _pdfDataCell(
                        _sanitizePdfText(Identity.displayName(p, participants)),
                      ),
                      _pdfDataCell(m1.toStringAsFixed(0)),
                      _pdfDataCell(m2.toStringAsFixed(0)),
                      _pdfDataCell(m3.toStringAsFixed(0)),
                      _pdfDataCell(m4.toStringAsFixed(0)),
                      _pdfDataCell(rq.toStringAsFixed(0)),
                      _pdfDataCell(tg.toStringAsFixed(0)),
                      _pdfDataCell(total.toStringAsFixed(1)),
                      _pdfDataCell(status),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 20),
          // Signature: only Kepala Sekolah
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  "Kepala Sekolah,",
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: kepsekSigImage != null ? 8 : 40),
                if (kepsekSigImage != null)
                  pw.SizedBox(
                    height: 40,
                    child: pw.Image(kepsekSigImage, fit: pw.BoxFit.contain),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _sanitizePdfText(config.kepalaSekolahNama),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (config.kepalaSekolahNim != null &&
                    config.kepalaSekolahNim!.isNotEmpty)
                  pw.Text(
                    'NIM: ${_sanitizePdfText(config.kepalaSekolahNim!)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  void pickAndUploadFile({
    required String type,
    required String id,
    required BuildContext context,
  }) {
    final isRetyping = type == 'retyping';
    final input = html.FileUploadInputElement()
      ..accept = isRetyping ? '.txt' : '.pdf';
    input.click();
    input.onChange.listen((event) {
      final file = input.files!.first;
      if (file.size > 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ukuran file melebihi 1MB! Silakan pilih file yang lebih kecil.',
              ),
            ),
          );
        }
        return;
      }
      final reader = html.FileReader();
      if (isRetyping) {
        reader.readAsText(file);
        reader.onLoadEnd.listen((e) async {
          final textString = reader.result as String;
          await ref
              .read(firebaseServiceProvider)
              .saveFileBase64(type, id, textString);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Berhasil mengunggah retyping untuk $id!'),
              ),
            );
          }
        });
      } else {
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((e) async {
          final base64String = reader.result as String;
          await ref
              .read(firebaseServiceProvider)
              .saveFileBase64(type, id, base64String);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Berhasil mengunggah $type untuk $id!')),
            );
          }
        });
      }
    });
  }

  Future<void> downloadResume({
    required String participantName,
    required BuildContext context,
  }) async {
    final base64String = await ref
        .read(firebaseServiceProvider)
        .getFileBase64("resume", participantName);
    if (base64String != null) {
      try {
        final anchor = html.AnchorElement(href: base64String)
          ..target = '_blank'
          ..download = 'resume_$participantName.pdf';
        anchor.click();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal mengunduh berkas: $e')));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas resume tidak ditemukan!')),
        );
      }
    }
  }

  Future<void> downloadRetyping({
    required String participantName,
    required BuildContext context,
  }) async {
    final textContent = await ref
        .read(firebaseServiceProvider)
        .getFileBase64("retyping", participantName);
    if (textContent != null) {
      try {
        final blob = html.Blob([textContent], 'text/plain');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..download = 'retyping_$participantName.txt';
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengunduh berkas retyping: $e')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas retyping tidak ditemukan!')),
        );
      }
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
