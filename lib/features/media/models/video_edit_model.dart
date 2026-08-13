/// Video editing data model for storing edit parameters
class VideoEditModel {
  final String videoPath;
  final Duration startTime;
  final Duration endTime;
  final double playbackSpeed; // 0.5x, 1.0x, 1.5x, 2.0x
  final int brightness; // -100 to 100
  final int contrast; // -100 to 100
  final int saturation; // -100 to 100
  final List<FilterEffect> filters;
  final List<TextOverlay> textOverlays;
  final List<AudioTrack> audioTracks;
  final String? backgroundMusic; // Supabase path
  final double musicVolume; // 0.0 to 1.0
  final bool isMuted; // Mute original audio
  final VideoAspectRatio aspectRatio;
  final List<Subtitle> subtitles;

  VideoEditModel({
    required this.videoPath,
    this.startTime = Duration.zero,
    Duration? endTime,
    this.playbackSpeed = 1.0,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.filters = const [],
    this.textOverlays = const [],
    this.audioTracks = const [],
    this.backgroundMusic,
    this.musicVolume = 0.5,
    this.isMuted = false,
    this.aspectRatio = VideoAspectRatio.portrait_9_16,
    this.subtitles = const [],
  }) : endTime = endTime ?? Duration.zero;

  VideoEditModel copyWith({
    String? videoPath,
    Duration? startTime,
    Duration? endTime,
    double? playbackSpeed,
    int? brightness,
    int? contrast,
    int? saturation,
    List<FilterEffect>? filters,
    List<TextOverlay>? textOverlays,
    List<AudioTrack>? audioTracks,
    String? backgroundMusic,
    double? musicVolume,
    bool? isMuted,
    VideoAspectRatio? aspectRatio,
    List<Subtitle>? subtitles,
  }) {
    return VideoEditModel(
      videoPath: videoPath ?? this.videoPath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      filters: filters ?? this.filters,
      textOverlays: textOverlays ?? this.textOverlays,
      audioTracks: audioTracks ?? this.audioTracks,
      backgroundMusic: backgroundMusic ?? this.backgroundMusic,
      musicVolume: musicVolume ?? this.musicVolume,
      isMuted: isMuted ?? this.isMuted,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      subtitles: subtitles ?? this.subtitles,
    );
  }
}

enum VideoAspectRatio {
  portrait_9_16, // TikTok/Instagram Reels (9:16)
  square_1_1, // Instagram (1:1)
  landscape_16_9, // YouTube (16:9)
  widescreen_21_9, // Cinema
}

class FilterEffect {
  final String name; // 'noir', 'sepia', 'vivid', 'cool', 'warm', 'blur', 'sharpen'
  final double intensity; // 0.0 to 1.0
  final String category; // 'color', 'blur', 'distortion'

  FilterEffect({
    required this.name,
    required this.intensity,
    required this.category,
  });

  FilterEffect copyWith({String? name, double? intensity, String? category}) {
    return FilterEffect(
      name: name ?? this.name,
      intensity: intensity ?? this.intensity,
      category: category ?? this.category,
    );
  }
}

class TextOverlay {
  final String id;
  final String text;
  final double startTime; // seconds
  final double duration; // seconds
  final String fontFamily; // 'Roboto', 'Pacifico', 'Playfair'
  final int fontSize;
  final int textColor; // 0xFFFFFFFF
  final int backgroundColor; // 0x00000000
  final double opacity; // 0.0 to 1.0
  final TextAlignment alignment;
  final double positionX; // 0.0 to 1.0
  final double positionY; // 0.0 to 1.0

  TextOverlay({
    required this.id,
    required this.text,
    required this.startTime,
    required this.duration,
    this.fontFamily = 'Roboto',
    this.fontSize = 36,
    this.textColor = 0xFFFFFFFF,
    this.backgroundColor = 0x00000000,
    this.opacity = 1.0,
    this.alignment = TextAlignment.center,
    this.positionX = 0.5,
    this.positionY = 0.5,
  });

  TextOverlay copyWith({
    String? id,
    String? text,
    double? startTime,
    double? duration,
    String? fontFamily,
    int? fontSize,
    int? textColor,
    int? backgroundColor,
    double? opacity,
    TextAlignment? alignment,
    double? positionX,
    double? positionY,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      opacity: opacity ?? this.opacity,
      alignment: alignment ?? this.alignment,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
    );
  }
}

enum TextAlignment { topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight }

class AudioTrack {
  final String id;
  final String audioPath;
  final double startTime; // seconds
  final double duration; // seconds
  final double volume; // 0.0 to 1.0
  final String? label; // 'Music', 'Voiceover', 'SFX'
  final bool isMuted;

  AudioTrack({
    required this.id,
    required this.audioPath,
    required this.startTime,
    required this.duration,
    this.volume = 1.0,
    this.label,
    this.isMuted = false,
  });

  AudioTrack copyWith({
    String? id,
    String? audioPath,
    double? startTime,
    double? duration,
    double? volume,
    String? label,
    bool? isMuted,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      audioPath: audioPath ?? this.audioPath,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      label: label ?? this.label,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class Subtitle {
  final String id;
  final String text;
  final double startTime; // seconds
  final double endTime; // seconds
  final String language; // 'en', 'fr', 'es', 'pt'
  final bool autoGenerated; // true = auto-caption, false = manual

  Subtitle({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.language = 'en',
    this.autoGenerated = false,
  });

  Subtitle copyWith({
    String? id,
    String? text,
    double? startTime,
    double? endTime,
    String? language,
    bool? autoGenerated,
  }) {
    return Subtitle(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      language: language ?? this.language,
      autoGenerated: autoGenerated ?? this.autoGenerated,
    );
  }
}
