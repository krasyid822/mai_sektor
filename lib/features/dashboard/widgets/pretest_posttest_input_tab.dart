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
  /// Stores score controllers keyed by 'participant|materi|type'
  final Map<String, TextEditingController> _scoreControllers = {};

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _scoreKey(String participant, String materi, String type) =>
      '$participant|$materi|$type';

  void _ensureControllers(List<Test> tests, List<TestScore> existingScores) {
    for (final t in tests) {
      final key = _scoreKey(t.name, t.materi, t.type);
      if (!_scoreControllers.containsKey(key)) {
        _scoreControllers[key] = TextEditingController();
      }
    }
    // Populate existing values
    for (final ts in existingScores) {
      if (ts.pretestScore != null) {
        final preKey = _scoreKey(ts.participantName, ts.materi, 'pre');
        if (_scoreControllers.containsKey(preKey)) {
          _scoreControllers[preKey]!.text = ts.pretestScore!.toStringAsFixed(0);
        }
      }
      if (ts.posttestScore != null) {
        final postKey = _scoreKey(ts.participantName, ts.materi, 'post');
        if (_scoreControllers.containsKey(postKey)) {
          _scoreControllers[postKey]!.text = ts.posttestScore!.toStringAsFixed(
            0,
          );
        }
      }
    }
  }

  Future<void> _saveScore(Test test, String value) async {
    final doubleVal = double.tryParse(value);
    if (doubleVal == null) return;

    // Get existing TestScore for this participant+materi
    final existingScores = await ref
        .read(firebaseServiceProvider)
        .streamTestScores()
        .first;
    final existing = existingScores
        .where(
          (ts) => ts.participantName == test.name && ts.materi == test.materi,
        )
        .firstOrNull;

    final testScore = TestScore(
      participantName: test.name,
      materi: test.materi,
      pretestScore: test.type == 'pre' ? doubleVal : existing?.pretestScore,
      posttestScore: test.type == 'post' ? doubleVal : existing?.posttestScore,
    );
    await ref.read(firebaseServiceProvider).saveTestScore(testScore);
  }

  /// Builds the question label for a given answer key based on test type.
  String _questionLabel(String key, String type) {
    if (type == 'pre') {
      switch (key) {
        case 'q1_pernah_dengar':
          return '1. Apakah Antum sudah pernah mendengar materi tersebut?';
        case 'q2_point_penting':
          return '2. Point-point penting mengenai materi';
        case 'q3_pentingnya_materi':
          return '3. Sejauh apa pentingnya materi tersebut';
        case 'q4_belum_paham':
          return '4. Bagian mana dari materi yang belum dipahami';
        case 'q5_kesan_ekspektasi':
          return '5. Kesan dan ekspektasi terhadap pemberi materi';
        default:
          return key;
      }
    } else {
      switch (key) {
        case 'q1_uraian':
          return '1. Uraikan Kembali Materi tersebut dengan singkat dan jelas';
        case 'q2_dalil_aqli':
          return '2. Sebutkan dalil aqli (Logika) dari materi tersebut';
        case 'q3_dalil_naqli':
          return '3. Sebutkan dalil naqli (Al-Qur\'an dan Sunnah) dari materi tersebut';
        case 'q4_implementasi':
          return '4. Sikap aplikasi atau implementasi yang bisa dilakukan';
        case 'q5_khazanah':
          return '5. Khazanah baru yang diperoleh dan rencana strategi';
        case 'rating_pemateri':
          return 'Penilaian untuk pemateri (1-5)';
        default:
          return key;
      }
    }
  }

  /// Builds the answer display for a single test submission.
  Widget _buildAnswerCard(Test test, TestScore? existingScore) {
    final scoreKey = _scoreKey(test.name, test.materi, test.type);
    final controller = _scoreControllers[scoreKey]!;

    // Pre-fill from existing score
    if (existingScore != null) {
      final existingVal = test.type == 'pre'
          ? existingScore.pretestScore
          : existingScore.posttestScore;
      if (existingVal != null && controller.text.isEmpty) {
        controller.text = existingVal.toStringAsFixed(0);
      }
    }

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
          '${test.type == 'pre' ? 'Pre-Test' : 'Post-Test'} | Materi: ${test.materi}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          'Pemateri: ${test.pemateri}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          'Instruktur: ${test.instruktur}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                const Text(
                  'JAWABAN PESERTA:',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ...test.answers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _questionLabel(entry.key, test.type),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                // Score input section
                Row(
                  children: [
                    const Text(
                      'Nilai (0-100):',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Nilai',
                          hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.tealAccent,
                            ),
                          ),
                        ),
                        onChanged: (val) => _saveScore(test, val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (controller.text.isNotEmpty &&
                        double.tryParse(controller.text) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          controller.text,
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);
    final testScoresAsync = ref.watch(testScoresStreamProvider);
    final testsAsync = ref.watch(testsStreamProvider);

    // Check if any provider is still loading
    final isLoading =
        identitiesAsync.isLoading ||
        groupsAsync.isLoading ||
        testScoresAsync.isLoading ||
        testsAsync.isLoading;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check for errors
    final error =
        identitiesAsync.error ??
        groupsAsync.error ??
        testScoresAsync.error ??
        testsAsync.error;
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }

    // All data available
    final identities = identitiesAsync.value ?? [];
    final groups = groupsAsync.value ?? [];
    final existingScores = testScoresAsync.value ?? [];
    final allTests = testsAsync.value ?? [];

    final participantNames = groups.expand((g) => g.participants).toSet();
    final participantsOnly =
        identities.where((i) => participantNames.contains(i.name)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    // Filter tests to only include registered participants
    final tests = allTests
        .where((t) => participantNames.contains(t.name))
        .toList();

    _ensureControllers(tests, existingScores);

    if (participantsOnly.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada peserta terdaftar.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    if (tests.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada jawaban pretest/posttest yang dikirim peserta.',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    // Group tests by participant name for organized display
    final Map<String, List<Test>> testsByParticipant = {};
    for (final t in tests) {
      testsByParticipant.putIfAbsent(t.name, () => []).add(t);
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
            'Berikut adalah lembar jawaban yang dikirim peserta. '
            'Masukkan nilai (0-100) pada setiap jawaban untuk menilai.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),
          // Group by participant
          ...participantsOnly.map((p) {
            final participantTests = testsByParticipant[p.name] ?? [];
            if (participantTests.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    Identity.displayName(p, participantsOnly),
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...participantTests.map((test) {
                  final existing = existingScores
                      .where(
                        (ts) =>
                            ts.participantName == test.name &&
                            ts.materi == test.materi,
                      )
                      .firstOrNull;
                  return _buildAnswerCard(test, existing);
                }),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}
