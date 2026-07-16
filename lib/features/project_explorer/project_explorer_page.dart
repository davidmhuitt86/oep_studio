import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engineering_project.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/engineering_project_storage.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/unified_navigation.dart';

/// The Project Explorer (WORK_PACKAGE_025, ENGINE-TASK-000126) — "the
/// primary navigation surface for OEP." Replaces the idea of
/// workspace-specific explorers (the Object Explorer, the Diagram
/// Explorer panel, ...) with one tree rooted at the active Engineering
/// Project: Knowledge, Diagrams, Evidence, Components, Validation, AI
/// Sessions, and a disabled Simulation placeholder. Every leaf calls
/// straight into `unified_navigation.dart` (ENGINE-TASK-000120), which
/// is what "automatically activates the appropriate workspace" means in
/// practice — this page does no navigation logic of its own.
///
/// Deliberately a new `StudioDestination`/route with a plain
/// `ExpansionTile` tree rather than a `StudioShell` layout rewrite or a
/// new docking system — consistent with every prior work package's
/// "basic implementation only" precedent for panels (see
/// `docs/PROJECT_EXPLORER.md`).
class ProjectExplorerPage extends ConsumerWidget {
  const ProjectExplorerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final project = projectState.activeProject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.workspaces_outlined, size: 18, color: StudioColors.selection),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  project == null ? 'Project Explorer' : project.name,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _createProject(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Project'),
              ),
            ],
          ),
        ),
        if (project == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No Engineering Project is active yet. Create one to coordinate Knowledge, '
              'Diagrams, Evidence, Validation, and AI Sessions under a single project.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _KnowledgeBranch(foundation: foundation, ref: ref),
              _DiagramsBranch(projectState: projectState),
              _EvidenceBranch(foundation: foundation, ref: ref),
              _ComponentsBranch(foundation: foundation, ref: ref),
              _ValidationBranch(projectState: projectState),
              _AiSessionsBranch(foundation: foundation),
              const _SimulationBranch(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Engineering Project'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final now = DateTime.now();
    final project = EngineeringProject(
      id: 'project_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      createdTime: now,
      lastModified: now,
    );
    await EngineeringProjectStorage.save(project);
    ref.read(engineeringProjectServiceProvider.notifier).setActiveProject(project);
  }
}

class _Branch extends StatelessWidget {
  const _Branch({required this.title, required this.icon, required this.children, this.trailing});

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        leading: Icon(icon, size: 18, color: StudioColors.textSecondary),
        title: Text(title, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: trailing,
        childrenPadding: const EdgeInsets.only(left: 12),
        children: children.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Nothing here yet.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
                ),
              ]
            : children,
      ),
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.label, required this.onTap, this.subtitle});

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5), overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        onTap: onTap,
      ),
    );
  }
}

class _KnowledgeBranch extends StatelessWidget {
  const _KnowledgeBranch({required this.foundation, required this.ref});

  final FoundationServiceState foundation;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final candidates = foundation.candidates;
    return _Branch(
      title: 'Knowledge',
      icon: Icons.auto_awesome_outlined,
      children: [
        for (final candidate in candidates.take(25))
          _Leaf(
            label: candidate.name,
            subtitle: 'Knowledge Candidate',
            onTap: () => goToKnowledgeObject(context, ref, candidate.id),
          ),
      ],
    );
  }
}

class _DiagramsBranch extends StatelessWidget {
  const _DiagramsBranch({required this.projectState});

  final EngineeringProjectState projectState;

  @override
  Widget build(BuildContext context) {
    final path = projectState.documentPath;
    return _Branch(
      title: 'Diagrams',
      icon: Icons.polyline_outlined,
      children: [
        _Leaf(
          label: path == null ? 'Untitled Diagram' : path.split(RegExp(r'[\\/]')).last,
          subtitle: projectState.isDirty ? 'Unsaved changes' : 'Diagram Document',
          onTap: () => context.go(StudioDestination.diagram.path),
        ),
      ],
    );
  }
}

class _EvidenceBranch extends StatelessWidget {
  const _EvidenceBranch({required this.foundation, required this.ref});

  final FoundationServiceState foundation;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final sources = foundation.sourceMaterials;
    return _Branch(
      title: 'Evidence',
      icon: Icons.description_outlined,
      children: [
        for (final source in sources.take(25))
          _Leaf(
            label: source.originalFileName,
            subtitle: 'Source Material',
            onTap: () {
              ref.read(foundationRuntimeServiceProvider.notifier).selectSourceMaterial(source);
              context.go(StudioDestination.knowledge.path);
            },
          ),
      ],
    );
  }
}

class _ComponentsBranch extends StatelessWidget {
  const _ComponentsBranch({required this.foundation, required this.ref});

  final FoundationServiceState foundation;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final objects = foundation.objectList ?? const [];
    return _Branch(
      title: 'Components',
      icon: Icons.category_outlined,
      children: [
        for (final object in objects.take(25))
          _Leaf(
            label: object.name,
            subtitle: object.category.label,
            onTap: () => goToKnowledgeObject(context, ref, object.objectId),
          ),
      ],
    );
  }
}

class _ValidationBranch extends StatelessWidget {
  const _ValidationBranch({required this.projectState});

  final EngineeringProjectState projectState;

  @override
  Widget build(BuildContext context) {
    final findings = projectState.validationReport?.findings ?? const [];
    return _Branch(
      title: 'Validation',
      icon: Icons.fact_check_outlined,
      trailing: findings.isEmpty
          ? null
          : Text('${findings.length}', style: const TextStyle(color: StudioColors.warning, fontSize: 12)),
      children: [
        _Leaf(
          label: findings.isEmpty ? 'No findings' : '${findings.length} finding(s)',
          subtitle: 'Open Validation',
          onTap: () => context.go(StudioDestination.validation.path),
        ),
      ],
    );
  }
}

class _AiSessionsBranch extends StatelessWidget {
  const _AiSessionsBranch({required this.foundation});

  final FoundationServiceState foundation;

  @override
  Widget build(BuildContext context) {
    final conversation = foundation.currentAiConversation;
    return _Branch(
      title: 'AI Sessions',
      icon: Icons.auto_awesome_outlined,
      children: [
        _Leaf(
          label: conversation == null ? 'No AI conversation yet' : 'Last AI conversation',
          subtitle: conversation == null
              ? null
              : (conversation.response == null
                  ? 'Awaiting response…'
                  : 'Provider: ${conversation.response!.providerId}'),
          onTap: () {},
        ),
      ],
    );
  }
}

class _SimulationBranch extends StatelessWidget {
  const _SimulationBranch();

  @override
  Widget build(BuildContext context) {
    return _Branch(
      title: 'Simulation',
      icon: Icons.science_outlined,
      children: const [
        _DisabledLeaf(label: 'Coming Soon'),
      ],
    );
  }
}

class _DisabledLeaf extends StatelessWidget {
  const _DisabledLeaf({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        enabled: false,
        title: Text(label, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 12.5)),
      ),
    );
  }
}
