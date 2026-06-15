import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'firebase_service.dart';

class SystemReportForm extends ConsumerStatefulWidget {
  final String Function() getReporterName;
  final String role;
  final String formSource;

  const SystemReportForm({
    super.key,
    required this.getReporterName,
    required this.role,
    required this.formSource,
  });

  @override
  ConsumerState<SystemReportForm> createState() => _SystemReportFormState();
}

class _SystemReportFormState extends ConsumerState<SystemReportForm> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan tidak boleh kosong!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final reporterName = widget.getReporterName();
      final finalName = reporterName.isEmpty ? 'Anonim' : reporterName;
      final firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.addSystemReport(
        SystemReport(
          id: '',
          reporterName: finalName,
          role: widget.role,
          formSource: widget.formSource,
          description: text,
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan kesalahan sistem berhasil dikirim!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Laporkan Masalah / Kendala Sistem',
                  style: TextStyle(
                    color: Colors.amberAccent.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Tuliskan detail kesalahan sistem di sini...',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitReport,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send, size: 14),
              label: const Text(
                'Kirim Laporan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
