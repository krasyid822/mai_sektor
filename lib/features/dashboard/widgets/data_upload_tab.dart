import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/firebase_service.dart';
import '../dashboard_controller.dart';

class DataUploadTab extends ConsumerWidget {
  const DataUploadTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groups = ref.watch(groupsStreamProvider).value ?? [];
    final participantNames = groups.expand((g) => g.participants).toSet();
    final uploadedFilesAsync = ref.watch(filesStreamProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return identitiesAsync.when(
      data: (identities) {
        return uploadedFilesAsync.when(
          data: (uploadedFiles) {
            final participantsOnly = identities
                .where((id) => participantNames.contains(id.name))
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Unggah Berkas/Tugas Resume Peserta",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF1E293B),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: participantsOnly.length,
                      itemBuilder: (context, index) {
                        final id = participantsOnly[index];
                        final hasResume = uploadedFiles.contains('resume-${id.name}');
                        return ListTile(
                          title: Text(
                            id.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            id.gender == 'ikhwan' ? "Ikhwan" : "Akhwat",
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                id.allowSignatureReset
                                    ? "Reset Ttd Diizinkan"
                                    : "Izinkan Ganti Ttd",
                                style: TextStyle(
                                  color: id.allowSignatureReset
                                      ? Colors.tealAccent
                                      : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Switch(
                                value: id.allowSignatureReset,
                                activeThumbColor: Colors.tealAccent,
                                onChanged: (val) async {
                                  await ref
                                      .read(firebaseServiceProvider)
                                      .updateSignatureResetPermission(id.name, val);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          val
                                              ? 'Ganti tanda tangan diizinkan untuk ${id.name}!'
                                              : 'Izin ganti tanda tangan dibatalkan untuk ${id.name}!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              if (hasResume) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.download),
                                  label: const Text("Download"),
                                  onPressed: () {
                                    controller.downloadResume(
                                      participantName: id.name,
                                      context: context,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: const Text("Upload Resume (PDF)"),
                                onPressed: () {
                                  controller.pickAndUploadFile(
                                    type: "resume",
                                    id: id.name,
                                    context: context,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Error: $e")),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }
}
