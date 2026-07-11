import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/knowledge_candidate_form_controller.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_validation_exception.dart';

/// The New/Edit Knowledge Candidate dialog (Work Package 007: "The
/// engineer shall be able to create manual proposals ... Edit").
/// [existing] is `null` to create a new candidate, or the candidate
/// being edited.
Future<void> showKnowledgeCandidateFormDialog(BuildContext context, {KnowledgeCandidate? existing}) {
  return showDialog<void>(context: context, builder: (context) => _KnowledgeCandidateFormDialog(existing: existing));
}

class _KnowledgeCandidateFormDialog extends ConsumerStatefulWidget {
  const _KnowledgeCandidateFormDialog({required this.existing});

  final KnowledgeCandidate? existing;

  @override
  ConsumerState<_KnowledgeCandidateFormDialog> createState() => _KnowledgeCandidateFormDialogState();
}

class _KnowledgeCandidateFormDialogState extends ConsumerState<_KnowledgeCandidateFormDialog> {
  // Owned by this State — see `_NewSessionDialogState`'s note on why
  // this must not be disposed via the showDialog Future instead.
  late final _form = KnowledgeCandidateFormController(
    name: widget.existing?.name ?? '',
    type: widget.existing?.type ?? KnowledgeCandidateType.component,
    description: widget.existing?.description ?? '',
  );
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    try {
      if (widget.existing == null) {
        notifier.addKnowledgeCandidate(type: _form.type, name: _form.name, description: _form.description);
      } else {
        notifier.editKnowledgeCandidate(
          widget.existing!.id,
          type: _form.type,
          name: _form.name,
          description: _form.description,
        );
      }
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(isEditing ? 'Edit Knowledge Candidate' : 'New Knowledge Candidate'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            ValueListenableBuilder<KnowledgeCandidateType>(
              valueListenable: _form.typeNotifier,
              builder: (context, type, _) => DropdownButtonHideUnderline(
                child: DropdownButton<KnowledgeCandidateType>(
                  value: type,
                  isExpanded: true,
                  dropdownColor: StudioColors.surfaceRaised,
                  style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                  items: [
                    for (final option in KnowledgeCandidateType.values)
                      DropdownMenuItem(value: option, child: Text(option.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) _form.typeNotifier.value = value;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _form.nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: _form.descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Add Candidate')),
      ],
    );
  }
}
