// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';

class TestForm extends ConsumerStatefulWidget {
  final String testType; // 'pre' or 'post'

  const TestForm({super.key, required this.testType});

  @override
  ConsumerState<TestForm> createState() => _TestFormState();
}

class _TestFormState extends ConsumerState<TestForm> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedName;
  final _materiController = TextEditingController();
  final _pemateriController = TextEditingController();
  final _instrukturController = TextEditingController();

  // Test answers
  final Map<String, String> _answers = {};
  double _pemateriRating = 5.0; // pretest rating

  @override
  void dispose() {
    _materiController.dispose();
    _pemateriController.dispose();
    _instrukturController.dispose();
    super.dispose();
  }

  Future<void> _submitTest() async {
    if (!_formKey.currentState!.validate()) return;

    final firebaseService = ref.read(firebaseServiceProvider);
    final name = _selectedName ?? '';
    final type = widget.testType;
    final materi = _materiController.text.trim();

    try {
      final firestore = ref.read(firestoreProvider);
      final existingTests = await firestore
          .collection('tests')
          .where('name', isEqualTo: name)
          .where('type', isEqualTo: type)
          .where('materi', isEqualTo: materi)
          .get();

      if (existingTests.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Anda sudah mengirimkan ${type.toUpperCase()} TEST untuk materi "$materi"!',
              ),
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }
    } catch (e) {
      html.window.console.log('[TestForm] Duplicate check error: $e');
    }

    // Store rating inside answers if pretest
    if (widget.testType == 'pre') {
      _answers['rating_pemateri'] = _pemateriRating.toStringAsFixed(0);
    }

    final testRecord = Test(
      id: '',
      type: type,
      name: name,
      materi: materi,
      pemateri: _pemateriController.text.trim(),
      instruktur: _instrukturController.text.trim(),
      answers: _answers,
    );

    try {
      await firebaseService.addTest(testRecord);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil mengirimkan ${widget.testType.toUpperCase()} TEST!',
            ),
          ),
        );
      }
      _formKey.currentState!.reset();
      setState(() {
        _answers.clear();
      });
    } catch (e) {
      html.window.console.log('[TestForm] Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: SelectableText('Terjadi kesalahan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.testType == 'pre'
                        ? "Form Evaluasi / PRETEST"
                        : "Form Evaluasi / POSTTEST",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Metadata inputs - only show participant names
                  Consumer(
                    builder: (context, ref, _) {
                      final groups =
                          ref.watch(groupsStreamProvider).value ?? [];
                      final participantNames =
                          groups.expand((g) => g.participants).toSet().toList()
                            ..sort();

                      if (participantNames.isEmpty) {
                        return const Text(
                          'Belum ada peserta terdaftar.',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        key: ValueKey(_selectedName),
                        dropdownColor: const Color(0xFF1E293B),
                        initialValue:
                            (_selectedName != null &&
                                participantNames.contains(_selectedName))
                            ? _selectedName
                            : null,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nama Peserta',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintText: 'Pilih nama Anda',
                        ),
                        items: participantNames.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedName = val),
                        validator: (val) =>
                            val == null ? 'Nama wajib diisi' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _materiController,
                    label: 'Materi (Judul/Tema)',
                    placeholder: 'Contoh: Konsekuensi Syahadatain',
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _pemateriController,
                    label: 'Nama Pemateri',
                    placeholder: 'Nama pembawa materi yang bersama instruktur',
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _instrukturController,
                    label: 'Nama Instruktur',
                    placeholder:
                        'Nama yang pertama speakup mendampingi pemateri',
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),

                  // Questions
                  if (widget.testType == 'pre') ...[
                    _buildQuestionField(
                      keyName: 'q1_uraian',
                      question:
                          '1. Uraikan Kembali Materi tersebut dengan singkat dan jelas',
                      placeholder: 'Tulis ringkasan materi...',
                    ),
                    _buildQuestionField(
                      keyName: 'q2_dalil_aqli',
                      question:
                          '2. Sebutkan dalil aqli (Logika) dari materi tersebut yang disampaikan tadi',
                      placeholder: 'Logika/dalil aqli...',
                    ),
                    _buildQuestionField(
                      keyName: 'q3_dalil_naqli',
                      question:
                          '3. Sebutkan dalil naqli (Al-Qur’an dan Sunnah) dari materi tersebut',
                      placeholder: 'Sebutkan dalil & surat/hadits...',
                    ),
                    _buildQuestionField(
                      keyName: 'q4_implementasi',
                      question:
                          '4. Coba antum uraikan bagaimana sikap aplikasi atau implementasi yang bisa antum lakukan sesuai materi tersebut',
                      placeholder: 'Rencana aksi nyata sehari-hari...',
                    ),
                    _buildQuestionField(
                      keyName: 'q5_khazanah',
                      question:
                          '5. Coba antum uraikan khazanah baru yang antum peroleh dan rencana strategi setelah memperoleh materi tersebut dalam rangka berorganisasi, berdakwah, & bermasyarakat',
                      placeholder: 'Strategi dakwah & organisasi...',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Berikan penilaian 1-5 untuk pemateri:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: _pemateriRating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Colors.tealAccent,
                      label: _pemateriRating.round().toString(),
                      onChanged: (val) => setState(() => _pemateriRating = val),
                    ),
                  ] else ...[
                    _buildQuestionField(
                      keyName: 'q1_pernah_dengar',
                      question:
                          '1. Apakah Antum sudah pernah mendengar materi tersebut?',
                      placeholder: 'Pernah/Belum...',
                    ),
                    _buildQuestionField(
                      keyName: 'q2_point_penting',
                      question:
                          '2. Jika sudah, coba antum sebutkan point-point penting mengenai materi!',
                      placeholder: 'Point-point penting materi...',
                    ),
                    _buildQuestionField(
                      keyName: 'q3_pentingnya_materi',
                      question:
                          '3. Jika belum, coba antum uraikan sejauh apa pentingnya materi tersebut!',
                      placeholder: 'Urgensi materi menurut pandangan antum...',
                    ),
                    _buildQuestionField(
                      keyName: 'q4_belum_paham',
                      question:
                          '4. Jika sudah, bagian mana dari materi tersebut yang belum antum pahami?',
                      placeholder: 'Bagian materi yang belum jelas...',
                    ),
                    _buildQuestionField(
                      keyName: 'q5_kesan_ekspektasi',
                      question:
                          '5. Jika belum, apa kesan dan ekspektasi antum terhadap pemberi materi?',
                      placeholder: 'Kesan dan harapan untuk pemateri...',
                    ),
                  ],

                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitTest,
                    child: const Text(
                      "KIRIM JAWABAN EVALUASI",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: placeholder,
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
    );
  }

  Widget _buildQuestionField({
    required String keyName,
    required String question,
    required String placeholder,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) => _answers[keyName] = val,
            validator: (val) =>
                val == null || val.isEmpty ? 'Jawaban wajib diisi' : null,
          ),
        ],
      ),
    );
  }
}
