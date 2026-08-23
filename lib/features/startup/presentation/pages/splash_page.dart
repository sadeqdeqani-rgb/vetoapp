import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    _navigationTimer = Timer(const Duration(milliseconds: 8800), () {
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
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Column(
                      children: [
                        Image(
                          image: AssetImage('assets/images/vetoapp.png'),
                          width: 110,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 12),
                        _OutlinedText(text: 'وِتواَپ', fontSize: 26),
                        SizedBox(height: 6),
                        _OutlinedText(
                          text: 'همه پرسی . انتخابات . استیضاح',
                          fontSize: 16,
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Image(
                        image: AssetImage('assets/images/persianmap.png'),
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Column(
                      children: [
                        _OutlinedText(
                          text: 'VetoApp',
                          fontSize: 20,
                          letterSpacing: 0.8,
                        ),
                        SizedBox(height: 6),
                        _OutlinedText(
                          text: 'Referendum. Election. Impeachment.',
                          fontSize: 14,
                          letterSpacing: 0.5,
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

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({
    required this.text,
    required this.fontSize,
    this.letterSpacing,
  });

  final String text;
  final double fontSize;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            foreground:
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.2
                  ..color = AppTheme.surface,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: AppTheme.textPrimary,
            shadows: const [
              Shadow(
                color: AppTheme.shadow,
                offset: Offset(1.5, 2.0),
                blurRadius: 3.5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
