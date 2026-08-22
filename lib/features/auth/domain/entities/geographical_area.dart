class GeographicalArea {
  const GeographicalArea({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  final int id;
  final int? parentId;
  final String name;
  final String type;
}
