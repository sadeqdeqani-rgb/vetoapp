import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_message_dialog.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    if (!mounted || _checkingConnection) return;
    setState(() => _checkingConnection = true);
    final startedAt = DateTime.now();
    const baseUrl = String.fromEnvironment(
      'VETO_API_BASE_URL',
      defaultValue: 'https://api.vetoapp.net',
    );
    var connected = false;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
    ));
    try {
      await dio.get('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/up');
      connected = true;
    } catch (_) {
      connected = false;
    } finally {
      dio.close(force: true);
    }
    if (!mounted) return;
    final remaining = const Duration(milliseconds: 650) - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;
    setState(() => _checkingConnection = false);
    if (connected) {
      context.go('/gateway');
      return;
    }
    await showAppMessageDialog<void>(
      context: context,
      title: 'اتصال اینترنت برقرار نیست',
      message: 'برای ورود و استفاده از خدمات وتواپ، اتصال اینترنت خود را بررسی کنید و دوباره تلاش کنید.',
      tone: AppMessageTone.warning,
      barrierDismissible: false,
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تلاش دوباره'),
        ),
      ],
    );
    if (mounted) _checkConnection();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: AppTheme.pageBackground,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Image(image: AssetImage('assets/images/vetoapp.png'), width: 110, height: 110, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const _OutlinedText(text: 'وِتواَپ', fontSize: 26),
              const SizedBox(height: 6),
              const _OutlinedText(text: 'همه پرسی . انتخابات . استیضاح', fontSize: 16),
              if (_checkingConnection) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(strokeWidth: 2.5),
              ],
            ]),
          ),
        ),
      ),
    ),
  );
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(fontFamily: AppTheme.fontFamily, fontSize: fontSize, fontWeight: FontWeight.bold);
    return Stack(alignment: Alignment.center, children: [
      Text(text, textAlign: TextAlign.center, style: baseStyle.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = AppTheme.surface)),
      Text(text, textAlign: TextAlign.center, style: baseStyle.copyWith(color: AppTheme.textPrimary, shadows: const [Shadow(color: AppTheme.shadow, offset: Offset(1.5, 2), blurRadius: 3.5)])),
    ]);
  }
}
