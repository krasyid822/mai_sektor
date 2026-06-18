import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class RekapPenilaianTab extends ConsumerStatefulWidget {
  final AppConfig config;

  const RekapPenilaianTab({super.key, required this.config});

  @override
  ConsumerState<RekapPenilaianTab> createState() => _RekapPenilaianTabState();
}

class _RekapPenilaianTabState extends ConsumerState<RekapPenilaianTab> {
  int _activeSubTabIndex = 0; // 0: Ringkasan Kelulusan, 1: Detail Qudwah, 2: Tugas Resume
  String _qudwahSearchQuery = '';
  String _qudwahWalikelasSearchQuery = '';

  // For Resume Score inputs
  final Map<String, TextEditingController> _resumeScoreControllers = {};

  @override
  void dispose() {
    for (final c in _resumeScoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showEditTugasScoreDialog(
    BuildContext context,
    WidgetRef ref,
    Identity participant,
    double currentScore,
  ) {
    final controller = TextEditingController(
      text: currentScore.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Nilai Tugas: ${participant.name}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Nilai Tugas (0 - 100)",
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              final newScore = double.tryParse(controller.text) ?? 0.0;
              await ref
                  .read(firebaseServiceProvider)
                  .saveResumeScore(participant.name, newScore);
              
              // Sync the local text controller if it exists in Sub-tab 3
              if (_resumeScoreControllers.containsKey(participant.name)) {
                _resumeScoreControllers[participant.name]?.text = newScore.toStringAsFixed(0);
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Berhasil menyimpan nilai tugas untuk ${participant.name}!",
                    ),
                  ),
                );
              }
            },
            child: const Text(
              "Simpan",
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBobotTotalIndicator(DashboardState state) {
    final totalBobot =
        state.bobotKelasBesar + state.bobotRoomQudwah + state.bobotTugas;
    final isCorrect = (totalBobot - 100.0).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.teal.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? Colors.tealAccent : Colors.orangeAccent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 18,
            color: isCorrect ? Colors.tealAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          Text(
            "Total Bobot: ${totalBobot.toStringAsFixed(1)}%",
            style: TextStyle(
              color: isCorrect ? Colors.tealAccent : Colors.orangeAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (!isCorrect) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                totalBobot < 100.0
                    ? "(Kurang dari 100%! Periksa kembali bobot)"
                    : "(Lebih dari 100%! Periksa kembali bobot)",
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantTable(
    BuildContext context,
    WidgetRef ref,
    List<Identity> participants,
    DashboardState state,
    DashboardController controller,
  ) {
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final attendances = ref.watch(attendanceStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];
    final resumeScores = ref.watch(resumeScoresStreamProvider).value ?? {};
    final testScores = ref.watch(testScoresStreamProvider).value ?? [];

    if (participants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada peserta.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
          columnWidths: const {
            0: FixedColumnWidth(160),
            1: FixedColumnWidth(60),
            2: FixedColumnWidth(60),
            3: FixedColumnWidth(60),
            4: FixedColumnWidth(60),
            5: FixedColumnWidth(100),
            6: FixedColumnWidth(80),
            7: FixedColumnWidth(70),
            8: FixedColumnWidth(90),
          },
          children: [
            // --- Header Row 1: Group headers ---
            TableRow(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
              ),
              children: [
                _headerCell('Nama'),
                _groupHeaderCell('Kelas Besar', colspan: 4),
                _headerCell('Room Qudwah'),
                _headerCell('Tugas'),
                _headerCell('Total'),
                _headerCell('Status'),
              ],
            ),
            // --- Header Row 2: Sub-columns ---
            TableRow(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
              ),
              children: [
                const SizedBox.shrink(), // empty under Nama
                _subHeaderCell('1'),
                _subHeaderCell('2'),
                _subHeaderCell('3'),
                _subHeaderCell('4'),
                const SizedBox.shrink(), // empty under Room Qudwah
                const SizedBox.shrink(), // empty under Tugas
                const SizedBox.shrink(), // empty under Total
                const SizedBox.shrink(), // empty under Status
              ],
            ),
            // --- Data rows ---
            ...participants.map((p) {
              final scores = controller.calculateParticipantScores(
                participant: p,
                evaluations: evaluations,
                tests: tests,
                attendances: attendances,
                uploadedFiles: uploadedFiles,
                resumeScores: resumeScores,
                testScores: testScores,
                config: widget.config,
              );
              final m1 = scores['materi_Urgensi Membina'] ?? 0.0;
              final m2 = scores['materi_Al Qudwah Qobla Dakwah'] ?? 0.0;
              final m3 = scores['materi_Manajemen Mentoring Aktif'] ?? 0.0;
              final m4 = scores['materi_Seni Menyentuh Hati'] ?? 0.0;
              final roomQudwahScore = scores['roomQudwah'] ?? 0.0;
              final tugasScore = scores['tugas'] ?? 0.0;
              final total = scores['total'] ?? 0.0;
              final isPass = total >= widget.config.nilaiMinimum;

              return TableRow(
                children: [
                  _dataCell(
                    Identity.displayName(p, participants),
                    maxWidth: 160,
                  ),
                  _materiCell(m1),
                  _materiCell(m2),
                  _materiCell(m3),
                  _materiCell(m4),
                  _dataCell(roomQudwahScore.toStringAsFixed(0)),
                  _tugasCell(context, ref, p, tugasScore),
                  _dataCell(total.toStringAsFixed(1)),
                  _statusCell(isPass),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _groupHeaderCell(String label, {int colspan = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _subHeaderCell(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white10, width: 0.5),
          right: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _dataCell(String text, {double? maxWidth}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      child: maxWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _materiCell(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white10, width: 0.5),
          right: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Text(
        score.toStringAsFixed(0),
        style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
      ),
    );
  }

  Widget _tugasCell(
    BuildContext context,
    WidgetRef ref,
    Identity participant,
    double tugasScore,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      alignment: Alignment.center,
      child: InkWell(
        onTap: () {
          _showEditTugasScoreDialog(context, ref, participant, tugasScore);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tugasScore.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.tealAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 12, color: Colors.tealAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCell(bool isPass) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPass
              ? Colors.teal.withValues(alpha: 0.15)
              : Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isPass ? "LULUS" : "TIDAK LULUS",
          style: TextStyle(
            color: isPass ? Colors.tealAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildQudwahDetailSubTab(
    BuildContext context,
    List<RoomQudwahEvaluation> evaluations,
  ) {
    final filteredEvals = evaluations.where((e) {
      final matchPeserta = e.peserta.toLowerCase().contains(_qudwahSearchQuery.toLowerCase());
      final matchWali = e.walikelas.toLowerCase().contains(_qudwahWalikelasSearchQuery.toLowerCase());
      return matchPeserta && matchWali;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Daftar Detail Evaluasi Room Qudwah",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Filter Row
        Row(
          children: [
            Expanded(
              child: TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Cari Nama Peserta',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                ),
                onChanged: (val) {
                  setState(() {
                    _qudwahSearchQuery = val;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Cari Wali Kelas',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.person, color: Colors.white70),
                ),
                onChanged: (val) {
                  setState(() {
                    _qudwahWalikelasSearchQuery = val;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredEvals.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada data evaluasi Room Qudwah.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
              columnWidths: const {
                0: FixedColumnWidth(150),
                1: FixedColumnWidth(150),
                2: FixedColumnWidth(100),
                3: FixedColumnWidth(180),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(100),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  children: [
                    _headerCell('Peserta'),
                    _headerCell('Wali Kelas'),
                    _headerCell('Pertemuan'),
                    _headerCell('Materi Syllabus'),
                    _headerCell('Rerata'),
                    _headerCell('Aksi'),
                  ],
                ),
                ...filteredEvals.map((e) {
                  final avgScore = e.scores.isNotEmpty
                      ? e.scores.values.reduce((a, b) => a + b) / e.scores.length
                      : 0.0;
                  return TableRow(
                    children: [
                      _dataCell(e.peserta),
                      _dataCell(e.walikelas),
                      _dataCell('Pertemuan ${e.pertemuanKe}'),
                      _dataCell(e.materi),
                      _dataCell(avgScore.toStringAsFixed(1)),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        child: IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.tealAccent, size: 20),
                          onPressed: () {
                            _showEvaluationDetailsDialog(context, e);
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  void _showEvaluationDetailsDialog(BuildContext context, RoomQudwahEvaluation eval) {
    final avgScore = eval.scores.isNotEmpty
        ? eval.scores.values.reduce((a, b) => a + b) / eval.scores.length
        : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Detail Evaluasi Room Qudwah",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Metadata block
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Peserta:", style: TextStyle(color: Colors.white70)),
                          Text(eval.peserta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Wali Kelas:", style: TextStyle(color: Colors.white70)),
                          Text(eval.walikelas, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pertemuan / Materi:", style: TextStyle(color: Colors.white70)),
                          Text("Pertemuan ${eval.pertemuanKe} / ${eval.materi}", style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Nilai Rerata:", style: TextStyle(color: Colors.white70)),
                          Text(avgScore.toStringAsFixed(1), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Rincian 14 Kriteria Penilaian",
                  style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FixedColumnWidth(60),
                    2: FlexColumnWidth(4),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03)),
                      children: [
                        Padding(padding: const EdgeInsets.all(6), child: Text("Kriteria", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(6), child: Text("Skor", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(6), child: Text("Catatan", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ...eval.scores.keys.map((k) {
                      final score = eval.scores[k] ?? 0;
                      final comment = eval.comments[k] ?? '-';
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(k, style: const TextStyle(color: Colors.white, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(score.toString(), style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Padding(padding: const EdgeInsets.all(6), child: Text(comment, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Tanda Tangan Wali Kelas",
                  style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.all(8),
                    height: 120,
                    width: 250,
                    child: _buildSignatureImage(eval.signatureBase64),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String sigData) {
    try {
      if (sigData.startsWith('data:image/png;base64,')) {
        final base64Str = sigData.substring('data:image/png;base64,'.length);
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(bytes, height: 100, fit: BoxFit.contain);
      }
      return Image.network(
        sigData,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }

  Widget _buildResumeDetailSubTab(
    BuildContext context,
    WidgetRef ref,
    List<Identity> participants,
    List<String> uploadedFiles,
    Map<String, double> resumeScores,
  ) {
    if (participants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada peserta.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Detail Unggahan & Input Nilai Tugas Resume",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Catatan: Jika berkas resume (PDF/TXT) sudah diunggah, nilai default adalah 100. Anda dapat menyesuaikan nilai di bawah ini secara manual. Tekan tombol Simpan di sebelah kanan setelah mengubah nilai.",
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
            columnWidths: const {
              0: FixedColumnWidth(150),
              1: FixedColumnWidth(140),
              2: FixedColumnWidth(140),
              3: FixedColumnWidth(140),
              4: FixedColumnWidth(100),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                children: [
                  _headerCell('Nama Peserta'),
                  _headerCell('Status Resume (PDF)'),
                  _headerCell('Status Retyping (TXT)'),
                  _headerCell('Nilai Tugas'),
                  _headerCell('Aksi'),
                ],
              ),
              ...participants.map((p) {
                final hasResumePdf = uploadedFiles.contains('resume-${p.name}');
                final hasResumeTxt = uploadedFiles.contains('retyping-${p.name}');
                final hasResumeAny = hasResumePdf || hasResumeTxt;
                final customScore = resumeScores[p.name];
                final currentScore = customScore ?? (hasResumeAny ? 100.0 : 0.0);

                if (!_resumeScoreControllers.containsKey(p.name)) {
                  _resumeScoreControllers[p.name] = TextEditingController(
                    text: currentScore.toStringAsFixed(0),
                  );
                }

                return TableRow(
                  children: [
                    _dataCell(p.name),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Icon(
                        hasResumePdf ? Icons.check_circle : Icons.cancel,
                        color: hasResumePdf ? Colors.tealAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Icon(
                        hasResumeTxt ? Icons.check_circle : Icons.cancel,
                        color: hasResumeTxt ? Colors.tealAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: TextFormField(
                        controller: _resumeScoreControllers[p.name],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: IconButton(
                        icon: const Icon(Icons.save, color: Colors.tealAccent),
                        onPressed: () async {
                          final textVal = _resumeScoreControllers[p.name]?.text ?? '';
                          final score = double.tryParse(textVal) ?? 0.0;
                          await ref
                              .read(firebaseServiceProvider)
                              .saveResumeScore(p.name, score);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Berhasil menyimpan nilai untuk ${p.name}!"),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isActive = _activeSubTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeSubTabIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.tealAccent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.tealAccent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.tealAccent : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.tealAccent : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final evaluations = ref.watch(evaluationsStreamProvider).value ?? [];
    final tests = ref.watch(testsStreamProvider).value ?? [];
    final testScores = ref.watch(testScoresStreamProvider).value ?? [];
    final uploadedFiles = ref.watch(filesStreamProvider).value ?? [];
    final resumeScores = ref.watch(resumeScoresStreamProvider).value ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-Tab Navigation Header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildSubTabButton(0, "Ringkasan Kelulusan", Icons.analytics_outlined),
                const SizedBox(width: 8),
                _buildSubTabButton(1, "Detail Evaluasi Room Qudwah", Icons.people_outline),
                const SizedBox(width: 8),
                _buildSubTabButton(2, "Detail & Input Tugas Resume", Icons.assignment_outlined),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Render active subtab
          if (_activeSubTabIndex == 0) ...[
            // --- Bobot & Kriteria Card ---
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                    // Wrap agar responsif di layar kecil
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 160,
                          child: TextFormField(
                            key: ValueKey('bobotKelasBesar_${state.bobotKelasBesar}'),
                            initialValue: state.bobotKelasBesar.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Kelas Besar (%)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            onChanged: (val) {
                              controller.updateLocalWeights(
                                bobotKelasBesar: double.tryParse(val) ?? 0.0,
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextFormField(
                            key: ValueKey('bobotRoomQudwah_${state.bobotRoomQudwah}'),
                            initialValue: state.bobotRoomQudwah.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Room Qudwah (%)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            onChanged: (val) {
                              controller.updateLocalWeights(
                                bobotRoomQudwah: double.tryParse(val) ?? 0.0,
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextFormField(
                            key: ValueKey('bobotTugas_${state.bobotTugas}'),
                            initialValue: state.bobotTugas.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Tugas (%)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            onChanged: (val) {
                              controller.updateLocalWeights(
                                bobotTugas: double.tryParse(val) ?? 0.0,
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextFormField(
                            key: ValueKey('nilaiMin_${state.nilaiMin}'),
                            initialValue: state.nilaiMin.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Nilai Minimum',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            onChanged: (val) {
                              controller.updateLocalWeights(
                                nilaiMin: double.tryParse(val) ?? 0.0,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Total bobot checker
                    _buildBobotTotalIndicator(state),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final totalBobot = state.bobotKelasBesar +
                            state.bobotRoomQudwah +
                            state.bobotTugas;
                        if ((totalBobot - 100.0).abs() > 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Error: Total bobot harus 100% sebelum dapat disimpan!",
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Simpan Kebijakan Nilai"),
                            content: const Text(
                              "Apakah Anda yakin ingin memperbarui kebijakan bobot nilai dan nilai minimum kelulusan?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Batal"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  "Simpan",
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await controller.saveWeightsToFirestore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Kebijakan nilai berhasil disimpan!"),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text("Simpan Perubahan"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header: Wrap agar tidak overflow ---
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "Tabel Rekapitulasi Kelulusan",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.config.rekapSigned
                                    ? Colors.teal.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.config.rekapSigned
                                      ? Colors.tealAccent
                                      : Colors.orangeAccent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.config.rekapSigned
                                    ? "SUDAH DITANDATANGANI"
                                    : "BELUM DITANDATANGANI",
                                style: TextStyle(
                                  color: widget.config.rekapSigned
                                      ? Colors.tealAccent
                                      : Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // --- Tombol Aksi ---
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Tombol Cetak / Lihat PDF — selalu tersedia
                            OutlinedButton.icon(
                              icon: const Icon(Icons.print_outlined, size: 16),
                              label: const Text("Cetak / Lihat Rekap"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                              ),
                              onPressed: () {
                                controller.downloadRekapPDF(
                                  participants: participantsOnly,
                                  evals: evaluations,
                                  tests: tests,
                                  config: widget.config,
                                  testScores: testScores,
                                );
                              },
                            ),

                            if (!widget.config.rekapSigned)
                              // Tombol Tanda Tangani — hanya jika belum teken
                              ElevatedButton.icon(
                                icon: const Icon(Icons.draw_outlined, size: 16),
                                label: const Text("Tanda Tangani Rekap"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                        "Tanda Tangani Rekap Penilaian?",
                                      ),
                                      content: const Text(
                                        "Pastikan Anda sudah melihat dan memeriksa rekap nilai sebelum menandatanganinya.\n\n"
                                        "Dengan menandatangani, Anda menyetujui rekapitulasi ini dan sertifikat kelulusan "
                                        "akan diterbitkan bagi peserta yang memenuhi nilai minimum.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.tealAccent,
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("Ya, Tanda Tangani"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await ref
                                        .read(firebaseServiceProvider)
                                        .updateRekapSigned(true);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Rekap penilaian berhasil ditandatangani!',
                                          ),
                                          backgroundColor: Colors.teal,
                                        ),
                                      );
                                    }
                                  }
                                },
                              )
                            else
                              // Tombol Batalkan Tanda Tangan — jika sudah teken
                              OutlinedButton.icon(
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text("Batalkan Tanda Tangan"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Batalkan Tanda Tangan?"),
                                      content: const Text(
                                        "Tanda tangan pada rekap penilaian akan dibatalkan.\n\n"
                                        "Sertifikat peserta tidak akan bisa diunduh sampai rekap ditandatangani kembali.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Tidak"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("Ya, Batalkan"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await ref
                                        .read(firebaseServiceProvider)
                                        .updateRekapSigned(false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Tanda tangan rekap berhasil dibatalkan.',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "Kebijakan Aktif - Kelas Besar: ${widget.config.bobotKelasBesar.toStringAsFixed(1)}%, "
                        "Room Qudwah: ${widget.config.bobotRoomQudwah.toStringAsFixed(1)}%, "
                        "Tugas: ${widget.config.bobotTugas.toStringAsFixed(1)}% | "
                        "Nilai Minimum Kelulusan: ${widget.config.nilaiMinimum.toStringAsFixed(1)}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Tab Ikhwan / Akhwat ---
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: "Ikhwan (Laki-laki)"),
                              Tab(text: "Akhwat (Perempuan)"),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Tinggi dinamis: 56px per row + 56px header, max 15 rows
                          SizedBox(
                            height: () {
                              final maxRows = [
                                ikhwans.length,
                                akhwats.length,
                              ].reduce((a, b) => a > b ? a : b);
                              final rows = maxRows.clamp(1, 15);
                              return 56.0 + (rows * 60.0);
                            }(),
                            child: TabBarView(
                              children: [
                                _buildParticipantTable(
                                  context,
                                  ref,
                                  ikhwans,
                                  state,
                                  controller,
                                ),
                                _buildParticipantTable(
                                  context,
                                  ref,
                                  akhwats,
                                  state,
                                  controller,
                                ),
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
          ] else if (_activeSubTabIndex == 1) ...[
            _buildQudwahDetailSubTab(context, evaluations),
          ] else if (_activeSubTabIndex == 2) ...[
            identitiesAsync.when(
              data: (idents) {
                final groups = ref.watch(groupsStreamProvider).value ?? [];
                final participantNames = groups
                    .expand((g) => g.participants)
                    .toSet();
                final participantsOnly = idents
                    .where((i) => participantNames.contains(i.name))
                    .toList();
                return _buildResumeDetailSubTab(
                  context,
                  ref,
                  participantsOnly,
                  uploadedFiles,
                  resumeScores,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
            ),
          ],
        ],
      ),
    );
  }
}
