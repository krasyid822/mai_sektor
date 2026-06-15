import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class TestsTab extends ConsumerWidget {
  const TestsTab({super.key});

  Widget _buildTestsList(BuildContext context, WidgetRef ref, String type, String filterQuery, List<Test> tests) {
    final filteredTests = tests.where((t) {
      if (t.type != type) return false;
      if (filterQuery.isEmpty) return true;
      final query = filterQuery.toLowerCase();
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final testsAsync = ref.watch(testsStreamProvider);

    return testsAsync.when(
      data: (tests) {
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
                  onChanged: controller.updateTestFilterQuery,
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
                    _buildTestsList(context, ref, 'pre', state.testFilterQuery, tests),
                    _buildTestsList(context, ref, 'post', state.testFilterQuery, tests),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
    );
  }
}
