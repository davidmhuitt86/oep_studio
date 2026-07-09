import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/dashboard_card.dart';
import '../../shared/widgets/responsive_card_grid.dart';
import 'widgets/getting_started_strip.dart';

/// The Dashboard (SDD-007), the engineer's landing page.
///
/// Matches the approved 001-OEP-STUDIO-DASHBOARD-v1.0.png mockup. All
/// data shown is placeholder — no Foundation Bridge call is made in
/// this work package, per STUDIO-TASK-000002.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              color: StudioColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Welcome to OEP Studio',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ResponsiveCardGrid(
            children: [
              _OpenRepositoryCard(),
              _CreateRepositoryCard(),
              _RepositoryStatusCard(),
            ],
          ),
          const SizedBox(height: 16),
          ResponsiveCardGrid(
            children: [
              _RecentRepositoriesCard(),
              _FoundationVersionCard(),
              _InstalledPackagesCard(),
            ],
          ),
          const SizedBox(height: 16),
          const GettingStartedStrip(),
        ],
      ),
    );
  }
}

class _OpenRepositoryCard extends StatelessWidget {
  const _OpenRepositoryCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Open Repository',
      icon: Icons.folder_open_outlined,
      iconColor: StudioColors.selection,
      iconBackground: StudioColors.selection.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open an existing OEP repository from your system.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              child: const Text('Open Repository'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateRepositoryCard extends StatelessWidget {
  const _CreateRepositoryCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Create Repository',
      icon: Icons.note_add_outlined,
      iconColor: StudioColors.success,
      iconBackground: StudioColors.success.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a new OEP repository in a few simple steps.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(backgroundColor: StudioColors.success),
              child: const Text('Create Repository'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepositoryStatusCard extends StatelessWidget {
  const _RepositoryStatusCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Repository Status',
      icon: Icons.dns_outlined,
      iconColor: const Color(0xFFB794F6),
      iconBackground: const Color(0xFFB794F6).withValues(alpha: 0.14),
      child: const Column(
        children: [
          _StatusRow(icon: Icons.check_circle_outline, label: 'Active Repository', value: 'None'),
          _StatusRow(icon: Icons.dns_outlined, label: 'Runtime State', value: 'Not Connected', valueColor: StudioColors.warning),
          _StatusRow(icon: Icons.insert_drive_file_outlined, label: 'Repository Path', value: '—'),
          _StatusRow(icon: Icons.schedule_outlined, label: 'Last Modified', value: '—'),
          _StatusRow(icon: Icons.category_outlined, label: 'Objects', value: '—'),
          _StatusRow(icon: Icons.hub_outlined, label: 'Relationships', value: '—', showDivider: false),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: StudioColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? StudioColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _RecentRepositoriesCard extends StatelessWidget {
  const _RecentRepositoriesCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Recent Repositories',
      icon: Icons.history,
      trailing: const ViewAllLink(),
      child: const _EmptyState(
        icon: Icons.folder_outlined,
        title: 'No recent repositories',
        description: 'Repositories you open will appear here.',
      ),
    );
  }
}

class _FoundationVersionCard extends StatelessWidget {
  const _FoundationVersionCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Foundation Version',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not Connected',
            style: TextStyle(
              color: StudioColors.warning,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect to a repository to see Foundation version information.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioColors.surfaceSunken,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: StudioColors.border),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _LabeledValue(label: 'Foundation Version', value: '—'),
                ),
                Expanded(
                  child: _LabeledValue(label: 'API Version', value: '—'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InstalledPackagesCard extends StatelessWidget {
  const _InstalledPackagesCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Installed Packages',
      icon: Icons.inventory_2_outlined,
      trailing: const ViewAllLink(),
      child: const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No packages installed',
        description: 'Installed packages will appear here.',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: StudioColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
