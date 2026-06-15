import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'setup_controller.dart';
import 'widgets/step1_kepsek_verification.dart';
import 'widgets/step2_manage_data.dart';

class SetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupScreen({super.key, required this.onSetupComplete});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _kepsekController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _tahunController = TextEditingController();
  String _gender = 'ikhwan';

  final SignatureController _kepsekSigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.teal,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _tahunController.text = "2026/2027";
  }

  @override
  void dispose() {
    _kepsekController.dispose();
    _tahunController.dispose();
    _whatsappController.dispose();
    _kepsekSigController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: state.currentStep == 1
                  ? Step1KepsekVerification(
                      formKey: _formKeyStep1,
                      kepsekController: _kepsekController,
                      whatsappController: _whatsappController,
                      tahunController: _tahunController,
                      gender: _gender,
                      kepsekSigController: _kepsekSigController,
                      onGenderChanged: (val) => setState(() => _gender = val),
                      onSetupComplete: widget.onSetupComplete,
                    )
                  : Step2ManageData(
                      kepsekSigController: _kepsekSigController,
                      kepsekName: _kepsekController.text,
                      tahun: _tahunController.text,
                      whatsapp: _whatsappController.text,
                      gender: _gender,
                      onSetupComplete: widget.onSetupComplete,
                      onGoBack: () {
                        ref.read(setupControllerProvider.notifier).updateStep(1);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
