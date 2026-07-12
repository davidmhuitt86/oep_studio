import 'settings_enums.dart';

/// Settings > Artificial Intelligence (SDD-023): "Enable AI, Provider,
/// Model, API Configuration, Local Server Configuration, Temperature,
/// Timeout, Context Window, Reasoning Depth, Privacy Controls, Test
/// Connection."
///
/// Per this work package's explicit instruction ("Do not implement
/// provider-specific settings ... yet"), every field here is an inert,
/// validated placeholder: this model has no dependency on
/// `lib/knowledge`'s `AiProvider`/`AiProviderRegistry` (Work Package
/// 016), and changing these values does not yet affect AI analysis
/// anywhere in Studio. `providerId`/`modelId` are free validated text,
/// not cross-checked against the real provider registry — wiring that
/// registry into Settings, so a provider genuinely registers its own
/// configuration UI per SDD-023 AI Provider Registration, is left to
/// the work package that introduces the first non-mock provider. See
/// `docs/STUDIO_SETTINGS.md` Architectural Observations.
///
/// No API key or credential field exists on this model, and none shall
/// ever be added directly here — SDD-023 Security: "AI credentials
/// shall never be stored inside Knowledge Sessions" and this work
/// package's own "Do not store secrets in exported configuration."
class AiSettings {
  const AiSettings({
    required this.enabled,
    required this.providerId,
    required this.modelId,
    required this.temperature,
    required this.timeoutSeconds,
    required this.contextWindowTokens,
    required this.reasoningDepth,
    required this.privacyControlsEnabled,
  });

  factory AiSettings.defaults() => const AiSettings(
    enabled: false,
    providerId: 'mock',
    modelId: '',
    temperature: 0.7,
    timeoutSeconds: 30,
    contextWindowTokens: 8192,
    reasoningDepth: ReasoningDepthPreference.standard,
    privacyControlsEnabled: true,
  );

  final bool enabled;
  final String providerId;
  final String modelId;
  final double temperature;
  final int timeoutSeconds;
  final int contextWindowTokens;
  final ReasoningDepthPreference reasoningDepth;
  final bool privacyControlsEnabled;

  AiSettings copyWith({
    bool? enabled,
    String? providerId,
    String? modelId,
    double? temperature,
    int? timeoutSeconds,
    int? contextWindowTokens,
    ReasoningDepthPreference? reasoningDepth,
    bool? privacyControlsEnabled,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      reasoningDepth: reasoningDepth ?? this.reasoningDepth,
      privacyControlsEnabled: privacyControlsEnabled ?? this.privacyControlsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'providerId': providerId,
    'modelId': modelId,
    'temperature': temperature,
    'timeoutSeconds': timeoutSeconds,
    'contextWindowTokens': contextWindowTokens,
    'reasoningDepth': reasoningDepth.name,
    'privacyControlsEnabled': privacyControlsEnabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AiSettings.defaults();
    return AiSettings(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      providerId: json['providerId'] as String? ?? defaults.providerId,
      modelId: json['modelId'] as String? ?? defaults.modelId,
      temperature: (json['temperature'] as num?)?.toDouble() ?? defaults.temperature,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? defaults.timeoutSeconds,
      contextWindowTokens: json['contextWindowTokens'] as int? ?? defaults.contextWindowTokens,
      reasoningDepth: ReasoningDepthPreference.values.firstWhere(
        (value) => value.name == json['reasoningDepth'],
        orElse: () => defaults.reasoningDepth,
      ),
      privacyControlsEnabled: json['privacyControlsEnabled'] as bool? ?? defaults.privacyControlsEnabled,
    );
  }
}
