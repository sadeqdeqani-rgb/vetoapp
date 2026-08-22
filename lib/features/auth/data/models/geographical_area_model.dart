import '../../domain/entities/geographical_area.dart';

class GeographicalAreaModel extends GeographicalArea {
  const GeographicalAreaModel({
    required super.id,
    required super.name,
    required super.type,
    super.parentId,
  });

  factory GeographicalAreaModel.fromJson(Map<String, dynamic> json) {
    return GeographicalAreaModel(
      id: (json['id'] as num).toInt(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}
