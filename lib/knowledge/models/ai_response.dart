/// One provider's response to an `AiRequest` (Work Package 016
/// STUDIO-TASK-000046: "AIResponse"). Ephemeral, like `AiRequest` — see
/// that class's own doc comment for why this isn't persisted.
///
/// [rawText] is the provider's complete, unmodified output — kept
/// verbatim, never partially discarded, so a malformed or unexpected
/// response is always fully inspectable rather than silently
/// truncated ("No hidden state").
class AiResponse {
  const AiResponse({
    required this.requestId,
    required this.providerId,
    required this.modelId,
    required this.rawText,
    required this.receivedTime,
    required this.success,
    this.errorMessage,
  });

  final String requestId;
  final String providerId;
  final String modelId;
  final String rawText;
  final DateTime receivedTime;

  /// `false` if the provider itself failed (e.g. a real provider's
  /// network/timeout/rate-limit failure) — distinct from
  /// `AiSuggestionParser` later failing to parse a *successful*
  /// response's malformed content, which is a separate failure mode
  /// surfaced via `AiAnalysisException`.
  final bool success;

  final String? errorMessage;
}
