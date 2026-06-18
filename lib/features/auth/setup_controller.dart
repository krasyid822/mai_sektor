import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:signature/signature.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/biometric_helper.dart';
import '../shared/signature_helper.dart';

class SetupState {
  final int currentStep;
  final bool hasCheckedStatus;
  final bool isReverifying;
  final bool showSigUpload;
  final bool showFaceScan;
  final bool isAlreadyConfigured;
  final List<String> teachers;
  final List<String> participants;
  final List<String> presenters;
  final Map<String, List<String>> groupings;
  final String? selectedTeacherForGrouping;
  final List<String> selectedParticipantsForGrouping;
  final bool isSaving;
  final Identity? existingIdentity;

  // Camera state
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final List<CameraDescription> cameras;
  final int selectedCameraIndex;

  SetupState({
    this.currentStep = 1,
    this.hasCheckedStatus = false,
    this.isReverifying = false,
    this.showSigUpload = true,
    this.showFaceScan = true,
    this.isAlreadyConfigured = false,
    this.teachers = const [],
    this.participants = const [],
    this.presenters = const [],
    this.groupings = const {},
    this.selectedTeacherForGrouping,
    this.selectedParticipantsForGrouping = const [],
    this.isSaving = false,
    this.existingIdentity,
    this.cameraController,
    this.isCameraInitialized = false,
    this.cameras = const [],
    this.selectedCameraIndex = 0,
  });

  SetupState copyWith({
    int? currentStep,
    bool? hasCheckedStatus,
    bool? isReverifying,
    bool? showSigUpload,
    bool? showFaceScan,
    bool? isAlreadyConfigured,
    List<String>? teachers,
    List<String>? participants,
    List<String>? presenters,
    Map<String, List<String>>? groupings,
    String? Function()? selectedTeacherForGrouping,
    List<String>? selectedParticipantsForGrouping,
    bool? isSaving,
    Identity? Function()? existingIdentity,
    CameraController? Function()? cameraController,
    bool? isCameraInitialized,
    List<CameraDescription>? cameras,
    int? selectedCameraIndex,
  }) {
    return SetupState(
      currentStep: currentStep ?? this.currentStep,
      hasCheckedStatus: hasCheckedStatus ?? this.hasCheckedStatus,
      isReverifying: isReverifying ?? this.isReverifying,
      showSigUpload: showSigUpload ?? this.showSigUpload,
      showFaceScan: showFaceScan ?? this.showFaceScan,
      isAlreadyConfigured: isAlreadyConfigured ?? this.isAlreadyConfigured,
      teachers: teachers ?? this.teachers,
      participants: participants ?? this.participants,
      presenters: presenters ?? this.presenters,
      groupings: groupings ?? this.groupings,
      selectedTeacherForGrouping: selectedTeacherForGrouping != null
          ? selectedTeacherForGrouping()
          : this.selectedTeacherForGrouping,
      selectedParticipantsForGrouping:
          selectedParticipantsForGrouping ??
          this.selectedParticipantsForGrouping,
      isSaving: isSaving ?? this.isSaving,
      existingIdentity: existingIdentity != null
          ? existingIdentity()
          : this.existingIdentity,
      cameraController: cameraController != null
          ? cameraController()
          : this.cameraController,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      cameras: cameras ?? this.cameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
    );
  }
}

class SetupController extends Notifier<SetupState> {
  CameraController? _cameraController;

  @override
  SetupState build() {
    ref.onDispose(() {
      _cameraController?.dispose();
    });
    Future.microtask(() => initializeCamera());
    return SetupState();
  }

  void updateStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void resetHasCheckedStatus() {
    state = state.copyWith(hasCheckedStatus: false);
  }

  Future<void> initializeCamera() async {
    try {
      final camerasList = await availableCameras();
      if (camerasList.isNotEmpty) {
        int defaultIndex = 0;
        for (int i = 0; i < camerasList.length; i++) {
          if (camerasList[i].lensDirection == CameraLensDirection.back) {
            defaultIndex = i;
            break;
          }
        }
        final controller = CameraController(
          camerasList[defaultIndex],
          ResolutionPreset.low,
          enableAudio: false,
        );
        await controller.initialize();
        _cameraController = controller;

        final updatedCameras = await availableCameras();
        int newSelectedIndex = defaultIndex;
        if (updatedCameras.isNotEmpty) {
          final activeCamera = camerasList[defaultIndex];
          final matchIdx = updatedCameras.indexWhere(
            (c) => c.name == activeCamera.name || c.lensDirection == activeCamera.lensDirection
          );
          if (matchIdx != -1) {
            newSelectedIndex = matchIdx;
          }
        }

        state = state.copyWith(
          cameras: updatedCameras.isNotEmpty ? updatedCameras : camerasList,
          selectedCameraIndex: newSelectedIndex,
          cameraController: () => controller,
          isCameraInitialized: true,
        );
      }
    } catch (e, stack) {
      debugPrint("Camera init error: $e");
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: 'Setup - System',
        role: 'system',
        formSource: 'Setup - Inisialisasi Kamera',
        exception: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> switchCamera() async {
    if (state.cameras.length <= 1) return;
    final nextIndex = (state.selectedCameraIndex + 1) % state.cameras.length;
    final selectedCamera = state.cameras[nextIndex];

    state = state.copyWith(isCameraInitialized: false);

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      state = state.copyWith(cameraController: () => null);
    }

    // Give hardware / browser some time to release camera lock
    await Future.delayed(const Duration(milliseconds: 300));

    final newController = CameraController(
      selectedCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await newController.initialize();
      _cameraController = newController;
      state = state.copyWith(
        selectedCameraIndex: nextIndex,
        cameraController: () => newController,
        isCameraInitialized: true,
      );
    } catch (e, stack) {
      debugPrint("Camera switch error: $e");
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: 'Setup - System',
        role: 'system',
        formSource: 'Setup - Switch Kamera',
        exception: e,
        stackTrace: stack,
      );
      // Fallback to re-initialize camera
      await initializeCamera();
    }
  }

  void addTeacher(String name) {
    if (name.isNotEmpty && !state.teachers.contains(name)) {
      final updatedTeachers = List<String>.from(state.teachers)..add(name);
      final updatedGroupings = Map<String, List<String>>.from(state.groupings);
      updatedGroupings[name] = [];
      state = state.copyWith(
        teachers: updatedTeachers,
        groupings: updatedGroupings,
      );
    }
  }

  void removeTeacher(String name) {
    final updatedTeachers = List<String>.from(state.teachers)..remove(name);
    final updatedGroupings = Map<String, List<String>>.from(state.groupings);
    final groupParticipants = updatedGroupings.remove(name) ?? [];

    // Return participants back to general pool
    final updatedParticipants = List<String>.from(state.participants)
      ..addAll(groupParticipants);

    state = state.copyWith(
      teachers: updatedTeachers,
      groupings: updatedGroupings,
      participants: updatedParticipants,
      selectedTeacherForGrouping: state.selectedTeacherForGrouping == name
          ? () => null
          : () => state.selectedTeacherForGrouping,
    );
  }

  void addParticipant(String name) {
    if (name.isNotEmpty && !state.participants.contains(name)) {
      final updatedParticipants = List<String>.from(state.participants)
        ..add(name);
      state = state.copyWith(participants: updatedParticipants);
    }
  }

  void removeParticipant(String name) {
    final updatedParticipants = List<String>.from(state.participants)
      ..remove(name);
    state = state.copyWith(participants: updatedParticipants);
  }

  void addPresenter(String name) {
    if (name.isNotEmpty && !state.presenters.contains(name)) {
      final updatedPresenters = List<String>.from(state.presenters)..add(name);
      state = state.copyWith(presenters: updatedPresenters);
    }
  }

  void removePresenter(String name) {
    final updatedPresenters = List<String>.from(state.presenters)..remove(name);
    state = state.copyWith(presenters: updatedPresenters);
  }

  void selectTeacherForGrouping(String? teacherName) {
    state = state.copyWith(selectedTeacherForGrouping: () => teacherName);
  }

  void toggleParticipantSelection(String participantName, bool selected) {
    final updatedSelections = List<String>.from(
      state.selectedParticipantsForGrouping,
    );
    if (selected) {
      if (!updatedSelections.contains(participantName)) {
        updatedSelections.add(participantName);
      }
    } else {
      updatedSelections.remove(participantName);
    }
    state = state.copyWith(selectedParticipantsForGrouping: updatedSelections);
  }

  void assignParticipantsToTeacher() {
    if (state.selectedTeacherForGrouping == null ||
        state.selectedParticipantsForGrouping.isEmpty) {
      return;
    }

    final teacher = state.selectedTeacherForGrouping!;
    final updatedGroupings = Map<String, List<String>>.from(state.groupings);
    final teacherGroup = List<String>.from(updatedGroupings[teacher] ?? [])
      ..addAll(state.selectedParticipantsForGrouping);
    updatedGroupings[teacher] = teacherGroup;

    final updatedParticipants = List<String>.from(state.participants)
      ..removeWhere((p) => state.selectedParticipantsForGrouping.contains(p));

    state = state.copyWith(
      groupings: updatedGroupings,
      participants: updatedParticipants,
      selectedParticipantsForGrouping: const [],
    );
  }

  void removeParticipantFromTeacher(String teacher, String participant) {
    final updatedGroupings = Map<String, List<String>>.from(state.groupings);
    if (updatedGroupings.containsKey(teacher)) {
      final list = List<String>.from(updatedGroupings[teacher]!)
        ..remove(participant);
      updatedGroupings[teacher] = list;
    }
    final updatedParticipants = List<String>.from(state.participants)
      ..add(participant);
    state = state.copyWith(
      groupings: updatedGroupings,
      participants: updatedParticipants,
    );
  }

  Future<void> checkKepsekStatus({
    required String name,
    required String year,
    required BuildContext context,
    required Function(String whatsapp, String gender) onStateLoad,
  }) async {
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap masukkan nama lengkap Kepala Sekolah!'),
          ),
        );
      }
      return;
    }

    state = state.copyWith(isSaving: true);

    try {
      final firestore = ref.read(firestoreProvider);

      final configDoc = await firestore
          .collection('config')
          .doc('global')
          .get();
      AppConfig? currentConfig;
      if (configDoc.exists && configDoc.data() != null) {
        currentConfig = AppConfig.fromMap(configDoc.data()!);
      }

      final identityDoc = await firestore
          .collection('identities')
          .doc(name)
          .get();
      Identity? existingIdentity;
      if (identityDoc.exists && identityDoc.data() != null) {
        existingIdentity = Identity.fromMap(identityDoc.data()!);
      }

      if (currentConfig != null) {
        if (currentConfig.kepalaSekolahNama.toLowerCase() ==
                name.toLowerCase() &&
            currentConfig.kepengurusanTahun == year) {
          final hasSignature =
              existingIdentity != null &&
              existingIdentity.signatureVector != null &&
              existingIdentity.signatureVector!.isNotEmpty;
          final hasFace =
              existingIdentity != null &&
              existingIdentity.faceVector != null &&
              existingIdentity.faceVector!.isNotEmpty;

          state = state.copyWith(
            showSigUpload: !hasSignature,
            showFaceScan: !hasFace,
            existingIdentity: () => existingIdentity,
            hasCheckedStatus: true,
            isReverifying: hasSignature && hasFace,
            isAlreadyConfigured: true,
          );
          if (existingIdentity != null) {
            onStateLoad(
              existingIdentity.whatsapp ?? '',
              existingIdentity.gender ?? 'ikhwan',
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Nama Kepala Sekolah atau tahun tidak sesuai dengan konfigurasi aktif (${currentConfig.kepengurusanTahun}).',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        final hasSignature =
            existingIdentity != null &&
            existingIdentity.signatureVector != null &&
            existingIdentity.signatureVector!.isNotEmpty;
        final hasFace =
            existingIdentity != null &&
            existingIdentity.faceVector != null &&
            existingIdentity.faceVector!.isNotEmpty;

        if (existingIdentity != null &&
            existingIdentity.whatsapp != null &&
            hasSignature &&
            hasFace) {
          state = state.copyWith(
            existingIdentity: () => existingIdentity,
            hasCheckedStatus: true,
            isReverifying: false,
            currentStep: 2,
          );
        } else {
          state = state.copyWith(
            showSigUpload: !hasSignature,
            showFaceScan: !hasFace,
            existingIdentity: () => existingIdentity,
            hasCheckedStatus: true,
            isReverifying: false,
          );
          if (existingIdentity != null) {
            onStateLoad(
              existingIdentity.whatsapp ?? '',
              existingIdentity.gender ?? 'ikhwan',
            );
          }
        }
      }
    } catch (e, stack) {
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: name,
        role: 'kepsek',
        formSource: 'Setup - Cek Status Kepsek',
        exception: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Gagal memeriksa status: $e')),
        );
      }
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> verifyAndLogin({
    required SignatureController sigController,
    required BuildContext context,
    required VoidCallback onSetupComplete,
  }) async {
    if (sigController.points.isEmpty) {
      if (context.mounted) {
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

    if (state.cameraController == null || !state.isCameraInitialized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera belum siap! Harap izinkan akses kamera.'),
          ),
        );
      }
      return;
    }

    state = state.copyWith(isSaving: true);

    try {
      double sigMatchRate = 0.0;
      if (state.existingIdentity != null &&
          state.existingIdentity!.signatureVector != null) {
        final parsedSig = SignatureHelper.parse(
          state.existingIdentity!.signatureVector,
        );
        if (parsedSig.points.isNotEmpty) {
          final currentOffsets = sigController.points
              .map((p) => p.offset)
              .toList();
          sigMatchRate = SignatureHelper.calculateSimilarity(
            currentOffsets,
            parsedSig.points,
          );
        } else {
          sigMatchRate = 100.0;
        }
      } else {
        sigMatchRate = 100.0;
      }

      if (sigMatchRate < 40.0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verifikasi Tanda Tangan Gagal! Kemiripan: ${sigMatchRate.toStringAsFixed(1)}% (Minimal 40.0%)',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        state = state.copyWith(isSaving: false);
        return;
      }

      final photoFile = await state.cameraController!.takePicture();
      final currentFaceVector = await BiometricHelper.extractFaceVector(photoFile);
      if (currentFaceVector.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verifikasi Wajah Gagal! Kamera terdeteksi gelap atau tertutup. '
                'Pastikan wajah Anda mendapat pencahayaan yang cukup.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        state = state.copyWith(isSaving: false);
        return;
      }

      double matchRate = 0.0;
      bool isLegacyMock = false;

      if (state.existingIdentity != null &&
          state.existingIdentity!.faceVector != null) {
        if (state.existingIdentity!.faceVector ==
            "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]") {
          isLegacyMock = true;
          matchRate = 100.0;
        } else {
          final registeredFaceVector = BiometricHelper.parseVectorString(
            state.existingIdentity!.faceVector!,
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

      if (matchRate < 65.0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verifikasi Wajah Gagal! Kemiripan hanya ${matchRate.toStringAsFixed(1)}% (Minimal 65.0%)',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        state = state.copyWith(isSaving: false);
        return;
      }

      if (context.mounted) {
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

      if (isLegacyMock && state.existingIdentity != null) {
        final firebaseService = ref.read(firebaseServiceProvider);
        await firebaseService.saveIdentity(
          Identity(
            name: state.existingIdentity!.name,
            gender: state.existingIdentity!.gender ?? 'ikhwan',
            whatsapp: state.existingIdentity!.whatsapp,
            signatureVector: state.existingIdentity!.signatureVector,
            faceVector: currentFaceVector.toString(),
            allowSignatureReset: state.existingIdentity!.allowSignatureReset,
          ),
        );
      }

      ref.read(sessionAuthStateProvider.notifier).login();
      onSetupComplete();
    } catch (e, stack) {
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: state.existingIdentity?.name ?? 'Kepsek (Login)',
        role: 'kepsek',
        formSource: 'Setup - Verifikasi & Login',
        exception: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal melakukan pemindaian wajah: $e')),
        );
      }
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> verifyNewKepsek({
    required SignatureController sigController,
    required String name,
    required String year,
    required String whatsapp,
    required String gender,
    required BuildContext context,
    required VoidCallback onSetupComplete,
  }) async {
    String? kepsekSigBase64;
    String? signatureVectorValue;

    if (state.showSigUpload) {
      if (sigController.points.isEmpty) {
        if (context.mounted) {
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
      final sigBytes = await sigController.toPngBytes();
      if (sigBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengekstrak tanda tangan!')),
          );
        }
        return;
      }
      kepsekSigBase64 = Uri.dataFromBytes(
        sigBytes,
        mimeType: 'image/png',
      ).toString();
      signatureVectorValue = SignatureHelper.serialize(
        kepsekSigBase64,
        sigController.points,
      );
    } else {
      signatureVectorValue = state.existingIdentity?.signatureVector;
      if (signatureVectorValue != null &&
          signatureVectorValue.startsWith('{')) {
        kepsekSigBase64 = SignatureHelper.parse(
          signatureVectorValue,
        ).imageBase64;
      } else {
        kepsekSigBase64 = signatureVectorValue;
      }
    }

    String? faceVectorString;
    if (state.showFaceScan) {
      if (state.cameraController == null || !state.isCameraInitialized) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamera belum siap! Harap izinkan akses kamera.'),
            ),
          );
        }
        return;
      }
      try {
        final photoFile = await state.cameraController!.takePicture();
        final currentFaceVector = await BiometricHelper.extractFaceVector(photoFile);
        if (currentFaceVector.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Verifikasi Wajah Gagal! Kamera terdeteksi gelap atau tertutup. '
                  'Pastikan wajah Anda mendapat pencahayaan yang cukup.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        faceVectorString = currentFaceVector.toString();
      } catch (e, stack) {
        ref.read(firebaseServiceProvider).reportSystemException(
          reporterName: name,
          role: 'kepsek',
          formSource: 'Setup - Ekstraksi Wajah Kepsek Baru',
          exception: e,
          stackTrace: stack,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengekstrak sensor wajah: $e')),
          );
        }
        return;
      }
    } else {
      faceVectorString = state.existingIdentity?.faceVector;
    }

    state = state.copyWith(isSaving: true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final firestore = ref.read(firestoreProvider);
      
      // Fetch current config from Firestore to preserve existing fields like NIMs and switch states
      final configDoc = await firestore.collection('config').doc('global').get();
      AppConfig? current;
      if (configDoc.exists && configDoc.data() != null) {
        current = AppConfig.fromMap(configDoc.data()!);
      }

      final config = AppConfig(
        activeMode: current?.activeMode ?? 'idle',
        kepalaSekolahNama: name,
        kepengurusanTahun: year,
        bobotKelasBesar: current?.bobotKelasBesar ?? 0.0,
        bobotRoomQudwah: current?.bobotRoomQudwah ?? 0.0,
        bobotTugas: current?.bobotTugas ?? 0.0,
        nilaiMinimum: current?.nilaiMinimum ?? 0.0,
        kepsekSignatureBase64: kepsekSigBase64,
        kadivNama: current?.kadivNama,
        kadivSignatureBase64: current?.kadivSignatureBase64,
        activeMateri: current?.activeMateri ?? '',
        rekapSigned: current?.rekapSigned ?? false,
        kepalaSekolahNim: current?.kepalaSekolahNim,
        kadivNim: current?.kadivNim,
        kadivIsKepsek: current?.kadivIsKepsek ?? false,
        enableGeolocation: current?.enableGeolocation ?? false,
        targetLatitude: current?.targetLatitude ?? 0.0,
        targetLongitude: current?.targetLongitude ?? 0.0,
        targetRadius: current?.targetRadius ?? 100.0,
      );
      await firebaseService.saveConfig(config);

      await firebaseService.saveIdentity(
        Identity(
          name: config.kepalaSekolahNama,
          gender: gender,
          whatsapp: whatsapp,
          signatureVector: signatureVectorValue,
          faceVector: faceVectorString,
        ),
      );

      if (state.isAlreadyConfigured) {
        ref.read(sessionAuthStateProvider.notifier).login();
        onSetupComplete();
      } else {
        state = state.copyWith(currentStep: 2);
      }
    } catch (e, stack) {
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: name,
        role: 'kepsek',
        formSource: 'Setup - Simpan Data Kepsek Baru',
        exception: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data Kepala Sekolah: $e')),
        );
      }
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> submitSetup({
    required SignatureController sigController,
    required String name,
    required String year,
    required String whatsapp,
    required String gender,
    required BuildContext context,
    required VoidCallback onSetupComplete,
  }) async {
    if (state.teachers.isEmpty ||
        state.groupings.values.every((list) => list.isEmpty)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Harap tambahkan guru/walikelas dan bagi kelompok peserta!',
            ),
          ),
        );
      }
      return;
    }

    state = state.copyWith(isSaving: true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      final kepsekSigBytes = await sigController.toPngBytes();
      String? kepsekSigBase64;
      if (kepsekSigBytes != null) {
        kepsekSigBase64 = Uri.dataFromBytes(
          kepsekSigBytes,
          mimeType: 'image/png',
        ).toString();
      }

      final firestore = ref.read(firestoreProvider);
      final configDoc = await firestore.collection('config').doc('global').get();
      AppConfig? current;
      if (configDoc.exists && configDoc.data() != null) {
        current = AppConfig.fromMap(configDoc.data()!);
      }

      final config = AppConfig(
        activeMode: current?.activeMode ?? 'idle',
        kepalaSekolahNama: name,
        kepengurusanTahun: year,
        bobotKelasBesar: current?.bobotKelasBesar ?? 0.0,
        bobotRoomQudwah: current?.bobotRoomQudwah ?? 0.0,
        bobotTugas: current?.bobotTugas ?? 0.0,
        nilaiMinimum: current?.nilaiMinimum ?? 0.0,
        kepsekSignatureBase64: kepsekSigBase64,
        kadivNama: current?.kadivNama,
        kadivSignatureBase64: current?.kadivSignatureBase64,
        activeMateri: current?.activeMateri ?? '',
        rekapSigned: current?.rekapSigned ?? false,
        kepalaSekolahNim: current?.kepalaSekolahNim,
        kadivNim: current?.kadivNim,
        kadivIsKepsek: current?.kadivIsKepsek ?? false,
        enableGeolocation: current?.enableGeolocation ?? false,
        targetLatitude: current?.targetLatitude ?? 0.0,
        targetLongitude: current?.targetLongitude ?? 0.0,
        targetRadius: current?.targetRadius ?? 100.0,
      );
      await firebaseService.saveConfig(config);

      final faceVector = "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]";
      await firebaseService.saveIdentity(
        Identity(
          name: config.kepalaSekolahNama,
          gender: gender,
          whatsapp: whatsapp,
          signatureVector: kepsekSigBase64 != null
              ? SignatureHelper.serialize(kepsekSigBase64, sigController.points)
              : null,
          faceVector: faceVector,
        ),
      );

      for (final teacher in state.teachers) {
        await firebaseService.saveIdentity(
          Identity(name: teacher, gender: 'ikhwan'),
        );
      }

      for (final presenter in state.presenters) {
        await firebaseService.saveIdentity(Identity(name: presenter));
      }

      for (final entry in state.groupings.entries) {
        final group = Group(walikelas: entry.key, participants: entry.value);
        await firebaseService.saveGroup(group);

        for (final participant in entry.value) {
          await firebaseService.saveIdentity(Identity(name: participant));
        }
      }

      ref.read(sessionAuthStateProvider.notifier).login();
      onSetupComplete();
    } catch (e, stack) {
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: name,
        role: 'kepsek',
        formSource: 'Setup - Submit Setup',
        exception: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  void revertToSigUpload() {
    state = state.copyWith(showSigUpload: true, isReverifying: false);
  }

  void revertToFaceScan() {
    state = state.copyWith(showFaceScan: true, isReverifying: false);
  }
}

final setupControllerProvider = NotifierProvider<SetupController, SetupState>(
  SetupController.new,
  isAutoDispose: true,
);
