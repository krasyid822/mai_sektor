// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:camera/camera.dart';
import '../shared/firebase_service.dart';
import '../shared/signature_upload_widget.dart';
import '../shared/title_case_formatter.dart';
import 'attendance_controller.dart';
import '../shared/system_report_form.dart';

class AttendanceForm extends ConsumerStatefulWidget {
  const AttendanceForm({super.key});

  @override
  ConsumerState<AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends ConsumerState<AttendanceForm> {
  final _formKey = GlobalKey<FormState>();
  final _murobbiController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _nimController = TextEditingController();

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _murobbiController.dispose();
    _whatsappController.dispose();
    _nimController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);
    final controller = ref.read(attendanceControllerProvider.notifier);

    ref.listen<AttendanceState>(attendanceControllerProvider, (prev, next) {
      if (prev?.whatsapp != next.whatsapp) {
        _whatsappController.text = next.whatsapp;
      }
      if (prev?.murobbi != next.murobbi) {
        _murobbiController.text = next.murobbi;
      }
      if (prev?.nim != next.nim) {
        _nimController.text = next.nim;
      }
      if (next.selectedName == null && prev?.selectedName != null) {
        _formKey.currentState?.reset();
        _sigController.clear();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Center(
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
                    value: state.role,
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
                    onChanged: (val) {
                      if (val != null) {
                        controller.updateRole(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Name dropdown (if not guest)
                  if (state.role != 'tamu')
                    Consumer(
                      builder: (context, ref, _) {
                        final groups = ref.watch(groupsStreamProvider).value ?? [];
                        final walikelasNames = groups.map((g) => g.walikelas).toSet();
                        final participantNames = groups.expand((g) => g.participants).toSet();

                        List<String> filteredNames;
                        String labelText;
                        if (state.role == 'guru') {
                          filteredNames = walikelasNames.toList()..sort();
                          labelText = 'Nama Wali Kelas';
                        } else {
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
                          key: ValueKey(state.selectedName),
                          dropdownColor: const Color(0xFF1E293B),
                          value: (state.selectedName != null && filteredNames.contains(state.selectedName))
                              ? state.selectedName
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
                            await controller.handleNameChange(val, context);
                          },
                          validator: (val) => val == null ? '$labelText wajib dipilih' : null,
                        );
                      },
                    )
                   else
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [TitleCaseTextInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Nama Tamu',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      onChanged: (val) async {
                        await controller.handleNameChange(val, context);
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                    ),

                  const SizedBox(height: 16),

                  // Murobbi Auto matching input
                  TextFormField(
                    controller: _murobbiController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [TitleCaseTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Nama Murobbi / Mentor',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Masukkan nama pembina halaqah Anda',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onChanged: (val) => controller.updateMurobbi(val),
                  ),
                  const SizedBox(height: 16),

                  // NIM (Optional)
                  TextFormField(
                    controller: _nimController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nomor Induk Mahasiswa (NIM)',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Masukkan NIM Anda',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onChanged: (val) => controller.updateNim(val),
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
                    onChanged: (val) => controller.updateWhatsapp(val),
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
                        "Gender: ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      ChoiceChip(
                        selected: state.gender == 'ikhwan',
                        label: const Text('Ikhwan'),
                        selectedColor: Colors.tealAccent,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: state.gender == 'ikhwan' ? Colors.black : Colors.white,
                        ),
                        onSelected: (selected) => controller.updateGender('ikhwan'),
                      ),
                      ChoiceChip(
                        selected: state.gender == 'akhwat',
                        label: const Text('Akhwat'),
                        selectedColor: Colors.tealAccent,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: state.gender == 'akhwat' ? Colors.black : Colors.white,
                        ),
                        onSelected: (selected) => controller.updateGender('akhwat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (state.isCameraInitialized && state.cameraController != null)
                    Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            const Text(
                              "Pemindaian Vektor Wajah",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (state.cameras.length > 1)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.flip_camera_ios_outlined,
                                  color: Colors.tealAccent,
                                  size: 20,
                                ),
                                tooltip: 'Ganti Kamera',
                                onPressed: controller.switchCamera,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 150,
                            child: CameraPreview(state.cameraController!),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: const [
                                  Icon(Icons.videocam_off, color: Colors.white30),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Menunggu kamera aktif...",
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => controller.initializeCamera(),
                              icon: const Icon(Icons.videocam, size: 16, color: Colors.tealAccent),
                              label: const Text(
                                "Retry",
                                style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SignatureUploadWidget(
                    controller: _sigController,
                    title: "Tanda Tangan",
                    height: 150,
                    onCleared: () => _sigController.clear(),
                  ),
                  const SizedBox(height: 24),

                  // Error report
                  SystemReportForm(
                    getReporterName: () => state.selectedName ?? '',
                    role: state.role,
                    formSource: 'Absensi',
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              final sigBytes = await _sigController.toPngBytes();
                              final sigPoints = List.of(_sigController.points);
                              if (context.mounted) {
                                await controller.submitAttendance(
                                  sigBytes: sigBytes,
                                  sigPoints: sigPoints,
                                  context: context,
                                );
                              }
                            }
                          },
                    child: state.isSubmitting
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
          if (state.isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.tealAccent),
                        SizedBox(height: 20),
                        Text(
                          "Mencocokkan Wajah & Data...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Mohon tunggu sebentar",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
