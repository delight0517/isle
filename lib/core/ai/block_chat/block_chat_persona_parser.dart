import 'block_chat_models.dart';
import 'block_chat_persona_scenarios.dart';

/// 진솔한 고민 문장 → persona_bundle 계획
class BlockChatPersonaParser {
  BlockChatPersonaParser._();

  static BlockChatPlan? parse(String raw, String t) {
    if (t.isEmpty) return null;

    BlockChatPersonaScenario? exact;
    for (final p in BlockChatPersonaScenarios.all) {
      if (raw.trim() == p.concern.trim()) {
        exact = p;
        break;
      }
    }
    if (exact != null) return exact.toBundlePlan();

    if (!BlockChatPersonaScenarios.looksLikeConcern(t)) return null;

    BlockChatPersonaScenario? best;
    var bestScore = 0;
    for (final p in BlockChatPersonaScenarios.all) {
      final s = p.score(t);
      if (s > bestScore) {
        bestScore = s;
        best = p;
      }
    }
    if (best == null || bestScore < best.matchMin) return null;

    final runnerUp = <int>[];
    for (final p in BlockChatPersonaScenarios.all) {
      if (p.id == best.id) continue;
      final s = p.score(t);
      if (s == bestScore) runnerUp.add(s);
    }
    if (runnerUp.isNotEmpty) return null;

    return best.toBundlePlan();
  }
}
