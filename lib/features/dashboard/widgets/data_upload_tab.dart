import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/firebase_service.dart';
import '../../shared/models.dart';
import '../dashboard_controller.dart';

class DataUploadTab extends ConsumerWidget {
  const DataUploadTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);
    final uploadedFilesAsync = ref.watch(filesStreamProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return groupsAsync.when(
      data: (groups) {
        final participantNames = groups.expand((g) => g.participants).toSet();
        return identitiesAsync.when(
          data: (identities) {
            return uploadedFilesAsync.when(
              data: (uploadedFiles) {
                final participantsOnly = participantNames.map((pName) {
                  return identities.cast<Identity?>().firstWhere(
                    (i) => i!.name == pName,
                    orElse: () =>
                        Identity(name: pName, allowSignatureReset: false),
                  )!;
                }).toList();

                if (participantsOnly.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "Belum ada peserta terdaftar. Harap daftarkan peserta terlebih dahulu di tab Kelola Profil & Kelompok.",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participantsOnly.length,
                        itemBuilder: (context, index) {
                          final id = participantsOnly[index];
                          final hasResume = uploadedFiles.contains(
                            'resume-${id.name}',
                          );
                          final hasRetyping = uploadedFiles.contains(
                            'retyping-${id.name}',
                          );
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;

                                  final infoWidget = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Identity.displayName(
                                          id,
                                          participantsOnly,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        id.gender == 'ikhwan'
                                            ? "Ikhwan"
                                            : (id.gender == 'akhwat' ? "Akhwat" : "-"),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  );

                                  final actionsWidget = Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Row(
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
                                                  .updateSignatureResetPermission(
                                                    id.name,
                                                    val,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
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
                                        ],
                                      ),
                                      // --- PDF RESUME BUTTONS ---
                                      if (hasResume)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(
                                            Icons.download,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "Unduh Resume (PDF)",
                                          ),
                                          onPressed: () {
                                            controller.downloadResume(
                                              participantName: id.name,
                                              context: context,
                                            );
                                          },
                                        ),
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.upload_file,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          "Upload Resume (PDF)",
                                        ),
                                        onPressed: () {
                                          controller.pickAndUploadFile(
                                            type: "resume",
                                            id: id.name,
                                            context: context,
                                          );
                                        },
                                      ),
                                      // --- RETYPING RESUME BUTTONS ---
                                      if (hasRetyping)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(
                                            Icons.description,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "Unduh Retyping (TXT)",
                                          ),
                                          onPressed: () {
                                            controller.downloadRetyping(
                                              participantName: id.name,
                                              context: context,
                                            );
                                          },
                                        ),
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.text_fields,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          "Upload Retyping (TXT)",
                                        ),
                                        onPressed: () {
                                          controller.pickAndUploadFile(
                                            type: "retyping",
                                            id: id.name,
                                            context: context,
                                          );
                                        },
                                      ),
                                    ],
                                  );

                                  if (isMobile) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        infoWidget,
                                        const Divider(
                                          color: Colors.white10,
                                          height: 24,
                                        ),
                                        actionsWidget,
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [infoWidget, actionsWidget],
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  "Error loading files: $e",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              "Error loading identities: $e",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          "Error loading groups: $e",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
