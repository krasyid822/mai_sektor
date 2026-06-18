import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';
import '../../shared/signature_upload_widget.dart';
import '../../shared/title_case_formatter.dart';
import '../dashboard_controller.dart';

class ManageProfileAndGroupsTab extends ConsumerStatefulWidget {
  final AppConfig config;

  const ManageProfileAndGroupsTab({super.key, required this.config});

  @override
  ConsumerState<ManageProfileAndGroupsTab> createState() =>
      _ManageProfileAndGroupsTabState();
}

class _ManageProfileAndGroupsTabState
    extends ConsumerState<ManageProfileAndGroupsTab> {
  final _newTeacherController = TextEditingController();
  final _newParticipantController = TextEditingController();
  final _kadivController = TextEditingController();
  final _kadivSigController = SignatureController();

  @override
  void dispose() {
    _newTeacherController.dispose();
    _newParticipantController.dispose();
    _kadivController.dispose();
    _kadivSigController.dispose();
    super.dispose();
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);
    final firebaseService = ref.read(firebaseServiceProvider);
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. MANAGE PROFILE KEPALA SEKOLAH
          identitiesAsync.when(
            data: (idents) {
              final kepsekId = idents.firstWhere(
                (id) =>
                    id.name.toLowerCase() ==
                    widget.config.kepalaSekolahNama.toLowerCase(),
                orElse: () => Identity(name: widget.config.kepalaSekolahNama),
              );

              return Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.tealAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Kelola Profil Kepala Sekolah",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildReadOnlyField(
                              "Nama Kepala Sekolah",
                              kepsekId.name,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildReadOnlyField(
                              "Tahun Kepengurusan",
                              widget.config.kepengurusanTahun,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: kepsekId.whatsapp ?? '',
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Nomor WhatsApp",
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: Colors.tealAccent,
                                ),
                              ),
                              onChanged: (val) async {
                                final updatedId = Identity(
                                  name: kepsekId.name,
                                  gender: kepsekId.gender,
                                  whatsapp: val.trim(),
                                  signatureVector: kepsekId.signatureVector,
                                  faceVector: kepsekId.faceVector,
                                  allowSignatureReset:
                                      kepsekId.allowSignatureReset,
                                );
                                await firebaseService.saveIdentity(updatedId);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  widget.config.kepalaSekolahNim ?? '',
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "NIM Kepala Sekolah",
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(
                                  Icons.badge,
                                  color: Colors.tealAccent,
                                ),
                              ),
                              onChanged: (val) async {
                                final updatedConfig = AppConfig(
                                  activeMode: widget.config.activeMode,
                                  kepalaSekolahNama:
                                      widget.config.kepalaSekolahNama,
                                  kepengurusanTahun:
                                      widget.config.kepengurusanTahun,
                                  bobotKelasBesar:
                                      widget.config.bobotKelasBesar,
                                  bobotRoomQudwah:
                                      widget.config.bobotRoomQudwah,
                                  bobotTugas: widget.config.bobotTugas,
                                  nilaiMinimum: widget.config.nilaiMinimum,
                                  kepsekSignatureBase64:
                                      widget.config.kepsekSignatureBase64,
                                  kadivNama: widget.config.kadivNama,
                                  kadivSignatureBase64:
                                      widget.config.kadivSignatureBase64,
                                  activeMateri: widget.config.activeMateri,
                                  rekapSigned: widget.config.rekapSigned,
                                  kepalaSekolahNim: val.trim().isEmpty
                                      ? null
                                      : val.trim(),
                                  kadivNim: widget.config.kadivNim,
                                  kadivIsKepsek: widget.config.kadivIsKepsek,
                                );
                                await firebaseService.saveConfig(updatedConfig);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Jenis Kelamin",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      selected: kepsekId.gender == 'ikhwan',
                                      label: const Text('Ikhwan'),
                                      selectedColor: Colors.tealAccent,
                                      checkmarkColor: Colors.black,
                                      labelStyle: TextStyle(
                                        color: kepsekId.gender == 'ikhwan'
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                      onSelected: (selected) async {
                                        final updatedId = Identity(
                                          name: kepsekId.name,
                                          gender: 'ikhwan',
                                          whatsapp: kepsekId.whatsapp,
                                          signatureVector:
                                              kepsekId.signatureVector,
                                          faceVector: kepsekId.faceVector,
                                          allowSignatureReset:
                                              kepsekId.allowSignatureReset,
                                        );
                                        await firebaseService.saveIdentity(
                                          updatedId,
                                        );
                                      },
                                    ),
                                    ChoiceChip(
                                      selected: kepsekId.gender == 'akhwat',
                                      label: const Text('Akhwat'),
                                      selectedColor: Colors.tealAccent,
                                      checkmarkColor: Colors.black,
                                      labelStyle: TextStyle(
                                        color: kepsekId.gender == 'akhwat'
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                      onSelected: (selected) async {
                                        final updatedId = Identity(
                                          name: kepsekId.name,
                                          gender: 'akhwat',
                                          whatsapp: kepsekId.whatsapp,
                                          signatureVector:
                                              kepsekId.signatureVector,
                                          faceVector: kepsekId.faceVector,
                                          allowSignatureReset:
                                              kepsekId.allowSignatureReset,
                                        );
                                        await firebaseService.saveIdentity(
                                          updatedId,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            "Status Pemindaian Wajah: ",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            kepsekId.faceVector != null
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: kepsekId.faceVector != null
                                ? Colors.tealAccent
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            kepsekId.faceVector != null
                                ? "Vektor Wajah Aktif"
                                : "Belum Dipindai",
                            style: TextStyle(
                              color: kepsekId.faceVector != null
                                  ? Colors.tealAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error load profile: $e")),
          ),
          const SizedBox(height: 24),

          // 1b. MANAGE PROFILE KEPALA DIVISI MAI
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.tealAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Kelola Profil Kepala Divisi MAI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.config.kadivIsKepsek) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _kadivController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [TitleCaseTextInputFormatter()],
                      decoration: InputDecoration(
                        labelText: "Nama Kepala Divisi MAI",
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText:
                            widget.config.kadivNama ?? "Masukkan nama Kadiv...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: widget.config.kadivNim ?? '',
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "NIM Kepala Divisi MAI",
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.badge, color: Colors.tealAccent),
                      ),
                      onChanged: (val) async {
                        final updatedConfig = AppConfig(
                          activeMode: widget.config.activeMode,
                          kepalaSekolahNama: widget.config.kepalaSekolahNama,
                          kepengurusanTahun: widget.config.kepengurusanTahun,
                          bobotKelasBesar: widget.config.bobotKelasBesar,
                          bobotRoomQudwah: widget.config.bobotRoomQudwah,
                          bobotTugas: widget.config.bobotTugas,
                          nilaiMinimum: widget.config.nilaiMinimum,
                          kepsekSignatureBase64:
                              widget.config.kepsekSignatureBase64,
                          kadivNama: widget.config.kadivNama,
                          kadivSignatureBase64:
                              widget.config.kadivSignatureBase64,
                          activeMateri: widget.config.activeMateri,
                          rekapSigned: widget.config.rekapSigned,
                          kepalaSekolahNim: widget.config.kepalaSekolahNim,
                          kadivNim: val.trim().isEmpty ? null : val.trim(),
                          kadivIsKepsek: widget.config.kadivIsKepsek,
                        );
                        await firebaseService.saveConfig(updatedConfig);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Toggle: Kadiv merangkap sebagai Kepala Sekolah
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Kadiv merangkap sebagai Kepala Sekolah",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Jika aktif, kolom Kadiv tidak akan ditampilkan "
                                "di sertifikat (digantikan Kepala Sekolah).",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: widget.config.kadivIsKepsek,
                          activeThumbColor: Colors.tealAccent,
                          onChanged: (val) async {
                            final updatedConfig = AppConfig(
                              activeMode: widget.config.activeMode,
                              kepalaSekolahNama:
                                  widget.config.kepalaSekolahNama,
                              kepengurusanTahun:
                                  widget.config.kepengurusanTahun,
                              bobotKelasBesar: widget.config.bobotKelasBesar,
                              bobotRoomQudwah: widget.config.bobotRoomQudwah,
                              bobotTugas: widget.config.bobotTugas,
                              nilaiMinimum: widget.config.nilaiMinimum,
                              kepsekSignatureBase64:
                                  widget.config.kepsekSignatureBase64,
                              kadivNama: widget.config.kadivNama,
                              kadivSignatureBase64:
                                  widget.config.kadivSignatureBase64,
                              activeMateri: widget.config.activeMateri,
                              rekapSigned: widget.config.rekapSigned,
                              kepalaSekolahNim: widget.config.kepalaSekolahNim,
                              kadivNim: widget.config.kadivNim,
                              kadivIsKepsek: val,
                            );
                            await firebaseService.saveConfig(updatedConfig);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!widget.config.kadivIsKepsek) ...[
                    const SizedBox(height: 16),
                    SignatureUploadWidget(
                      controller: _kadivSigController,
                      title: "Tanda Tangan Kepala Divisi MAI",
                      height: 120,
                      onCleared: () async {
                        await firebaseService.saveConfig(
                          AppConfig(
                            activeMode: widget.config.activeMode,
                            kepalaSekolahNama: widget.config.kepalaSekolahNama,
                            kepengurusanTahun: widget.config.kepengurusanTahun,
                            bobotKelasBesar: widget.config.bobotKelasBesar,
                            bobotRoomQudwah: widget.config.bobotRoomQudwah,
                            bobotTugas: widget.config.bobotTugas,
                            nilaiMinimum: widget.config.nilaiMinimum,
                            kepsekSignatureBase64:
                                widget.config.kepsekSignatureBase64,
                            kadivNama: widget.config.kadivNama,
                            kadivSignatureBase64: null,
                            activeMateri: widget.config.activeMateri,
                            kepalaSekolahNim: widget.config.kepalaSekolahNim,
                            kadivNim: widget.config.kadivNim,
                            kadivIsKepsek: widget.config.kadivIsKepsek,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text("SIMPAN PROFIL KADIV"),
                      onPressed: () async {
                        final kadivName = _kadivController.text.trim();
                        if (kadivName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Harap masukkan nama Kepala Divisi MAI!',
                              ),
                            ),
                          );
                          return;
                        }

                        String? kadivSigBase64;
                        if (_kadivSigController.value.isNotEmpty) {
                          final sigBytes = await _kadivSigController.toPngBytes();
                          if (sigBytes != null) {
                            kadivSigBase64 =
                                'data:image/png;base64,${base64Encode(sigBytes)}';
                          }
                        }

                        await firebaseService.saveConfig(
                          AppConfig(
                            activeMode: widget.config.activeMode,
                            kepalaSekolahNama: widget.config.kepalaSekolahNama,
                            kepengurusanTahun: widget.config.kepengurusanTahun,
                            bobotKelasBesar: widget.config.bobotKelasBesar,
                            bobotRoomQudwah: widget.config.bobotRoomQudwah,
                            bobotTugas: widget.config.bobotTugas,
                            nilaiMinimum: widget.config.nilaiMinimum,
                            kepsekSignatureBase64:
                                widget.config.kepsekSignatureBase64,
                            kadivNama: kadivName,
                            kadivSignatureBase64: kadivSigBase64,
                            activeMateri: widget.config.activeMateri,
                            kepalaSekolahNim: widget.config.kepalaSekolahNim,
                            kadivNim: widget.config.kadivNim,
                            kadivIsKepsek: widget.config.kadivIsKepsek,
                          ),
                        );

                        await firebaseService.saveIdentity(
                          Identity(name: kadivName),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Profil Kepala Divisi MAI berhasil disimpan!',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. MANAGE SMALL CLASS GROUPS
          groupsAsync.when(
            data: (groups) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      final addTeacherCard = Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Tambah Walikelas (Guru)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newTeacherController,
                                style: const TextStyle(color: Colors.white),
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  TitleCaseTextInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  hintText: "Nama Guru/Walikelas...",
                                  hintStyle: TextStyle(color: Colors.white30),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text("TAMBAH KELOMPOK"),
                                onPressed: () async {
                                  final name = _newTeacherController.text
                                      .trim();
                                  if (name.isNotEmpty) {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    await firebaseService.saveGroup(
                                      Group(walikelas: name, participants: []),
                                    );
                                    await firebaseService.saveIdentity(
                                      Identity(name: name, gender: 'ikhwan'),
                                    );
                                    _newTeacherController.clear();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Kelompok Walikelas $name berhasil ditambahkan!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );

                      final addParticipantCard = Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Tambah & Kelompokkan Peserta",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newParticipantController,
                                style: const TextStyle(color: Colors.white),
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  TitleCaseTextInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  hintText: "Nama Peserta Baru...",
                                  hintStyle: TextStyle(color: Colors.white30),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E293B),
                                initialValue:
                                    groups.any(
                                      (g) =>
                                          g.walikelas ==
                                          state
                                              .selectedTeacherForNewParticipant,
                                    )
                                    ? state.selectedTeacherForNewParticipant
                                    : null,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "Pilih Walikelas",
                                  labelStyle: TextStyle(color: Colors.white70),
                                ),
                                items: groups.map((g) {
                                  return DropdownMenuItem(
                                    value: g.walikelas,
                                    child: Text(g.walikelas),
                                  );
                                }).toList(),
                                onChanged:
                                    controller.selectTeacherForNewParticipant,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.person_add),
                                label: const Text("TAMBAH PESERTA"),
                                onPressed: () async {
                                  final pName = _newParticipantController.text
                                      .trim();
                                  final wName =
                                      state.selectedTeacherForNewParticipant;
                                  if (pName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Harap masukkan nama peserta!',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (wName == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Harap pilih Walikelas!'),
                                      ),
                                    );
                                    return;
                                  }

                                  final targetGroup = groups.firstWhere(
                                    (g) => g.walikelas == wName,
                                  );
                                  final updatedParticipants = List<String>.from(
                                    targetGroup.participants,
                                  );
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  if (!updatedParticipants.contains(pName)) {
                                    updatedParticipants.add(pName);
                                    await firebaseService.saveGroup(
                                      Group(
                                        walikelas: wName,
                                        participants: updatedParticipants,
                                      ),
                                    );
                                    await firebaseService.saveIdentity(
                                      Identity(name: pName),
                                    );
                                  }

                                  _newParticipantController.clear();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Peserta $pName dimasukkan ke kelompok $wName!',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            addTeacherCard,
                            const SizedBox(height: 16),
                            addParticipantCard,
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: addTeacherCard),
                            const SizedBox(width: 16),
                            Expanded(child: addParticipantCard),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Daftar Kelompok Kelas Kecil",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.school,
                                          color: Colors.tealAccent,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Kelompok: ${group.walikelas}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Hapus Kelompok?"),
                                          content: Text(
                                            "Apakah Anda yakin ingin menghapus kelompok Walikelas ${group.walikelas}?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text("Batal"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                "Hapus",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await firebaseService.deleteGroup(
                                          group.walikelas,
                                        );
                                        await firebaseService.deleteIdentity(
                                          group.walikelas,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Kelompok ${group.walikelas} berhasil dihapus!',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12),
                              group.participants.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 24,
                                        ),
                                        child: Text(
                                          "Belum ada peserta",
                                          style: TextStyle(
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: group.participants.map((pName) {
                                        return Chip(
                                          label: Text(
                                            pName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.05),
                                  deleteIcon: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.redAccent,
                                          ),
                                          onDeleted: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("Hapus Peserta"),
                                                content: Text(
                                                  "Apakah Anda yakin ingin mengeluarkan peserta $pName dan menghapus data identitasnya secara permanen?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx, false),
                                                    child: const Text("Batal"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx, true),
                                                    child: const Text(
                                                      "Hapus",
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm != true) return;

                                            final updatedParticipants =
                                                List<String>.from(
                                                  group.participants,
                                                )..remove(pName);
                                            await firebaseService.saveGroup(
                                              Group(
                                                walikelas: group.walikelas,
                                                participants:
                                                    updatedParticipants,
                                              ),
                                            );
                                            await firebaseService
                                                .deleteIdentity(pName);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Peserta $pName dikeluarkan dari kelompok!',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error load groups: $e")),
          ),
        ],
      ),
    );
  }
}
