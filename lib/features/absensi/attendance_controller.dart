import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import '../shared/models.dart';
import '../shared/firebase_service.dart';
import '../shared/biometric_helper.dart';
import '../shared/signature_helper.dart';

class AttendanceState {
  final String? selectedName;
  final String? gender;
  final String role;
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final String? capturedFaceVector;
  final List<CameraDescription> cameras;
  final int selectedCameraIndex;
  final bool isSubmitting;
  final String murobbi;
  final String whatsapp;
  final String nim;
  AttendanceState({
    this.selectedName,
    this.gender,
    this.role = 'peserta',
    this.cameraController,
    this.isCameraInitialized = false,
    this.capturedFaceVector,
    this.cameras = const [],
    this.selectedCameraIndex = 0,
    this.isSubmitting = false,
    this.murobbi = '',
    this.whatsapp = '',
    this.nim = '',
  });

  AttendanceState copyWith({
    String? Function()? selectedName,
    String? Function()? gender,
    String? role,
    CameraController? Function()? cameraController,
    bool? isCameraInitialized,
    String? Function()? capturedFaceVector,
    List<CameraDescription>? cameras,
    int? selectedCameraIndex,
    bool? isSubmitting,
    String? murobbi,
    String? whatsapp,
    String? nim,
  }) {
    return AttendanceState(
      selectedName: selectedName != null ? selectedName() : this.selectedName,
      gender: gender != null ? gender() : this.gender,
      role: role ?? this.role,
      cameraController: cameraController != null ? cameraController() : this.cameraController,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      capturedFaceVector: capturedFaceVector != null ? capturedFaceVector() : this.capturedFaceVector,
      cameras: cameras ?? this.cameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      murobbi: murobbi ?? this.murobbi,
      whatsapp: whatsapp ?? this.whatsapp,
      nim: nim ?? this.nim,
    );
  }
}

class AttendanceController extends Notifier<AttendanceState> {
  CameraController? _cameraController;

  @override
  AttendanceState build() {
    ref.onDispose(() {
      _cameraController?.dispose();
    });
    Future.microtask(() => initializeCamera());
    return AttendanceState();
  }

  Future<void> initializeCamera() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
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
        reporterName: state.selectedName ?? 'System',
        role: state.role,
        formSource: 'Absensi - Inisialisasi Kamera',
        exception: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> switchCamera() async {
    if (state.cameras.length <= 1) return;
    final nextIndex = (state.selectedCameraIndex + 1) % state.cameras.length;
    final selectedCamera = state.cameras[nextIndex];

    state = state.copyWith(
      isCameraInitialized: false,
    );

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
        reporterName: state.selectedName ?? 'System',
        role: state.role,
        formSource: 'Absensi - Switch Kamera',
        exception: e,
        stackTrace: stack,
      );
      // Fallback to re-initialize camera
      await initializeCamera();
    }
  }

  void updateRole(String role) {
    state = state.copyWith(role: role, selectedName: () => null, nim: '', gender: () => null);
  }

  void updateGender(String gender) {
    state = state.copyWith(gender: () => gender);
  }

  void updateMurobbi(String murobbi) {
    state = state.copyWith(murobbi: murobbi);
  }

  void updateWhatsapp(String whatsapp) {
    state = state.copyWith(whatsapp: whatsapp);
  }

  void updateNim(String nim) {
    state = state.copyWith(nim: nim);
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
        gender: () => myIdent.gender ?? state.gender,
        nim: myIdent.nim ?? state.nim,
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
    required List<Point> sigPoints,
    required BuildContext context,
  }) async {
    if (state.isSubmitting) return false;
    if (state.gender == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap pilih Jenis Kelamin/Gender Anda!'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      return false;
    }
    if (sigBytes == null || sigPoints.isEmpty) {
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

    final selectedName = state.selectedName ?? '';
    final name = state.role == 'tamu'
        ? 'Tamu - ${selectedName.isNotEmpty ? selectedName : "Anonim"}'
        : selectedName;
    final role = state.role;

    state = state.copyWith(
      isSubmitting: true,
    );

    String faceVectorString = '';

    try {
      // --- BIOMETRIC VERIFICATION for peserta and guru (walikelas) ---
      if ((role == 'peserta' || role == 'guru') && selectedName.isNotEmpty) {
        final idents = ref.read(identitiesStreamProvider).value ?? [];
        final existingIdent = idents.cast<Identity?>().firstWhere(
          (i) => i!.name.toLowerCase() == selectedName.toLowerCase(),
          orElse: () => null,
        );

        if (existingIdent != null) {
          String? finalFaceVector = existingIdent.faceVector;
          String? finalSignatureVector = existingIdent.signatureVector;
          bool signatureResetAllowed = existingIdent.allowSignatureReset;

          // --- Face Verification ---
          if (state.isCameraInitialized && state.cameraController != null) {
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
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
                state = state.copyWith(isSubmitting: false);
                await initializeCamera();
                return false;
              }
              faceVectorString = currentFaceVector.toString();

              if (existingIdent.faceVector != null &&
                  existingIdent.faceVector!.isNotEmpty &&
                  existingIdent.faceVector != "[0.12, -0.45, 0.89, 0.23, 0.54, -0.01]") {
                final registeredFaceVector = BiometricHelper.parseVectorString(existingIdent.faceVector!);
                final faceMatch = BiometricHelper.calculateSimilarity(currentFaceVector, registeredFaceVector) * 100.0;

                if (faceMatch < 65.0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Verifikasi Wajah Gagal! Kemiripan hanya ${faceMatch.toStringAsFixed(1)}% (Minimal 65.0%). '
                          'Pastikan wajah Anda terlihat jelas di kamera.',
                        ),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                  state = state.copyWith(isSubmitting: false);
                  await initializeCamera();
                  return false;
                }
              } else {
                // Legacy mock or null: save the new face vector
                finalFaceVector = faceVectorString;
              }
            } catch (e, stack) {
              debugPrint('[Attendance] Face verification skipped: $e');
              ref.read(firebaseServiceProvider).reportSystemException(
                reporterName: selectedName,
                role: role,
                formSource: 'Absensi - Verifikasi Wajah',
                exception: e,
                stackTrace: stack,
              );
            }
          }

          // --- Signature Verification ---
          if (existingIdent.signatureVector != null &&
              existingIdent.signatureVector!.isNotEmpty) {
            final parsedSig = SignatureHelper.parse(existingIdent.signatureVector!);
            if (parsedSig.points.isNotEmpty) {
              final currentOffsets = sigPoints.map((p) => p.offset).toList();
              final sigMatchRate = SignatureHelper.calculateSimilarity(currentOffsets, parsedSig.points);

              if (sigMatchRate < 35.0) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Verifikasi Tanda Tangan Gagal! Kemiripan hanya ${sigMatchRate.toStringAsFixed(1)}% (Minimal 35.0%). '
                        'Silakan tanda tangan sesuai pola Anda.',
                      ),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
                state = state.copyWith(isSubmitting: false);
                await initializeCamera();
                return false;
              }
              if (existingIdent.allowSignatureReset) {
                finalSignatureVector = SignatureHelper.serialize(sigBase64, sigPoints);
                signatureResetAllowed = false;
              }
            } else {
              // Parsed sig points empty: register signature
              finalSignatureVector = SignatureHelper.serialize(sigBase64, sigPoints);
              signatureResetAllowed = false;
            }
          } else {
            // No signature registered yet
            finalSignatureVector = SignatureHelper.serialize(sigBase64, sigPoints);
            signatureResetAllowed = false;
          }

          // --- Save/Update Identity in Firestore ---
          await ref.read(firebaseServiceProvider).saveIdentity(
            Identity(
              name: existingIdent.name,
              nim: state.nim.trim().isNotEmpty ? state.nim.trim() : existingIdent.nim,
              gender: state.gender,
              whatsapp: state.whatsapp,
              signatureVector: finalSignatureVector,
              faceVector: finalFaceVector,
              allowSignatureReset: signatureResetAllowed,
            ),
          );
        }
      }

      // --- Duplicate Check-in Guard ---
      final firestore = ref.read(firestoreProvider);
      final todayStart = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0,
      );
      final activeMateri = ref.read(configStreamProvider).value?.activeMateri ?? '';

      final existingAttendance = await firestore
          .collection('attendance')
          .where('identityName', isEqualTo: name)
          .where('role', isEqualTo: role)
          .get();

      bool alreadyCheckedIn = false;
      String snackBarMsg = 'Anda sudah melakukan absensi hari ini!';

      if (role == 'peserta' && activeMateri.isNotEmpty) {
        final group1 = ['Urgensi Membina', 'Al Qudwah Qobla Dakwah'];
        final group2 = ['Manajemen Mentoring Aktif', 'Seni Menyentuh Hati'];

        final isGroup1 = group1.contains(activeMateri);
        final isGroup2 = group2.contains(activeMateri);

        for (final doc in existingAttendance.docs) {
          final data = doc.data();
          final attMateri = data['materi'] as String? ?? '';
          if (isGroup1 && (group1.contains(attMateri) || attMateri.isEmpty)) {
            alreadyCheckedIn = true;
            snackBarMsg = 'Anda sudah melakukan absensi untuk sesi Kelas Besar 1!';
            break;
          } else if (isGroup2 && group2.contains(attMateri)) {
            alreadyCheckedIn = true;
            snackBarMsg = 'Anda sudah melakukan absensi untuk sesi Kelas Besar 2!';
            break;
          } else if (!isGroup1 && !isGroup2 && attMateri == activeMateri) {
            alreadyCheckedIn = true;
            snackBarMsg = 'Anda sudah melakukan absensi untuk materi ini!';
            break;
          }
        }
      } else {
        alreadyCheckedIn = existingAttendance.docs.any((doc) {
          final checkInTime = doc.data()['checkInTime'] as Timestamp?;
          if (checkInTime == null) return false;
          return checkInTime.toDate().isAfter(todayStart);
        });
      }

      if (alreadyCheckedIn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackBarMsg),
              backgroundColor: Colors.amber,
            ),
          );
        }
        await initializeCamera();
        state = state.copyWith(isSubmitting: false);
        return false;
      }

      // --- Save Attendance ---
      final att = Attendance(
        id: '',
        identityName: name,
        role: role,
        checkInTime: DateTime.now(),
        signatureBase64: sigBase64,
        faceVector: faceVectorString.isNotEmpty ? faceVectorString : null,
        absenceReason: null,
        materi: activeMateri,
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
    } catch (e, stack) {
      debugPrint('[AttendanceForm] Error submitting: $e');
      ref.read(firebaseServiceProvider).reportSystemException(
        reporterName: selectedName,
        role: role,
        formSource: 'Absensi - Pengiriman Absensi',
        exception: e,
        stackTrace: stack,
      );
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
  isAutoDispose: true,
);
