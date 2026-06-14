import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Central service layer for all LUMO backend microservices.
///
/// Hosts:
///   - Chatbot API     → :8000
///   - Image Analysis  → :8001
///   - Story / Audio   → :8081
class LumoApiService {
  static const String _host = '20.230.160.202';

  // ─── Base URIs ────────────────────────────────────────────────────────────

  static Uri get _analysisBase => Uri(scheme: 'http', host: _host, port: 8001);
  static Uri get _storyBase => Uri(scheme: 'http', host: _host, port: 8081);

  // ─── Timeouts ─────────────────────────────────────────────────────────────

  static const Duration _defaultTimeout = Duration(seconds: 60);
  static const Duration _audioTimeout = Duration(seconds: 90);

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Emotion & Gaze Analysis API  (POST :8001/analyze_image)
  // ──────────────────────────────────────────────────────────────────────────

  /// Sends an image [file] to Carol's emotion & gaze analysis model.
  ///
  /// Uses a [http.MultipartRequest] with the file field key `'file'`.
  /// Returns the raw decoded JSON map so the repository can parse it freely.
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final uri = _analysisBase.replace(path: '/analyze_image');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file', // ← required key name per Swagger spec
          imageFile.path,
        ),
      );

    final streamed = await request.send().timeout(_defaultTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = utf8.decode(response.bodyBytes);
      return jsonDecode(decoded) as Map<String, dynamic>;
    } else {
      throw LumoApiException(
        statusCode: response.statusCode,
        message: 'Image Analysis API error: ${response.body}',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Story & Audio API  (GET :8081/get-story-audio)
  // ──────────────────────────────────────────────────────────────────────────

  /// Fetches a generated story MP3 from the audio API.
  ///
  /// The response body contains raw MP3 bytes.
  /// Metadata (story text, emotion, question, answer) is URL-encoded inside
  /// custom HTTP headers and MUST be decoded with [Uri.decodeComponent].
  Future<StoryAudioResponse> getStoryAudio() async {
    final uri = _storyBase.replace(path: '/get-story-audio');

    final response = await http
        .get(uri)
        .timeout(_audioTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Extract and URL-decode Arabic metadata headers.
      String decodeHeader(String? value) =>
          value != null ? Uri.decodeComponent(value) : '';

      final headers = response.headers;

      return StoryAudioResponse(
        audioBytes: response.bodyBytes,
        story: decodeHeader(headers['x-story']),
        question: decodeHeader(headers['x-question']),
        answer: decodeHeader(headers['x-answer']),
        emotion: decodeHeader(headers['x-emotion']),
      );
    } else {
      throw LumoApiException(
        statusCode: response.statusCode,
        message: 'Story Audio API error: ${response.statusCode}',
      );
    }
  }
}

// ─── Value objects ──────────────────────────────────────────────────────────

/// Holds the audio bytes and URL-decoded metadata returned by the story API.
class StoryAudioResponse {
  final List<int> audioBytes;
  final String story;
  final String question;
  final String answer;
  final String emotion;

  const StoryAudioResponse({
    required this.audioBytes,
    required this.story,
    required this.question,
    required this.answer,
    required this.emotion,
  });
}

/// Thrown when a LUMO microservice returns a non-2xx status code.
class LumoApiException implements Exception {
  final int statusCode;
  final String message;

  const LumoApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'LumoApiException($statusCode): $message';
}
