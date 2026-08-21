import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../models/geographical_area_model.dart';

class GeographicalAreaRepository {
  GeographicalAreaRepository({Dio? client}) : _client = client ?? createDioClient();

  final Dio _client;

  Future<List<GeographicalAreaModel>> children({int? parentId}) async {
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
        .map(GeographicalAreaModel.fromJson)
        .toList();
  }
}
