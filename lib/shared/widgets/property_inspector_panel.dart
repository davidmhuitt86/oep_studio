import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../knowledge/inspector/knowledge_candidate_properties.dart';
import '../../knowledge/inspector/relationship_candidate_properties.dart';
import '../../knowledge/inspector/session_properties.dart';
import '../../knowledge/inspector/source_material_properties.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import 'property_field.dart';

/// The Property Inspector (SDD-004, introduced as a placeholder in
/// Work Package 003; live Object data in Work Package 004; Relationship
/// mode in Work Package 005; Knowledge Candidate/Session modes in Work
/// Package 007; Relationship Candidate/Source Material modes in Work
/// Package 008). Automatically switches between modes based on the
/// Connection Manager's Current Selection — Knowledge Candidate,
/// Relationship Candidate, Source Material, Object, and Relationship
/// selection are mutually exclusive (see
/// `FoundationRuntimeNotifier.selectObject`/`selectRelationship`/
/// `selectKnowledgeCandidate`/`selectRelationshipCandidate`/
/// `selectSourceMaterial`); Session mode is shown only as a fallback,
/// when a Knowledge Curation Session exists but nothing more specific
/// is selected. Display only — no editing here, per SDD-011 and every
/// work package since (candidate editing happens through the
/// Engineering Review panel instead).
class PropertyInspectorPanel extends ConsumerWidget {
  const PropertyInspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final selectedCandidate = foundation.selectedCandidate;
    final selectedRelationshipCandidate = foundation.selectedRelationshipCandidate;
    final selectedSourceMaterial = foundation.selectedSourceMaterial;
    final selectedObject = foundation.selectedObject;
    final selectedRelationship = foundation.selectedRelationship;
    final knowledgeSession = foundation.knowledgeSession;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(left: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Property Inspector',
              style: TextStyle(
                color: StudioColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch ((
              selectedCandidate,
              selectedRelationshipCandidate,
              selectedSourceMaterial,
              selectedObject,
              selectedRelationship,
              knowledgeSession,
            )) {
              (final candidate?, _, _, _, _, _) => KnowledgeCandidateProperties(candidate: candidate),
              (_, final relationship?, _, _, _, _) => RelationshipCandidateProperties(
                relationship: relationship,
                sourceName: _candidateName(foundation.candidates, relationship.sourceCandidateId),
                targetName: _candidateName(foundation.candidates, relationship.targetCandidateId),
              ),
              (_, _, final source?, _, _, _) => SourceMaterialProperties(source: source),
              (_, _, _, final object?, _, _) => _ObjectProperties(object: object),
              (_, _, _, _, final relationship?, _) => _RelationshipProperties(relationship: relationship),
              (_, _, _, _, _, final session?) => SessionProperties(
                session: session,
                sourceCount: foundation.knowledgeSourceCount,
                candidateCount: foundation.knowledgeCandidateCount,
                acceptedCount: foundation.knowledgeAcceptedCount,
                rejectedCount: foundation.knowledgeRejectedCount,
                pendingCount: foundation.knowledgePendingCount,
                relationshipCandidateCount: foundation.knowledgeRelationshipCandidateCount,
              ),
              _ => const _NoSelection(),
            },
          ),
        ],
      ),
    );
  }

  static String _candidateName(List<KnowledgeCandidate> candidates, String candidateId) {
    for (final candidate in candidates) {
      if (candidate.id == candidateId) return candidate.name;
    }
    return candidateId;
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No Object Selected',
          textAlign: TextAlign.center,
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

class _ObjectProperties extends StatelessWidget {
  const _ObjectProperties({required this.object});

  final EngineeringObjectSummary object;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: object.name),
        PropertyField(label: 'Object ID', value: object.objectId, monospace: true),
        PropertyField(label: 'Object Type', value: object.category.label),
        PropertyField(label: 'Author', value: object.author),
        PropertyField(label: 'Version', value: object.version),
        PropertyField(label: 'Description', value: object.description.isEmpty ? '—' : object.description),
        PropertyField(label: 'Tags', value: object.tags.isEmpty ? '—' : object.tags.join(', ')),
      ],
    );
  }
}

class _RelationshipProperties extends StatelessWidget {
  const _RelationshipProperties({required this.relationship});

  final RelationshipSummary relationship;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship ID', value: relationship.relationshipId, monospace: true),
        PropertyField(label: 'Relationship Type', value: relationship.type.label),
        PropertyField(label: 'Source Object', value: relationship.sourceObjectName),
        PropertyField(label: 'Target Object', value: relationship.targetObjectName),
        PropertyField(label: 'Author', value: relationship.author),
        PropertyField(label: 'Description', value: relationship.description.isEmpty ? '—' : relationship.description),
        PropertyField(label: 'Created Date', value: relationship.createdUtc.isEmpty ? '—' : relationship.createdUtc),
      ],
    );
  }
}
