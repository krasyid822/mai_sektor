import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/firebase_service.dart';

class SignedContractsTab extends ConsumerWidget {
  const SignedContractsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceStreamProvider);

    return attendanceAsync.when(
      data: (attendances) {
        final contracts = attendances
            .where((att) => att.role == 'kontrak' && att.signatureBase64 != null)
            .toList();

        if (contracts.isEmpty) {
          return const Center(
            child: Text(
              "Belum ada peserta yang menandatangani Kontrak Belajar.",
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final contract = contracts[index];
            Uint8List? sigBytes;
            try {
              final base64Str = contract.signatureBase64!.split(',').last;
              sigBytes = base64Decode(base64Str);
            } catch (_) {}

            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10),
              ),
              child: ExpansionTile(
                iconColor: Colors.tealAccent,
                collapsedIconColor: Colors.white70,
                title: Text(
                  contract.identityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Ditandatangani pada: ${contract.checkInTime.toLocal().toString().split('.')[0]}",
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "DOKUMEN KONTRAK BELAJAR",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Dengan menandatangani akad kontrak belajar ini, peserta program MAI Sektor berkomitmen penuh untuk:\n"
                            "1. Menghadiri seluruh rangkaian kelas besar (1 & 2) tepat waktu.\n"
                            "2. Hadir secara berkala pada pertemuan Room Qudwah (kelas kecil) setiap minggunya sebanyak 12 pertemuan.\n"
                            "3. Menyelesaikan dan mengumpulkan tugas resume materi perkuliahan tepat waktu sebelum tenggat waktu yang ditentukan.\n"
                            "4. Menjaga adab, tata tertib, dan akhlakul karimah selama berlangsungnya program.\n"
                            "5. Siap menerima konsekuensi penilaian kelulusan sesuai dengan kebijakan kelulusan minimum yang ditetapkan Kepala Sekolah.\n\n"
                            "Demikian kontrak belajar ini dibuat secara sadar tanpa paksaan dari pihak manapun.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  "Peserta,",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                if (sigBytes != null)
                                  Container(
                                    width: 120,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Image.memory(sigBytes, fit: BoxFit.contain),
                                  )
                                else
                                  const SizedBox(height: 50, child: Text("Ttd Tidak Terbaca", style: TextStyle(color: Colors.redAccent))),
                                const SizedBox(height: 8),
                                Text(
                                  contract.identityName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text("Error: $e", style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
