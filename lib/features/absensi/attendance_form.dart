// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';

class AttendanceForm extends ConsumerStatefulWidget {
  const AttendanceForm({super.key});

  @override
  ConsumerState<AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends ConsumerState<AttendanceForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedName;
  final _murobbiController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _errorController = TextEditingController();
  String _gender = 'ikhwan';
  String _role = 'peserta';

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _capturedFaceVector;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        CameraDescription selectedCamera = cameras.first;
        for (final camera in cameras) {
          if (camera.lensDirection == CameraLensDirection.back) {
            selectedCamera = camera;
            break;
          }
        }
        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.low,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _murobbiController.dispose();
    _whatsappController.dispose();
    _errorController.dispose();
    _sigController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String? val) async {
    if (val == null || val.trim().isEmpty) return;

    final idents = ref.read(identitiesStreamProvider).value ?? [];
    final groups = ref.read(groupsStreamProvider).value ?? [];
    final walikelasNames = groups.map((g) => g.walikelas).toSet();

    final myIdent = idents.cast<Identity?>().firstWhere(
      (i) => i!.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => null,
    );

    if (myIdent != null) {
      if (myIdent.whatsapp != null && myIdent.whatsapp!.isNotEmpty) {
        _whatsappController.text = myIdent.whatsapp!;
      }
      if (myIdent.gender != null && myIdent.gender!.isNotEmpty) {
        setState(() {
          _gender = myIdent.gender!;
        });
      }

      final murobbiName = myIdent.murobbi;
      if (murobbiName != null && murobbiName.isNotEmpty) {
        if (walikelasNames.contains(murobbiName)) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Konfirmasi Murobbi"),
              content: Text("Apakah Murobbi/Mentor Anda adalah $murobbiName?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Tidak"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Ya"),
                ),
              ],
            ),
          );
          if (confirm == true && mounted) {
            setState(() {
              _murobbiController.text = murobbiName;
            });
          }
        }
      }
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitAttendance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final sigBytes = await _sigController.toPngBytes();
    if (sigBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap tanda tangani pad absensi!')),
        );
      }
      return;
    }

    final sigBase64 = Uri.dataFromBytes(
      sigBytes,
      mimeType: 'image/png',
    ).toString();

    // Mock Face Vector Generation
    final faceVector =
        _capturedFaceVector ?? "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]";

    final name = _role == 'tamu'
        ? 'Tamu - ${_selectedName ?? "Anonim"}'
        : (_selectedName ?? '');
    final role = _role;

    setState(() {
      _isCameraInitialized = false;
      _isSubmitting = true;
    });

    try {
      final firestore = ref.read(firestoreProvider);
      final todayStart = DateTime.now().copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      );
      final existingAttendance = await firestore
          .collection('attendance')
          .where('identityName', isEqualTo: name)
          .where('role', isEqualTo: role)
          .where(
            'checkInTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah melakukan absensi hari ini!'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        _initializeCamera();
        return;
      }

      final att = Attendance(
        id: '',
        identityName: name,
        role: role,
        checkInTime: DateTime.now(),
        signatureBase64: sigBase64,
        faceVector: faceVector,
        errorReport: _errorController.text.trim(),
      );

      await ref.read(firebaseServiceProvider).addAttendance(att);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Absensi berhasil disimpan!')),
        );
      }
      _formKey.currentState!.reset();
      _sigController.clear();
      _initializeCamera();
    } catch (e) {
      html.window.console.log('[AttendanceForm] Error submitting: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: SelectableText('Gagal mengirim absensi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
                    "Absensi MAI Sektor",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Role Selector
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    initialValue: _role,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Tipe Kehadiran',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: ['peserta', 'guru', 'tamu'].map((r) {
                      final label = r == 'guru' ? 'wali kelas' : r;
                      return DropdownMenuItem(
                        value: r,
                        child: Text(label.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _role = val ?? 'peserta'),
                  ),
                  const SizedBox(height: 16),

                  // Name dropdown (if not guest)
                  if (_role != 'tamu')
                    Consumer(
                      builder: (context, ref, _) {
                        final groups =
                            ref.watch(groupsStreamProvider).value ?? [];
                        final walikelasNames = groups
                            .map((g) => g.walikelas)
                            .toSet();
                        final participantNames = groups
                            .expand((g) => g.participants)
                            .toSet();

                        // Filter names based on role
                        List<String> filteredNames;
                        String labelText;
                        if (_role == 'guru') {
                          // Guru/walikelas: show only walikelas names
                          filteredNames = walikelasNames.toList()..sort();
                          labelText = 'Nama Wali Kelas';
                        } else {
                          // Peserta: show only participant names
                          filteredNames = participantNames.toList()..sort();
                          labelText = 'Nama Peserta';
                        }

                        if (filteredNames.isEmpty) {
                          return const Text(
                            'Belum ada data. Harap hubungi Kepala Sekolah.',
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
                                  filteredNames.contains(_selectedName))
                              ? _selectedName
                              : null,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: labelText,
                            labelStyle: const TextStyle(color: Colors.white70),
                          ),
                          items: filteredNames.map((name) {
                            return DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            setState(() => _selectedName = val);
                            await _onNameChanged(val);
                          },
                          validator: (val) =>
                              val == null ? '$labelText wajib dipilih' : null,
                        );
                      },
                    )
                  else
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nama Tamu',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      onChanged: (val) async {
                        setState(() => _selectedName = val);
                        await _onNameChanged(val);
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nama wajib diisi'
                          : null,
                    ),

                  const SizedBox(height: 16),

                  // Murobbi Auto matching input
                  TextFormField(
                    controller: _murobbiController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nama Murobbi / Mentor',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Masukkan nama pembina halaqah Anda',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onChanged: (val) {
                      // Simulating instant check in real database
                    },
                  ),
                  const SizedBox(height: 16),

                  // WhatsApp
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Kontak WhatsApp',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Nomor WhatsApp wajib diisi';
                      }
                      if (!RegExp(r'^[0-9+]{8,15}$').hasMatch(val)) {
                        return 'Nomor WhatsApp tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Gender
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Jenis Kelamin: ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      ChoiceChip(
                        selected: _gender == 'ikhwan',
                        label: const Text('Ikhwan'),
                        selectedColor: Colors.tealAccent,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: _gender == 'ikhwan'
                              ? Colors.black
                              : Colors.white,
                        ),
                        onSelected: (selected) =>
                            setState(() => _gender = 'ikhwan'),
                      ),
                      ChoiceChip(
                        selected: _gender == 'akhwat',
                        label: const Text('Akhwat'),
                        selectedColor: Colors.tealAccent,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: _gender == 'akhwat'
                              ? Colors.black
                              : Colors.white,
                        ),
                        onSelected: (selected) =>
                            setState(() => _gender = 'akhwat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Web Face Vector Mock (Camera preview if available)
                  if (_isCameraInitialized && _cameraController != null)
                    Column(
                      children: [
                        const Text(
                          "Pemindaian Vektor Wajah Real-time",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 150,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),

                  // Signature pad
                  const Text(
                    "Tanda Tangan Digital",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Signature(
                      controller: _sigController,
                      height: 150,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _sigController.clear(),
                      child: const Text(
                        "Bersihkan Pad",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),

                  // Error report
                  TextFormField(
                    controller: _errorController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Laporkan Kesalahan Sistem (Opsional)',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isSubmitting ? null : _submitAttendance,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "KIRIM ABSENSI",
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
