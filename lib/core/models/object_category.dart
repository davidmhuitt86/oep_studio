import 'package:flutter/material.dart';

/// Engineering Object categories shown by the Repository Explorer
/// (STUDIO-TASK-000005). Mirrors `oep::repository::ObjectType` in
/// Foundation (`platform/repository/include/oep/repository/engineering_object.hpp`)
/// 1:1 — this is Foundation's own taxonomy, not a Studio invention.
///
/// The Public C API does not yet expose object enumeration (see
/// `docs/CONNECTION_MANAGER.md` § Missing Public API), so this enum is
/// currently used for category structure and navigation only — no
/// category is ever populated with real counts or objects yet.
enum ObjectCategory {
  component('Components', Icons.category_outlined),
  document('Documents', Icons.description_outlined),
  diagram('Diagrams', Icons.account_tree_outlined),
  procedure('Procedures', Icons.checklist_outlined),
  image('Images', Icons.image_outlined),
  project('Projects', Icons.folder_special_outlined);

  const ObjectCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}
