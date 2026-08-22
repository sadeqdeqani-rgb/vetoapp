import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/geographical_area.dart';

/// آداپتور قدیمی دریافت حوزه‌ها برای تست/سازگاری موقت.
///
/// این کلاس مستقیماً در Presentation یا DI اصلی استفاده نمی‌شود. قرارداد
/// رسمی این قابلیت [RegistrationRepository] است و پیاده‌سازی production آن
/// در [RegistrationRepositoryImpl] قرار دارد. پس از قطعی شدن API می‌توان این
/// فایل را بدون تغییر در صفحات حذف کرد.
@Deprecated(
  'از RegistrationRepository و RegistrationRepositoryImpl استفاده شود.',
)
class GeographicalAreaRepository {
  GeographicalAreaRepository({Dio? client}) : _client = client ?? createDioClient();

  final Dio _client;

  Future<List<GeographicalArea>> children({int? parentId}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/geographical-areas',
        queryParameters: parentId == null ? null : {'parent_id': parentId},
      );

      final data = response.data?['data'];
      if (data is! List) {
        throw const FormatException('پاسخ حوزه‌های جغرافیایی نامعتبر است.');
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => GeographicalArea(
              id: json['id'] as int,
              parentId: json['parent_id'] as int?,
              name: json['name'] as String,
              type: json['type'] as String,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw NetworkFailure(
        'دریافت حوزه‌های جغرافیایی انجام نشد: ${error.message}',
      );
    }
  }
}
