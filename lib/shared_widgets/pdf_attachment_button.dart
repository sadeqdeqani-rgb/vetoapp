import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_theme.dart';

class PdfAttachmentButton extends StatefulWidget {
  const PdfAttachmentButton({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<PdfAttachmentButton> createState() => _PdfAttachmentButtonState();
}

class _PdfAttachmentButtonState extends State<PdfAttachmentButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final source = await rootBundle.load(widget.assetPath);
      final directory = await getTemporaryDirectory();
      final fileName = widget.assetPath.split('/').last;
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(source.buffer.asUint8List(), flush: true);
      await const MethodChannel(
        'vetoapp/document',
      ).invokeMethod<void>('openPdf', {'path': file.path});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن فایل ضمیمه ناموفق بود.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _opening ? null : _open,
      icon:
          _opening
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(widget.title),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        alignment: Alignment.centerRight,
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}
