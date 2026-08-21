enum DashboardItemId {
  registerTopic,
  registerRequest,
  introduce,
  registeredUsers,
}

class DashboardItem {
  final DashboardItemId id;
  final String label;
  final String iconAsset;

  const DashboardItem({
    required this.id,
    required this.label,
    required this.iconAsset,
  });
}
