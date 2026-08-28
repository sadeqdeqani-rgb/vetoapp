import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/public_content.dart';
import '../../domain/repositories/public_content_repository.dart';

class PublicContentRepositoryImpl implements PublicContentRepository {
  const PublicContentRepositoryImpl(this._client);

  final Dio _client;

  @override
  Future<Either<Failure, PublicContent>> getIntroduction() =>
      _getContent('/api/v1/content/introduction', 'دریافت معرفی سامانه');

  @override
  Future<Either<Failure, PublicContent>> getTerms() =>
      _getContent('/api/v1/content/terms', 'دریافت قوانین و مقررات');

  @override
  Future<Either<Failure, PublicIntroductionVideo>>
  getIntroductionVideo() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/content/introduction-video',
      );
      final data = response.data?['data'];
      if (data is! Map) {
        return const Left(ServerFailure('اطلاعات ویدیوی معرفی نامعتبر است.'));
      }

      return Right(
        PublicIntroductionVideo(
          id: _int(data['introduction_video_id']),
          versionNumber: _int(data['version_number']),
          title: '${data['title'] ?? ''}',
          videoUrl: '${data['video_url'] ?? ''}',
          posterUrl: data['poster_url']?.toString(),
          durationSeconds: _nullableInt(data['duration_seconds']),
          publishedAt: _date(data['published_at']),
        ),
      );
    } on DioException {
      return const Left(
        NetworkFailure('ارتباط با سرور محتوای سامانه برقرار نشد.'),
      );
    } catch (_) {
      return const Left(ServerFailure('دریافت ویدیوی معرفی ناموفق بود.'));
    }
  }

  Future<Either<Failure, PublicContent>> _getContent(
    String path,
    String operation,
  ) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (data is! Map) {
        return Left(ServerFailure('$operation ناموفق بود.'));
      }

      return Right(
        PublicContent(
          id: _int(data['introduction_content_id'] ?? data['terms_content_id']),
          versionNumber: _int(data['version_number']),
          title: '${data['title'] ?? ''}',
          body: '${data['body_text'] ?? ''}',
          publishedAt: _date(data['published_at']),
        ),
      );
    } on DioException {
      return const Left(
        NetworkFailure('ارتباط با سرور محتوای سامانه برقرار نشد.'),
      );
    } catch (_) {
      return Left(ServerFailure('$operation ناموفق بود.'));
    }
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.parse('$value');

  int? _nullableInt(dynamic value) =>
      value == null
          ? null
          : (value is num ? value.toInt() : int.tryParse('$value'));

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');
}
