import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _navigationTimer;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _playSplashSound();
    _startTimer();
  }

  void _playSplashSound() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer?.play(AssetSource('audio/startup.wav'));
    } catch (e) {
      if (kDebugMode) {
        print('Audio playback exception: $e');
      }
    }
  }

  void _startTimer() {
    _navigationTimer = Timer(const Duration(milliseconds: 4400), () {
      if (mounted) {
        context.go('/gateway');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // بخش ۱: لوگو و عناوین فارسی
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/vetoapp.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'درگاه ملی وتواپ',
                          style: TextStyle(
                            fontFamily: 'B Mitra',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'همه پرسی . انتخابات . استیضاح',
                          style: TextStyle(
                            fontFamily: 'B Mitra',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // بخش ۲: نقشه ایران
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Image.asset(
                        'assets/images/persianmap.png',
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // بخش ۳: عناوین انگلیسی
                    const Column(
                      children: [
                        Text(
                          'VetoApp National Portal',
                          style: TextStyle(
                            fontFamily: 'B Mitra',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Referendum. Election. Impeachment.',
                          style: TextStyle(
                            fontFamily: 'B Mitra',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB71C1C),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
