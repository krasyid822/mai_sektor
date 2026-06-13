// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/signature_upload_widget.dart';
import '../shared/qr_code_page.dart';
import '../shared/signature_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;

class LiveDashboard extends ConsumerStatefulWidget {
  const LiveDashboard({super.key});

  @override
  ConsumerState<LiveDashboard> createState() => _LiveDashboardState();
}

class _LiveDashboardState extends ConsumerState<LiveDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile / Groups Tab Controllers
  final _newTeacherController = TextEditingController();
  final _newParticipantController = TextEditingController();
  String? _selectedTeacherForNewParticipant;

  // Kadiv (Kepala Divisi MAI) Controllers
  final _kadivController = TextEditingController();
  final _kadivSigController = SignatureController();



  // Music Player Mock State
  bool _isPlaying = false;
  double _volume = 0.5;
  String _currentTrack = "Nasyid Perjuangan - Harapan Ummah";
  final List<String> _playlist = [
    "Nasyid Perjuangan - Harapan Ummah",
    "Instrumental Shalawat - Kedamaian Hati",
    "Mars MAI Sektor - Semangat Dakwah",
  ];

  // Weights state
  double _bobotKelasBesar = 40.0;
  double _bobotRoomQudwah = 40.0;
  double _bobotTugas = 20.0;
  double _nilaiMin = 75.0;
  String _testFilterQuery = "";

  // Real Web Audio Player
  html.AudioElement? _audioElement;
  final Map<String, String> _trackUrls = {
    "Nasyid Perjuangan - Harapan Ummah":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "Instrumental Shalawat - Kedamaian Hati":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
    "Mars MAI Sektor - Semangat Dakwah":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
  };

  void _togglePlay() {
    if (_audioElement == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _audioElement!.play();
      } else {
        _audioElement!.pause();
      }
    });
  }

  void _updateAudioSource() {
    if (_audioElement == null) return;
    final url = _trackUrls[_currentTrack];
    if (url != null) {
      _audioElement!.src = url;
      _audioElement!.volume = _volume;
      if (_isPlaying) {
        _audioElement!.play();
      }
    }
  }

  void _changeTrack(String track) {
    setState(() {
      _currentTrack = track;
    });
    _updateAudioSource();
  }

  void _updateVolume(double vol) {
    setState(() {
      _volume = vol;
    });
    _audioElement?.volume = vol;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _audioElement = html.AudioElement()..loop = true;
    _updateAudioSource();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newTeacherController.dispose();
    _newParticipantController.dispose();
    _kadivController.dispose();
    _kadivSigController.dispose();

    _audioElement?.pause();
    _audioElement = null;
    super.dispose();
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

  Map<String, double> _calculateParticipantScores({
    required Identity participant,
    required List<RoomQudwahEvaluation> evaluations,
    required List<Test> tests,
    required List<Attendance> attendances,
    required List<String> uploadedFiles,
  }) {
    // 1. Kelas Besar Score (attendance + tests)
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

    // 2. Room Qudwah Score (average of all 14 criteria of all evaluations for the participant)
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

    // 3. Tugas Score (resume upload)
    final hasResume = uploadedFiles.contains('resume-${participant.name}');
    double tugasScore = hasResume ? 100.0 : 0.0;

    final total = (kelasBesarScore * _bobotKelasBesar / 100) +
                  (roomQudwahScore * _bobotRoomQudwah / 100) +
                  (tugasScore * _bobotTugas / 100);

    return {
      'kelasBesar': kelasBesarScore,
      'roomQudwah': roomQudwahScore,
      'tugas': tugasScore,
      'total': total,
    };
  }

  // Helper to trigger PDF download of Rekap
  Future<void> _downloadRekapPDF(
    List<Identity> participants,
    List<RoomQudwahEvaluation> evals,
    List<Test> tests,
    AppConfig config,
  ) async {
    final pdf = pw.Document();
    final attendances = ref.read(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.read(filesStreamProvider).value ?? [];

    // Load Kop Surat Assets
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
                  final scores = _calculateParticipantScores(
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
                  final status = total >= _nilaiMin
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

  // File Upload Helper (converts file to Base64)
  void _pickAndUploadFile(String type, String id) {
    final input = html.FileUploadInputElement()..accept = '.pdf';
    input.click();
    input.onChange.listen((event) {
      final file = input.files!.first;
      if (file.size > 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ukuran file melebihi 1MB! Silakan pilih file yang lebih kecil.',
            ),
          ),
        );
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) async {
        final base64String = reader.result as String;
        await ref
            .read(firebaseServiceProvider)
            .saveFileBase64(type, id, base64String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil mengunggah $type untuk $id!')),
          );
        }
      });
    });
  }

  void _downloadResume(String participantName) async {
    final base64String = await ref.read(firebaseServiceProvider).getFileBase64("resume", participantName);
    if (base64String != null) {
      try {
        final anchor = html.AnchorElement(href: base64String)
          ..target = '_blank'
          ..download = 'resume_$participantName.pdf';
        anchor.click();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengunduh berkas: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas resume tidak ditemukan!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configStreamProvider);
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final attendanceAsync = ref.watch(attendanceStreamProvider);
    final testsAsync = ref.watch(testsStreamProvider);
    final evaluationsAsync = ref.watch(evaluationsStreamProvider);
    // Watch groupsStreamProvider to have access to small class groupings
    final groupsAsync = ref.watch(groupsStreamProvider);

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
            Tab(
              icon: Icon(Icons.manage_accounts),
              text: 'Kelola Profil & Kelompok',
            ),
            Tab(
              icon: Icon(Icons.fingerprint),
              text: 'Kelola Biometrik',
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
              _buildSessionControlTab(config, attendanceAsync),
              const QrCodePage(),
              _buildDataUploadTab(identitiesAsync),
              _buildRekapTab(
                config,
                identitiesAsync,
                evaluationsAsync,
                testsAsync,
              ),
              _buildCertificateTab(config, identitiesAsync),
              _buildSignedContractsTab(identitiesAsync, attendanceAsync),
              _buildPrePostTestMainTab(testsAsync),
              _buildManageProfileAndGroupsTab(
                config,
                identitiesAsync,
                groupsAsync,
              ),
              _buildManageBiometricsTab(identitiesAsync),
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

  // TAB 1: Kontrol Sesi & QR
  Widget _buildSessionControlTab(
    AppConfig config,
    AsyncValue<List<Attendance>> attendanceAsync,
  ) {
    // Watch groups, tests, and attendance to compute completion status
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toList()
      ..sort();
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];

    // Collect unique teacher/guru names from attendance
    final teacherNames =
        attendances
            .where((att) => att.role == 'guru')
            .map((att) => att.identityName)
            .toSet()
            .toList()
          ..sort();

    // Collect unique tamu names from attendance
    final tamuNames =
        attendances
            .where((att) => att.role == 'tamu')
            .map((att) => att.identityName)
            .toSet()
            .toList()
          ..sort();

    // Map completion for participants
    final completedCount = participantNames.where((pName) {
      if (config.activeMode == 'absensi') {
        return attendances.any(
          (att) => att.identityName == pName && att.role == 'peserta',
        );
      } else if (config.activeMode == 'pretest') {
        return tests.any((t) => t.name == pName && t.type == 'pre');
      } else if (config.activeMode == 'posttest') {
        return tests.any((t) => t.name == pName && t.type == 'post');
      } else if (config.activeMode == 'kontrak') {
        return attendances.any(
          (att) => att.identityName == pName && att.role == 'kontrak',
        );
      }
      return false; // idle
    }).length;

    final pendingCount = participantNames.length - completedCount;

    // Teacher attendance status (always based on absensi role 'guru')
    final teacherAttendedCount = teacherNames.where((tName) {
      return attendances.any(
        (att) => att.identityName == tName && att.role == 'guru',
      );
    }).length;

    // Tamu attendance status
    final tamuAttendedCount =
        tamuNames.length; // all tamu in attendance are present by definition

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Switcher & Status
              Expanded(
                flex: 2,
                child: Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Kontrol Sesi Aktif",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Sesi Aktif: ",
                              style: TextStyle(color: Colors.white70),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                config.activeMode.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Ubah Mode Sesi QR:",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                'idle',
                                'absensi',
                                'pretest',
                                'posttest',
                                'kontrak',
                              ].map((mode) {
                                final isActive = config.activeMode == mode;
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isActive
                                        ? Colors.tealAccent
                                        : Colors.white10,
                                    foregroundColor: isActive
                                        ? Colors.black
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => ref
                                      .read(firebaseServiceProvider)
                                      .updateActiveMode(mode),
                                  child: Text(mode.toUpperCase()),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Music Player Card
              Expanded(
                flex: 1,
                child: Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note,
                              color: Colors.tealAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentTrack,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.skip_previous,
                                color: Colors.white70,
                                size: 28,
                              ),
                              onPressed: () {
                                final index = _playlist.indexOf(_currentTrack);
                                final newTrack =
                                    _playlist[(index - 1) % _playlist.length];
                                _changeTrack(newTrack);
                              },
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 52,
                                minHeight: 52,
                              ),
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: Colors.tealAccent,
                                size: 44,
                              ),
                              onPressed: _togglePlay,
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.skip_next,
                                color: Colors.white70,
                                size: 28,
                              ),
                              onPressed: () {
                                final index = _playlist.indexOf(_currentTrack);
                                final newTrack =
                                    _playlist[(index + 1) % _playlist.length];
                                _changeTrack(newTrack);
                              },
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.volume_up,
                              color: Colors.white54,
                              size: 20,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                ),
                                child: Slider(
                                  value: _volume,
                                  activeColor: Colors.tealAccent,
                                  onChanged: _updateVolume,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // WAYGROUND LIVE STATUS BOARD
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Wayground Live Status Sesi",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          _buildCounterBadge(
                            "Selesai",
                            completedCount,
                            Colors.tealAccent,
                          ),
                          const SizedBox(width: 8),
                          _buildCounterBadge(
                            "Belum Melengkapi",
                            pendingCount,
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  participantNames.isEmpty
                      ? const Center(
                          child: Text(
                            "Belum ada peserta terdaftar. Harap daftarkan peserta terlebih dahulu di tab Kelola Profil & Kelompok.",
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: participantNames.map((pName) {
                            // Determine if completed
                            bool isCompleted = false;
                            if (config.activeMode == 'absensi') {
                              isCompleted = attendances.any(
                                (att) =>
                                    att.identityName == pName &&
                                    att.role == 'peserta',
                              );
                            } else if (config.activeMode == 'pretest') {
                              isCompleted = tests.any(
                                (t) => t.name == pName && t.type == 'pre',
                              );
                            } else if (config.activeMode == 'posttest') {
                              isCompleted = tests.any(
                                (t) => t.name == pName && t.type == 'post',
                              );
                            } else if (config.activeMode == 'kontrak') {
                              isCompleted = attendances.any(
                                (att) =>
                                    att.identityName == pName &&
                                    att.role == 'kontrak',
                              );
                            }

                            final initials = pName.isNotEmpty
                                ? pName[0].toUpperCase()
                                : "?";

                            return Tooltip(
                              message: pName,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: isCompleted
                                            ? [
                                                const Color(0xFF0D9488),
                                                const Color(0xFF14B8A6),
                                              ]
                                            : [
                                                const Color(0xFF334155),
                                                const Color(0xFF475569),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: isCompleted
                                            ? Colors.tealAccent
                                            : Colors.white24,
                                        width: isCompleted ? 3 : 1,
                                      ),
                                      boxShadow: isCompleted
                                          ? [
                                              BoxShadow(
                                                color: Colors.tealAccent
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: isCompleted
                                                    ? Colors.white
                                                    : Colors.white38,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                          if (isCompleted)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.tealAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      pName,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCompleted
                                            ? Colors.white
                                            : Colors.white38,
                                        fontSize: 12,
                                        fontWeight: isCompleted
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                  // Teacher / Dewan Guru section
                  if (teacherNames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.school,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Dewan Guru",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _buildCounterBadge(
                          "Hadir",
                          teacherAttendedCount,
                          Colors.amberAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: teacherNames.map((tName) {
                        final isPresent = attendances.any(
                          (att) =>
                              att.identityName == tName && att.role == 'guru',
                        );
                        final initials = tName.isNotEmpty
                            ? tName[0].toUpperCase()
                            : "?";
                        return Tooltip(
                          message: tName,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isPresent
                                        ? [
                                            const Color(0xFFB45309),
                                            const Color(0xFFD97706),
                                          ]
                                        : [
                                            const Color(0xFF334155),
                                            const Color(0xFF475569),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: isPresent
                                        ? Colors.amberAccent
                                        : Colors.white24,
                                    width: isPresent ? 3 : 1,
                                  ),
                                  boxShadow: isPresent
                                      ? [
                                          BoxShadow(
                                            color: Colors.amberAccent
                                                .withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: isPresent
                                          ? Colors.white
                                          : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  tName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isPresent
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: isPresent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  // Tamu section
                  if (tamuNames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_pin,
                          color: Colors.purpleAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Tamu",
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _buildCounterBadge(
                          "Hadir",
                          tamuAttendedCount,
                          Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: tamuNames.map((tName) {
                        final initials = tName.isNotEmpty
                            ? tName[0].toUpperCase()
                            : "?";
                        return Tooltip(
                          message: tName,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6B21A8),
                                      Color(0xFF9333EA),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.purpleAccent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purpleAccent.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  tName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Data & File Upload
  Widget _buildDataUploadTab(AsyncValue<List<Identity>> identitiesAsync) {
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toSet();
    final uploadedFilesAsync = ref.watch(filesStreamProvider);

    return identitiesAsync.when(
      data: (identities) {
        return uploadedFilesAsync.when(
          data: (uploadedFiles) {
            final participantsOnly = identities
                .where((id) => participantNames.contains(id.name))
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Unggah Berkas/Tugas Resume Peserta",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF1E293B),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: participantsOnly.length,
                      itemBuilder: (context, index) {
                        final id = participantsOnly[index];
                        final hasResume = uploadedFiles.contains('resume-${id.name}');
                        return ListTile(
                          title: Text(
                            id.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            id.gender == 'ikhwan' ? "Ikhwan" : "Akhwat",
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                id.allowSignatureReset
                                    ? "Reset Ttd Diizinkan"
                                    : "Izinkan Ganti Ttd",
                                style: TextStyle(
                                  color: id.allowSignatureReset
                                      ? Colors.tealAccent
                                      : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Switch(
                                value: id.allowSignatureReset,
                                activeThumbColor: Colors.tealAccent,
                                onChanged: (val) async {
                                  await ref
                                      .read(firebaseServiceProvider)
                                      .updateSignatureResetPermission(id.name, val);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          val
                                              ? 'Ganti tanda tangan diizinkan untuk ${id.name}!'
                                              : 'Izin ganti tanda tangan dibatalkan untuk ${id.name}!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              if (hasResume) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.download),
                                  label: const Text("Download"),
                                  onPressed: () => _downloadResume(id.name),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: const Text("Upload Resume (PDF)"),
                                onPressed: () =>
                                    _pickAndUploadFile("resume", id.name),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Error: $e")),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  // TAB 3: Rekap Penilaian
  Widget _buildRekapTab(
    AppConfig config,
    AsyncValue<List<Identity>> identitiesAsync,
    AsyncValue<List<RoomQudwahEvaluation>> evaluationsAsync,
    AsyncValue<List<Test>> testsAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weights Editor
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Kebijakan Bobot & Kriteria Kelulusan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _bobotKelasBesar.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Kelas Besar (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) => setState(
                            () =>
                                _bobotKelasBesar = double.tryParse(val) ?? 40.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _bobotRoomQudwah.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Room Qudwah (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) => setState(
                            () =>
                                _bobotRoomQudwah = double.tryParse(val) ?? 40.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _bobotTugas.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Tugas (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) => setState(
                            () => _bobotTugas = double.tryParse(val) ?? 20.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _nilaiMin.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Nilai Minimum Kelulusan',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) => setState(
                            () => _nilaiMin = double.tryParse(val) ?? 75.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rekap Table (Ikhwan and Akhwat tabs)
          identitiesAsync.when(
            data: (idents) {
              final groups = ref.watch(groupsStreamProvider).value ?? [];
              final participantNames = groups
                  .expand((g) => g.participants)
                  .toSet();
              final participantsOnly = idents
                  .where((i) => participantNames.contains(i.name))
                  .toList();

              final ikhwans = participantsOnly
                  .where((i) => i.gender == 'ikhwan')
                  .toList();
              final akhwats = participantsOnly
                  .where((i) => i.gender == 'akhwat')
                  .toList();

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tabel Rekapitulasi Kelulusan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text("Cetak & Tanda Tangani Rekap"),
                        onPressed: () =>
                            _downloadRekapPDF(participantsOnly, [], [], config),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: "Ikhwan (Laki-laki)"),
                            Tab(text: "Akhwat (Perempuan)"),
                          ],
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              _buildParticipantTable(ikhwans),
                              _buildParticipantTable(akhwats),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text("Error: $e"),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTable(List<Identity> participants) {
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text('Nama', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Kelas Besar', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Room Qudwah', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Tugas', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Total Nilai', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Status', style: TextStyle(color: Colors.white)),
          ),
        ],
        rows: participants.map((p) {
          final scores = _calculateParticipantScores(
            participant: p,
            evaluations: evaluations,
            tests: tests,
            attendances: attendances,
            uploadedFiles: uploadedFiles,
          );
          final kelasBesarScore = scores['kelasBesar'] ?? 0.0;
          final roomQudwahScore = scores['roomQudwah'] ?? 0.0;
          final tugasScore = scores['tugas'] ?? 0.0;
          final total = scores['total'] ?? 0.0;
          final isPass = total >= _nilaiMin;

          return DataRow(
            cells: [
              DataCell(
                Text(p.name, style: const TextStyle(color: Colors.white70)),
              ),
              DataCell(
                Text(
                  kelasBesarScore.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              DataCell(
                Text(
                  roomQudwahScore.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              DataCell(
                Text(
                  tugasScore.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              DataCell(
                Text(
                  total.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              DataCell(
                Text(
                  isPass ? "LULUS" : "TIDAK LULUS",
                  style: TextStyle(
                    color: isPass ? Colors.tealAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // TAB 4: Sertifikat
  Widget _buildCertificateTab(
    AppConfig config,
    AsyncValue<List<Identity>> identitiesAsync,
  ) {
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toSet();

    return identitiesAsync.when(
      data: (idents) {
        final participantsOnly = idents
            .where((id) => participantNames.contains(id.name))
            .toList();
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
                itemCount: participantsOnly.length,
                itemBuilder: (context, index) {
                  final id = participantsOnly[index];
                  // Let's assume all pass for demo purposes
                  return ListTile(
                    title: Text(
                      id.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Status Ttd: (Kepsek: ✓, Walikelas: ✓, Kadiv: ✓)",
                      style: TextStyle(color: Colors.white60),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text("Unduh Sertifikat (PDF)"),
                      onPressed: () => _generateCertificatePDF(id, config),
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

  // Generate certificate PDF helper
  Future<void> _generateCertificatePDF(Identity participant, AppConfig config) async {
    final pdf = pw.Document();

    // Load Kop Surat Assets
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

    // Load signature images from base64
    pw.MemoryImage? kepsekSigImage;
    pw.MemoryImage? kadivSigImage;
    pw.MemoryImage? walikelasSigImage;

    // 1. Kepsek
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

    // 2. Kadiv
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

    // Find the walikelas for this participant
    final groups = ref.read(groupsStreamProvider).value ?? [];
    final participantGroup = groups.cast<Group?>().firstWhere(
      (g) => g!.participants.contains(participant.name),
      orElse: () => null,
    );

    // 3. Walikelas
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
                      _sanitizePdfText(participant.name),
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _sanitizePdfText("Telah dinyatakan LULUS dalam program MAI Sektor kepengurusan ${config.kepengurusanTahun}."),
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
                        pw.Text("Kepala Sekolah,", style: const pw.TextStyle(fontSize: 11)),
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
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text("Wali Kelas,", style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        if (walikelasSigImage != null)
                          pw.Container(
                            width: 80,
                            height: 30,
                            child: pw.Image(walikelasSigImage),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _sanitizePdfText(participantGroup?.walikelas ?? "Wali Kelas"),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text("Kepala Divisi MAI,", style: const pw.TextStyle(fontSize: 11)),
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
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
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

  // TAB 5: Kelola Profil Kepala Sekolah & Kelompok Kelas Kecil
  Widget _buildManageProfileAndGroupsTab(
    AppConfig config,
    AsyncValue<List<Identity>> identitiesAsync,
    AsyncValue<List<Group>> groupsAsync,
  ) {
    final firebaseService = ref.read(firebaseServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. MANAGE PROFILE KEPALA SEKOLAH
          identitiesAsync.when(
            data: (idents) {
              final kepsekId = idents.firstWhere(
                (id) =>
                    id.name.toLowerCase() ==
                    config.kepalaSekolahNama.toLowerCase(),
                orElse: () => Identity(name: config.kepalaSekolahNama),
              );

              return Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.tealAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Kelola Profil Kepala Sekolah",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildReadOnlyField(
                              "Nama Kepala Sekolah",
                              kepsekId.name,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildReadOnlyField(
                              "Tahun Kepengurusan",
                              config.kepengurusanTahun,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: kepsekId.whatsapp ?? '',
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Nomor WhatsApp",
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: Colors.tealAccent,
                                ),
                              ),
                              onChanged: (val) async {
                                final updatedId = Identity(
                                  name: kepsekId.name,
                                  gender: kepsekId.gender,
                                  whatsapp: val.trim(),
                                  signatureVector: kepsekId.signatureVector,
                                  faceVector: kepsekId.faceVector,
                                  allowSignatureReset:
                                      kepsekId.allowSignatureReset,
                                );
                                await firebaseService.saveIdentity(updatedId);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Jenis Kelamin",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      selected: kepsekId.gender == 'ikhwan',
                                      label: const Text('Ikhwan'),
                                      selectedColor: Colors.tealAccent,
                                      checkmarkColor: Colors.black,
                                      labelStyle: TextStyle(
                                        color: kepsekId.gender == 'ikhwan'
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                      onSelected: (selected) async {
                                        final updatedId = Identity(
                                          name: kepsekId.name,
                                          gender: 'ikhwan',
                                          whatsapp: kepsekId.whatsapp,
                                          signatureVector:
                                              kepsekId.signatureVector,
                                          faceVector: kepsekId.faceVector,
                                          allowSignatureReset:
                                              kepsekId.allowSignatureReset,
                                        );
                                        await firebaseService.saveIdentity(
                                          updatedId,
                                        );
                                      },
                                    ),
                                    ChoiceChip(
                                      selected: kepsekId.gender == 'akhwat',
                                      label: const Text('Akhwat'),
                                      selectedColor: Colors.tealAccent,
                                      checkmarkColor: Colors.black,
                                      labelStyle: TextStyle(
                                        color: kepsekId.gender == 'akhwat'
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                      onSelected: (selected) async {
                                        final updatedId = Identity(
                                          name: kepsekId.name,
                                          gender: 'akhwat',
                                          whatsapp: kepsekId.whatsapp,
                                          signatureVector:
                                              kepsekId.signatureVector,
                                          faceVector: kepsekId.faceVector,
                                          allowSignatureReset:
                                              kepsekId.allowSignatureReset,
                                        );
                                        await firebaseService.saveIdentity(
                                          updatedId,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            "Status Pemindaian Wajah: ",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            kepsekId.faceVector != null
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: kepsekId.faceVector != null
                                ? Colors.tealAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            kepsekId.faceVector != null
                                ? "Vektor Wajah Aktif"
                                : "Belum Dipindai",
                            style: TextStyle(
                              color: kepsekId.faceVector != null
                                  ? Colors.tealAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error load profile: $e")),
          ),
          const SizedBox(height: 24),

          // 1b. MANAGE PROFILE KEPALA DIVISI MAI
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.tealAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Kelola Profil Kepala Divisi MAI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _kadivController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nama Kepala Divisi MAI",
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: config.kadivNama ?? "Masukkan nama Kadiv...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SignatureUploadWidget(
                    controller: _kadivSigController,
                    title: "Tanda Tangan Kepala Divisi MAI",
                    height: 120,
                    onCleared: () async {
                      await firebaseService.saveConfig(
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
                          kadivSignatureBase64: null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text("SIMPAN PROFIL KADIV"),
                    onPressed: () async {
                      final kadivName = _kadivController.text.trim();
                      if (kadivName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Harap masukkan nama Kepala Divisi MAI!',
                            ),
                          ),
                        );
                        return;
                      }

                      // Save kadivNama to AppConfig
                      String? kadivSigBase64;
                      if (_kadivSigController.value.isNotEmpty) {
                        final sigBytes = await _kadivSigController.toPngBytes();
                        if (sigBytes != null) {
                          kadivSigBase64 =
                              'data:image/png;base64,${base64Encode(sigBytes)}';
                        }
                      }

                      await firebaseService.saveConfig(
                        AppConfig(
                          activeMode: config.activeMode,
                          kepalaSekolahNama: config.kepalaSekolahNama,
                          kepengurusanTahun: config.kepengurusanTahun,
                          bobotKelasBesar: config.bobotKelasBesar,
                          bobotRoomQudwah: config.bobotRoomQudwah,
                          bobotTugas: config.bobotTugas,
                          nilaiMinimum: config.nilaiMinimum,
                          kepsekSignatureBase64: config.kepsekSignatureBase64,
                          kadivNama: kadivName,
                          kadivSignatureBase64: kadivSigBase64,
                        ),
                      );

                      // Save Kadiv identity
                      await firebaseService.saveIdentity(
                        Identity(name: kadivName),
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Profil Kepala Divisi MAI berhasil disimpan!',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. MANAGE SMALL CLASS GROUPS (KELOMPOK KELAS KECIL)
          groupsAsync.when(
            data: (groups) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Setup/Creation tools
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      final addTeacherCard = Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Tambah Walikelas (Guru)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newTeacherController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Nama Guru/Walikelas...",
                                  hintStyle: TextStyle(color: Colors.white30),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text("TAMBAH KELOMPOK"),
                                onPressed: () async {
                                  final name = _newTeacherController.text.trim();
                                  if (name.isNotEmpty) {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await firebaseService.saveGroup(
                                      Group(
                                        walikelas: name,
                                        participants: [],
                                      ),
                                    );
                                    await firebaseService.saveIdentity(
                                      Identity(name: name, gender: 'ikhwan'),
                                    );
                                    _newTeacherController.clear();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Kelompok Walikelas $name berhasil ditambahkan!'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );

                      final addParticipantCard = Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Tambah & Kelompokkan Peserta",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newParticipantController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Nama Peserta Baru...",
                                  hintStyle: TextStyle(color: Colors.white30),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E293B),
                                value: groups.any((g) => g.walikelas == _selectedTeacherForNewParticipant)
                                    ? _selectedTeacherForNewParticipant
                                    : null,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "Pilih Walikelas",
                                  labelStyle: TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                items: groups.map((g) {
                                  return DropdownMenuItem(
                                    value: g.walikelas,
                                    child: Text(g.walikelas),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(
                                  () => _selectedTeacherForNewParticipant = val,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.person_add),
                                label: const Text("TAMBAH PESERTA"),
                                onPressed: () async {
                                  final pName = _newParticipantController.text.trim();
                                  final wName = _selectedTeacherForNewParticipant;
                                  if (pName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Harap masukkan nama peserta!'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (wName == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Harap pilih Walikelas!'),
                                      ),
                                    );
                                    return;
                                  }

                                  final targetGroup = groups.firstWhere(
                                    (g) => g.walikelas == wName,
                                  );
                                  final updatedParticipants =
                                      List<String>.from(targetGroup.participants);
                                  final messenger = ScaffoldMessenger.of(context);
                                  if (!updatedParticipants.contains(pName)) {
                                    updatedParticipants.add(pName);
                                    await firebaseService.saveGroup(
                                      Group(
                                        walikelas: wName,
                                        participants: updatedParticipants,
                                      ),
                                    );
                                    await firebaseService.saveIdentity(
                                      Identity(name: pName),
                                    );
                                  }

                                  _newParticipantController.clear();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Peserta $pName dimasukkan ke kelompok $wName!'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            addTeacherCard,
                            const SizedBox(height: 16),
                            addParticipantCard,
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: addTeacherCard),
                            const SizedBox(width: 16),
                            Expanded(child: addParticipantCard),
                          ],
                        );
                      }
                    },
                  ),
                  const Text(
                    "Daftar Kelompok Kelas Kecil",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Render Group Cards
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.school,
                                          color: Colors.tealAccent,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Kelompok: ${group.walikelas}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Hapus Kelompok?"),
                                          content: Text(
                                            "Apakah Anda yakin ingin menghapus kelompok Walikelas ${group.walikelas}?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text("Batal"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                "Hapus",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await firebaseService.deleteGroup(
                                          group.walikelas,
                                        );
                                        await firebaseService.deleteIdentity(
                                          group.walikelas,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Kelompok ${group.walikelas} berhasil dihapus!',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12),
                              group.participants.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Text(
                                          "Belum ada peserta",
                                          style: TextStyle(
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: group.participants.map((pName) {
                                        return Chip(
                                          label: Text(
                                            pName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.redAccent,
                                          ),
                                          onDeleted: () async {
                                            final updatedParticipants =
                                                List<String>.from(group.participants)..remove(pName);
                                            await firebaseService.saveGroup(
                                              Group(
                                                walikelas: group.walikelas,
                                                participants: updatedParticipants,
                                              ),
                                            );
                                            await firebaseService.deleteIdentity(pName);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Peserta $pName dikeluarkan dari kelompok!'),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error load groups: $e")),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageBiometricsTab(AsyncValue<List<Identity>> identitiesAsync) {
    final firebaseService = ref.read(firebaseServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.fingerprint,
                        color: Colors.tealAccent,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Kelola Kredensial & Biometrik Identitas",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Daftar seluruh identitas (Kepala Sekolah, Wali Kelas, Peserta, Pemateri) yang terdaftar di dalam sistem. Anda dapat memantau dan menghapus vektor wajah atau tanda tangan mereka.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  identitiesAsync.when(
                    data: (idents) {
                      if (idents.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "Belum ada identitas yang terdaftar.",
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;

                          if (isMobile) {
                            // Render mobile list view
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: idents.length,
                              itemBuilder: (context, idx) {
                                final id = idents[idx];
                                return _buildIdentityBiometricsCard(id, firebaseService);
                              },
                            );
                          }

                          // Render desktop table view
                          return Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3), // Nama
                              1: FlexColumnWidth(1.5), // WhatsApp
                              2: FlexColumnWidth(1.2), // Gender
                              3: FlexColumnWidth(2.5), // Face Status
                              4: FlexColumnWidth(2.5), // Sig Status
                            },
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            children: [
                              // Table Header Row
                              TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white12, width: 1),
                                  ),
                                ),
                                children: [
                                  _buildTableHeader("Nama Lengkap"),
                                  _buildTableHeader("WhatsApp"),
                                  _buildTableHeader("Gender"),
                                  _buildTableHeader("Status Wajah"),
                                  _buildTableHeader("Status Ttd"),
                                ],
                              ),
                              // Table Content Rows
                              ...idents.map((id) {
                                final hasFace = id.faceVector != null && id.faceVector!.isNotEmpty;
                                final hasSig = id.signatureVector != null && id.signatureVector!.isNotEmpty;

                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Text(
                                        id.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      id.whatsapp ?? '-',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    Text(
                                      id.gender ?? '-',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    _buildBiometricStatusCell(
                                      hasFace,
                                      "Wajah Aktif",
                                      "Belum Dipindai",
                                      Icons.face,
                                      () async {
                                        final confirm = await _showConfirmDialog(
                                          "Hapus Vektor Wajah?",
                                          "Apakah Anda yakin ingin menghapus vektor wajah untuk ${id.name}?",
                                        );
                                        if (confirm) {
                                          final updated = Identity(
                                            name: id.name,
                                            gender: id.gender,
                                            whatsapp: id.whatsapp,
                                            signatureVector: id.signatureVector,
                                            faceVector: null,
                                            allowSignatureReset: id.allowSignatureReset,
                                          );
                                          await firebaseService.saveIdentity(updated);
                                        }
                                      },
                                    ),
                                    _buildBiometricStatusCell(
                                      hasSig,
                                      "Ttd Terdaftar",
                                      "Belum Ttd",
                                      Icons.gesture,
                                      () async {
                                        final confirm = await _showConfirmDialog(
                                          "Hapus Tanda Tangan?",
                                          "Apakah Anda yakin ingin menghapus tanda tangan untuk ${id.name}?",
                                        );
                                        if (confirm) {
                                          final updated = Identity(
                                            name: id.name,
                                            gender: id.gender,
                                            whatsapp: id.whatsapp,
                                            signatureVector: null,
                                            faceVector: id.faceVector,
                                            allowSignatureReset: id.allowSignatureReset,
                                          );
                                          await firebaseService.saveIdentity(updated);
                                        }
                                      },
                                    ),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          "Gagal memuat identitas: $err",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBiometricStatusCell(
    bool hasData,
    String activeText,
    String inactiveText,
    IconData icon,
    VoidCallback onDelete,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasData ? Icons.check_circle : Icons.error_outline,
          color: hasData ? Colors.tealAccent : Colors.white30,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasData ? activeText : inactiveText,
            style: TextStyle(
              color: hasData ? Colors.tealAccent : Colors.white38,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasData)
          IconButton(
            icon: const Icon(Icons.delete_forever, size: 18),
            color: Colors.redAccent.withValues(alpha: 0.7),
            hoverColor: Colors.redAccent.withValues(alpha: 0.1),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Hapus",
          ),
      ],
    );
  }

  Widget _buildIdentityBiometricsCard(
    Identity id,
    FirebaseService firebaseService,
  ) {
    final hasFace = id.faceVector != null && id.faceVector!.isNotEmpty;
    final hasSig = id.signatureVector != null && id.signatureVector!.isNotEmpty;

    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              id.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            if (id.whatsapp != null || id.gender != null) ...[
              Text(
                "Info: ${id.gender ?? '-'} | WA: ${id.whatsapp ?? '-'}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        hasFace ? Icons.face : Icons.face_retouching_off,
                        color: hasFace ? Colors.tealAccent : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasFace ? "Wajah Aktif" : "Belum Dipindai",
                        style: TextStyle(
                          color: hasFace ? Colors.tealAccent : Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                      if (hasFace) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await _showConfirmDialog(
                              "Hapus Vektor Wajah?",
                              "Apakah Anda yakin ingin menghapus vektor wajah untuk ${id.name}?",
                            );
                            if (confirm) {
                              final updated = Identity(
                                name: id.name,
                                gender: id.gender,
                                whatsapp: id.whatsapp,
                                signatureVector: id.signatureVector,
                                faceVector: null,
                                allowSignatureReset: id.allowSignatureReset,
                              );
                              await firebaseService.saveIdentity(updated);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        hasSig ? Icons.gesture : Icons.draw,
                        color: hasSig ? Colors.tealAccent : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasSig ? "Ttd Terdaftar" : "Belum Ttd",
                        style: TextStyle(
                          color: hasSig ? Colors.tealAccent : Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                      if (hasSig) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await _showConfirmDialog(
                              "Hapus Tanda Tangan?",
                              "Apakah Anda yakin ingin menghapus tanda tangan untuk ${id.name}?",
                            );
                            if (confirm) {
                              final updated = Identity(
                                name: id.name,
                                gender: id.gender,
                                whatsapp: id.whatsapp,
                                signatureVector: null,
                                faceVector: id.faceVector,
                                allowSignatureReset: id.allowSignatureReset,
                              );
                              await firebaseService.saveIdentity(updated);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Widget _buildSignedContractsTab(
    AsyncValue<List<Identity>> identitiesAsync,
    AsyncValue<List<Attendance>> attendanceAsync,
  ) {
    return attendanceAsync.when(
      data: (attendances) {
        final contracts = attendances
            .where((att) => att.role == 'kontrak' && att.signatureBase64 != null)
            .toList();

        if (contracts.isEmpty) {
          return const Center(
            child: Text(
              "Belum ada peserta yang menandatangani Kontrak Belajar.",
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final contract = contracts[index];
            Uint8List? sigBytes;
            try {
              final base64Str = contract.signatureBase64!.split(',').last;
              sigBytes = base64Decode(base64Str);
            } catch (_) {}

            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10),
              ),
              child: ExpansionTile(
                iconColor: Colors.tealAccent,
                collapsedIconColor: Colors.white70,
                title: Text(
                  contract.identityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Ditandatangani pada: ${contract.checkInTime.toLocal().toString().split('.')[0]}",
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "DOKUMEN KONTRAK BELAJAR",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Dengan menandatangani akad kontrak belajar ini, peserta program MAI Sektor berkomitmen penuh untuk:\n"
                            "1. Menghadiri seluruh rangkaian kelas besar (1 & 2) tepat waktu.\n"
                            "2. Hadir secara berkala pada pertemuan Room Qudwah (kelas kecil) setiap minggunya sebanyak 12 pertemuan.\n"
                            "3. Menyelesaikan dan mengumpulkan tugas resume materi perkuliahan tepat waktu sebelum tenggat waktu yang ditentukan.\n"
                            "4. Menjaga adab, tata tertib, dan akhlakul karimah selama berlangsungnya program.\n"
                            "5. Siap menerima konsekuensi penilaian kelulusan sesuai dengan kebijakan kelulusan minimum yang ditetapkan Kepala Sekolah.\n\n"
                            "Demikian kontrak belajar ini dibuat secara sadar tanpa paksaan dari pihak manapun.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  "Peserta,",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                if (sigBytes != null)
                                  Container(
                                    width: 120,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Image.memory(sigBytes, fit: BoxFit.contain),
                                  )
                                else
                                  const SizedBox(height: 50, child: Text("Ttd Tidak Terbaca", style: TextStyle(color: Colors.redAccent))),
                                const SizedBox(height: 8),
                                Text(
                                  contract.identityName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text("Error: $e", style: const TextStyle(color: Colors.white)),
      ),
    );
  }
  Widget _buildTestsTab(String type, AsyncValue<List<Test>> testsAsync) {
    return testsAsync.when(
      data: (tests) {
        final filteredTests = tests.where((t) {
          if (t.type != type) return false;
          if (_testFilterQuery.isEmpty) return true;
          final query = _testFilterQuery.toLowerCase();
          return t.name.toLowerCase().contains(query) ||
              t.materi.toLowerCase().contains(query) ||
              t.pemateri.toLowerCase().contains(query) ||
              t.instruktur.toLowerCase().contains(query);
        }).toList();

        if (filteredTests.isEmpty) {
          return Center(
            child: Text(
              "Belum ada data untuk ${type == 'pre' ? 'Pretest' : 'Posttest'}.",
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: filteredTests.length,
          itemBuilder: (context, index) {
            final test = filteredTests[index];
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10),
              ),
              child: ExpansionTile(
                iconColor: Colors.tealAccent,
                collapsedIconColor: Colors.white70,
                title: Text(
                  test.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Materi: ${test.materi} | Pemateri: ${test.pemateri}",
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Metadata Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Instruktur: ${test.instruktur}",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            if (test.score != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Nilai: ${test.score}",
                                  style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),
                        const Text(
                          "JAWABAN PESERTA:",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Answers details
                        ...test.answers.entries.map((entry) {
                          String questionText = entry.key;
                          if (type == 'pre') {
                            if (entry.key == 'q1_uraian') {
                              questionText = "1. Uraikan Kembali Materi tersebut dengan singkat dan jelas";
                            } else if (entry.key == 'q2_dalil_aqli') {
                              questionText = "2. Sebutkan dalil aqli (Logika) dari materi tersebut";
                            } else if (entry.key == 'q3_dalil_naqli') {
                              questionText = "3. Sebutkan dalil naqli (Al-Qur’an dan Sunnah) dari materi tersebut";
                            } else if (entry.key == 'q4_implementasi') {
                              questionText = "4. Sikap aplikasi atau implementasi yang bisa dilakukan";
                            } else if (entry.key == 'q5_khazanah') {
                              questionText = "5. Khazanah baru yang diperoleh dan rencana strategi";
                            } else if (entry.key == 'rating_pemateri') {
                              questionText = "Penilaian untuk pemateri (1-5)";
                            }
                          } else {
                            if (entry.key == 'q1_pernah_dengar') {
                              questionText = "1. Apakah Antum sudah pernah mendengar materi tersebut?";
                            } else if (entry.key == 'q2_point_penting') {
                              questionText = "2. Point-point penting mengenai materi";
                            } else if (entry.key == 'q3_pentingnya_materi') {
                              questionText = "3. Sejauh apa pentingnya materi tersebut";
                            } else if (entry.key == 'q4_belum_paham') {
                              questionText = "4. Bagian mana dari materi yang belum dipahami";
                            } else if (entry.key == 'q5_kesan_ekspektasi') {
                              questionText = "5. Kesan dan ekspektasi terhadap pemberi materi";
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  questionText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    entry.value.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text("Error: $e", style: const TextStyle(color: Colors.white)),
      ),
    );
  }
  Widget _buildPrePostTestMainTab(AsyncValue<List<Test>> testsAsync) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Cari nama peserta, materi, pemateri, atau instruktur...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.tealAccent),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _testFilterQuery = val;
                });
              },
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: "Pre-Test"),
              Tab(text: "Post-Test"),
            ],
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.tealAccent,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTestsTab('pre', testsAsync),
                _buildTestsTab('post', testsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
