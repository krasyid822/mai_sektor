import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import '../setup_controller.dart';

class Step2ManageData extends ConsumerStatefulWidget {
  final SignatureController kepsekSigController;
  final String kepsekName;
  final String tahun;
  final String whatsapp;
  final String gender;
  final VoidCallback onSetupComplete;
  final VoidCallback onGoBack;

  const Step2ManageData({
    super.key,
    required this.kepsekSigController,
    required this.kepsekName,
    required this.tahun,
    required this.whatsapp,
    required this.gender,
    required this.onSetupComplete,
    required this.onGoBack,
  });

  @override
  ConsumerState<Step2ManageData> createState() => _Step2ManageDataState();
}

class _Step2ManageDataState extends ConsumerState<Step2ManageData> {
  final _teacherController = TextEditingController();
  final _participantController = TextEditingController();
  final _presenterController = TextEditingController();

  @override
  void dispose() {
    _teacherController.dispose();
    _participantController.dispose();
    _presenterController.dispose();
    super.dispose();
  }

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
                onPressed: () {
                  onAdd();
                  controller.clear();
                },
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

  Widget _buildGroupingSection(SetupState state, SetupController controller) {
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
                  initialValue: state.selectedTeacherForGrouping,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Pilih Walikelas',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: state.teachers.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: controller.selectTeacherForGrouping,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sisa Peserta Belum Dikelompokkan: ${state.participants.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.selectedTeacherForGrouping != null && state.participants.isNotEmpty)
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
                  children: state.participants.map((p) {
                    final isSelected = state.selectedParticipantsForGrouping.contains(p);
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
                        controller.toggleParticipantSelection(p, selected);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: controller.assignParticipantsToTeacher,
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
          ...state.groupings.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '• ${entry.key}: ${entry.value.isEmpty ? "(Belum ada peserta)" : entry.value.join(", ")}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (entry.value.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.edit, color: Colors.white54, size: 16),
                      onSelected: (part) {
                        controller.removeParticipantFromTeacher(entry.key, part);
                      },
                      itemBuilder: (ctx) => entry.value.map((part) {
                        return PopupMenuItem(
                          value: part,
                          child: Text('Hapus $part'),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);

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
                onAdd: () => controller.addTeacher(_teacherController.text.trim()),
                items: state.teachers,
                onDelete: controller.removeTeacher,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSectionCard(
                title: 'Peserta Sekolah',
                icon: Icons.people,
                controller: _participantController,
                onAdd: () => controller.addParticipant(_participantController.text.trim()),
                items: state.participants,
                onDelete: controller.removeParticipant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionCard(
          title: 'Pembawa Materi',
          icon: Icons.record_voice_over,
          controller: _presenterController,
          onAdd: () => controller.addPresenter(_presenterController.text.trim()),
          items: state.presenters,
          onDelete: controller.removePresenter,
        ),
        const SizedBox(height: 24),

        if (state.teachers.isNotEmpty &&
            (state.participants.isNotEmpty || state.groupings.values.any((l) => l.isNotEmpty)))
          _buildGroupingSection(state, controller),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: widget.onGoBack,
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
                onPressed: state.isSaving
                    ? null
                    : () {
                        controller.submitSetup(
                          sigController: widget.kepsekSigController,
                          name: widget.kepsekName,
                          year: widget.tahun,
                          whatsapp: widget.whatsapp,
                          gender: widget.gender,
                          context: context,
                          onSetupComplete: widget.onSetupComplete,
                        );
                      },
                child: state.isSaving
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
}
