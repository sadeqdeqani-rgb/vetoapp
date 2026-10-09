import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/telegram_password_recovery.dart';

abstract interface class TelegramPasswordRecoveryRepository {
  Future<Either<Failure, TelegramPasswordRecoveryChallenge>> start({
    required String phoneNumber,
  });

  Future<Either<Failure, TelegramPasswordRecoveryStatus>> status({
    required String nonce,
  });
}
