import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/source_material.dart';

/// Property Inspector's Source Material mode (Work Package 008
/// STUDIO-TASK-000016 Property Inspector: "Display: ... Source
/// Material"; Work Package 009: "Source Metadata" extended with the
/// Evidence Region count and selected pages this source now carries).
class SourceMaterialProperties extends StatelessWidget {
  const SourceMaterialProperties({
    required this.source,
    this.evidenceRegionCount = 0,
    this.selectedPages = const [],
    super.key,
  });

  final SourceMaterial source;

  /// How many Evidence Regions belong to this source (Work Package 009
  /// STUDIO-TASK-000020).
  final int evidenceRegionCount;

  /// Page Selections belonging to this source (Work Package 009
  /// STUDIO-TASK-000019 § Selection), sorted ascending.
  final List<int> selectedPages;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Source ID', value: source.id, monospace: true),
        PropertyField(label: 'File Name', value: source.originalFileName),
        PropertyField(label: 'Type', value: source.type.label),
        PropertyField(label: 'Size', value: formatFileSize(source.sizeBytes)),
        PropertyField(label: 'Date Added', value: formatDateTime(source.importDate)),
        PropertyField(label: 'Added By', value: source.addedBy),
        PropertyField(label: 'Evidence Regions', value: '$evidenceRegionCount'),
        PropertyField(
          label: 'Selected Pages',
          value: selectedPages.isEmpty ? '—' : selectedPages.join(', '),
        ),
        PropertyField(label: 'Local Path', value: source.localPath, monospace: true),
      ],
    );
  }
}
