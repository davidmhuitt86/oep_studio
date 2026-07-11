import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/models/session_status.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';

KnowledgeCandidate _candidate(
  String name, {
  String? id,
  KnowledgeCandidateStatus status = KnowledgeCandidateStatus.pending,
}) {
  return KnowledgeCandidate(
    id: id ?? name,
    type: KnowledgeCandidateType.component,
    name: name,
    status: status,
    createdTime: DateTime(2026, 1, 1),
  );
}

void main() {
  group('validateNewSession', () {
    test('rejects an empty name', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: '  ', repositoryName: 'demo'),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a missing repository', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: 'Session A', repositoryName: ''),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a valid name and repository', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: 'Session A', repositoryName: 'demo'),
        returnsNormally,
      );
    });
  });

  group('validateCandidateName', () {
    final existing = [_candidate('Main Generator'), _candidate('Backup Battery')];

    test('rejects an empty name', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName('  ', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a duplicate name case-insensitively', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName('main generator', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a unique name', () {
      expect(() => KnowledgeSessionService.validateCandidateName('Timing Cover', existing), returnsNormally);
    });

    test('excludingId allows a candidate to keep its own name while editing', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName(
          'Main Generator',
          existing,
          excludingId: 'Main Generator',
        ),
        returnsNormally,
      );
    });
  });

  group('validateStatusTransition', () {
    test('allows the forward sequence', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.created, SessionStatus.preparing),
        returnsNormally,
      );
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.preparing, SessionStatus.reviewing),
        returnsNormally,
      );
      expect(
        () =>
            KnowledgeSessionService.validateStatusTransition(SessionStatus.reviewing, SessionStatus.readyToCommit),
        returnsNormally,
      );
    });

    test('rejects skipping a stage', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.created, SessionStatus.reviewing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('allows cancelling from any non-cancelled state', () {
      for (final status in [
        SessionStatus.created,
        SessionStatus.preparing,
        SessionStatus.reviewing,
        SessionStatus.readyToCommit,
      ]) {
        expect(
          () => KnowledgeSessionService.validateStatusTransition(status, SessionStatus.cancelled),
          returnsNormally,
        );
      }
    });

    test('rejects cancelling an already-cancelled session', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.cancelled, SessionStatus.cancelled),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects advancing a cancelled session', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.cancelled, SessionStatus.preparing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });
  });

  group('validateRelationshipCandidate', () {
    final existing = [_candidate('Main Generator', id: 'c1'), _candidate('Backup Battery', id: 'c2')];

    test('rejects a self-referencing relationship', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c1',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a relationship whose source does not exist', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'missing',
          targetCandidateId: 'c2',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a relationship whose target does not exist', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'missing',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a relationship between two existing, distinct candidates', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          existingCandidates: existing,
        ),
        returnsNormally,
      );
    });
  });

  group('isDuplicateRelationshipCandidate', () {
    final relationship = RelationshipCandidate(
      id: 'r1',
      sourceCandidateId: 'c1',
      targetCandidateId: 'c2',
      type: RelationshipType.references,
      createdTime: DateTime(2026, 1, 1),
    );

    test('is true for a matching source/target/type', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          existingRelationships: [relationship],
        ),
        isTrue,
      );
    });

    test('is false for a different relationship type', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.dependsOn,
          existingRelationships: [relationship],
        ),
        isFalse,
      );
    });

    test('excludingId ignores the relationship being edited', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          existingRelationships: [relationship],
          excludingId: 'r1',
        ),
        isFalse,
      );
    });
  });

  group('computeCommitPreview', () {
    test('splits candidates into new objects and rejected, and flags pending candidates', () {
      final candidates = [
        _candidate('Accepted One', id: 'a1', status: KnowledgeCandidateStatus.accepted),
        _candidate('Rejected One', id: 'r1', status: KnowledgeCandidateStatus.rejected),
        _candidate('Pending One', id: 'p1'),
      ];
      final preview = KnowledgeSessionService.computeCommitPreview(
        candidates: candidates,
        relationshipCandidates: const [],
        repositoryStatistics: null,
      );
      expect(preview.newObjects, hasLength(1));
      expect(preview.rejectedCandidates, hasLength(1));
      expect(preview.validationIssues, contains('1 candidate still pending review.'));
      expect(preview.currentStatistics, isNull);
      expect(preview.projectedObjectCount, isNull);
    });

    test('flags a relationship candidate whose endpoint no longer exists', () {
      final candidates = [_candidate('Only One', id: 'c1', status: KnowledgeCandidateStatus.accepted)];
      final relationships = [
        RelationshipCandidate(
          id: 'r1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'missing',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final preview = KnowledgeSessionService.computeCommitPreview(
        candidates: candidates,
        relationshipCandidates: relationships,
        repositoryStatistics: null,
      );
      expect(preview.validationIssues, isNotEmpty);
      expect(preview.validationIssues.first, contains('no longer exists'));
    });
  });
}
