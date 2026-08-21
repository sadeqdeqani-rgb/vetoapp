class GeographicalAreaModel {
  const GeographicalAreaModel({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  final int id;
  final int? parentId;
  final String name;
  final String type;

  factory GeographicalAreaModel.fromJson(Map<String, dynamic> json) {
    return GeographicalAreaModel(
      id: (json['id'] as num).toInt(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}
