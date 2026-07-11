import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/knowledge_session.dart';
import '../models/session_health_metrics.dart';

/// Property Inspector's Session mode (Work Package 007 Property
/// Inspector: "Display: ... Session metadata"), shown when a Knowledge
/// Curation Session exists but nothing more specific (a candidate, a
/// relationship candidate, a source, an object, a relationship) is
/// selected. Work Package 011 STUDIO-TASK-000029: "Property Inspector:
/// Extend support for: ... Session Health" — added as a section here
/// rather than a separate mode, since a whole-session dashboard has no
/// "selection" to switch on the way every other mode does.
class SessionProperties extends StatelessWidget {
  const SessionProperties({
    required this.session,
    required this.sourceCount,
    required this.candidateCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.pendingCount,
    required this.relationshipCandidateCount,
    this.health,
    super.key,
  });

  final KnowledgeSession session;
  final int sourceCount;
  final int candidateCount;
  final int acceptedCount;
  final int rejectedCount;
  final int pendingCount;
  final int relationshipCandidateCount;

  /// The Session Health Dashboard's metrics (Work Package 011), `null`
  /// only defensively (the Connection Manager's `sessionHealth` getter
  /// is `null` exactly when [session] itself would be `null`, which
  /// cannot happen here since this widget requires a non-null session).
  final SessionHealthMetrics? health;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Session ID', value: session.id, monospace: true),
        PropertyField(label: 'Name', value: session.name),
        PropertyField(label: 'Repository', value: session.repositoryName),
        PropertyField(label: 'Author', value: session.author),
        PropertyField(label: 'Status', value: session.status.label + (session.archived ? ' (Archived)' : '')),
        PropertyField(label: 'Creation Time', value: formatDateTime(session.createdTime)),
        PropertyField(label: 'Last Modified', value: formatDateTime(session.lastModified)),
        PropertyField(label: 'Description', value: session.description.isEmpty ? '—' : session.description),
        PropertyField(label: 'Source Count', value: '$sourceCount'),
        PropertyField(label: 'Candidate Count', value: '$candidateCount'),
        PropertyField(label: 'Accepted Count', value: '$acceptedCount'),
        PropertyField(label: 'Rejected Count', value: '$rejectedCount'),
        PropertyField(label: 'Pending Count', value: '$pendingCount'),
        PropertyField(label: 'Relationship Candidate Count', value: '$relationshipCandidateCount'),
        if (health != null) _SessionHealthSection(health: health!),
      ],
    );
  }
}

/// The Session Health Dashboard (Work Package 011 STUDIO-TASK-000029):
/// "informational only" engineering quality metrics for the active
/// session.
class _SessionHealthSection extends StatelessWidget {
  const _SessionHealthSection({required this.health});

  final SessionHealthMetrics health;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Session Health',
          style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        PropertyField(label: 'Knowledge Candidates', value: '${health.candidateCount}'),
        PropertyField(label: 'Relationship Candidates', value: '${health.relationshipCandidateCount}'),
        PropertyField(label: 'Evidence Regions', value: '${health.evidenceRegionCount}'),
        PropertyField(label: 'Procedures', value: '${health.procedureCount}'),
        PropertyField(label: 'Specifications', value: '${health.specificationCount}'),
        PropertyField(
          label: 'Validation Errors',
          value: '${health.validationErrorCount}',
        ),
        PropertyField(label: 'Candidates Missing Evidence', value: '${health.candidatesMissingEvidenceCount}'),
        PropertyField(label: 'Duplicate Candidates', value: '${health.duplicateCandidateCount}'),
        PropertyField(label: 'Orphaned Candidates', value: '${health.orphanedCandidateCount}'),
        PropertyField(label: 'Relationship Density', value: health.relationshipDensity.toStringAsFixed(2)),
        PropertyField(
          label: 'Average Evidence Coverage',
          value: '${health.averageEvidenceCoveragePercent.toStringAsFixed(0)}%',
        ),
      ],
    );
  }
}
