import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DifyPromptApiService {
  final String _baseUrl = dotenv.env['DIFY_URL'].toString();
  final String _key = dotenv.env['DIFY_API_KEY'].toString();

  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      print('❌ Error getting auth token: $e');
      return null;
    }
  }

  // Get user identifier from SharedPreferences or use default
  Future<String> _getUserIdentifier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        return userId;
      }

      // Fallback to auth token or default
      final token = await _getAuthToken();
      return token ?? 'defaultuser';
    } catch (e) {
      print('❌ Error getting user identifier: $e');
      return 'defaultuser';
    }
  }

  // Convert PlatformFile to Dify file format
  Map<String, dynamic>? _convertFileForDify(PlatformFile file) {
    try {
      // For now, we'll handle files as attachments
      // In real implementation, you might need to upload file first and get URL
      return {
        'type': _getFileType(file.extension),
        'transfer_method':
            'local_file', // or 'remote_url' if you upload to cloud first
        'name': file.name,
        'size': file.size,
        // For remote_url, you would add:
        // 'url': 'https://your-file-storage.com/uploaded-file-url'
      };
    } catch (e) {
      print('❌ Error converting file for Dify: $e');
      return null;
    }
  }

  // Determine file type based on extension
  String _getFileType(String? extension) {
    if (extension == null) return 'document';

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return 'image';
      case 'pdf':
        return 'document';
      case 'doc':
      case 'docx':
        return 'document';
      case 'txt':
        return 'document';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      case 'mp3':
      case 'wav':
        return 'audio';
      default:
        return 'document';
    }
  }

  // Main method to send message to Dify API
  Future<Map<String, dynamic>?> sendMessage({
    required String query,
    String conversationId = '',
    Map<String, dynamic> inputs = const {},
    String responseMode = 'blocking',
    PlatformFile? file,
  }) async {
    try {
      print('📡 Sending message to Dify API...');
      print('📤 Query: $query');
      print(
        '🔗 Conversation ID: ${conversationId.isEmpty ? 'New conversation' : conversationId}',
      );

      final url = Uri.parse('$_baseUrl/chat-messages');
      final userIdentifier = await _getUserIdentifier();

      // Build request body according to Dify API specification
      final requestBody = <String, dynamic>{
        'inputs': inputs,
        'query': query,
        'response_mode': responseMode,
        'conversation_id': conversationId,
        'user': userIdentifier,
      };

      // Add files if provided
      if (file != null) {
        final difyFile = _convertFileForDify(file);
        if (difyFile != null) {
          requestBody['files'] = [difyFile];
          print('📎 File attached: ${file.name}');
        }
      }

      print('📋 Request body: ${json.encode(requestBody)}');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      headers['Authorization'] = 'Bearer $_key';
      // Send HTTP POST request
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('✅ Dify API response received successfully');
        print('📋 Response data keys: ${responseData.keys.join(', ')}');

        return responseData;
      } else {
        print('❌ Dify API error: ${response.statusCode}');
        print('❌ Error body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error sending message to Dify: $e');
      return null;
    }
  }

  // Method to extract answer from Dify response
  String? extractAnswer(Map<String, dynamic>? responseData) {
    if (responseData == null) return null;

    try {
      // Common response formats from Dify
      if (responseData.containsKey('answer')) {
        return responseData['answer'] as String?;
      }

      if (responseData.containsKey('data') && responseData['data'] is Map) {
        final data = responseData['data'] as Map<String, dynamic>;
        if (data.containsKey('answer')) {
          return data['answer'] as String?;
        }
      }

      if (responseData.containsKey('message')) {
        return responseData['message'] as String?;
      }

      if (responseData.containsKey('content')) {
        return responseData['content'] as String?;
      }

      // If no standard field found, return the full response as string
      return json.encode(responseData);
    } catch (e) {
      print('❌ Error extracting answer from Dify response: $e');
      return null;
    }
  }

  // Method to extract conversation ID from response (for continuing conversations)
  String? extractConversationId(Map<String, dynamic>? responseData) {
    if (responseData == null) return null;

    try {
      if (responseData.containsKey('conversation_id')) {
        return responseData['conversation_id'] as String?;
      }

      if (responseData.containsKey('data') && responseData['data'] is Map) {
        final data = responseData['data'] as Map<String, dynamic>;
        if (data.containsKey('conversation_id')) {
          return data['conversation_id'] as String?;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error extracting conversation ID: $e');
      return null;
    }
  }

  // Convenience method that combines send message and extract answer
  Future<String?> sendMessageAndGetAnswer({
    required String query,
    String conversationId = '',
    Map<String, dynamic> inputs = const {},
    String responseMode = 'blocking',
    PlatformFile? file,
  }) async {
    final response = await sendMessage(
      query: query,
      conversationId: conversationId,
      inputs: inputs,
      responseMode: responseMode,
      file: file,
    );

    return extractAnswer(response);
  }

  // Method to handle file upload to remote storage (if needed)
  Future<String?> uploadFileToRemoteStorage(PlatformFile file) async {
    // TODO: Implement file upload to your cloud storage
    // This would upload the file and return the URL
    // For now, return null to use local_file transfer method

    try {
      print('📤 Uploading file to remote storage: ${file.name}');

      // Example implementation:
      // 1. Upload file to your cloud storage (AWS S3, Google Cloud, etc.)
      // 2. Return the public URL

      // For demonstration purposes, return a mock URL
      // In real implementation, replace this with actual upload logic
      return null; // Return actual URL after upload
    } catch (e) {
      print('❌ Error uploading file to remote storage: $e');
      return null;
    }
  }

  // Test connection to Dify API
  Future<bool> testConnection() async {
    try {
      print('🔧 Testing connection to Dify API...');

      final response = await sendMessage(
        query: 'Hello, this is a connection test.',
        responseMode: 'blocking',
      );

      if (response != null) {
        print('✅ Dify API connection successful');
        return true;
      } else {
        print('❌ Dify API connection failed');
        return false;
      }
    } catch (e) {
      print('❌ Error testing Dify API connection: $e');
      return false;
    }
  }
}
