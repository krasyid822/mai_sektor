import 'dart:async';
import 'package:flutter/material.dart';

class InformativeSplashLoading extends StatefulWidget {
  final String statusMessage;

  const InformativeSplashLoading({
    super.key,
    this.statusMessage = 'Menyiapkan sistem MAI Sektor...',
  });

  @override
  State<InformativeSplashLoading> createState() => _InformativeSplashLoadingState();
}

class _InformativeSplashLoadingState extends State<InformativeSplashLoading> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  int _tipIndex = 0;
  Timer? _tipTimer;

  final List<String> _tips = [
    "Wali kelas dapat melakukan penilaian Room Qudwah langsung menggunakan QR Code.",
    "Tanda tangan peserta akan divalidasi kecocokannya dengan data pendaftaran (minimal 40% kemiripan).",
    "Sesi absensi, pretest, posttest, dan kontrak dikontrol secara real-time dari Dashboard Kepala Sekolah.",
    "Pemindaian wajah (Face Vector) digunakan untuk mempercepat proses absensi dan verifikasi masuk dasbor.",
    "Hasil rekapitulasi nilai dapat langsung dicetak ke dalam bentuk dokumen PDF resmi.",
    "Pembawa materi dan instruktur wajib diinputkan pada pretest/posttest untuk kelengkapan rekam jejak akademik.",
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Rotate tips every 4 seconds
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background subtle ambient lights
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    blurRadius: 120,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // Brand Logo / Icon with Pulse
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.tealAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.tealAccent.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.tealAccent,
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  const Text(
                    "MAI SEKTOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const Text(
                    "Sistem Manajemen & Penilaian Akademik",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Loader
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Loading Status
                  Text(
                    widget.statusMessage,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Informative Tip Card
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Container(
                      key: ValueKey<int>(_tipIndex),
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: Colors.amberAccent,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "INFO SISTEM",
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _tips[_tipIndex],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
