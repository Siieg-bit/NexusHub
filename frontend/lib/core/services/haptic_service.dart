import 'package:flutter/services.dart';

// ============================================================================
// HapticService — Feedback tátil contextual inspirado no OluOlu
//
// O OluOlu usa diferentes intensidades de vibração para ações distintas:
// - Toque no teclado: leve (selectionClick)
// - Clique em botão: médio (lightImpact)
// - Ação importante: forte (mediumImpact)
// - Eventos especiais (promoção, recompensa): pesado (heavyImpact)
// - Erro/alerta: vibração dupla
//
// Uso:
//   HapticService.tap();           // toque leve (teclado, seleção)
//   HapticService.buttonPress();   // clique em botão
//   HapticService.action();        // ação importante (enviar, confirmar)
//   HapticService.success();       // sucesso (check-in, conquista)
//   HapticService.error();         // erro ou alerta
//   HapticService.promoted();      // promoção (speaker, nível up)
//   HapticService.reward();        // recompensa (moedas, streak)
// ============================================================================

class HapticService {
  HapticService._();

  // ── Toque leve (seleção, teclado) ────────────────────────────────────────
  static Future<void> tap() => HapticFeedback.selectionClick();

  // ── Clique em botão normal ────────────────────────────────────────────────
  static Future<void> buttonPress() => HapticFeedback.lightImpact();

  // ── Ação importante (enviar mensagem, confirmar) ──────────────────────────
  static Future<void> action() => HapticFeedback.mediumImpact();

  // ── Sucesso (check-in, conquista, like) ───────────────────────────────────
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  // ── Erro ou alerta ────────────────────────────────────────────────────────
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  // ── Promoção (virou speaker, subiu de nível) ──────────────────────────────
  static Future<void> promoted() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  // ── Recompensa (moedas, streak, presente) ────────────────────────────────
  static Future<void> reward() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // ── Mão levantada (levantar/baixar mão no FreeTalk) ──────────────────────
  static Future<void> handRaise() => HapticFeedback.selectionClick();

  // ── Microfone ativado ─────────────────────────────────────────────────────
  static Future<void> micOn() async {
    await HapticFeedback.mediumImpact();
  }

  // ── Microfone desativado ──────────────────────────────────────────────────
  static Future<void> micOff() async {
    await HapticFeedback.lightImpact();
  }

  // ── Long press ────────────────────────────────────────────────────────────
  static Future<void> longPress() => HapticFeedback.heavyImpact();

  // ── Swipe / dismiss ───────────────────────────────────────────────────────
  static Future<void> swipe() => HapticFeedback.selectionClick();
}
