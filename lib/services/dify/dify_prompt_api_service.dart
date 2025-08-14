import 'dart:convert';
import 'dart:io';
import 'package:difychatbot/services/api/me_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../../models/upload_file_dify_response.dart';

class DifyPromptApiService {
  final String _baseUrl = dotenv.env['DIFY_URL'].toString();
  final String _key = dotenv.env['DIFY_API_KEY'].toString();

  // Debug method to check configuration
  void debugConfiguration() async {
    print('🔍 === DIFY CONFIGURATION DEBUG ===');
    print('🔗 Base URL: $_baseUrl');
    print(
      '🔑 API Key: ${_key.isEmpty ? "NOT SET" : "SET (${_key.length} chars)"}',
    );
    print('🔗 Upload URL: $_baseUrl/files/upload');
    print('🔗 Chat URL: $_baseUrl/chat-messages');

    // Test user identifier from me_api_service
    try {
      final userIdentifier = await _getUserIdentifier();
      print('👤 User Identifier: $userIdentifier');
    } catch (e) {
      print('❌ Error getting user identifier: $e');
    }

    print('🔍 === END CONFIGURATION DEBUG ===');
  }

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

  // Get user identifier from me_api_service
  Future<String> _getUserIdentifier() async {
    try {
      // Get user data from me_api_service
      final meApiService = meAPI();
      final meResponse = await meApiService.getUserProfile();

      if (meResponse != null && meResponse.data.isNotEmpty) {
        final userData = meResponse.data.first;
        final userId = userData.id;
        print('👤 Using user ID from me_api_service: $userId');
        print('👤 User name: ${userData.namaDepan} ${userData.namaBelakang}');
        print('👤 User email: ${userData.email}');
        return userId.toString();
      }
    } catch (e) {
      print('❌ Error getting user identifier from me_api_service: $e');

      return '0'; // Fallback if error occurs
    }
    // Ensure a non-nullable String is always returned
    return '0';
  }

  // Upload file to Dify first and get file ID - now returns structured response
  Future<UploadFileDifyResponse?> uploadFileToDify(PlatformFile file) async {
    try {
      print('📤 Uploading file to Dify: ${file.name}');
      print('📊 File size: ${file.size} bytes');
      print('📋 File extension: ${file.extension}');
      print('🔗 Base URL: $_baseUrl');
      print('🔑 API Key available: ${_key.isNotEmpty ? "Yes" : "No"}');

      final uploadUrl = Uri.parse('$_baseUrl/files/upload');
      print('🌐 Upload URL: $uploadUrl');
      final userIdentifier = await _getUserIdentifier();
      var request = http.MultipartRequest('POST', uploadUrl);

      // Set headers - Dify API menggunakan Bearer token
      request.headers['Authorization'] = 'Bearer $_key';

      // Add file menggunakan bytes atau path fallback
      if (file.bytes != null) {
        print('✅ File bytes available: ${file.bytes!.length} bytes');

        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        print('📄 MIME type: $mimeType');

        // Add file dengan content type yang proper
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', // Field name untuk file upload
            file.bytes!,
            filename: file.name,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (file.path != null) {
        // Fallback: jika bytes null, coba baca dari path
        print('⚠️ File bytes is null, trying to read from path: ${file.path}');

        try {
          final fileBytes = await File(file.path!).readAsBytes();
          print('✅ File read from path: ${fileBytes.length} bytes');

          final mimeType =
              lookupMimeType(file.name) ?? 'application/octet-stream';
          print('📄 MIME type: $mimeType');

          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: file.name,
              contentType: MediaType.parse(mimeType),
            ),
          );
        } catch (e) {
          print('❌ Error reading file from path: $e');
          return null;
        }
      } else {
        print('❌ Both file.bytes and file.path are null');
        print('💡 Make sure to use FilePicker with withData: true');
        return null;
      }

      // Add fields untuk upload request
      request.fields['user'] = userIdentifier;

      // Add type field berdasarkan extension
      final fileType = _getSimpleFileType(file.extension);
      request.fields['type'] = fileType;

      print('👤 User identifier: $userIdentifier');
      print('📄 File type: $fileType');

      print('🔄 Sending file upload request...');
      print('📋 Request headers: ${request.headers}');
      print('📋 Request fields: ${request.fields}');
      print('📋 Request files count: ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response headers: ${response.headers}');
      print('📥 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          // Parse response menggunakan model yang sudah dibuat
          final uploadResponse = uploadFileDifyResponseFromJson(response.body);
          print('✅ File uploaded successfully using model!');
          print('📋 Upload Response: $uploadResponse');
          print('🆔 File ID: ${uploadResponse.id}');
          print('📄 File Name: ${uploadResponse.name}');
          print('📊 File Size: ${uploadResponse.size} bytes');
          print('📎 Extension: ${uploadResponse.extension}');
          print('🎭 MIME Type: ${uploadResponse.mimeType}');

          return uploadResponse;
        } catch (e) {
          print('❌ Error parsing upload response with model: $e');
          print('📄 Raw response: ${response.body}');

          // Fallback: parse manual jika model gagal
          try {
            final responseData = json.decode(response.body);
            print('  Fallback - Parsed response data: $responseData');
            return null;
          } catch (fallbackError) {
            print('❌ Fallback parsing also failed: $fallbackError');
            return null;
          }
        }
      } else {
        print('❌ File upload failed with status: ${response.statusCode}');
        print('❌ Error response: ${response.body}');

        // Try to parse error details
        try {
          final errorData = json.decode(response.body);
          print('❌ Error details: $errorData');
        } catch (e) {
          print('❌ Could not parse error response');
        }
      }

      print('❌ File upload failed');
      return null;
    } catch (e) {
      print('❌ Error uploading file to Dify: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Get simple file type untuk field 'type' di request
  String _getSimpleFileType(String? extension) {
    if (extension == null) return 'document';

    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'doc':
      case 'docx':
        return 'document';
      case 'txt':
        return 'text';
      default:
        return 'document';
    }
  }

  // Convert uploaded file to Dify files format using response model
  // Convert UploadFileDifyResponse to files format (sesuai format yang diminta)
  Map<String, dynamic>? convertUploadResponseToFilesFormat(
    UploadFileDifyResponse uploadResponse,
  ) {
    try {
      // Format sesuai dengan contoh yang diberikan
      return {
        'id': uploadResponse.id,
        'type': _getFileType(uploadResponse.extension),
        'transfer_method': 'local_file',
        'filename': uploadResponse.name,
        'extension': uploadResponse.extension, // Tanpa titik seperti contoh
        'mime_type': uploadResponse.mimeType,
        'size': uploadResponse.size,
      };
    } catch (e) {
      print('❌ Error converting upload response to files format: $e');
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

      // Debug configuration first
      debugConfiguration();

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

      // Handle file upload if provided
      if (file != null) {
        print('📤 Processing file upload...');

        // Upload file using the new method with model response
        final uploadResponse = await uploadFileToDify(file);
        print('📎 Upload Response: $uploadResponse');

        if (uploadResponse != null) {
          print('✅ File uploaded successfully!');
          print('🆔 File ID: ${uploadResponse.id}');
          print('📄 File Name: ${uploadResponse.name}');
          print('📊 File Size: ${uploadResponse.size} bytes');

          // Convert to files format menggunakan format baru
          final difyFile = convertUploadResponseToFilesFormat(uploadResponse);
          if (difyFile != null) {
            // Use files array format as per format yang diminta
            requestBody['files'] = [difyFile];
            print('📎 File attached to chat with ID: ${uploadResponse.id}');
            print('📋 Files data: $difyFile');
          } else {
            print('❌ Failed to convert upload response to files format');
          }
        } else {
          print('❌ Failed to upload file, sending without file');
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

  // Test file upload endpoint directly
  Future<void> testUploadEndpoint() async {
    try {
      print('🔧 Testing upload endpoint...');
      print('🌐 Testing URL: $_baseUrl/files/upload');
      print('🔑 API Key: ${_key.isNotEmpty ? "Available" : "Missing"}');

      // Test with simple GET to see if endpoint exists
      final testUrl = Uri.parse('$_baseUrl/files/upload');
      final response = await http.get(
        testUrl,
        headers: {'Authorization': 'Bearer $_key'},
      );

      print('📥 Test response status: ${response.statusCode}');
      print('📥 Test response: ${response.body}');
    } catch (e) {
      print('❌ Upload endpoint test failed: $e');
    }
  }

  // Method untuk menampilkan contoh format request dengan file
  void showRequestFormatExample() async {
    print('📋 === CONTOH FORMAT REQUEST DENGAN FILE ===');

    // Get real user identifier dari me_api_service
    final userIdentifier = await _getUserIdentifier();

    final exampleRequest = {
      "inputs": {},
      "query": "apa isi dokumen ini?",
      "response_mode": "blocking",
      "conversation_id": "",
      "user": userIdentifier, // User ID dari me_api_service
      "files": [
        {
          "id": "e8e8b4f1-3f8f-4f8a-bf6f-123456789abc",
          "type": "document",
          "transfer_method": "local_file",
          "filename": "dokumen.pdf",
          "extension": "pdf",
          "mime_type": "application/pdf",
          "size": 23456,
        },
      ],
    };
    print('📄 Format JSON: ${json.encode(exampleRequest)}');
    print('👤 User ID diambil dari me_api_service: $userIdentifier');
    print('📋 === END FORMAT EXAMPLE ===');
  }
}
