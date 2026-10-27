import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================

  static const String baseUrl = 'https://microblog-api-s2vk.onrender.com/api';

  static String get serverBaseUrl {
    final uri = Uri.parse(baseUrl);

    return '${uri.scheme}://${uri.host}'
        '${uri.hasPort ? ':${uri.port}' : ''}';
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final result = Map<String, dynamic>.from(decoded);

        if (!result.containsKey('success')) {
          result['success'] =
              response.statusCode >= 200 && response.statusCode < 300;
        }

        result['_statusCode'] = response.statusCode;

        return result;
      }

      return {
        'success': false,
        'message': 'Invalid server response',
        '_statusCode': response.statusCode,
      };
    } catch (_) {
      return {
        'success': false,
        'message': response.body.isNotEmpty
            ? response.body
            : 'Invalid server response',
        '_statusCode': response.statusCode,
      };
    }
  }

  static Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await clearLocalSession();
    }
  }

  static String _errorMessage(http.Response response, String fallback) {
    final decoded = _decode(response);

    final message = decoded['message']?.toString().trim() ?? '';

    if (message.isNotEmpty) {
      return message;
    }

    switch (response.statusCode) {
      case 400:
        return 'Invalid request';

      case 401:
        return 'Authentication required';

      case 403:
        return 'You are not allowed to perform this action';

      case 404:
        return 'Requested resource was not found';

      case 409:
        return 'This action conflicts with existing data';

      case 500:
        return 'Server error';

      default:
        return fallback;
    }
  }

  // ============================================================
  // AUTH / TOKEN
  // ============================================================

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('token');
  }

  static Future<String?> _validToken() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    // Check JWT expiration when possible.
    try {
      final parts = token.split('.');

      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );

        if (payload is Map && payload['exp'] is num) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(
            (payload['exp'] as num).toInt() * 1000,
          );

          if (!expiry.isAfter(DateTime.now())) {
            await clearLocalSession();
            return null;
          }
        }
      }
    } catch (_) {
      // If token is not a standard JWT,
      // let the backend validate it.
    }

    return token;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _validToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // IMAGE HELPERS
  // ============================================================

  static String? normalizeImageUrl(dynamic image) {
    if (image == null) {
      return null;
    }

    final value = image.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    if (value.toLowerCase().startsWith('data:image/')) {
      return value;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('//')) {
      return 'http:$value';
    }

    if (value.startsWith('/')) {
      return '$serverBaseUrl$value';
    }

    return '$serverBaseUrl/$value';
  }

  static Uint8List? dataUrlToBytes(dynamic image) {
    final value = image?.toString().trim() ?? '';

    if (!value.toLowerCase().startsWith('data:image/')) {
      return null;
    }

    final comma = value.indexOf(',');

    if (comma < 0) {
      return null;
    }

    try {
      return Uint8List.fromList(
        base64Decode(value.substring(comma + 1).trim()),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> fileToDataUrl(File file) async {
    final bytes = await file.readAsBytes();

    final path = file.path.toLowerCase();

    String mime = 'image/jpeg';

    if (path.endsWith('.png')) {
      mime = 'image/png';
    } else if (path.endsWith('.webp')) {
      mime = 'image/webp';
    } else if (path.endsWith('.gif')) {
      mime = 'image/gif';
    } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      mime = 'image/jpeg';
    }

    return 'data:$mime;base64,'
        '${base64Encode(bytes)}';
  }

  // ============================================================
  // AUTH API
  // ============================================================

  static Future<Map<String, dynamic>> register({
    String? displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'displayName': displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : username.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await clearLocalSession();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    final result = _decode(response);

    final token = result['data']?['token'];

    if (result['success'] == true &&
        token != null &&
        token.toString().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', token.toString());
    }

    return result;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final result = await getMe();

    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Unable to load profile');
    }

    final user = result['data']?['user'];

    if (user is! Map) {
      throw Exception('User profile data not found');
    }

    return Map<String, dynamic>.from(user);
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? username,
    String? email,
    String? bio,
    String? avatar,
    String? coverPhoto,
    String? location,
    String? website,
    String? dateOfBirth,
  }) async {
    final body = <String, dynamic>{};

    if (displayName != null) {
      body['displayName'] = displayName.trim();
    }

    if (username != null) {
      body['username'] = username.trim();
    }

    if (email != null) {
      body['email'] = email.trim();
    }

    if (bio != null) {
      body['bio'] = bio.trim();
    }

    if (avatar != null) {
      body['avatar'] = avatar;
    }

    if (coverPhoto != null) {
      body['coverPhoto'] = coverPhoto;
    }

    if (location != null) {
      body['location'] = location.trim();
    }

    if (website != null) {
      body['website'] = website.trim();
    }

    // ISO date string (YYYY-MM-DD); an empty string clears it.
    if (dateOfBirth != null) {
      body['dateOfBirth'] = dateOfBirth.trim();
    }

    final response = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // POSTS
  // ============================================================

  static Future<Map<String, dynamic>> createPost({
    required String content,
    String? image,
    String? video,
    String? location,
    Map<String, dynamic>? poll,
  }) async {
    final body = <String, dynamic>{'content': content.trim()};

    if (image != null && image.trim().isNotEmpty) {
      body['image'] = image;
    }

    if (video != null && video.trim().isNotEmpty) {
      body['video'] = video;
    }

    if (location != null && location.trim().isNotEmpty) {
      body['location'] = location.trim();
    }

    if (poll != null) {
      body['poll'] = poll;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> getPosts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> getMyStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/stats'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // DELETE POST / REPOST
  // ============================================================

  static Future<Map<String, dynamic>> deletePost({
    required String postId,
  }) async {
    if (postId.trim().isEmpty) {
      return {'success': false, 'message': 'Post ID is required'};
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/posts/$postId'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // LIKE
  // ============================================================

  static Future<Map<String, dynamic>> toggleLike({
    required String postId,
  }) async {
    if (postId.trim().isEmpty) {
      return {'success': false, 'message': 'Post ID is required'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // COMMENTS AND NESTED REPLIES
  // ============================================================


static Future<Map<String, dynamic>> createComment({
  required String postId,
  required String content,
  String? parentId,
}) async {
  if (postId.trim().isEmpty) {
    return {
      'success': false,
      'message': 'Post ID is required',
    };
  }

  if (content.trim().isEmpty) {
    return {
      'success': false,
      'message': 'Comment cannot be empty',
    };
  }

  final body = <String, dynamic>{
    'content': content.trim(),
  };

  if (parentId != null && parentId.trim().isNotEmpty) {
    body['parentId'] = parentId.trim();
  }

  final response = await http.post(
    Uri.parse('$baseUrl/posts/$postId/comments'),
    headers: await _headers(),
    body: jsonEncode(body),
  );

  await _handleUnauthorized(response);
  return _decode(response);
}

static Future<Map<String, dynamic>> getComments({
  required String postId,
}) async {
  if (postId.trim().isEmpty) {
    return {
      'success': false,
      'message': 'Post ID is required',
    };
  }

  final response = await http.get(
    Uri.parse('$baseUrl/posts/$postId/comments'),
    headers: await _headers(),
  );

  await _handleUnauthorized(response);
  return _decode(response);
}

// ==========================================
// EDIT COMMENT
// ==========================================
static Future<Map<String, dynamic>> updateComment({
  required String postId,
  required String commentId,
  required String content,
}) async {
  final response = await http.put(
    Uri.parse(
      "$baseUrl/posts/$postId/comments/$commentId",
    ),
    headers: await _headers(),
    body: jsonEncode({
      "content": content.trim(),
    }),
  );

  await _handleUnauthorized(response);

  return jsonDecode(response.body) as Map<String, dynamic>;
}

// ==========================================
// DELETE COMMENT
// ==========================================
static Future<Map<String, dynamic>> deleteComment({
  required String postId,
  required String commentId,
}) async {
  final response = await http.delete(
    Uri.parse(
      "$baseUrl/posts/$postId/comments/$commentId",
    ),
    headers: await _headers(),
  );

  await _handleUnauthorized(response);

  return jsonDecode(response.body) as Map<String, dynamic>;
}
  // ============================================================
  // MY COMMENTED POSTS
  //
  // This method is used by ProfileScreen.
  //
  // We intentionally implement this using the existing APIs so
  // you do NOT need to change the Node.js backend just to make
  // the Flutter application compile.
  //
  // It:
  // 1. Loads all posts.
  // 2. Loads comments for each post.
  // 3. Finds comments written by the current user.
  // 4. Returns the corresponding posts.
  // ============================================================

  static Future<Map<String, dynamic>> getMyCommentedPosts() async {
    try {
      final currentUser = await getCurrentUser();

      final currentUserId =
          currentUser['_id']?.toString() ?? currentUser['id']?.toString() ?? '';

      if (currentUserId.isEmpty) {
        return {
          'success': false,
          'message': 'Current user ID not found',
          'data': {'posts': <dynamic>[]},
        };
      }

      final postsResult = await getPosts();

      if (postsResult['success'] != true) {
        return postsResult;
      }

      final rawPosts = postsResult['data']?['posts'];

      if (rawPosts is! List) {
        return {
          'success': true,
          'data': {'posts': <dynamic>[]},
        };
      }

      final commentedPosts = <dynamic>[];

      for (final rawPost in rawPosts) {
        if (rawPost is! Map) {
          continue;
        }

        final postId = rawPost['_id']?.toString() ?? '';

        if (postId.isEmpty) {
          continue;
        }

        try {
          final commentsResult = await getComments(postId: postId);

          if (commentsResult['success'] != true) {
            continue;
          }

          final comments = commentsResult['data']?['comments'];

          if (comments is! List) {
            continue;
          }

          bool commentedByMe = false;

          for (final rawComment in comments) {
            if (rawComment is! Map) {
              continue;
            }

            final author = rawComment['author'];

            String? authorId;

            if (author is Map) {
              authorId = author['_id']?.toString() ?? author['id']?.toString();
            } else if (author != null) {
              authorId = author.toString();
            }

            if (authorId == currentUserId) {
              commentedByMe = true;
              break;
            }
          }

          if (commentedByMe) {
            commentedPosts.add(Map<String, dynamic>.from(rawPost));
          }
        } catch (_) {
          // If one post's comments fail,
          // continue checking the remaining posts.
          continue;
        }
      }

      return {
        'success': true,
        'data': {'posts': commentedPosts},
      };
    } catch (error) {
      return {
        'success': false,
        'message': error.toString(),
        'data': {'posts': <dynamic>[]},
      };
    }
  }

  // ============================================================
  // RECORD SHARE
  // ============================================================
  // Append this static declaration inside your ApiService class
  static Future<Map<String, dynamic>> recordShare({
    required String postId,
  }) async {
    try {
      // Directs payload calls back to your Node.js routing controllers
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/share'),
        headers: {
          'Content-Type': 'application/json',
          // Ensure your standard authorization headers map cleanly here if needed
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Share recorded successfully'};
      }
      return {'success': false, 'message': 'Failed to record analytics'};
    } catch (e) {
      debugPrint('ApiService recordShare exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================
  // BOOKMARK
  // ============================================================

  static Future<Map<String, dynamic>> toggleBookmark({
    required String postId,
  }) async {
    if (postId.trim().isEmpty) {
      return {'success': false, 'message': 'Post ID is required'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/bookmark'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> getBookmarks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/bookmarks'),
      headers: await _headers(),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // REPOST WITH CAPTION
  // ============================================================

  static Future<Map<String, dynamic>> repost({
    required String postId,
    String caption = '',
  }) async {
    if (postId.trim().isEmpty) {
      return {'success': false, 'message': 'Post ID is required'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/repost'),
      headers: await _headers(),
      body: jsonEncode({'caption': caption.trim()}),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // POLL VOTE
  // ============================================================

  static Future<Map<String, dynamic>> votePoll({
    required String postId,
    required int optionIndex,
  }) async {
    if (postId.trim().isEmpty) {
      return {'success': false, 'message': 'Post ID is required'};
    }

    if (optionIndex < 0) {
      return {'success': false, 'message': 'Invalid poll option'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/poll/vote'),
      headers: await _headers(),
      body: jsonEncode({'optionIndex': optionIndex}),
    );

    await _handleUnauthorized(response);

    return _decode(response);
  }

  // ============================================================
  // SESSION
  // ============================================================

  static Future<bool> isLoggedIn() async {
    final token = await _validToken();

    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await clearLocalSession();
  }

  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('token');
  }
}