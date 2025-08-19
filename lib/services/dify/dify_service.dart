import 'package:difychatbot/services/api/me_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'dify_prompt_api_service.dart';
import '../../models/upload_file_dify_response.dart';

class DifyService {
  final DifyPromptApiService _apiService = DifyPromptApiService();
  String? _currentConversationId;

  // Smart URL selection based on platform (kept for compatibility)
  String get difyUrl {
    if (kIsWeb) {
      // For web development, use local tunnel to avoid CORS
      return dotenv.env['DIFY_URL'].toString();
    } else {
      // For mobile, can use either local or server URL
      return dotenv.env['DIFY_URL'].toString();
    }
  }

  Future<String?> sendMessage({
    required String message,
    required String model,
    PlatformFile? file, // Add file parameter
  }) async {
    try {
      var userID = await meAPI().getUserProfile();
      print('📡 Using Dify API Service for message: $message');
      print('🤖 Model: $model');

      // Use the new DifyPromptApiService
      final response = await _apiService.sendMessage(
        query: message,
        conversationId: _currentConversationId ?? '',
        file: file,
      );

      if (response != null) {
        // Extract conversation ID for next messages
        final newConversationId = _apiService.extractConversationId(response);
        if (newConversationId != null && newConversationId.isNotEmpty) {
          _currentConversationId = newConversationId;
          print('💬 Conversation ID updated: $_currentConversationId');
        }

        // Extract and return the answer
        final answer = _apiService.extractAnswer(response);
        if (answer != null && answer.isNotEmpty) {
          print('✅ Dify response received successfully');
          return answer;
        }
      }

      print('⚠️ No valid response from Dify API, using fallback');
      return _getDefaultDifyResponse(model, message);
    } catch (e) {
      print('❌ Error communicating with Dify: $e');
      return _getDefaultDifyResponse(model, message);
    }
  }

  // Reset conversation (start new conversation)
  void resetConversation() {
    _currentConversationId = null;
    print('🔄 Conversation reset - next message will start new conversation');
  }

  // Get current conversation ID
  String? get currentConversationId => _currentConversationId;

  // Set conversation ID manually (if needed)
  void setConversationId(String? conversationId) {
    _currentConversationId = conversationId;
    print('🔧 Conversation ID set manually: $_currentConversationId');
  }

  // Test Dify API connection
  Future<bool> testConnection() async {
    return await _apiService.testConnection();
  }

  // Test upload endpoint
  Future<void> testUploadEndpoint() async {
    await _apiService.testUploadEndpoint();
  }

  // Tampilkan contoh format request
  void showRequestFormatExample() {
    _apiService.showRequestFormatExample();
  }

  // Upload file with detailed response model
  Future<UploadFileDifyResponse?> uploadFile(PlatformFile file) async {
    try {
      print('📤 DifyService: Uploading file ${file.name}');
      final uploadResponse = await _apiService.uploadFileToDify(file);

      if (uploadResponse != null) {
        print('✅ DifyService: File uploaded successfully');
        print('🆔 File ID: ${uploadResponse.id}');
        print('📄 File Name: ${uploadResponse.name}');
        print('📊 File Size: ${uploadResponse.size} bytes');
        print('📎 Extension: ${uploadResponse.extension}');
        print('🎭 MIME Type: ${uploadResponse.mimeType}');
      } else {
        print('❌ DifyService: File upload failed');
      }

      return uploadResponse;
    } catch (e) {
      print('❌ DifyService: Error uploading file: $e');
      return null;
    }
  }

  // Get default response for Dify (single general response)
  String _getDefaultDifyResponse(String model, String message) {
    return '''Halo! Saya adalah Dify AI Assistant.

Maaf, saat ini **tidak dapat terhubung** ke Dify AI assistant. 

### Silakan coba:
1. Periksa koneksi internet Anda
2. Refresh halaman 
3. Coba lagi dalam beberapa saat

---

_Jika masalah berlanjut, hubungi administrator sistem._

Saya tetap siap membantu Anda dengan berbagai pertanyaan dan tugas setelah koneksi kembali normal.''';
  }
}
