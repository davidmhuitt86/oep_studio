import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';

/// The Property Inspector (SDD-004, introduced as a placeholder in
/// Work Package 003; live Object data in Work Package 004; Relationship
/// mode in Work Package 005). Automatically switches between Object
/// mode and Relationship mode based on the Connection Manager's Current
/// Selection — the two are mutually exclusive (see
/// `FoundationRuntimeNotifier.selectObject`/`selectRelationship`).
/// Display only — no editing, per SDD-011 and every work package since.
class PropertyInspectorPanel extends ConsumerWidget {
  const PropertyInspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedObject = ref.watch(foundationRuntimeServiceProvider.select((state) => state.selectedObject));
    final selectedRelationship = ref.watch(
      foundationRuntimeServiceProvider.select((state) => state.selectedRelationship),
    );

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
            child: switch ((selectedObject, selectedRelationship)) {
              (final object?, _) => _ObjectProperties(object: object),
              (_, final relationship?) => _RelationshipProperties(relationship: relationship),
              _ => const _NoSelection(),
            },
          ),
        ],
      ),
    );
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
        _Field(label: 'Name', value: object.name),
        _Field(label: 'Object ID', value: object.objectId, monospace: true),
        _Field(label: 'Object Type', value: object.category.label),
        _Field(label: 'Author', value: object.author),
        _Field(label: 'Version', value: object.version),
        _Field(label: 'Description', value: object.description.isEmpty ? '—' : object.description),
        _Field(label: 'Tags', value: object.tags.isEmpty ? '—' : object.tags.join(', ')),
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
        _Field(label: 'Relationship ID', value: relationship.relationshipId, monospace: true),
        _Field(label: 'Relationship Type', value: relationship.type.label),
        _Field(label: 'Source Object', value: relationship.sourceObjectName),
        _Field(label: 'Target Object', value: relationship.targetObjectName),
        _Field(label: 'Author', value: relationship.author),
        _Field(label: 'Description', value: relationship.description.isEmpty ? '—' : relationship.description),
        _Field(label: 'Created Date', value: relationship.createdUtc.isEmpty ? '—' : relationship.createdUtc),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: monospace
                ? StudioTheme.monoTextStyle
                : const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
