import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';

/// The 4 materi (Kelas Besar 1: materi 1-2, Kelas Besar 2: materi 3-4)
const List<String> kMateriList = [
  'Urgensi Membina',
  'Al Qudwah Qobla Dakwah',
  'Manajemen Mentoring Aktif',
  'Seni Menyentuh Hati',
];

class PretestPosttestInputTab extends ConsumerStatefulWidget {
  const PretestPosttestInputTab({super.key});

  @override
  ConsumerState<PretestPosttestInputTab> createState() =>
      _PretestPosttestInputTabState();
}

class _PretestPosttestInputTabState
    extends ConsumerState<PretestPosttestInputTab> {
  final Map<String, TextEditingController> _preControllers = {};
  final Map<String, TextEditingController> _postControllers = {};

  @override
  void dispose() {
    for (final c in _preControllers.values) {
      c.dispose();
    }
    for (final c in _postControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(String participant, String materi) => '$participant|$materi';

  void _ensureControllers(
    List<Identity> participants,
    List<TestScore> existingScores,
  ) {
    for (final p in participants) {
      for (final materi in kMateriList) {
        final key = _key(p.name, materi);
        if (!_preControllers.containsKey(key)) {
          _preControllers[key] = TextEditingController();
        }
        if (!_postControllers.containsKey(key)) {
          _postControllers[key] = TextEditingController();
        }
      }
    }
    // Populate existing values
    for (final ts in existingScores) {
      final key = _key(ts.participantName, ts.materi);
      if (_preControllers.containsKey(key) && ts.pretestScore != null) {
        _preControllers[key]!.text = ts.pretestScore!.toStringAsFixed(0);
      }
      if (_postControllers.containsKey(key) && ts.posttestScore != null) {
        _postControllers[key]!.text = ts.posttestScore!.toStringAsFixed(0);
      }
    }
  }

  Future<void> _saveScore(
    String participantName,
    String materi,
    double? pretestScore,
    double? posttestScore,
  ) async {
    final testScore = TestScore(
      participantName: participantName,
      materi: materi,
      pretestScore: pretestScore,
      posttestScore: posttestScore,
    );
    await ref.read(firebaseServiceProvider).saveTestScore(testScore);
  }

  @override
  Widget build(BuildContext context) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);
    final testScoresAsync = ref.watch(testScoresStreamProvider);

    return testScoresAsync.when(
      data: (existingScores) {
        return identitiesAsync.when(
          data: (idents) {
            return groupsAsync.when(
              data: (groups) {
                final participantNames = groups
                    .expand((g) => g.participants)
                    .toSet();
                final participantsOnly =
                    idents
                        .where((i) => participantNames.contains(i.name))
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));

                _ensureControllers(participantsOnly, existingScores);

                if (participantsOnly.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada peserta terdaftar.',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Input Nilai Pre-Test & Post-Test',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masukkan nilai (0-100) untuk setiap peserta pada setiap materi. '
                        'Nilai ini akan digunakan dalam perhitungan nilai Kelas Besar.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Colors.white.withValues(alpha: 0.05),
                            ),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 72,
                            columnSpacing: 16,
                            columns: [
                              const DataColumn(
                                label: Text(
                                  'Peserta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // 4 materi × 2 columns (Pre, Post) = 8 columns
                              ...kMateriList.expand(
                                (m) => [
                                  DataColumn(
                                    label: Text(
                                      '$m\n(Pre)',
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '$m\n(Post)',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            rows: participantsOnly.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 4 materi × 2 input fields
                                  ...kMateriList.expand((m) {
                                    final key = _key(p.name, m);
                                    return [
                                      DataCell(
                                        _buildScoreField(
                                          controller: _preControllers[key]!,
                                          hint: 'Pre',
                                          onSaved: (val) {
                                            final doubleVal = double.tryParse(
                                              val,
                                            );
                                            final existing = existingScores
                                                .where(
                                                  (ts) =>
                                                      ts.participantName ==
                                                          p.name &&
                                                      ts.materi == m,
                                                )
                                                .firstOrNull;
                                            _saveScore(
                                              p.name,
                                              m,
                                              doubleVal,
                                              existing?.posttestScore,
                                            );
                                          },
                                        ),
                                      ),
                                      DataCell(
                                        _buildScoreField(
                                          controller: _postControllers[key]!,
                                          hint: 'Post',
                                          onSaved: (val) {
                                            final doubleVal = double.tryParse(
                                              val,
                                            );
                                            final existing = existingScores
                                                .where(
                                                  (ts) =>
                                                      ts.participantName ==
                                                          p.name &&
                                                      ts.materi == m,
                                                )
                                                .firstOrNull;
                                            _saveScore(
                                              p.name,
                                              m,
                                              existing?.pretestScore,
                                              doubleVal,
                                            );
                                          },
                                        ),
                                      ),
                                    ];
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildScoreField({
    required TextEditingController controller,
    required String hint,
    required void Function(String) onSaved,
  }) {
    return SizedBox(
      width: 60,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.tealAccent),
          ),
        ),
        onChanged: onSaved,
      ),
    );
  }
}
