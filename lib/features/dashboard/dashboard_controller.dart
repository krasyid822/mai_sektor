// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import '../shared/models.dart';
import '../shared/firebase_service.dart';

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
    "Nasyid Perjuangan - Harapan Ummah": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "Instrumental Shalawat - Kedamaian Hati": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
    "Mars MAI Sektor - Semangat Dakwah": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
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

    _updateAudioSource("Nasyid Perjuangan - Harapan Ummah", 0.5);

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

  void _updateAudioSource(String track, double volume) {
    if (_audioElement == null) return;
    final url = _trackUrls[track];
    if (url != null) {
      _audioElement!.src = url;
      _audioElement!.volume = volume;
      if (state.isPlaying) {
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
    _updateAudioSource(track, state.volume);
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

  void updateWeights({
    double? bobotKelasBesar,
    double? bobotRoomQudwah,
    double? bobotTugas,
    double? nilaiMin,
  }) {
    state = state.copyWith(
      bobotKelasBesar: bobotKelasBesar ?? state.bobotKelasBesar,
      bobotRoomQudwah: bobotRoomQudwah ?? state.bobotRoomQudwah,
      bobotTugas: bobotTugas ?? state.bobotTugas,
      nilaiMin: nilaiMin ?? state.nilaiMin,
    );
  }

  void updateTestFilterQuery(String query) {
    state = state.copyWith(testFilterQuery: query);
  }

  void selectTeacherForNewParticipant(String? teacher) {
    state = state.copyWith(selectedTeacherForNewParticipant: () => teacher);
  }

  Map<String, double> calculateParticipantScores({
    required Identity participant,
    required List<RoomQudwahEvaluation> evaluations,
    required List<Test> tests,
    required List<Attendance> attendances,
    required List<String> uploadedFiles,
  }) {
    final participantTests = tests.where((t) => t.name == participant.name);
    final hasAttendance = attendances.any((a) => a.identityName == participant.name && a.role == 'peserta');
    double kelasBesarScore = 0.0;
    int kbComponents = 0;
    if (hasAttendance) {
      kelasBesarScore += 100.0;
      kbComponents++;
    }
    if (participantTests.isNotEmpty) {
      for (final test in participantTests) {
        kelasBesarScore += (test.score ?? 100).toDouble();
        kbComponents++;
      }
    }
    if (kbComponents > 0) {
      kelasBesarScore /= kbComponents;
    }

    final participantEvals = evaluations.where((e) => e.peserta == participant.name);
    double roomQudwahScore = 0.0;
    if (participantEvals.isNotEmpty) {
      double totalEvalScore = 0.0;
      for (final eval in participantEvals) {
        if (eval.scores.isNotEmpty) {
          final criteriaAverage = eval.scores.values.reduce((a, b) => a + b) / eval.scores.length;
          totalEvalScore += criteriaAverage;
        } else {
          totalEvalScore += 100.0;
        }
      }
      roomQudwahScore = totalEvalScore / participantEvals.length;
    }

    final hasResume = uploadedFiles.contains('resume-${participant.name}');
    double tugasScore = hasResume ? 100.0 : 0.0;

    final total = (kelasBesarScore * state.bobotKelasBesar / 100) +
                  (roomQudwahScore * state.bobotRoomQudwah / 100) +
                  (tugasScore * state.bobotTugas / 100);

    return {
      'kelasBesar': kelasBesarScore,
      'roomQudwah': roomQudwahScore,
      'tugas': tugasScore,
      'total': total,
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

  Future<void> downloadRekapPDF({
    required List<Identity> participants,
    required List<RoomQudwahEvaluation> evals,
    required List<Test> tests,
    required AppConfig config,
  }) async {
    final pdf = pw.Document();
    final attendances = ref.read(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.read(filesStreamProvider).value ?? [];

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

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (headerImage != null) ...[
                pw.Image(headerImage, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 16),
              ],
              pw.Text(
                "REKAP PENILAIAN MAI SEKTOR",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _sanitizePdfText("Kepala Sekolah: ${config.kepalaSekolahNama} | Tahun: ${config.kepengurusanTahun}"),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Nama',
                  'Kelas Besar',
                  'Room Qudwah',
                  'Tugas',
                  'Total',
                  'Status',
                ],
                data: participants.map((p) {
                  final scores = calculateParticipantScores(
                    participant: p,
                    evaluations: evals,
                    tests: tests,
                    attendances: attendances,
                    uploadedFiles: uploadedFiles,
                  );
                  final kb = scores['kelasBesar'] ?? 0.0;
                  final rq = scores['roomQudwah'] ?? 0.0;
                  final tg = scores['tugas'] ?? 0.0;
                  final total = scores['total'] ?? 0.0;
                  final status = total >= state.nilaiMin
                      ? "LULUS"
                      : "TIDAK LULUS";
                  return [
                    _sanitizePdfText(p.name),
                    kb.toStringAsFixed(0),
                    rq.toStringAsFixed(0),
                    tg.toStringAsFixed(0),
                    total.toStringAsFixed(1),
                    status,
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 32),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text("Kepala Sekolah,"),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        _sanitizePdfText(config.kepalaSekolahNama),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text("Kepala Divisi MAI,"),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        _sanitizePdfText(config.kadivNama ?? "Kadiv MAI"),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              if (footerImage != null) ...[
                pw.Spacer(),
                pw.Image(footerImage, fit: pw.BoxFit.contain),
              ],
            ],
          );
        },
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
    final input = html.FileUploadInputElement()..accept = '.pdf';
    input.click();
    input.onChange.listen((event) {
      final file = input.files!.first;
      if (file.size > 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran file melebihi 1MB! Silakan pilih file yang lebih kecil.'),
            ),
          );
        }
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) async {
        final base64String = reader.result as String;
        await ref.read(firebaseServiceProvider).saveFileBase64(type, id, base64String);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil mengunggah $type untuk $id!')),
          );
        }
      });
    });
  }

  Future<void> downloadResume({
    required String participantName,
    required BuildContext context,
  }) async {
    final base64String = await ref.read(firebaseServiceProvider).getFileBase64("resume", participantName);
    if (base64String != null) {
      try {
        final anchor = html.AnchorElement(href: base64String)
          ..target = '_blank'
          ..download = 'resume_$participantName.pdf';
        anchor.click();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengunduh berkas: $e')),
          );
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
}

final dashboardControllerProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
