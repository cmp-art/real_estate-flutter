// lib/core/providers/video_providers.dart
//
// Global video mute state — shared across ALL video players in the app
// (property cards, ad cards, detail screens).
//
// When user mutes/unmutes ANY video, ALL videos in the app follow.
// State persists for the lifetime of the app session.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global mute state. true = muted (default), false = unmuted.
final videoMuteProvider = StateNotifierProvider<VideoMuteNotifier, bool>(
  (_) => VideoMuteNotifier(),
);

class VideoMuteNotifier extends StateNotifier<bool> {
  VideoMuteNotifier() : super(true); // start muted

  void toggleMute() => state = !state;
  void setMuted(bool muted) => state = muted;
}