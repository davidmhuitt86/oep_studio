import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/engineering_proposal.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/models/proposal_type.dart';
import 'package:oep_studio/knowledge/models/session_status.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';

EngineeringProposal _proposal(String name) {
  return EngineeringProposal(
    id: name,
    type: ProposalType.component,
    name: name,
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

  group('validateProposalName', () {
    final existing = [_proposal('Main Generator'), _proposal('Backup Battery')];

    test('rejects an empty name', () {
      expect(
        () => KnowledgeSessionService.validateProposalName('  ', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a duplicate name case-insensitively', () {
      expect(
        () => KnowledgeSessionService.validateProposalName('main generator', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a unique name', () {
      expect(() => KnowledgeSessionService.validateProposalName('Timing Cover', existing), returnsNormally);
    });

    test('excludingId allows a proposal to keep its own name while editing', () {
      expect(
        () => KnowledgeSessionService.validateProposalName(
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
}
