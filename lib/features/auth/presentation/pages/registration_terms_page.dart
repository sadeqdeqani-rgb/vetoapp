import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dartz/dartz.dart' show Either;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/di/injection.dart';
import '../../../content/domain/entities/public_content.dart';
import '../../../content/domain/usecases/get_public_content.dart';

/// صفحهٔ قوانین و مقررات پیش از شروع ثبت‌نام.
class RegistrationTermsPage extends StatefulWidget {
  const RegistrationTermsPage({super.key});

  @override
  State<RegistrationTermsPage> createState() => _RegistrationTermsPageState();
}

class _RegistrationTermsPageState extends State<RegistrationTermsPage> {
  bool _hasAcceptedTerms = false;
  late final Future<Either<Failure, PublicContent>> _termsFuture;

  @override
  void initState() {
    super.initState();
    _termsFuture = getIt<GetPublicTermsUseCase>()();
  }

  void _continue() {
    if (!_hasAcceptedTerms) {
      return;
    }

    context.pushNamed('register-phone');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: () => context.pop(),
      child: AuthFormCard(
        title: 'ثبت نام',
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<Either<Failure, PublicContent>>(
              future: _termsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data!.fold(
                  (failure) => Text(
                    failure.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  (content) => Text(
                    content.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: FutureBuilder<Either<Failure, PublicContent>>(
                future: _termsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return snapshot.data!.fold(
                    (failure) => Text(
                      failure.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    (content) => Text(
                      content.body,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.9,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 0),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _hasAcceptedTerms,
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onChanged:
                    (value) =>
                        setState(() => _hasAcceptedTerms = value ?? false),
                title: const Text(
                  'متن شرایط و قوانین را مطالعه کردم '
                  'و موافقم.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthActionButton(
              label: 'تأیید و ادامه',
              onPressed: _hasAcceptedTerms ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }
}
