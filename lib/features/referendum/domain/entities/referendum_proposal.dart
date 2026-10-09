class ReferendumProposal {
  const ReferendumProposal({
    required this.processId,
    required this.title,
    required this.stateCode,
    required this.geographicLevelCode,
    required this.geographicId,
    required this.geographicLabel,
    required this.geographicName,
    required this.supportCount,
    required this.requiredSupportCount,
    required this.frozenPopulationTotal,
    this.hasSupported = false,
    this.userScopeMatches = false,
    this.canSupport = false,
    this.availableBreakdownLevels = const [],
  });

  final int processId;
  final String title;
  final String stateCode;
  final int geographicLevelCode;
  final int geographicId;
  final String geographicLabel;
  final String geographicName;
  final int supportCount;
  final int requiredSupportCount;
  final int frozenPopulationTotal;
  final bool hasSupported;
  final bool userScopeMatches;
  final bool canSupport;
  final List<int> availableBreakdownLevels;

  factory ReferendumProposal.fromJson(Map<String, dynamic> json) {
    return ReferendumProposal(
      processId: _asInt(json['process_id']),
      title: json['title']?.toString() ?? '',
      stateCode: json['state_code']?.toString() ?? 'Supporting',
      geographicLevelCode: _asInt(json['geographic_level_code']),
      geographicId: _asInt(json['geographic_id']),
      geographicLabel: json['geographic_label']?.toString() ?? '',
      geographicName: json['geographic_name']?.toString() ?? '',
      supportCount: _asInt(json['support_count']),
      requiredSupportCount: _asInt(json['required_support_count']),
      frozenPopulationTotal: _asInt(json['frozen_population_total']),
      hasSupported: json['has_supported'] == true,
      userScopeMatches: json['user_scope_matches'] == true,
      canSupport: json['can_support'] == true,
      availableBreakdownLevels:
          (json['available_breakdown_levels'] as List<dynamic>? ?? const [])
              .map(_asInt)
              .toList(growable: false),
    );
  }
}

class ProposalPage {
  const ProposalPage({
    required this.items,
    required this.page,
    required this.total,
  });

  final List<ReferendumProposal> items;
  final int page;
  final int total;
}

class ProposalSupportArea {
  const ProposalSupportArea({
    required this.geographicId,
    required this.name,
    required this.supportCount,
  });

  final int geographicId;
  final String name;
  final int supportCount;

  factory ProposalSupportArea.fromJson(Map<String, dynamic> json) =>
      ProposalSupportArea(
        geographicId: _asInt(json['geographic_id']),
        name: json['name']?.toString() ?? '',
        supportCount: _asInt(json['support_count']),
      );
}

class ProposalSupportPage {
  const ProposalSupportPage({required this.items, required this.total});

  final List<ProposalSupportArea> items;
  final int total;
}

class ProposalScope {
  const ProposalScope({
    required this.levelCode,
    required this.geographicId,
    required this.label,
    required this.name,
  });

  final int levelCode;
  final int geographicId;
  final String label;
  final String name;

  factory ProposalScope.fromJson(Map<String, dynamic> json) => ProposalScope(
    levelCode: _asInt(json['geographic_level_code']),
    geographicId: _asInt(json['geographic_id']),
    label: json['label']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

class ProposalPreview {
  const ProposalPreview({
    required this.normalizedSubject,
    required this.scopes,
  });

  final String normalizedSubject;
  final List<ProposalScope> scopes;
}

class ProposalCandidate {
  const ProposalCandidate({
    required this.processId,
    required this.title,
    required this.normalizedSubject,
    required this.similarity,
    required this.supportCount,
  });

  final int processId;
  final String title;
  final String normalizedSubject;
  final double similarity;
  final int supportCount;

  factory ProposalCandidate.fromJson(Map<String, dynamic> json) =>
      ProposalCandidate(
        processId: _asInt(json['process_id']),
        title: json['title']?.toString() ?? '',
        normalizedSubject: json['normalized_subject']?.toString() ?? '',
        similarity: double.tryParse('${json['similarity']}') ?? 0,
        supportCount: _asInt(json['support_count']),
      );
}

class ProposalCommitSelection {
  const ProposalCommitSelection({
    required this.subject,
    required this.geographicLevelCode,
    required this.geographicId,
    this.existingProcessId,
  });

  final String subject;
  final int geographicLevelCode;
  final int geographicId;
  final int? existingProcessId;

  factory ProposalCommitSelection.fromProposal(ReferendumProposal proposal) =>
      ProposalCommitSelection(
        subject: proposal.title,
        geographicLevelCode: proposal.geographicLevelCode,
        geographicId: proposal.geographicId,
        existingProcessId: proposal.processId,
      );
}

int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
