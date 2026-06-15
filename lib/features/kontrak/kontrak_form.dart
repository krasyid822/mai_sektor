// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/signature_helper.dart';
import '../shared/signature_upload_widget.dart';
import '../shared/system_report_form.dart';

class KontrakForm extends ConsumerStatefulWidget {
  const KontrakForm({super.key});

  @override
  ConsumerState<KontrakForm> createState() => _KontrakFormState();
}

class _KontrakFormState extends ConsumerState<KontrakForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedName;
  bool _agreedToTerms = false;

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  bool _isVerifying = false;

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSubmitContract(List<Identity> identities) async {
    if (!_formKey.currentState!.validate() || !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Anda harus menyetujui semua poin perjanjian dan mengisi nama!',
          ),
        ),
      );
      return;
    }

    final name = _selectedName!;
    setState(() => _isVerifying = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final existingContract = await firestore
          .collection('attendance')
          .where('identityName', isEqualTo: name)
          .where('role', isEqualTo: 'kontrak')
          .get();

      if (existingContract.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah menandatangani kontrak belajar!'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        setState(() => _isVerifying = false);
        return;
      }
    } catch (e) {
      html.window.console.log('[KontrakForm] Duplicate check error: $e');
    }

    final sigBytes = await _sigController.toPngBytes();
    if (sigBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap tanda tangani kontrak belajar!')),
        );
      }
      setState(() => _isVerifying = false);
      return;
    }

    // Real Signature Vector comparison
    final matchingIdentity = identities.firstWhere(
      (element) => element.name == name,
      orElse: () => Identity(name: ''),
    );

    bool isMatch = true;
    double similarity = 0.0;
    if (matchingIdentity.allowSignatureReset) {
      isMatch = true; // Bypassed by Kepsek permission
    } else if (matchingIdentity.signatureVector != null &&
        matchingIdentity.signatureVector!.isNotEmpty) {
      final parsed = SignatureHelper.parse(matchingIdentity.signatureVector);
      if (parsed.points.isNotEmpty) {
        final currentOffsets = _sigController.points.map((p) => p.offset).toList();
        similarity = SignatureHelper.calculateSimilarity(currentOffsets, parsed.points);
        // We require at least 40% similarity for a matching signature
        if (similarity < 40.0) {
          isMatch = false;
        }
      } else {
        // Fallback for legacy data (image base64 only)
        if (_sigController.points.length < 5) {
          isMatch = false;
        }
      }
    }

    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;

      if (!isMatch) {
        setState(() => _isVerifying = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                similarity > 0.0
                    ? 'Tanda tangan tidak cocok (Tingkat kemiripan: ${similarity.toStringAsFixed(1)}%, minimal 40.0%). Harap tanda tangan ulang dengan lebih mirip.'
                    : 'Tanda tangan tidak cocok dengan data pendaftaran! Harap tanda tangan ulang dengan lebih mirip.',
              ),
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }

      // Save signed contract confirmation
      final sigBase64 = Uri.dataFromBytes(
        sigBytes,
        mimeType: 'image/png',
      ).toString();
      final serializedVector = SignatureHelper.serialize(sigBase64, _sigController.points);
      try {
        await ref
            .read(firebaseServiceProvider)
            .updateIdentitySignature(_selectedName!, serializedVector);

        // Also log attendance with role 'kontrak' to track session completion!
        await ref
            .read(firebaseServiceProvider)
            .addAttendance(
              Attendance(
                id: '',
                identityName: _selectedName!,
                role: 'kontrak',
                checkInTime: DateTime.now(),
                signatureBase64: sigBase64,
              ),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kontrak Belajar berhasil ditandatangani dan diverifikasi!',
              ),
            ),
          );
        }
        _sigController.clear();
        setState(() {
          _agreedToTerms = false;
        });
      } catch (e) {
        html.window.console.log('[KontrakForm] Submit error: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: SelectableText('Terjadi kesalahan: $e')));
        }
      } finally {
        setState(() => _isVerifying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
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
                    "Kontrak Belajar & Perjanjian Peserta",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Contract text scrollable panel
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const SingleChildScrollView(
                      child: Text(
                        "KONTRAK BELAJAR MAI SEKTOR\n\n"
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
                  ),
                  const SizedBox(height: 16),

                  // Select Name - only show participant names
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

                  // Agreement checkbox
                  CheckboxListTile(
                    value: _agreedToTerms,
                    title: const Text(
                      "Saya menyetujui semua poin kontrak belajar diatas",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    activeColor: Colors.tealAccent,
                    checkColor: Colors.black,
                    onChanged: (val) =>
                        setState(() => _agreedToTerms = val ?? false),
                  ),
                  const SizedBox(height: 16),

                  SignatureUploadWidget(
                    controller: _sigController,
                    title: "Tanda Tangan Peserta (Harus sesuai pendaftaran)",
                    height: 150,
                    onCleared: () => _sigController.clear(),
                  ),
                  const SizedBox(height: 24),

                  // Error report
                  SystemReportForm(
                    getReporterName: () => _selectedName ?? '',
                    role: 'peserta',
                    formSource: 'Kontrak Belajar',
                  ),
                  const SizedBox(height: 24),

                  identitiesAsync.when(
                    data: (idents) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isVerifying
                          ? null
                          : () => _verifyAndSubmitContract(idents),
                      child: _isVerifying
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "VERIFIKASI & TANDA TANGANI KONTRAK",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text("Error: $e"),
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
