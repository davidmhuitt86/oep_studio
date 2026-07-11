import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/source_material.dart';

/// Property Inspector's Source Material mode (Work Package 008
/// Property Inspector: "Display: ... Source Material").
class SourceMaterialProperties extends StatelessWidget {
  const SourceMaterialProperties({required this.source, super.key});

  final SourceMaterial source;

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
        PropertyField(label: 'Local Path', value: source.localPath, monospace: true),
      ],
    );
  }
}
