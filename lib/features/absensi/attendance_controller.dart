import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';

class AttendanceState {
  final String? selectedName;
  final String gender;
  final String role;
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final String? capturedFaceVector;
  final List<CameraDescription> cameras;
  final int selectedCameraIndex;
  final bool isSubmitting;
  final String murobbi;
  final String whatsapp;
  final String errorReport;

  AttendanceState({
    this.selectedName,
    this.gender = 'ikhwan',
    this.role = 'peserta',
    this.cameraController,
    this.isCameraInitialized = false,
    this.capturedFaceVector,
    this.cameras = const [],
    this.selectedCameraIndex = 0,
    this.isSubmitting = false,
    this.murobbi = '',
    this.whatsapp = '',
    this.errorReport = '',
  });

  AttendanceState copyWith({
    String? Function()? selectedName,
    String? gender,
    String? role,
    CameraController? Function()? cameraController,
    bool? isCameraInitialized,
    String? Function()? capturedFaceVector,
    List<CameraDescription>? cameras,
    int? selectedCameraIndex,
    bool? isSubmitting,
    String? murobbi,
    String? whatsapp,
    String? errorReport,
  }) {
    return AttendanceState(
      selectedName: selectedName != null ? selectedName() : this.selectedName,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      cameraController: cameraController != null ? cameraController() : this.cameraController,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      capturedFaceVector: capturedFaceVector != null ? capturedFaceVector() : this.capturedFaceVector,
      cameras: cameras ?? this.cameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      murobbi: murobbi ?? this.murobbi,
      whatsapp: whatsapp ?? this.whatsapp,
      errorReport: errorReport ?? this.errorReport,
    );
  }
}

class AttendanceController extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    ref.onDispose(() {
      state.cameraController?.dispose();
    });
    Future.microtask(() => initializeCamera());
    return AttendanceState();
  }

  Future<void> initializeCamera() async {
    try {
      if (state.cameraController != null) {
        await state.cameraController!.dispose();
        state = state.copyWith(
          cameraController: () => null,
          isCameraInitialized: false,
        );
      }
      final camerasList = await availableCameras();
      if (camerasList.isNotEmpty) {
        int defaultIndex = 0;
        // Prioritize Front/Selfie Camera as default
        for (int i = 0; i < camerasList.length; i++) {
          if (camerasList[i].lensDirection == CameraLensDirection.front) {
            defaultIndex = i;
            break;
          }
        }
        final controller = CameraController(
          camerasList[defaultIndex],
          ResolutionPreset.low,
        );
        await controller.initialize();
        state = state.copyWith(
          cameras: camerasList,
          selectedCameraIndex: defaultIndex,
          cameraController: () => controller,
          isCameraInitialized: true,
        );
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> switchCamera() async {
    if (state.cameras.length <= 1) return;
    final nextIndex = (state.selectedCameraIndex + 1) % state.cameras.length;
    final selectedCamera = state.cameras[nextIndex];

    if (state.cameraController != null) {
      await state.cameraController!.dispose();
    }

    final newController = CameraController(
      selectedCamera,
      ResolutionPreset.low,
    );

    try {
      await newController.initialize();
      state = state.copyWith(
        selectedCameraIndex: nextIndex,
        cameraController: () => newController,
        isCameraInitialized: true,
      );
    } catch (e) {
      debugPrint("Camera switch error: $e");
    }
  }

  void updateRole(String role) {
    state = state.copyWith(role: role, selectedName: () => null);
  }

  void updateGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  void updateMurobbi(String murobbi) {
    state = state.copyWith(murobbi: murobbi);
  }

  void updateWhatsapp(String whatsapp) {
    state = state.copyWith(whatsapp: whatsapp);
  }

  void updateErrorReport(String report) {
    state = state.copyWith(errorReport: report);
  }

  Future<bool> handleNameChange(String? val, BuildContext context) async {
    if (val == null || val.trim().isEmpty) return false;
    state = state.copyWith(selectedName: () => val);

    final idents = ref.read(identitiesStreamProvider).value ?? [];
    final groups = ref.read(groupsStreamProvider).value ?? [];
    final walikelasNames = groups.map((g) => g.walikelas).toSet();

    final myIdent = idents.cast<Identity?>().firstWhere(
      (i) => i!.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => null,
    );

    if (myIdent != null) {
      state = state.copyWith(
        whatsapp: myIdent.whatsapp ?? state.whatsapp,
        gender: myIdent.gender ?? state.gender,
      );

      final murobbiName = myIdent.murobbi;
      if (murobbiName != null && murobbiName.isNotEmpty) {
        if (walikelasNames.contains(murobbiName)) {
          if (!context.mounted) return false;
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
          if (confirm == true) {
            state = state.copyWith(murobbi: murobbiName);
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<bool> submitAttendance({
    required List<int>? sigBytes,
    required BuildContext context,
  }) async {
    if (state.isSubmitting) return false;
    if (sigBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap tanda tangani pad absensi!')),
        );
      }
      return false;
    }

    final sigBase64 = Uri.dataFromBytes(
      sigBytes,
      mimeType: 'image/png',
    ).toString();

    final faceVector = state.capturedFaceVector ?? "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]";
    final name = state.role == 'tamu'
        ? 'Tamu - ${state.selectedName ?? "Anonim"}'
        : (state.selectedName ?? '');
    final role = state.role;

    state = state.copyWith(
      isCameraInitialized: false,
      isSubmitting: true,
    );

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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah melakukan absensi hari ini!'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        await initializeCamera();
        state = state.copyWith(isSubmitting: false);
        return false;
      }

      final att = Attendance(
        id: '',
        identityName: name,
        role: role,
        checkInTime: DateTime.now(),
        signatureBase64: sigBase64,
        faceVector: faceVector,
        errorReport: state.errorReport.trim(),
      );

      await ref.read(firebaseServiceProvider).addAttendance(att);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Absensi berhasil disimpan!')),
        );
      }
      state = AttendanceState(
        cameras: state.cameras,
        selectedCameraIndex: state.selectedCameraIndex,
      );
      await initializeCamera();
      return true;
    } catch (e) {
      debugPrint('[AttendanceForm] Error submitting: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Gagal mengirim absensi: $e')),
        );
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    }
  }
}

final attendanceControllerProvider = NotifierProvider<AttendanceController, AttendanceState>(
  AttendanceController.new,
);
