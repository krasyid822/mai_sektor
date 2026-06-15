import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models.dart';
import '../../shared/firebase_service.dart';

class ManageBiometricsTab extends ConsumerStatefulWidget {
  const ManageBiometricsTab({super.key});

  @override
  ConsumerState<ManageBiometricsTab> createState() => _ManageBiometricsTabState();
}

class _ManageBiometricsTabState extends ConsumerState<ManageBiometricsTab> {
  Future<bool> _showConfirmDialog(String title, String content) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBiometricStatusCell(
    bool hasData,
    String activeText,
    String inactiveText,
    IconData icon,
    VoidCallback onDelete,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasData ? Icons.check_circle : Icons.error_outline,
          color: hasData ? Colors.tealAccent : Colors.white30,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasData ? activeText : inactiveText,
            style: TextStyle(
              color: hasData ? Colors.tealAccent : Colors.white38,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasData)
          IconButton(
            icon: const Icon(Icons.delete_forever, size: 18),
            color: Colors.redAccent.withValues(alpha: 0.7),
            hoverColor: Colors.redAccent.withValues(alpha: 0.1),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Hapus",
          ),
      ],
    );
  }

  Widget _buildIdentityBiometricsCard(
    Identity id,
    FirebaseService firebaseService,
  ) {
    final hasFace = id.faceVector != null && id.faceVector!.isNotEmpty;
    final hasSig = id.signatureVector != null && id.signatureVector!.isNotEmpty;

    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              id.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            if (id.whatsapp != null || id.gender != null) ...[
              Text(
                "Info: ${id.gender ?? '-'} | WA: ${id.whatsapp ?? '-'}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        hasFace ? Icons.face : Icons.face_retouching_off,
                        color: hasFace ? Colors.tealAccent : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasFace ? "Wajah Aktif" : "Belum Dipindai",
                        style: TextStyle(
                          color: hasFace ? Colors.tealAccent : Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                      if (hasFace) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await _showConfirmDialog(
                              "Hapus Vektor Wajah?",
                              "Apakah Anda yakin ingin menghapus vektor wajah untuk ${id.name}?",
                            );
                            if (confirm) {
                              final updated = Identity(
                                name: id.name,
                                gender: id.gender,
                                whatsapp: id.whatsapp,
                                signatureVector: id.signatureVector,
                                faceVector: null,
                                allowSignatureReset: id.allowSignatureReset,
                              );
                              await firebaseService.saveIdentity(updated);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        hasSig ? Icons.gesture : Icons.draw,
                        color: hasSig ? Colors.tealAccent : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasSig ? "Ttd Terdaftar" : "Belum Ttd",
                        style: TextStyle(
                          color: hasSig ? Colors.tealAccent : Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                      if (hasSig) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await _showConfirmDialog(
                              "Hapus Tanda Tangan?",
                              "Apakah Anda yakin ingin menghapus tanda tangan untuk ${id.name}?",
                            );
                            if (confirm) {
                              final updated = Identity(
                                name: id.name,
                                gender: id.gender,
                                whatsapp: id.whatsapp,
                                signatureVector: null,
                                faceVector: id.faceVector,
                                allowSignatureReset: id.allowSignatureReset,
                              );
                              await firebaseService.saveIdentity(updated);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identitiesAsync = ref.watch(identitiesStreamProvider);
    final firebaseService = ref.read(firebaseServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      Icon(Icons.fingerprint, color: Colors.tealAccent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "Kelola Kredensial & Biometrik Identitas",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Daftar seluruh identitas (Kepala Sekolah, Wali Kelas, Peserta, Pemateri) yang terdaftar di dalam sistem. Anda dapat memantau dan menghapus vektor wajah atau tanda tangan mereka.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  identitiesAsync.when(
                    data: (idents) {
                      if (idents.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "Belum ada identitas yang terdaftar.",
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;

                          if (isMobile) {
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: idents.length,
                              itemBuilder: (context, idx) {
                                final id = idents[idx];
                                return _buildIdentityBiometricsCard(id, firebaseService);
                              },
                            );
                          }

                          return Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.2),
                              3: FlexColumnWidth(2.5),
                              4: FlexColumnWidth(2.5),
                            },
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
                                ),
                                children: [
                                  _buildTableHeader("Nama Lengkap"),
                                  _buildTableHeader("WhatsApp"),
                                  _buildTableHeader("Gender"),
                                  _buildTableHeader("Status Wajah"),
                                  _buildTableHeader("Status Ttd"),
                                ],
                              ),
                              ...idents.map((id) {
                                final hasFace = id.faceVector != null && id.faceVector!.isNotEmpty;
                                final hasSig = id.signatureVector != null && id.signatureVector!.isNotEmpty;

                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Text(
                                        id.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(id.whatsapp ?? '-', style: const TextStyle(color: Colors.white70)),
                                    Text(id.gender ?? '-', style: const TextStyle(color: Colors.white70)),
                                    _buildBiometricStatusCell(
                                      hasFace,
                                      "Wajah Aktif",
                                      "Belum Dipindai",
                                      Icons.face,
                                      () async {
                                        final confirm = await _showConfirmDialog(
                                          "Hapus Vektor Wajah?",
                                          "Apakah Anda yakin ingin menghapus vektor wajah untuk ${id.name}?",
                                        );
                                        if (confirm) {
                                          final updated = Identity(
                                            name: id.name,
                                            gender: id.gender,
                                            whatsapp: id.whatsapp,
                                            signatureVector: id.signatureVector,
                                            faceVector: null,
                                            allowSignatureReset: id.allowSignatureReset,
                                          );
                                          await firebaseService.saveIdentity(updated);
                                        }
                                      },
                                    ),
                                    _buildBiometricStatusCell(
                                      hasSig,
                                      "Ttd Terdaftar",
                                      "Belum Ttd",
                                      Icons.gesture,
                                      () async {
                                        final confirm = await _showConfirmDialog(
                                          "Hapus Tanda Tangan?",
                                          "Apakah Anda yakin ingin menghapus tanda tangan untuk ${id.name}?",
                                        );
                                        if (confirm) {
                                          final updated = Identity(
                                            name: id.name,
                                            gender: id.gender,
                                            whatsapp: id.whatsapp,
                                            signatureVector: null,
                                            faceVector: id.faceVector,
                                            allowSignatureReset: id.allowSignatureReset,
                                          );
                                          await firebaseService.saveIdentity(updated);
                                        }
                                      },
                                    ),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text("Gagal memuat identitas: $err", style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
