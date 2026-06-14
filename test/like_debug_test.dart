import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  final token = '9|AKdczmBDZvT2CktsijiBaChiW6VoJmII57zfHo8z0398eb9a';
  final client = HttpClient();
  
  try {
    final request = await client.getUrl(Uri.parse('https://app2.clickexpress.delivery/api/home'));
    request.headers.add('Authorization', 'Bearer $token');
    request.headers.add('Accept', 'application/json');
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final data = json.decode(responseBody);
    
    // Most Laravel APIs return 'data' as paginated: { "data": { "current_page": 1, "data": [...] } }
    // Or just { "data": [...] }
    dynamic posts;
    if (data['data'] != null) {
      if (data['data'] is List) {
        posts = data['data'];
      } else if (data['data'] is Map && data['data']['data'] is List) {
        posts = data['data']['data'];
      }
    } else if (data['posts'] != null) {
      posts = data['posts'];
    }
    
    if (posts is List && posts.isNotEmpty) {
      final post = posts.first;
      debugPrint('--- RAW POST JSON ---');
      debugPrint(const JsonEncoder.withIndent('  ').convert(post));
      
      debugPrint('\n--- LIKE PROPERTIES ---');
      debugPrint('is_liked: ${post['is_liked']}');
      debugPrint('likes_count: ${post['likes_count']}');
      debugPrint('likes: ${post['likes']}');
      debugPrint('liked_by_user_ids: ${post['liked_by_user_ids']}');
    } else {
      debugPrint('No posts or unexpected format: $data');
    }
  } catch (e) {
    debugPrint('Error: $e');
  } finally {
    client.close();
  }
}
