import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class SessionControlTab extends ConsumerStatefulWidget {
  final AppConfig config;

  const SessionControlTab({super.key, required this.config});

  @override
  ConsumerState<SessionControlTab> createState() => _SessionControlTabState();
}

class _SessionControlTabState extends ConsumerState<SessionControlTab> {
  double? _currentSliderValue = 1.0;

  @override
  void initState() {
    super.initState();
    _currentSliderValue = _getMateriValue(widget.config.activeMateri);
  }

  @override
  void didUpdateWidget(covariant SessionControlTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.activeMateri != widget.config.activeMateri) {
      setState(() {
        _currentSliderValue = _getMateriValue(widget.config.activeMateri);
      });
    }
  }

  double _getMateriValue(String? materi) {
    if (materi == null) return 1.0;
    switch (materi) {
      case 'Urgensi Membina':
        return 1.0;
      case 'Al Qudwah Qobla Dakwah':
        return 2.0;
      case 'Manajemen Mentoring Aktif':
        return 3.0;
      case 'Seni Menyentuh Hati':
        return 4.0;
      default:
        return 1.0;
    }
  }

  String _getMateriName(int value) {
    switch (value) {
      case 1:
        return 'Urgensi Membina';
      case 2:
        return 'Al Qudwah Qobla Dakwah';
      case 3:
        return 'Manajemen Mentoring Aktif';
      case 4:
        return 'Seni Menyentuh Hati';
      default:
        return '';
    }
  }

  String _getMateriNumber(String materi) {
    switch (materi) {
      case 'Urgensi Membina':
        return '1';
      case 'Al Qudwah Qobla Dakwah':
        return '2';
      case 'Manajemen Mentoring Aktif':
        return '3';
      case 'Seni Menyentuh Hati':
        return '4';
      default:
        return materi;
    }
  }

  bool _isAttendanceCompleted(
    Attendance att,
    String activeMateri,
    String pName,
  ) {
    if (att.identityName != pName || att.role != 'peserta') return false;
    if (activeMateri.isEmpty) return true;

    final group1 = ['Urgensi Membina', 'Al Qudwah Qobla Dakwah'];
    final group2 = ['Manajemen Mentoring Aktif', 'Seni Menyentuh Hati'];

    final attMateri = att.materi ?? '';

    if (group1.contains(activeMateri)) {
      return group1.contains(attMateri) || attMateri.isEmpty;
    } else if (group2.contains(activeMateri)) {
      return group2.contains(attMateri);
    }

    return attMateri == activeMateri || attMateri.isEmpty;
  }

  Widget _buildCounterBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$label: $count",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final sliderVal = _currentSliderValue ?? 1.0;

    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toList()
      ..sort();
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];

    final teacherNames =
        attendances
            .where((att) => att.role == 'guru')
            .map((att) => att.identityName)
            .toSet()
            .toList()
          ..sort();

    final tamuNames =
        attendances
            .where((att) => att.role == 'tamu')
            .map((att) => att.identityName)
            .toSet()
            .toList()
          ..sort();

    final completedCount = participantNames.where((pName) {
      if (config.activeMode == 'absensi') {
        return attendances.any(
          (att) => _isAttendanceCompleted(att, config.activeMateri, pName),
        );
      } else if (config.activeMode == 'pretest') {
        return tests.any(
          (t) =>
              t.name == pName &&
              t.type == 'pre' &&
              (config.activeMateri.isEmpty ||
                  t.materi.toLowerCase() == config.activeMateri.toLowerCase()),
        );
      } else if (config.activeMode == 'posttest') {
        return tests.any(
          (t) =>
              t.name == pName &&
              t.type == 'post' &&
              (config.activeMateri.isEmpty ||
                  t.materi.toLowerCase() == config.activeMateri.toLowerCase()),
        );
      } else if (config.activeMode == 'kontrak') {
        return attendances.any(
          (att) => att.identityName == pName && att.role == 'kontrak',
        );
      }
      return false;
    }).length;

    final pendingCount = participantNames.length - completedCount;
    final teacherAttendedCount = teacherNames.where((tName) {
      return attendances.any(
        (att) => att.identityName == tName && att.role == 'guru',
      );
    }).length;
    final tamuAttendedCount = tamuNames.length;

    final isPortrait = MediaQuery.of(context).size.width < 768;

    final sessionControlCard = Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: Colors.tealAccent.withValues(alpha: 0.15),
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
                if (config.activeMateri.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Text(
                    "Materi: ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getMateriNumber(config.activeMateri),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
              children: ['idle', 'absensi', 'pretest', 'posttest', 'kontrak']
                  .map((mode) {
                    final isActive = config.activeMode == mode;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? Colors.tealAccent
                            : Colors.white10,
                        foregroundColor: isActive ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => ref
                          .read(firebaseServiceProvider)
                          .updateActiveMode(mode),
                      child: Text(mode.toUpperCase()),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pilih Sesi Materi Kelas Besar:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "${sliderVal.round()}",
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.tealAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.tealAccent,
                overlayColor: Colors.tealAccent.withValues(alpha: 0.2),
                valueIndicatorColor: Colors.teal,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                value: sliderVal,
                min: 1.0,
                max: 4.0,
                divisions: 3,
                label: "Sesi ${sliderVal.round()}",
                onChanged: (val) {
                  setState(() {
                    _currentSliderValue = val;
                  });
                },
                onChangeEnd: (val) async {
                  final newMateri = _getMateriName(val.round());
                  await ref
                      .read(firebaseServiceProvider)
                      .saveConfig(
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
                          activeMateri: newMateri,
                          kepalaSekolahNim: config.kepalaSekolahNim,
                          kadivNim: config.kadivNim,
                          kadivIsKepsek: config.kadivIsKepsek,
                        ),
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );

    final audioPlayerCard = Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                    state.currentTrack,
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
                  onPressed: () => controller.skipTrack(false),
                ),
                const SizedBox(width: 12),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 52,
                    minHeight: 52,
                  ),
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.tealAccent,
                    size: 44,
                  ),
                  onPressed: controller.togglePlay,
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
                  onPressed: () => controller.skipTrack(true),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.volume_up, color: Colors.white54, size: 20),
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
                      value: state.volume,
                      activeColor: Colors.tealAccent,
                      onChanged: controller.updateVolume,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPortrait) ...[
            sessionControlCard,
            const SizedBox(height: 16),
            audioPlayerCard,
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: sessionControlCard),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: audioPlayerCard),
              ],
            ),
          ],
          const SizedBox(height: 24),

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
                  isPortrait
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Wayground Live Status Sesi",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildCounterBadge(
                                  "Selesai",
                                  completedCount,
                                  Colors.tealAccent,
                                ),
                                _buildCounterBadge(
                                  "Belum Melengkapi",
                                  pendingCount,
                                  Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
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
                            bool isCompleted = false;
                            if (config.activeMode == 'absensi') {
                              isCompleted = attendances.any(
                                (att) => _isAttendanceCompleted(
                                  att,
                                  config.activeMateri,
                                  pName,
                                ),
                              );
                            } else if (config.activeMode == 'pretest') {
                              isCompleted = tests.any(
                                (t) =>
                                    t.name == pName &&
                                    t.type == 'pre' &&
                                    (config.activeMateri.isEmpty ||
                                        t.materi.toLowerCase() ==
                                            config.activeMateri.toLowerCase()),
                              );
                            } else if (config.activeMode == 'posttest') {
                              isCompleted = tests.any(
                                (t) =>
                                    t.name == pName &&
                                    t.type == 'post' &&
                                    (config.activeMateri.isEmpty ||
                                        t.materi.toLowerCase() ==
                                            config.activeMateri.toLowerCase()),
                              );
                            } else if (config.activeMode == 'kontrak') {
                              isCompleted = attendances.any(
                                (att) =>
                                    att.identityName == pName &&
                                    att.role == 'kontrak',
                              );
                            }

                            final group1 = [
                              'Urgensi Membina',
                              'Al Qudwah Qobla Dakwah',
                            ];
                            final group2 = [
                              'Manajemen Mentoring Aktif',
                              'Seni Menyentuh Hati',
                            ];
                            final activeMateri = config.activeMateri;
                            final isGroup1 = group1.contains(activeMateri);
                            final isGroup2 = group2.contains(activeMateri);

                            final absenceRecord = attendances
                                .cast<Attendance?>()
                                .firstWhere((att) {
                                  if (att == null) return false;
                                  if (att.identityName != pName ||
                                      att.role != 'tidak_hadir') {
                                    return false;
                                  }
                                  final attMateri = att.materi ?? '';
                                  if (isGroup1 &&
                                      (group1.contains(attMateri) ||
                                          attMateri.isEmpty)) {
                                    return true;
                                  } else if (isGroup2 &&
                                      group2.contains(attMateri)) {
                                    return true;
                                  } else if (!isGroup1 &&
                                      !isGroup2 &&
                                      attMateri == activeMateri) {
                                    return true;
                                  }
                                  return false;
                                }, orElse: () => null);

                            final initials = pName.isNotEmpty
                                ? pName[0].toUpperCase()
                                : "?";

                            return GestureDetector(
                              onTap: () async {
                                final textCtrl = TextEditingController(
                                  text: absenceRecord?.errorReport ?? '',
                                );
                                final reason = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      absenceRecord == null
                                          ? "Tambah Keterangan Tidak Hadir"
                                          : "Ubah Keterangan Tidak Hadir",
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Nama Peserta: $pName",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: textCtrl,
                                          decoration: const InputDecoration(
                                            labelText:
                                                "Alasan Ketidakhadiran / Keterangan",
                                            hintText:
                                                "Sakit, Izin (Ada keperluan keluarga), dll.",
                                            border: OutlineInputBorder(),
                                          ),
                                          maxLines: 3,
                                          autofocus: true,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      if (absenceRecord != null)
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, '__DELETE__'),
                                          child: const Text(
                                            "Hapus Alasan",
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("Batal"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          ctx,
                                          textCtrl.text.trim(),
                                        ),
                                        child: const Text("Simpan"),
                                      ),
                                    ],
                                  ),
                                );

                                if (reason != null) {
                                  final firestore = ref.read(firestoreProvider);
                                  if (reason == '__DELETE__') {
                                    if (absenceRecord != null) {
                                      await firestore
                                          .collection('attendance')
                                          .doc(absenceRecord.id)
                                          .delete();
                                    }
                                  } else if (reason.isNotEmpty) {
                                    if (absenceRecord != null) {
                                      await firestore
                                          .collection('attendance')
                                          .doc(absenceRecord.id)
                                          .update({'errorReport': reason});
                                    } else {
                                      final att = Attendance(
                                        id: '',
                                        identityName: pName,
                                        role: 'tidak_hadir',
                                        checkInTime: DateTime.now(),
                                        materi: config.activeMateri,
                                        errorReport: reason,
                                      );
                                      await ref
                                          .read(firebaseServiceProvider)
                                          .addAttendance(att);
                                    }
                                  }
                                }
                              },
                              child: Tooltip(
                                message: absenceRecord != null
                                    ? "$pName (Ket: ${absenceRecord.errorReport})"
                                    : pName,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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
                                              : (absenceRecord != null
                                                    ? [
                                                        const Color(0xFF7C2D12),
                                                        const Color(0xFF9A3412),
                                                      ] // dark orange-red gradient for absent with reason
                                                    : [
                                                        const Color(0xFF334155),
                                                        const Color(0xFF475569),
                                                      ]),
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: isCompleted
                                              ? Colors.tealAccent
                                              : (absenceRecord != null
                                                    ? Colors.orangeAccent
                                                    : Colors.white24),
                                          width:
                                              (isCompleted ||
                                                  absenceRecord != null)
                                              ? 3
                                              : 1,
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
                                            : (absenceRecord != null
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors
                                                            .orangeAccent
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        blurRadius: 12,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ]
                                                  : []),
                                      ),
                                      child: Center(
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  color:
                                                      (isCompleted ||
                                                          absenceRecord != null)
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
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            Colors.tealAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    size: 12,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              )
                                            else if (absenceRecord != null)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            Colors.orangeAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.info_outline,
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
                                    RunningText(
                                      text: pName,
                                      width: 80,
                                      style: TextStyle(
                                        color: isCompleted
                                            ? Colors.white
                                            : (absenceRecord != null
                                                  ? Colors.orangeAccent
                                                  : Colors.white38),
                                        fontSize: 12,
                                        fontWeight:
                                            (isCompleted ||
                                                absenceRecord != null)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
                              RunningText(
                                text: tName,
                                width: 72,
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
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                              RunningText(
                                text: tName,
                                width: 72,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
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
}

class RunningText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double width;

  const RunningText({
    super.key,
    required this.text,
    required this.style,
    required this.width,
  });

  @override
  State<RunningText> createState() => _RunningTextState();
}

class _RunningTextState extends State<RunningText> {
  late ScrollController _scrollController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
  }

  void _checkScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _shouldScroll = true;
        });
        _startScroll();
      }
    }
  }

  Future<void> _startScroll() async {
    while (_shouldScroll && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;
      final maxScroll = _scrollController.position.maxScrollExtent;

      // Scroll to end
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 40).round() + 1200),
        curve: Curves.linear,
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      // Scroll back to start
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (maxScroll * 40).round() + 1200),
        curve: Curves.linear,
      );
    }
  }

  @override
  void didUpdateWidget(covariant RunningText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _shouldScroll = false;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScroll();
      });
    }
  }

  @override
  void dispose() {
    _shouldScroll = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.style.fontSize != null ? widget.style.fontSize! * 1.6 : 20,
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(widget.text, style: widget.style, maxLines: 1),
        ),
      ),
    );
  }
}
