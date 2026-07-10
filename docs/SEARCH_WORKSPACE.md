# Search Workspace

Implemented in Work Package 005 (STUDIO-TASK-000010) by
`lib/features/search/search_page.dart`. Consumes only the
[Connection Manager](CONNECTION_MANAGER.md) (`foundationRuntimeServiceProvider`)
— never the Foundation Bridge or Public C API directly, and never
performs searching independently or reorders Foundation's results.

---

## Status

As of this work package, the Public C API exposes no search function
(`oep::search::SearchEngine::search_objects`/`search_relationships`
exist in Foundation's C++ layer but nothing in `oep_api.h` calls
them — see `docs/CONNECTION_MANAGER.md` § Missing Public API). Every
search in this work package is therefore honestly reported as
**unavailable**, not as "zero results" — those are different facts,
and Work Package 005's error handling rule requires a professional
message rather than a misleading empty state.

## Search Workflow

```
User types a query, clicks Search (or presses Enter)
  -> SearchPage._runSearch(query)
       -> FoundationRuntimeNotifier.search(query)
            -> state.copyWith(searchQuery: query, clearSearchResults: true)
       -> local: query pushed to the front of Search History
  -> UI reads state.searchQuery (non-empty) and state.searchResults (always null)
       -> renders "Couldn't search for '<query>'" / "Live repository
          search isn't available in this version of Studio yet."
```

Once a search function exists in `oep_api.h`, the only change expected
here is inside `FoundationRuntimeNotifier.search()`: it would call the
Bridge, populate `searchResults` with real `SearchResult`s (combining
`oep_search_objects`- and `oep_search_relationships`-shaped results,
tagged by `SearchResultKind`), and the same `search(query)` /
`clearSearch()` call sites and UI states already wired up would not
need to change — only the data source underneath them would.

`Clear` (both the button next to Search and the composed `clearSearch()`
call) resets `searchQuery` to `''` and `searchResults` to `null`,
returning the page to its idle state — distinct from "Clear History"
(below), which only clears the local history list, not the current
query/results.

## Relationship Workflow

See `docs/CONNECTION_MANAGER.md` § State Ownership and § Foundation
Interaction for how `selectedRelationship` is owned and how it
interacts with `selectedObject`. In brief: the Relationship Explorer
(`lib/features/relationships/relationships_page.dart`) is a separate
page from the Search Workspace, but both ultimately drive the same
Connection Manager selection state that the Property Inspector reads.

## Selection Lifecycle

Per Work Package 005: *"Selecting a result shall: Navigate to the
appropriate Explorer. Select the corresponding item. Update the
Property Inspector."* Since `searchResults` is always `null` in this
work package, no result row ever exists to select, and this behavior
has no code path to exercise yet. The intended lifecycle, once real
results exist:

```
User taps a SearchResult row
  -> if kind == object:
       context.go(StudioDestination.objects.path)
       ref.read(...).selectObject(<the matching EngineeringObjectSummary>)
  -> if kind == relationship:
       context.go(StudioDestination.relationships.path)
       ref.read(...).selectRelationship(<the matching RelationshipSummary>)
```

Both `selectObject` and `selectRelationship` already exist (Work
Package 004/005) and already clear the other selection, so the
Property Inspector's Object/Relationship mode switch (see
`property_inspector_panel.dart`) requires no further change once this
is wired up — it is written generically against "whichever of
`selectedObject`/`selectedRelationship` is non-null," not against how
that selection was made.

## Search History

Per Work Package 005: *"Maintain an in-memory search history during
the current Studio session. History shall not persist between
sessions."* Implemented as local `State` inside `_SearchPageState`
(`_history`, a `List<String>`, most-recent-first, deduplicated on
re-search) — **not** part of `FoundationServiceState`/the Connection
Manager, since it is Search Workspace presentation state, not
Foundation-derived state (the Connection Manager's documented
additions for this work package are specifically Current Search
Query/Results and Current Relationship Selection — history is not
among them). Rebuilding the widget tree (e.g. hot reload) or
navigating away and back preserves history only because `SearchPage`
itself isn't recreated by `go_router`'s `ShellRoute`... in practice,
history is scoped to the `SearchPage` widget's lifetime, which for
this single-workspace shell effectively means "for as long as Studio
is running," consistent with "current Studio session."

"Previous Searches" clicking a row re-runs that exact query
(equivalent to typing it and pressing Search). "Clear History" empties
the local list only — it does not affect `searchQuery`/`searchResults`.

## Navigation Behavior

The Search Workspace is reached via the Navigation Rail's "Search"
item (`StudioDestination.search`, unchanged since Work Package 001) or,
once wired per § Selection Lifecycle above, indirectly by selecting a
search result from within the Search page itself (which then navigates
*away* to Objects or Relationships). Search never opens a floating
window or a second Primary Workspace, consistent with SDD-003/SDD-004's
single-workspace rule already followed by every other Explorer.
