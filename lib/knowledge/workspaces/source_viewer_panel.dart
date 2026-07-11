import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import '../services/source_material_service.dart';
import '../widgets/knowledge_placeholder.dart';

/// The Source Viewer panel (Work Package 008 STUDIO-TASK-000016:
/// "displays the original engineering source for the currently selected
/// item"). Renders what it reasonably can — an image thumbnail, or a
/// text/Markdown file's raw content — and otherwise shows the file's
/// location rather than attempting to render it. "No OCR. No parsing."
/// applies here too: nothing extracts structured meaning from a
/// source's content, this only displays it, the same way an OS file
/// preview pane would.
class SourceViewerPanel extends ConsumerWidget {
  const SourceViewerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(foundationRuntimeServiceProvider.select((state) => state.selectedSourceMaterial));
    if (source == null) {
      return const KnowledgePlaceholder(message: 'Select a source in the Import Queue to preview it here.');
    }
    if (!SourceMaterialService.exists(source)) {
      return KnowledgePlaceholder(message: 'Missing source file: "${source.originalFileName}" could not be found.');
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: switch (source.type) {
        SourceMaterialType.image => _ImagePreview(source: source),
        SourceMaterialType.markdown || SourceMaterialType.text => _TextPreview(source: source),
        SourceMaterialType.pdf || SourceMaterialType.other => _UnsupportedPreview(source: source),
      },
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.source});

  final SourceMaterial source;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.originalFileName,
          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Image.file(
            File(source.localPath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const KnowledgePlaceholder(
              message: 'This image could not be displayed.',
            ),
          ),
        ),
      ],
    );
  }
}

class _TextPreview extends StatefulWidget {
  const _TextPreview({required this.source});

  final SourceMaterial source;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  late Future<String> _contents = File(widget.source.localPath).readAsString();

  @override
  void didUpdateWidget(covariant _TextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.localPath != widget.source.localPath) {
      _contents = File(widget.source.localPath).readAsString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.source.originalFileName,
          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<String>(
            future: _contents,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) {
                return const KnowledgePlaceholder(message: 'This file could not be displayed.');
              }
              return SingleChildScrollView(
                child: SelectableText(snapshot.data!, style: StudioTheme.monoTextStyle),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({required this.source});

  final SourceMaterial source;

  @override
  Widget build(BuildContext context) {
    return KnowledgePlaceholder(
      message: '${source.type.label} preview is not available in this work package.\n'
          'File: ${source.originalFileName}',
    );
  }
}
