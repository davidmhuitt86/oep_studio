import 'package:flutter/material.dart';

/// The field a search query matched against. Mirrors
/// `oep::search::MatchLocation`
/// (`platform/search/include/oep/search/search_engine.hpp`).
enum SearchMatchLocation { name, description, author, tags, objectType, relationshipType }

/// Whether a [SearchResult] refers to an Engineering Object or a
/// Relationship — Foundation's `SearchEngine` exposes these as two
/// separate calls (`search_objects`/`search_relationships`) returning
/// two distinct result types; Studio combines them into one displayed
/// list per STUDIO-TASK-000010's "Search Results" requirements, tagged
/// with which kind each row is so selecting one can navigate to the
/// right Explorer.
enum SearchResultKind { object, relationship }

/// A single search result row, as the Search Workspace displays it.
/// Mirrors the union of `oep::search::ObjectSearchResult` and
/// `oep::search::RelationshipSearchResult` — no Public C API function
/// returns either yet (see `docs/CONNECTION_MANAGER.md` § Missing
/// Public API). Studio never computes [matchScore] itself; it is
/// always exactly what Foundation's `SearchEngine` reports, and result
/// ordering must never be changed by Studio (STUDIO-TASK-000010:
/// "Studio shall never reorder Foundation results").
class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.matchScore,
    required this.matchLocation,
  });

  final SearchResultKind kind;
  final String id;
  final String name;
  final String typeLabel;
  final double matchScore;
  final SearchMatchLocation matchLocation;

  IconData get icon => switch (kind) {
    SearchResultKind.object => Icons.category_outlined,
    SearchResultKind.relationship => Icons.hub_outlined,
  };
}
