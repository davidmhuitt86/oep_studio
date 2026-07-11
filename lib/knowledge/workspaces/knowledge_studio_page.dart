import 'package:flutter/material.dart';

import '../review/engineering_review_panel.dart';
import '../sessions/session_header.dart';
import '../widgets/knowledge_panel.dart';
import '../widgets/knowledge_placeholder.dart';
import 'commit_preview_panel.dart';
import 'import_queue_panel.dart';
import 'source_viewer_panel.dart';

/// The Knowledge Studio workspace (Work Package 007 STUDIO-TASK-000013;
/// Work Package 008; SDD-013, SDD-016). Registers as a Studio workspace
/// like every other Primary Workspace page — same Navigation Rail,
/// Connection Manager, theme, and window layout (`StudioShell`), per
/// this work package's Navigation requirement: "No separate application
/// shall be created."
///
/// Import Queue, Source Viewer, Engineering Review, and Commit Summary
/// carry real functionality as of Work Package 008. AI Suggestions and
/// Repository Matches remain placeholder content — both presuppose
/// workflows this and the prior work package explicitly exclude ("Do
/// not introduce AI functionality"; repository matching has no
/// Public C API surface yet, see `docs/KNOWLEDGE_SESSION_FORMAT.md`
/// § Architectural Observations).
class KnowledgeStudioPage extends StatelessWidget {
  const KnowledgeStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SessionHeader(),
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Import Queue',
                        icon: Icons.upload_file_outlined,
                        child: ImportQueuePanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Source Viewer',
                        icon: Icons.visibility_outlined,
                        child: SourceViewerPanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'AI Suggestions',
                        icon: Icons.auto_awesome_outlined,
                        child: KnowledgePlaceholder(
                          message: 'AI-proposed Engineering Objects will appear here. '
                              'No AI implementation exists in this work package.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Repository Matches',
                        icon: Icons.compare_arrows_outlined,
                        child: KnowledgePlaceholder(
                          message: 'Possible existing repository matches will appear here.',
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: KnowledgePanel(
                        title: 'Engineering Review',
                        icon: Icons.fact_check_outlined,
                        child: const EngineeringReviewPanel(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 2,
                child: KnowledgePanel(
                  title: 'Commit Summary',
                  icon: Icons.summarize_outlined,
                  child: const CommitPreviewPanel(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
