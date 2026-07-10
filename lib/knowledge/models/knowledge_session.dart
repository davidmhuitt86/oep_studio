import 'session_status.dart';

/// A Knowledge Curation Session (Work Package 007, STUDIO-TASK-000014;
/// SDD-017). Entirely in-memory — "The session shall remain entirely
/// in memory. Persistence is deferred." No repository commit occurs in
/// this work package.
class KnowledgeSession {
  const KnowledgeSession({
    required this.id,
    required this.name,
    required this.repositoryName,
    required this.author,
    this.description = '',
    required this.createdTime,
    this.status = SessionStatus.created,
  });

  final String id;
  final String name;

  /// The repository this session curates knowledge for — a name only,
  /// not a live `RepositoryStatus` reference. Work Package 007 requires
  /// "Assign: Repository" without requiring it to be the Foundation
  /// repository currently open elsewhere in Studio.
  final String repositoryName;
  final String author;
  final String description;
  final DateTime createdTime;
  final SessionStatus status;

  KnowledgeSession copyWith({SessionStatus? status}) {
    return KnowledgeSession(
      id: id,
      name: name,
      repositoryName: repositoryName,
      author: author,
      description: description,
      createdTime: createdTime,
      status: status ?? this.status,
    );
  }
}
