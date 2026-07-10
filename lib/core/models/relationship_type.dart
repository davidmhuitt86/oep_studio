import 'package:flutter/material.dart';

/// Relationship classifications. Mirrors
/// `oep::repository::RelationshipType`
/// (`platform/repository/include/oep/repository/relationship.hpp`) —
/// Foundation's own taxonomy, not a Studio invention.
///
/// No `nativeValue` mapping exists yet, unlike [ObjectCategory]: the
/// Public C API has no relationship-enumeration function to decode a
/// native value from (see `docs/CONNECTION_MANAGER.md` § Missing
/// Public API). Declaration order matches
/// `oep::repository::RelationshipType`'s C++ declaration order so a
/// future `nativeValue` can be added the same way
/// `ObjectCategory.nativeValue` was, without reordering.
enum RelationshipType {
  references('References', Icons.link),
  contains('Contains', Icons.account_tree_outlined),
  dependsOn('Depends On', Icons.arrow_forward),
  connectedTo('Connected To', Icons.cable),
  documents('Documents', Icons.description_outlined),
  implements_('Implements', Icons.check_circle_outline);

  const RelationshipType(this.label, this.icon);

  final String label;
  final IconData icon;
}
