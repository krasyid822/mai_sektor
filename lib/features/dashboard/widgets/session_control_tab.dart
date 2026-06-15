import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class SessionControlTab extends ConsumerWidget {
  final AppConfig config;

  const SessionControlTab({super.key, required this.config});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toList()..sort();
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];

    final teacherNames = attendances
        .where((att) => att.role == 'guru')
        .map((att) => att.identityName)
        .toSet()
        .toList()
      ..sort();

    final tamuNames = attendances
        .where((att) => att.role == 'tamu')
        .map((att) => att.identityName)
        .toSet()
        .toList()
      ..sort();

    final completedCount = participantNames.where((pName) {
      if (config.activeMode == 'absensi') {
        return attendances.any((att) => att.identityName == pName && att.role == 'peserta');
      } else if (config.activeMode == 'pretest') {
        return tests.any((t) => t.name == pName && t.type == 'pre');
      } else if (config.activeMode == 'posttest') {
        return tests.any((t) => t.name == pName && t.type == 'post');
      } else if (config.activeMode == 'kontrak') {
        return attendances.any((att) => att.identityName == pName && att.role == 'kontrak');
      }
      return false;
    }).length;

    final pendingCount = participantNames.length - completedCount;
    final teacherAttendedCount = teacherNames.where((tName) {
      return attendances.any((att) => att.identityName == tName && att.role == 'guru');
    }).length;
    final tamuAttendedCount = tamuNames.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          children: ['idle', 'absensi', 'pretest', 'posttest', 'kontrak'].map((mode) {
                            final isActive = config.activeMode == mode;
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isActive ? Colors.tealAccent : Colors.white10,
                                foregroundColor: isActive ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => ref.read(firebaseServiceProvider).updateActiveMode(mode),
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
              Expanded(
                flex: 1,
                child: Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.music_note, color: Colors.tealAccent, size: 22),
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
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 28),
                              onPressed: () => controller.skipTrack(false),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                              icon: Icon(
                                state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.tealAccent,
                                size: 44,
                              ),
                              onPressed: controller.togglePlay,
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              icon: const Icon(Icons.skip_next, color: Colors.white70, size: 28),
                              onPressed: () => controller.skipTrack(true),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.volume_up, color: Colors.white54, size: 20),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
                ),
              ),
            ],
          ),
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
                          _buildCounterBadge("Selesai", completedCount, Colors.tealAccent),
                          const SizedBox(width: 8),
                          _buildCounterBadge("Belum Melengkapi", pendingCount, Colors.redAccent),
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
                              isCompleted = attendances.any((att) => att.identityName == pName && att.role == 'peserta');
                            } else if (config.activeMode == 'pretest') {
                              isCompleted = tests.any((t) => t.name == pName && t.type == 'pre');
                            } else if (config.activeMode == 'posttest') {
                              isCompleted = tests.any((t) => t.name == pName && t.type == 'post');
                            } else if (config.activeMode == 'kontrak') {
                              isCompleted = attendances.any((att) => att.identityName == pName && att.role == 'kontrak');
                            }

                            final initials = pName.isNotEmpty ? pName[0].toUpperCase() : "?";

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
                                            ? [const Color(0xFF0D9488), const Color(0xFF14B8A6)]
                                            : [const Color(0xFF334155), const Color(0xFF475569)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: isCompleted ? Colors.tealAccent : Colors.white24,
                                        width: isCompleted ? 3 : 1,
                                      ),
                                      boxShadow: isCompleted
                                          ? [
                                              BoxShadow(
                                                color: Colors.tealAccent.withValues(alpha: 0.4),
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
                                                color: isCompleted ? Colors.white : Colors.white38,
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
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.tealAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.check, size: 12, color: Colors.black),
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
                                        color: isCompleted ? Colors.white : Colors.white38,
                                        fontSize: 12,
                                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
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
                        const Icon(Icons.school, color: Colors.amberAccent, size: 18),
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
                        _buildCounterBadge("Hadir", teacherAttendedCount, Colors.amberAccent),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: teacherNames.map((tName) {
                        final isPresent = attendances.any((att) => att.identityName == tName && att.role == 'guru');
                        final initials = tName.isNotEmpty ? tName[0].toUpperCase() : "?";
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
                                        ? [const Color(0xFFB45309), const Color(0xFFD97706)]
                                        : [const Color(0xFF334155), const Color(0xFF475569)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: isPresent ? Colors.amberAccent : Colors.white24,
                                    width: isPresent ? 3 : 1,
                                  ),
                                  boxShadow: isPresent
                                      ? [
                                          BoxShadow(
                                            color: Colors.amberAccent.withValues(alpha: 0.4),
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
                                      color: isPresent ? Colors.white : Colors.white38,
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
                                    color: isPresent ? Colors.white : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: isPresent ? FontWeight.bold : FontWeight.normal,
                                  ),
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
                        const Icon(Icons.person_pin, color: Colors.purpleAccent, size: 18),
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
                        _buildCounterBadge("Hadir", tamuAttendedCount, Colors.purpleAccent),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: tamuNames.map((tName) {
                        final initials = tName.isNotEmpty ? tName[0].toUpperCase() : "?";
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
                                    colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.purpleAccent, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purpleAccent.withValues(alpha: 0.4),
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
}
