import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:camera/camera.dart';
import '../setup_controller.dart';
import '../../shared/signature_upload_widget.dart';

class Step1KepsekVerification extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController kepsekController;
  final TextEditingController whatsappController;
  final TextEditingController tahunController;
  final String gender;
  final SignatureController kepsekSigController;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onSetupComplete;

  const Step1KepsekVerification({
    super.key,
    required this.formKey,
    required this.kepsekController,
    required this.whatsappController,
    required this.tahunController,
    required this.gender,
    required this.kepsekSigController,
    required this.onGenderChanged,
    required this.onSetupComplete,
  });

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: validator,
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
                  ),
                ),
                const Text(
                  "Sudah terdaftar di database cloud",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text(
              "Ubah",
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
              final isSelected = tahunController.text == yearStr;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () {
                    tahunController.text = yearStr;
                    onGenderChanged(gender); // trigger rebuild
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);

    if (!state.hasCheckedStatus) {
      return Form(
        key: formKey,
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
              controller: kepsekController,
              label: 'Nama Lengkap Kepala Sekolah',
              icon: Icons.person,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (val) {
                controller.checkKepsekStatus(
                  name: val,
                  year: tahunController.text,
                  context: context,
                  onStateLoad: (wa, g) {
                    whatsappController.text = wa;
                    onGenderChanged(g);
                  },
                );
              },
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
              onPressed: () {
                controller.checkKepsekStatus(
                  name: kepsekController.text,
                  year: tahunController.text,
                  context: context,
                  onStateLoad: (wa, g) {
                    whatsappController.text = wa;
                    onGenderChanged(g);
                  },
                );
              },
              child: state.isSaving
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

    if (state.isReverifying) {
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
            'Konfigurasi aktif mendeteksi ${kepsekController.text.trim()} (${tahunController.text.trim()}). Silakan verifikasi identitas Anda untuk masuk.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (state.isCameraInitialized && state.cameraController != null)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Pemindaian Wajah untuk Verifikasi Sesi",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.cameras.length > 1) ...[
                      const SizedBox(width: 8),
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
                const SizedBox(height: 16),
              ],
            ),

          SignatureUploadWidget(
            title: 'Gambarkan Tanda Tangan Anda (Untuk Verifikasi)',
            controller: kepsekSigController,
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
            onPressed: () {
              controller.verifyAndLogin(
                sigController: kepsekSigController,
                context: context,
                onSetupComplete: onSetupComplete,
              );
            },
            child: const Text(
              'VERIFIKASI & MASUK DASBOR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: controller.revertToSigUpload,
            child: const Text(
              'Bukan Anda? Kembali',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      );
    }

    return Form(
      key: formKey,
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
            'Isi data identitas lengkap untuk Kepala Sekolah: ${kepsekController.text.trim()}',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _buildTextField(
            controller: whatsappController,
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
                    selected: gender == 'ikhwan',
                    label: const Text('Ikhwan'),
                    selectedColor: Colors.tealAccent,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: gender == 'ikhwan' ? Colors.black : Colors.white,
                    ),
                    onSelected: (selected) => onGenderChanged('ikhwan'),
                  ),
                  ChoiceChip(
                    selected: gender == 'akhwat',
                    label: const Text('Akhwat'),
                    selectedColor: Colors.tealAccent,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: gender == 'akhwat' ? Colors.black : Colors.white,
                    ),
                    onSelected: (selected) => onGenderChanged('akhwat'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!state.showFaceScan)
            _buildRegisteredCard(
              title: "Vektor Wajah Kepala Sekolah",
              icon: Icons.face,
              onChange: controller.revertToFaceScan,
            )
          else if (state.isCameraInitialized && state.cameraController != null)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Pemindaian Vektor Wajah Kepala Sekolah",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.cameras.length > 1) ...[
                      const SizedBox(width: 8),
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
              ],
            ),
          const SizedBox(height: 24),

          if (!state.showSigUpload)
            _buildRegisteredCard(
              title: "Tanda Tangan Kepala Sekolah",
              icon: Icons.gesture,
              onChange: controller.revertToSigUpload,
            )
          else
            SignatureUploadWidget(
              title: 'Tanda Tangan Kepala Sekolah (Wajib)',
              controller: kepsekSigController,
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                controller.verifyNewKepsek(
                  sigController: kepsekSigController,
                  name: kepsekController.text.trim(),
                  year: tahunController.text.trim(),
                  whatsapp: whatsappController.text.trim(),
                  gender: gender,
                  context: context,
                  onSetupComplete: onSetupComplete,
                );
              }
            },
            child: const Text(
              'VERIFIKASI & LANJUTKAN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(setupControllerProvider.notifier).resetHasCheckedStatus();
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
}
