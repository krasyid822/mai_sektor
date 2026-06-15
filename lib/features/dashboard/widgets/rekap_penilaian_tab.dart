import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class RekapPenilaianTab extends ConsumerWidget {
  final AppConfig config;

  const RekapPenilaianTab({super.key, required this.config});

  Widget _buildParticipantTable(WidgetRef ref, List<Identity> participants, DashboardState state, DashboardController controller) {
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nama', style: TextStyle(color: Colors.white))),
          DataColumn(label: Text('Kelas Besar', style: TextStyle(color: Colors.white))),
          DataColumn(label: Text('Room Qudwah', style: TextStyle(color: Colors.white))),
          DataColumn(label: Text('Tugas', style: TextStyle(color: Colors.white))),
          DataColumn(label: Text('Total Nilai', style: TextStyle(color: Colors.white))),
          DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
        ],
        rows: participants.map((p) {
          final scores = controller.calculateParticipantScores(
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
          final isPass = total >= state.nilaiMin;

          return DataRow(
            cells: [
              DataCell(Text(p.name, style: const TextStyle(color: Colors.white70))),
              DataCell(Text(kelasBesarScore.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
              DataCell(Text(roomQudwahScore.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
              DataCell(Text(tugasScore.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
              DataCell(Text(total.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                          initialValue: state.bobotKelasBesar.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Kelas Besar (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) {
                            controller.updateWeights(bobotKelasBesar: double.tryParse(val) ?? 40.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: state.bobotRoomQudwah.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Room Qudwah (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) {
                            controller.updateWeights(bobotRoomQudwah: double.tryParse(val) ?? 40.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: state.bobotTugas.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bobot Tugas (%)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) {
                            controller.updateWeights(bobotTugas: double.tryParse(val) ?? 20.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: state.nilaiMin.toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Nilai Minimum Kelulusan',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (val) {
                            controller.updateWeights(nilaiMin: double.tryParse(val) ?? 75.0);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          identitiesAsync.when(
            data: (idents) {
              final groups = ref.watch(groupsStreamProvider).value ?? [];
              final participantNames = groups.expand((g) => g.participants).toSet();
              final participantsOnly = idents.where((i) => participantNames.contains(i.name)).toList();
              final ikhwans = participantsOnly.where((i) => i.gender == 'ikhwan').toList();
              final akhwats = participantsOnly.where((i) => i.gender == 'akhwat').toList();

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
                        onPressed: () {
                          controller.downloadRekapPDF(
                            participants: participantsOnly,
                            evals: evaluations,
                            tests: tests,
                            config: config,
                          );
                        },
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
                              _buildParticipantTable(ref, ikhwans, state, controller),
                              _buildParticipantTable(ref, akhwats, state, controller),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error: $e")),
          ),
        ],
      ),
    );
  }
}
