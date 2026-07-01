class AudioTier {
  final String label;
  final int bitrate; // kbps

  const AudioTier(this.label, this.bitrate);
}

class AudioOptimizationService {
  /// Returns the 4 audio tiers based on the number of channels detected.
  static List<AudioTier> getTiersForChannels(int channels) {
    if (channels <= 1) { // Mono
      return const [
        AudioTier('Space Saver', 24),
        AudioTier('Transparent', 48),
        AudioTier('Audiophile', 64),
        AudioTier('Archival', 96),
      ];
    } else if (channels == 2) { // Stereo
      return const [
        AudioTier('Space Saver', 64),
        AudioTier('Transparent', 96),
        AudioTier('Audiophile', 128),
        AudioTier('Archival', 192),
      ];
    } else if (channels <= 6) { // 5.1 Surround
      return const [
        AudioTier('Space Saver', 192),
        AudioTier('Transparent', 256),
        AudioTier('Audiophile', 384),
        AudioTier('Archival', 512),
      ];
    } else { // 7.1 Surround or higher
      return const [
        AudioTier('Space Saver', 256),
        AudioTier('Transparent', 384),
        AudioTier('Audiophile', 512),
        AudioTier('Archival', 768),
      ];
    }
  }

  /// Calculates the appropriate FFmpeg arguments for the selected audio settings
  static List<String> buildAudioArgs(int originalChannels, int selectedBitrate, bool downmixToStereo) {
    final args = <String>[
      '-c:a', 'libopus',
      '-b:a', '${selectedBitrate}k',
    ];

    if (downmixToStereo && originalChannels > 2) {
      args.addAll(['-ac', '2']);
    }

    return args;
  }
}
