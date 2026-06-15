import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/signature_upload_widget.dart';
import '../shared/title_case_formatter.dart';
import '../shared/system_report_form.dart';

class QudwahForm extends ConsumerStatefulWidget {
  final String? initialWalikelas;

  const QudwahForm({super.key, this.initialWalikelas});

  @override
  ConsumerState<QudwahForm> createState() => _QudwahFormState();
}

class _QudwahFormState extends ConsumerState<QudwahForm> {
  final _formKey = GlobalKey<FormState>();
  final _walikelasController = TextEditingController();
  String? _selectedPeserta;
  String? _selectedMateri;
  int _pertemuanKe = 1;

  // 14 evaluation criteria
  final List<String> _criteria = [
    "Penampilan: Suara",
    "Penampilan: Cara Berpakaian",
    "Penampilan: Gaya/Sikap",
    "Forum: Mengantisipasi Reaksi Peserta",
    "Forum: Memancing Reaksi Peserta",
    "Forum: Menjaga Ketenangan Forum",
    "Forum: Ice Breaking",
    "Bahasa: Kejelasan Vokal",
    "Bahasa: Kemudahan Dipahami",
    "Bahasa: Perbendaharaan Kata",
    "Bahasa: Intonasi",
    "Materi: Sistematika",
    "Materi: Penguasaan Materi",
    "Materi: Relevansi",
  ];

  final Map<String, int> _scores = {};
  final Map<String, String> _comments = {};

  final List<String> _syllabus = [
    "Urgensi Mentoring",
    "Konsekuensi Syahadatain",
    "Ma’rifatul Islam (Mengenal Hakikat Islam)",
    "Ma’rifatul Insan (Mengenal Hakikat Manusia)",
    "Ma'rifatullah (Mengenal Allah)",
    "Ma'rifatur Rasul (Mengenal Rasulullah)",
    "Ma’rifatul Qur’an (Mengenal Al-Qur'an)",
    "Ukhuwah Islamiyah (Persaudaraan Sesama Muslim)",
    "Invasi Pemikiran (Ghazwul Fikri)",
    "Peran Pemuda/i Islam",
    "Pentingnya Pendidikan Islam",
    "Pentingnya Akhlak Islam",
  ];

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialWalikelas != null) {
      _walikelasController.text = widget.initialWalikelas!;
    }
    _walikelasController.addListener(() {
      if (mounted) setState(() {});
    });
    // Initialize default scores
    for (final criterion in _criteria) {
      _scores[criterion] = 80;
      _comments[criterion] = "Sangat baik";
    }
  }

  @override
  void dispose() {
    _walikelasController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _submitEvaluation() async {
    if (!_formKey.currentState!.validate()) return;

    final sigBytes = await _sigController.toPngBytes();
    if (sigBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap tanda tangani evaluasi ini!')),
        );
      }
      return;
    }

    final sigBase64 = Uri.dataFromBytes(
      sigBytes,
      mimeType: 'image/png',
    ).toString();

    final eval = RoomQudwahEvaluation(
      id: '',
      walikelas: _walikelasController.text.trim(),
      peserta: _selectedPeserta ?? '',
      materi: _selectedMateri ?? '',
      pertemuanKe: _pertemuanKe,
      scores: _scores,
      comments: _comments,
      signatureBase64: sigBase64,
    );

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.addEvaluation(eval);
      
      // Automatically update the group's walikelas signature
      final walikelasName = _walikelasController.text.trim();
      await firebaseService.updateWalikelasSignature(walikelasName, sigBase64);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluasi Room Qudwah berhasil disimpan!'),
          ),
        );
      }
      _sigController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: SelectableText('Gagal menyimpan evaluasi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Penilaian Room Qudwah - Walikelas',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 750),
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
                  const Text(
                    "Format Penilaian Kelas Kecil (Room Qudwah)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Metadata
                  TextFormField(
                    controller: _walikelasController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [TitleCaseTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Nama Wali Kelas',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  Consumer(
                    builder: (context, ref, _) {
                      final groups = ref.watch(groupsStreamProvider).value ?? [];
                      final currentWalikelas = _walikelasController.text.trim().toLowerCase();
                      final myGroup = groups.firstWhere(
                        (g) => g.walikelas.toLowerCase() == currentWalikelas,
                        orElse: () => Group(walikelas: '', participants: []),
                      );
                      final myParticipants = List<String>.from(myGroup.participants)..sort();

                      if (myParticipants.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            "Belum ada peserta terdaftar untuk Wali Kelas ini.",
                            style: TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        initialValue: () {
                          if (_selectedPeserta != null && myParticipants.contains(_selectedPeserta)) {
                            return _selectedPeserta;
                          }
                          return null;
                        }(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nama Peserta',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        items: myParticipants.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedPeserta = val),
                        validator: (val) =>
                            val == null ? 'Wajib memilih peserta' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          initialValue: _selectedMateri,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Syllabus Materi',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          items: _syllabus.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedMateri = val),
                          validator: (val) =>
                              val == null ? 'Wajib memilih materi' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          dropdownColor: const Color(0xFF1E293B),
                          initialValue: _pertemuanKe,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Pertemuan Ke',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          items: List.generate(12, (index) => index + 1).map((
                            n,
                          ) {
                            return DropdownMenuItem(
                              value: n,
                              child: Text("Pertemuan $n"),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _pertemuanKe = val ?? 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    "Kriteria Evaluasi Sub-Jenis Penilaian (1-100)",
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 14 sub-indikator inputs
                  ..._criteria.map((criterion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            criterion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: "80",
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Skor (1-100)',
                                    labelStyle: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  onChanged: (val) => _scores[criterion] =
                                      int.tryParse(val) ?? 80,
                                  validator: (val) {
                                    final score = int.tryParse(val ?? '');
                                    if (score == null ||
                                        score < 1 ||
                                        score > 100) {
                                      return 'Input skor 1-100';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: "Sangat baik",
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Keterangan/Catatan',
                                    labelStyle: TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  onChanged: (val) =>
                                      _comments[criterion] = val,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Signature Pad for Walikelas
                  SignatureUploadWidget(
                    controller: _sigController,
                    title: "Tanda Tangan Wali Kelas",
                    height: 120,
                  ),
                  const SizedBox(height: 24),

                  // Error report
                  SystemReportForm(
                    getReporterName: () => _walikelasController.text.trim(),
                    role: 'guru',
                    formSource: 'Room Qudwah',
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitEvaluation,
                    child: const Text(
                      "SIMPAN EVALUASI ROOM QUDWAH",
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
}
