import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:camera/camera.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/biometric_helper.dart';
import '../shared/signature_upload_widget.dart';
import '../shared/signature_helper.dart';

class SetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupScreen({super.key, required this.onSetupComplete});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();

  // Step 1: Kepsek attributes
  final _kepsekController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _gender = 'ikhwan';
  final _tahunController = TextEditingController();

  final SignatureController _kepsekSigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _capturedFaceVector;

  // Step 2 variables
  int _currentStep = 1; // 1: Kepsek verification, 2: Guru & Peserta management

  // Custom Flow Variables for Recovery & Split-step Verification
  bool _hasCheckedStatus = false;
  bool _isReverifying = false;
  bool _showSigUpload = true;
  bool _showFaceScan = true;
  bool _isAlreadyConfigured = false;

  final List<String> _teachers = [];
  final List<String> _participants = [];
  final List<String> _presenters = [];

  final _teacherController = TextEditingController();
  final _participantController = TextEditingController();
  final _presenterController = TextEditingController();

  // Groupings: Walikelas -> List of Participant names
  final Map<String, List<String>> _groupings = {};
  String? _selectedTeacherForGrouping;
  final List<String> _selectedParticipantsForGrouping = [];

  bool _isSaving = false;
  Identity? _existingIdentity;

  @override
  void initState() {
    super.initState();
    _tahunController.text = "2026/2027";
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
    _kepsekController.dispose();
    _tahunController.dispose();
    _whatsappController.dispose();
    _teacherController.dispose();
    _participantController.dispose();
    _presenterController.dispose();
    _kepsekSigController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _addTeacher() {
    final name = _teacherController.text.trim();
    if (name.isNotEmpty && !_teachers.contains(name)) {
      setState(() {
        _teachers.add(name);
        _groupings[name] = [];
        _teacherController.clear();
      });
    }
  }

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (name.isNotEmpty && !_participants.contains(name)) {
      setState(() {
        _participants.add(name);
        _participantController.clear();
      });
    }
  }

  void _addPresenter() {
    final name = _presenterController.text.trim();
    if (name.isNotEmpty && !_presenters.contains(name)) {
      setState(() {
        _presenters.add(name);
        _presenterController.clear();
      });
    }
  }

  void _assignParticipantsToTeacher() {
    if (_selectedTeacherForGrouping == null ||
        _selectedParticipantsForGrouping.isEmpty) {
      return;
    }

    setState(() {
      _groupings[_selectedTeacherForGrouping!]!.addAll(
        _selectedParticipantsForGrouping,
      );
      _participants.removeWhere(
        (p) => _selectedParticipantsForGrouping.contains(p),
      );
      _selectedParticipantsForGrouping.clear();
    });
  }

  Future<void> _checkKepsekStatus() async {
    final name = _kepsekController.text.trim();
    final year = _tahunController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap masukkan nama lengkap Kepala Sekolah!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firestore = ref.read(firestoreProvider);

      // Get global config
      final configDoc = await firestore
          .collection('config')
          .doc('global')
          .get();
      AppConfig? currentConfig;
      if (configDoc.exists && configDoc.data() != null) {
        currentConfig = AppConfig.fromMap(configDoc.data()!);
      }

      // Query identities
      final identityDoc = await firestore
          .collection('identities')
          .doc(name)
          .get();
      Identity? existingIdentity;
      if (identityDoc.exists && identityDoc.data() != null) {
        existingIdentity = Identity.fromMap(identityDoc.data()!);
      }
      _existingIdentity = existingIdentity;

      if (currentConfig != null) {
        // App is already configured
        if (currentConfig.kepalaSekolahNama.toLowerCase() ==
                name.toLowerCase() &&
            currentConfig.kepengurusanTahun == year) {
          final hasSignature = existingIdentity != null &&
              existingIdentity.signatureVector != null &&
              existingIdentity.signatureVector!.isNotEmpty;
          final hasFace = existingIdentity != null &&
              existingIdentity.faceVector != null &&
              existingIdentity.faceVector!.isNotEmpty;

          setState(() {
            _showSigUpload = !hasSignature;
            _showFaceScan = !hasFace;
            if (existingIdentity != null) {
              _whatsappController.text = existingIdentity.whatsapp ?? '';
              _gender = existingIdentity.gender ?? 'ikhwan';
            }
            _hasCheckedStatus = true;
            _isReverifying = hasSignature && hasFace;
            _isAlreadyConfigured = true;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Nama Kepala Sekolah atau tahun tidak sesuai dengan konfigurasi aktif (${currentConfig.kepalaSekolahNama} - ${currentConfig.kepengurusanTahun}).',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        // Fresh install (no config yet)
        final hasSignature = existingIdentity != null &&
            existingIdentity.signatureVector != null &&
            existingIdentity.signatureVector!.isNotEmpty;
        final hasFace = existingIdentity != null &&
            existingIdentity.faceVector != null &&
            existingIdentity.faceVector!.isNotEmpty;

        if (existingIdentity != null &&
            existingIdentity.whatsapp != null &&
            hasSignature &&
            hasFace) {
          // Identity already complete
          setState(() {
            _hasCheckedStatus = true;
            _isReverifying = false;
            _currentStep = 2; // Jump to Teacher management
          });
        } else {
          // Needs complete profile (some or all data missing)
          setState(() {
            _showSigUpload = !hasSignature;
            _showFaceScan = !hasFace;
            if (existingIdentity != null) {
              _whatsappController.text = existingIdentity.whatsapp ?? '';
              _gender = existingIdentity.gender ?? 'ikhwan';
            }
            _hasCheckedStatus = true;
            _isReverifying = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: SelectableText('Gagal memeriksa status: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyAndLogin() async {
    if (_kepsekSigController.points.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Harap tanda tangani pad untuk memverifikasi identitas Anda!',
            ),
          ),
        );
      }
      return;
    }

    if (_cameraController == null || !_isCameraInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera belum siap! Harap izinkan akses kamera.'),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Verify Signature Vector similarity
      double sigMatchRate = 0.0;
      if (_existingIdentity != null && _existingIdentity!.signatureVector != null) {
        final parsedSig = SignatureHelper.parse(_existingIdentity!.signatureVector);
        if (parsedSig.points.isNotEmpty) {
          final currentOffsets = _kepsekSigController.points.map((p) => p.offset).toList();
          sigMatchRate = SignatureHelper.calculateSimilarity(currentOffsets, parsedSig.points);
        } else {
          // If registered signature has no points (legacy base64 string only), allow verification check to pass
          sigMatchRate = 100.0;
        }
      } else {
        sigMatchRate = 100.0;
      }

      if (sigMatchRate < 40.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verifikasi Tanda Tangan Gagal! Kemiripan: ${sigMatchRate.toStringAsFixed(1)}% (Minimal 40.0%)',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      final photoFile = await _cameraController!.takePicture();
      final currentFaceVector = await BiometricHelper.extractFaceVector(
        photoFile,
      );

      double matchRate = 0.0;
      bool isLegacyMock = false;

      if (_existingIdentity != null && _existingIdentity!.faceVector != null) {
        // If they registered before real biometrics was implemented, their vector is the mock placeholder
        if (_existingIdentity!.faceVector ==
            "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]") {
          isLegacyMock = true;
          matchRate = 100.0; // Auto-pass to allow migration
        } else {
          final registeredFaceVector = BiometricHelper.parseVectorString(
            _existingIdentity!.faceVector!,
          );
          matchRate =
              BiometricHelper.calculateSimilarity(
                currentFaceVector,
                registeredFaceVector,
              ) *
              100.0;
        }
      } else {
        matchRate = 100.0;
      }

      if (matchRate < 75.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verifikasi Wajah Gagal! Kemiripan hanya ${matchRate.toStringAsFixed(1)}% (Minimal 75.0%)',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLegacyMock
                  ? 'Verifikasi Berhasil! Migrasi profil biometrik wajah lama berhasil.'
                  : 'Verifikasi Berhasil! Kemiripan wajah: ${matchRate.toStringAsFixed(1)}%',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }

      // If they had a legacy mock profile, migrate it to the newly captured real biometrics vector
      if (isLegacyMock && _existingIdentity != null) {
        final firebaseService = ref.read(firebaseServiceProvider);
        await firebaseService.saveIdentity(
          Identity(
            name: _existingIdentity!.name,
            gender: _existingIdentity!.gender ?? _gender,
            whatsapp: _existingIdentity!.whatsapp,
            signatureVector: _existingIdentity!.signatureVector,
            faceVector: currentFaceVector.toString(),
            allowSignatureReset: _existingIdentity!.allowSignatureReset,
          ),
        );
      }

      // Set session authenticated in provider
      ref.read(sessionAuthStateProvider.notifier).login();
      widget.onSetupComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal melakukan pemindaian wajah: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyNewKepsek() async {
    if (!_formKeyStep1.currentState!.validate()) return;

    String? kepsekSigBase64;
    String? signatureVectorValue;

    if (_showSigUpload) {
      if (_kepsekSigController.points.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Harap tanda tangani pad untuk memverifikasi Kepala Sekolah!',
              ),
            ),
          );
        }
        return;
      }
      final sigBytes = await _kepsekSigController.toPngBytes();
      if (sigBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal mengekstrak tanda tangan!',
              ),
            ),
          );
        }
        return;
      }
      kepsekSigBase64 = Uri.dataFromBytes(
        sigBytes,
        mimeType: 'image/png',
      ).toString();
      signatureVectorValue = SignatureHelper.serialize(kepsekSigBase64, _kepsekSigController.points);
    } else {
      signatureVectorValue = _existingIdentity?.signatureVector;
      if (signatureVectorValue != null && signatureVectorValue.startsWith('{')) {
        kepsekSigBase64 = SignatureHelper.parse(signatureVectorValue).imageBase64;
      } else {
        kepsekSigBase64 = signatureVectorValue;
      }
    }

    String? faceVectorString;
    if (_showFaceScan) {
      if (_cameraController == null || !_isCameraInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamera belum siap! Harap izinkan akses kamera.'),
            ),
          );
        }
        return;
      }
      try {
        final photoFile = await _cameraController!.takePicture();
        final currentFaceVector = await BiometricHelper.extractFaceVector(
          photoFile,
        );
        faceVectorString = currentFaceVector.toString();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengekstrak sensor wajah: $e')),
          );
        }
        return;
      }
    } else {
      faceVectorString = _existingIdentity?.faceVector;
    }

    setState(() => _isSaving = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      // 1. Save Config
      final config = AppConfig(
        activeMode: 'idle',
        kepalaSekolahNama: _kepsekController.text.trim(),
        kepengurusanTahun: _tahunController.text.trim(),
        bobotKelasBesar: 40.0,
        bobotRoomQudwah: 40.0,
        bobotTugas: 20.0,
        nilaiMinimum: 75.0,
        kepsekSignatureBase64: kepsekSigBase64,
      );
      await firebaseService.saveConfig(config);

      // 2. Save Kepsek Identity
      await firebaseService.saveIdentity(
        Identity(
          name: config.kepalaSekolahNama,
          gender: _gender,
          whatsapp: _whatsappController.text.trim(),
          signatureVector: signatureVectorValue,
          faceVector: faceVectorString,
        ),
      );

      if (_isAlreadyConfigured) {
        ref.read(sessionAuthStateProvider.notifier).login();
        widget.onSetupComplete();
      } else {
        setState(() {
          _currentStep = 2; // Transition to Step 2
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data Kepala Sekolah: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _submitSetup() async {
    if (_teachers.isEmpty || _groupings.values.every((list) => list.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap tambahkan guru/walikelas dan bagi kelompok peserta!',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      // Save Kepsek Signature
      final kepsekSigBytes = await _kepsekSigController.toPngBytes();
      String? kepsekSigBase64;
      if (kepsekSigBytes != null) {
        kepsekSigBase64 = Uri.dataFromBytes(
          kepsekSigBytes,
          mimeType: 'image/png',
        ).toString();
      }

      // Save Config
      final config = AppConfig(
        activeMode: 'idle',
        kepalaSekolahNama: _kepsekController.text.trim(),
        kepengurusanTahun: _tahunController.text.trim(),
        bobotKelasBesar: 40.0,
        bobotRoomQudwah: 40.0,
        bobotTugas: 20.0,
        nilaiMinimum: 75.0,
        kepsekSignatureBase64: kepsekSigBase64,
      );
      await firebaseService.saveConfig(config);

      // Save Kepsek Identity (Fully filled identity as verified)
      final faceVector =
          _capturedFaceVector ?? "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]";
      await firebaseService.saveIdentity(
        Identity(
          name: config.kepalaSekolahNama,
          gender: _gender,
          whatsapp: _whatsappController.text.trim(),
          signatureVector: SignatureHelper.serialize(kepsekSigBase64!, _kepsekSigController.points),
          faceVector: faceVector,
        ),
      );

      // Save Teachers (Name only initially)
      for (final teacher in _teachers) {
        await firebaseService.saveIdentity(
          Identity(name: teacher, gender: 'ikhwan'),
        );
      }

      // Save Presenters (Name only initially)
      for (final presenter in _presenters) {
        await firebaseService.saveIdentity(Identity(name: presenter));
      }

      // Save Groups & Participants Identities (Name only initially)
      for (final entry in _groupings.entries) {
        final group = Group(walikelas: entry.key, participants: entry.value);
        await firebaseService.saveGroup(group);

        for (final participant in entry.value) {
          await firebaseService.saveIdentity(Identity(name: participant));
        }
      }

      ref.read(sessionAuthStateProvider.notifier).login();
      widget.onSetupComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: SelectableText('Terjadi kesalahan: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _currentStep == 1
                  ? _buildStep1KepsekVerification()
                  : _buildStep2ManageData(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tahun Kepengurusan',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, index) {
              final startYear = 2024 + index;
              final yearStr = "$startYear/${startYear + 1}";
              final isSelected = _tahunController.text == yearStr;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _tahunController.text = yearStr;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.tealAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.tealAccent
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.tealAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        yearStr,
                        style: TextStyle(
                          color: isSelected ? Colors.tealAccent : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredCard({
    required String title,
    required IconData icon,
    required VoidCallback onChange,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Sudah terdaftar',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onChange,
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }

  // STEP 1: Verifikasi Identitas Kepala Sekolah
  Widget _buildStep1KepsekVerification() {
    final theme = Theme.of(context);

    if (!_hasCheckedStatus) {
      return Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrasi Kepala Sekolah',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ini bukan halaman untuk peserta, jika anda terlempar kesini coba pindai ulang kode qr yang ada didepan anda. Silakan masukkan nama Kepala Sekolah dan tentukan tahun kepengurusan aktif untuk memulai atau memulihkan sesi.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _buildTextField(
              controller: _kepsekController,
              label: 'Nama Lengkap Kepala Sekolah',
              icon: Icons.person,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: _checkKepsekStatus,
            ),
            const SizedBox(height: 24),

            _buildYearTimeline(),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _checkKepsekStatus,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'CEK STATUS VERIFIKASI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    if (_isReverifying) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selamat Datang Kembali!',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Konfigurasi aktif mendeteksi ${_kepsekController.text.trim()} (${_tahunController.text.trim()}). Silakan verifikasi identitas Anda untuk masuk.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_isCameraInitialized && _cameraController != null)
            Column(
              children: [
                const Text(
                  "Pemindaian Wajah untuk Verifikasi Sesi",
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
                const SizedBox(height: 16),
              ],
            ),

          // Signature Pad for Kepsek (Verified using vector)
          SignatureUploadWidget(
            title: 'Gambarkan Tanda Tangan Anda (Untuk Verifikasi)',
            controller: _kepsekSigController,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _verifyAndLogin,
            child: const Text(
              'VERIFIKASI & MASUK DASBOR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _hasCheckedStatus = false;
                _isReverifying = false;
              });
            },
            child: const Text(
              'Bukan Anda? Kembali',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      );
    }

    // Otherwise must complete profile fields
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lengkapi Profil Kepala Sekolah',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Isi data identitas lengkap untuk Kepala Sekolah: ${_kepsekController.text.trim()}',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _buildTextField(
            controller: _whatsappController,
            label: 'Nomor WhatsApp',
            icon: Icons.phone,
            validator: (val) =>
                val == null || val.isEmpty ? 'WhatsApp wajib diisi' : null,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Jenis Kelamin: ",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    selected: _gender == 'ikhwan',
                    label: const Text('Ikhwan'),
                    selectedColor: Colors.tealAccent,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: _gender == 'ikhwan' ? Colors.black : Colors.white,
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
                      color: _gender == 'akhwat' ? Colors.black : Colors.white,
                    ),
                    onSelected: (selected) =>
                        setState(() => _gender = 'akhwat'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Face Scanner Section
          if (!_showFaceScan)
            _buildRegisteredCard(
              title: "Vektor Wajah Kepala Sekolah",
              icon: Icons.face,
              onChange: () => setState(() => _showFaceScan = true),
            )
          else if (_isCameraInitialized && _cameraController != null)
            Column(
              children: [
                const Text(
                  "Pemindaian Vektor Wajah Kepala Sekolah",
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
              ],
            ),
          const SizedBox(height: 24),

          // Signature Section
          if (!_showSigUpload)
            _buildRegisteredCard(
              title: "Tanda Tangan Kepala Sekolah",
              icon: Icons.gesture,
              onChange: () => setState(() => _showSigUpload = true),
            )
          else
            SignatureUploadWidget(
              title: 'Tanda Tangan Kepala Sekolah (Wajib)',
              controller: _kepsekSigController,
            ),
          const SizedBox(height: 32),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _verifyNewKepsek,
            child: const Text(
              'VERIFIKASI & LANJUTKAN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _hasCheckedStatus = false;
              });
            },
            child: const Text(
              'Kembali ke Pengisian Nama',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: Kelola Dewan Guru, Peserta, Pemateri, & Kelompok
  Widget _buildStep2ManageData() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Langkah 2: Kelola Dewan Guru & Peserta',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Kepala Sekolah menginputkan nama-nama Dewan Guru, Peserta, Pemateri, serta membaginya ke kelompok Walikelas.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'Dewan Guru (Walikelas)',
                icon: Icons.school,
                controller: _teacherController,
                onAdd: _addTeacher,
                items: _teachers,
                onDelete: (item) {
                  setState(() {
                    _teachers.remove(item);
                    _groupings.remove(item);
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSectionCard(
                title: 'Peserta Sekolah',
                icon: Icons.people,
                controller: _participantController,
                onAdd: _addParticipant,
                items: _participants,
                onDelete: (item) => setState(() => _participants.remove(item)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionCard(
          title: 'Pembawa Materi',
          icon: Icons.record_voice_over,
          controller: _presenterController,
          onAdd: _addPresenter,
          items: _presenters,
          onDelete: (item) => setState(() => _presenters.remove(item)),
        ),
        const SizedBox(height: 24),

        if (_teachers.isNotEmpty &&
            (_participants.isNotEmpty ||
                _groupings.values.any((l) => l.isNotEmpty)))
          _buildGroupingSection(),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('KEMBALI'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSaving ? null : _submitSetup,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'SELESAIKAN SETUP & MASUK DASBOR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Capitalize the first letter of each word in a string.
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    VoidCallback? onFieldSubmitted,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: (val) {
        final capitalized = _capitalizeWords(val);
        if (capitalized != val) {
          controller.value = TextEditingValue(
            text: capitalized,
            selection: TextSelection.collapsed(offset: capitalized.length),
          );
        }
      },
      onFieldSubmitted: (_) => onFieldSubmitted?.call(),
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required List<String> items,
    required Function(String) onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    final capitalized = _capitalizeWords(val);
                    if (capitalized != val) {
                      controller.value = TextEditingValue(
                        text: capitalized,
                        selection: TextSelection.collapsed(
                          offset: capitalized.length,
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Nama...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.tealAccent,
                  size: 32,
                ),
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => onDelete(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.group_work, color: Colors.tealAccent),
              const SizedBox(width: 8),
              const Text(
                'Pembagian Kelompok Walikelas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF203A43),
                  initialValue: _selectedTeacherForGrouping,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Pilih Walikelas',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: _teachers.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedTeacherForGrouping = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sisa Peserta Belum Dikelompokkan: ${_participants.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedTeacherForGrouping != null && _participants.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pilih Peserta untuk dimasukkan:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _participants.map((p) {
                    final isSelected = _selectedParticipantsForGrouping
                        .contains(p);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(p),
                      selectedColor: Colors.tealAccent,
                      checkmarkColor: Colors.black,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedParticipantsForGrouping.add(p);
                          } else {
                            _selectedParticipantsForGrouping.remove(p);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _assignParticipantsToTeacher,
                  child: const Text('Masukkan ke Kelompok'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Text(
            'Daftar Kelompok:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._groupings.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                '• ${entry.key}: ${entry.value.isEmpty ? "(Belum ada peserta)" : entry.value.join(", ")}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }),
        ],
      ),
    );
  }
}
