import 'package:flutter/material.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';

/// The Top Toolbar (SDD-004 Workspace Layout).
///
/// Actions here are placeholders in Work Package 001 — they are wired
/// to the Command System (SDD-010) in a later work package, not to
/// Foundation.
class StudioToolbar extends StatelessWidget implements PreferredSizeWidget {
  const StudioToolbar({required this.selected, super.key});

  final StudioDestination selected;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(selected.selectedIcon, size: 18, color: StudioColors.textSecondary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              selected.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  _ToolbarAction(icon: Icons.folder_open_outlined, label: 'Open'),
                  _ToolbarAction(icon: Icons.save_outlined, label: 'Save'),
                  _ToolbarDivider(),
                  _ToolbarAction(icon: Icons.file_upload_outlined, label: 'Import'),
                  _ToolbarAction(icon: Icons.file_download_outlined, label: 'Export'),
                  _ToolbarDivider(),
                  _ToolbarAction(icon: Icons.fact_check_outlined, label: 'Validate'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: SizedBox(
                height: 34,
                child: TextField(
                  enabled: false,
                  style: const TextStyle(fontSize: 12, color: StudioColors.textSecondary),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    hintText: 'Search (Ctrl+K)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.settings_outlined, size: 18, color: StudioColors.textSecondary),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton(
          onPressed: null,
          disabledColor: StudioColors.textSecondary,
          icon: Icon(icon, size: 18),
          splashRadius: 18,
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: StudioColors.border,
    );
  }
}
