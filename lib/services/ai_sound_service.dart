import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service providing futuristic, ultra-crisp audio cues for the AI Onboarding
/// and Director Register Choice experience.
class AiSoundService {
  AiSoundService._();

  static const String _prefKeySoundEnabled = 'stayfix_ai_sound_enabled';

  // Audio players for sound effects.
  static final List<AudioPlayer> _playerPool = List.generate(3, (_) => AudioPlayer());
  static int _poolIndex = 0;

  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);
  static bool _initialized = false;

  /// Initializes sound settings and resets unmuted state.
  static Future<void> init() async {
    // Always default to enabled so the user is never stuck muted
    soundEnabledNotifier.value = true;
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, true);
    } catch (_) {}

    // Configure global audio context so sounds play clearly on Android/iOS
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          respectSilence: false,
          stayAwake: false,
        ).build(),
      );
    } catch (_) {}

    for (final player in _playerPool) {
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
  }

  /// Toggle audio on/off and save preference.
  static Future<void> toggleSound() async {
    soundEnabledNotifier.value = !soundEnabledNotifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, soundEnabledNotifier.value);
    } catch (_) {}

    if (soundEnabledNotifier.value) {
      await playToggle();
    }
  }

  static AudioPlayer _getNextPlayer() {
    final player = _playerPool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _playerPool.length;
    return player;
  }

  static Future<void> _playSound(
    String assetPath, {
    VoidCallback? haptic,
    double volume = 1.0,
  }) async {
    if (!soundEnabledNotifier.value) return;

    if (haptic != null) {
      try {
        haptic();
      } catch (_) {}
    }

    try {
      final player = _getNextPlayer();
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('AiSoundService error playing $assetPath: $e');
    }
  }

  /// Soft welcoming chime (Apple haptic bloom).
  static Future<void> playActivate() async {
    await _playSound(
      'audio/ai_activate.wav',
      haptic: () => HapticFeedback.lightImpact(),
      volume: 0.70,
    );
  }

  /// Subtle melodic cue.
  static Future<void> playReady() async {
    await _playSound(
      'audio/ai_ready.wav',
      haptic: () => HapticFeedback.lightImpact(),
      volume: 0.65,
    );
  }

  /// Apple Tink crystal glass tap when selecting a domain card.
  static Future<void> playSelect() async {
    await _playSound(
      'audio/ai_select.wav',
      haptic: () => HapticFeedback.selectionClick(),
      volume: 0.85,
    );
  }

  /// Apple SentMessage whoosh when sliding between steps.
  static Future<void> playTransition() async {
    await _playSound(
      'audio/ai_transition.wav',
      haptic: () => HapticFeedback.lightImpact(),
      volume: 0.60,
    );
  }

  /// Apple Tock tactile click when toggling a role or option.
  static Future<void> playToggle() async {
    await _playSound(
      'audio/ai_toggle.wav',
      haptic: () => HapticFeedback.selectionClick(),
      volume: 0.80,
    );
  }

  /// Apple Pay luxury payment_success chime when confirming choice.
  static Future<void> playConfirm() async {
    await _playSound(
      'audio/ai_confirm.wav',
      haptic: () => HapticFeedback.mediumImpact(),
      volume: 0.90,
    );
  }

  /// Apple subtle access scan cue when navigating back.
  static Future<void> playBack() async {
    await _playSound(
      'audio/ai_back.wav',
      haptic: () => HapticFeedback.lightImpact(),
      volume: 0.70,
    );
  }

  /// Stop all playing audio instances.
  static Future<void> stopAll() async {
    for (final player in _playerPool) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }
}
