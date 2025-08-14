import 'dart:convert';
import 'package:difychatbot/services/api/me_api_service.dart';
import 'package:difychatbot/utils/string_capitalize.dart';
import 'package:difychatbot/constants/app_colors.dart';
import 'package:difychatbot/services/dify/dify_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_message.dart';
import '../../models/me_response.dart';
import '../../components/index.dart';
import '../../services/web_chat_service.dart';

class DifyChatScreen extends StatefulWidget {
  @override
  _DifyChatScreenState createState() => _DifyChatScreenState();
}

class _DifyChatScreenState extends State<DifyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final meAPI _meAPI = meAPI();
  final DifyService _difyService = DifyService();
  final WebChatService _chatService = WebChatService();

  // Chat state
  String _selectedModel = 'General Chat'; // Fixed model for Dify
  PlatformFile? _selectedFile; // Add file attachment capability
  List<Map<String, dynamic>> _conversationHistory = [];
  bool _isLoadingHistory = false;

  // User data variables
  UserData? currentUser;
  bool isLoading = true;
  bool isClearingChat = false;
  bool isAiThinking = false;
  String? errorMessage;

  // Sample chat messages
  List<ChatMessage> messages = [
    ChatMessage(
      id: '1',
      text:
          "Halo! Saya adalah Dify AI assistant Anda. Bagaimana saya bisa membantu Anda hari ini?",
      isUser: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState(); // Test koneksi Dify saat init
    initUser().then((_) {
      if (currentUser != null) {
        setState(() {
          messages[0] = ChatMessage(
            id: '1',
            text: getGreetingMessage(),
            isUser: false,
            timestamp: DateTime.now().subtract(Duration(minutes: 5)),
          );
        });
        _loadChatHistory();
        _autoCreateNewConversationIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> initUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await _meAPI.getUserProfile();

      if (response != null && response.data.isNotEmpty) {
        setState(() {
          currentUser = response.data.first;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          currentUser = null;
          isLoading = false;
          errorMessage = 'Gagal mendapatkan data pengguna';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anda belum login atau session telah berakhir'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentUser = null;
        isLoading = false;
        errorMessage = 'Terjadi kesalahan: $e';
      });

      print('Error loading user: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan saat memuat data pengguna'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty && _selectedFile == null) return;

    final userMessage = message;

    // Add user message to UI
    setState(() {
      if (message.isNotEmpty) {
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: userMessage,
            isUser: true,
            timestamp: DateTime.now(),
            fileName: _selectedFile?.name,
            fileType: _selectedFile != null ? 'file' : null,
          ),
        );
      }

      // Add file info if exists
      if (_selectedFile != null && message.isEmpty) {
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_file',
            text: '📎 File: ${_selectedFile!.name}',
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
      }

      isAiThinking = true;
    });

    _messageController.clear();
    final tempFile = _selectedFile;
    _selectedFile = null; // Clear selected file
    _scrollToBottom();

    try {
      // Handle Dify API call
      String textResponse = '';

      print('🚀 Starting Dify API call...');
      print('📨 Message: $userMessage');
      print('🏷️ Model: $_selectedModel');
      print('📎 File: ${tempFile?.name ?? 'No file'}');

      final difyResponse = await _difyService.sendMessage(
        message: userMessage,
        model: _selectedModel,
        file: tempFile, // Pass file to Dify service
      );

      print("📥 Dify response: $difyResponse");
      print("📊 Response type: ${difyResponse.runtimeType}");
      print("📏 Response length: ${difyResponse?.length ?? 0}");

      if (difyResponse != null && difyResponse.isNotEmpty) {
        textResponse = difyResponse;
        print("✅ Using API response");
      } else {
        print("⚠️ No response from API, using fallback");
        textResponse = '''# Koneksi Terputus 

## Tidak dapat terhubung ke Dify Assistant

Maaf, saat ini **tidak dapat terhubung** ke Dify AI assistant. 

### Silakan coba:
1. Periksa koneksi internet Anda
2. Refresh halaman 
3. Coba lagi dalam beberapa saat

---

_Jika masalah berlanjut, hubungi administrator sistem._
''';
      }

      // Add AI response to UI
      setState(() {
        isAiThinking = false;
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: textResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      // Save to chat history
      if (currentUser != null) {
        await _saveChatToHistory(userMessage, textResponse);
      }

      _scrollToBottom();
    } catch (e) {
      print('❌ Error in _sendMessage: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('📋 Stack trace: ${StackTrace.current}');

      setState(() {
        isAiThinking = false;
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text:
                "Maaf, terjadi kesalahan pada Dify service. Silakan coba lagi.\n\nError: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();
      print('❌ Error sending message to Dify: $e');
    }
  }

  Future<void> _cleanErrorMessagesFromStorage(int conversationId) async {
    try {
      print(
        '🧹 Cleaning error messages from DIFY conversation $conversationId',
      );
      final prefs = await SharedPreferences.getInstance();

      // Get messages key
      final messagesKey = 'n8n_messages_$conversationId';
      final messagesJson = prefs.getString(messagesKey);

      if (messagesJson != null && messagesJson.isNotEmpty) {
        final List<dynamic> messagesList = jsonDecode(messagesJson);

        final cleanMessages =
            messagesList.where((message) {
              final content = (message['content']?.toString() ?? '').trim();
              final isErrorMessage =
                  content ==
                      'Maaf, terjadi kesalahan saat memproses pesan Anda. Silakan coba lagi.' ||
                  content == 'Error memuat conversation' ||
                  content == '[Error loading message]' ||
                  content == 'Memuat riwayat percakapan...' ||
                  content.startsWith(
                    'Maaf, tidak dapat memuat riwayat percakapan ini',
                  ) ||
                  content.startsWith('Maaf, terjadi kesalahan pada') ||
                  content.contains('Silakan coba lagi');

              if (isErrorMessage) {
                print(
                  '🗑️ Removing error message from storage: ${content.substring(0, 50)}...',
                );
              }

              return !isErrorMessage;
            }).toList();

        if (cleanMessages.length != messagesList.length) {
          // Save cleaned messages back to storage
          await prefs.setString(messagesKey, jsonEncode(cleanMessages));
          print(
            '✅ Cleaned ${messagesList.length - cleanMessages.length} error messages from storage',
          );
        } else {
          print('ℹ️ No error messages found to clean in storage');
        }
      }
    } catch (e) {
      print('❌ Error cleaning messages from storage: $e');
    }
  }

  void _onFileSelected() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
        print('📎 File selected: ${_selectedFile!.name}');
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memilih file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  void _showNewChatConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.secondaryBackground,
              title: Text(
                'Percakapan Baru',
                style: TextStyle(color: AppColors.primaryText),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isClearingChat)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.accent),
                          SizedBox(height: 8),
                          Text(
                            'Membuat percakapan baru...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Apakah Anda ingin membuat percakapan baru?',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
              actions: [
                if (!isClearingChat) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Batal',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _createNewChatWithLoading(setDialogState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primaryText,
                    ),
                    child: Text('Ya, Buat Baru'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createNewChatWithLoading(StateSetter setDialogState) async {
    setDialogState(() {
      isClearingChat = true;
    });
    setState(() {
      isClearingChat = true;
    });

    try {
      if (currentUser != null) {
        // Reset current conversation
        _chatService.setCurrentConversation(0);

        // Create new conversation with DIFY prefix
        final newConversationId = await _chatService.startNewConversation(
          userId: currentUser!.id,
          title:
              'DIFY Chat ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );

        print('🆕 Created new DIFY conversation: $newConversationId');
        await _chatService.setCurrentConversation(newConversationId);
      }

      await Future.delayed(Duration(milliseconds: 500));

      setState(() {
        messages.clear();
        messages.add(
          ChatMessage(
            id: '1',
            text: getGreetingMessage(),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        isClearingChat = false;
      });

      // Reload chat history to show new conversation
      if (mounted) {
        _loadChatHistory();
      }

      Navigator.pop(context);
      _scrollToBottom();
    } catch (e) {
      print('❌ Error creating new DIFY conversation: $e');
      setState(() {
        isClearingChat = false;
      });
      Navigator.pop(context);
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String getUserDisplayName() {
    if (currentUser != null) {
      return 'Selamat Datang ${currentUser!.namaDepan.capitalize()}';
    }
    return 'Guest User';
  }

  String getGreetingMessage() {
    if (currentUser != null) {
      return 'Halo ${currentUser!.namaDepan}! Saya adalah Dify AI assistant Anda. Bagaimana saya bisa membantu anda hari ini?';
    }
    return 'Halo! Saya adalah Dify AI assistant Anda. Bagaimana saya bisa membantu anda hari ini?';
  }

  // Method untuk debug manual
  Future<void> _debugDifyService() async {
    try {
      print('🔍 === DIFY SERVICE DEBUG START ===');

      // Test simple message
      final testResponse = await _difyService.sendMessage(
        message: 'Test koneksi Dify',
        model: _selectedModel,
      );

      print('📤 Test message sent: "Test koneksi Dify"');
      print('📥 Test response: $testResponse');
      print('📊 Response type: ${testResponse.runtimeType}');
      print('📏 Response length: ${testResponse?.length ?? 0}');

      if (testResponse != null && testResponse.isNotEmpty) {
        print('✅ DIFY SERVICE WORKING');

        // Add test response to chat
        setState(() {
          messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text:
                  '🔧 **Debug Test Berhasil**\n\nResponse dari Dify:\n$testResponse',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        print('❌ DIFY SERVICE NOT WORKING');

        setState(() {
          messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text:
                  '❌ **Debug Test Gagal**\n\nDify service tidak merespons dengan benar.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }

      print('🔍 === DIFY SERVICE DEBUG END ===');
      _scrollToBottom();
    } catch (e) {
      print('❌ Error in debug: $e');

      setState(() {
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '❌ **Debug Error**\n\nError: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  // Chat history methods for DIFY
  Future<void> _loadChatHistory() async {
    if (currentUser == null || !mounted) return;

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      // Use prefix for DIFY conversations to separate from N8N
      final history = await _chatService.getConversationHistory(
        currentUser!.id,
      );

      // Filter only DIFY conversations by checking title prefix
      final difyChatHistory =
          history.where((conv) {
            final title = conv['conversation_title'].toString();
            return title.startsWith('DIFY') ||
                title.startsWith('dify') ||
                title.contains('DIFY Chat') ||
                title.contains('DIFY:');
          }).toList();

      // Auto-repair corrupted data if history is empty or has issues
      if (difyChatHistory.isEmpty && history.isNotEmpty) {
        print('🔧 No DIFY history found, checking for corrupted data...');
        // await _chatService.repairCorruptedData(); // Method not available
      }

      difyChatHistory.sort((a, b) {
        try {
          final aTime = DateTime.parse(a['updated_at'] as String);
          final bTime = DateTime.parse(b['updated_at'] as String);
          return bTime.compareTo(aTime);
        } catch (e) {
          print('⚠️ Error sorting DIFY conversation by date: $e');
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _conversationHistory = difyChatHistory;
          _isLoadingHistory = false;
        });
      }
      print('📚 Loaded ${difyChatHistory.length} DIFY conversations');
    } catch (e) {
      print('❌ Error loading DIFY chat history: $e');

      // Try to repair data on error
      try {
        print('🔧 Attempting to repair corrupted DIFY chat data...');
        // await _chatService.repairCorruptedData(); // Method not available

        // Try loading again after repair
        final repairedHistory = await _chatService.getConversationHistory(
          currentUser!.id,
        );
        final repairedDifyHistory =
            repairedHistory
                .where(
                  (conv) =>
                      conv['conversation_title'].toString().startsWith('DIFY'),
                )
                .toList();

        if (mounted) {
          setState(() {
            _conversationHistory = repairedDifyHistory;
            _isLoadingHistory = false;
          });
        }
        print(
          '✅ Successfully repaired and loaded ${repairedDifyHistory.length} DIFY conversations',
        );
      } catch (repairError) {
        print('❌ Failed to repair DIFY data: $repairError');
        if (mounted) {
          setState(() {
            _conversationHistory = [];
            _isLoadingHistory = false;
          });
        }
      }
    }
  }

  Future<void> _loadConversation(Map<String, dynamic> conversation) async {
    try {
      print(
        '🔄 Loading DIFY conversation: ${conversation['conversation_title']}',
      );

      // Validate conversation data
      if (conversation['id'] == null) {
        throw Exception('Invalid conversation: missing ID');
      }

      final conversationId = conversation['id'] as int;
      print('📋 Conversation ID: $conversationId');

      // Show loading indicator
      if (mounted) {
        setState(() {
          messages.clear();
          messages.add(
            ChatMessage(
              id: 'loading',
              text: 'Memuat riwayat percakapan...',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }

      final chatHistory = await _chatService.getChatHistory(conversationId);
      print('✅ Loaded ${chatHistory.length} messages from history');

      // Debug: Print all messages
      for (int i = 0; i < chatHistory.length; i++) {
        final msg = chatHistory[i];
        print(
          '📝 Message $i: [${msg.isUser ? "USER" : "BOT"}] ${msg.text.length > 100 ? msg.text.substring(0, 100) + "..." : msg.text}',
        );
      }

      // Clean error messages from storage permanently
      await _cleanErrorMessagesFromStorage(conversationId);

      // Filter out specific error messages for display
      final cleanHistory =
          chatHistory.where((message) {
            final text = message.text.trim();
            final isSpecificErrorMessage =
                text ==
                    'Maaf, terjadi kesalahan saat memproses pesan Anda. Silakan coba lagi.' ||
                text == 'Error memuat conversation' ||
                text == '[Error loading message]' ||
                text == 'Memuat riwayat percakapan...' ||
                text.startsWith(
                  'Maaf, tidak dapat memuat riwayat percakapan ini',
                );

            if (isSpecificErrorMessage) {
              print(
                '🧹 Filtering out specific error message: ${text.length > 50 ? text.substring(0, 50) + "..." : text}',
              );
            }

            return !isSpecificErrorMessage;
          }).toList();

      print('🔍 After filtering: ${cleanHistory.length} messages remaining');

      if (mounted) {
        setState(() {
          messages.clear();

          // Use cleaned history for display
          if (cleanHistory.isNotEmpty) {
            messages.addAll(cleanHistory);
            print('📝 Added ${cleanHistory.length} cleaned messages to chat');
          } else {
            // Add greeting if no valid history found
            messages.add(
              ChatMessage(
                id: '1',
                text: getGreetingMessage(),
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            print('👋 Added greeting message (no history found)');
          }
        });
      }

      await _chatService.setCurrentConversation(conversationId);
      print(
        '📖 Successfully loaded DIFY conversation: ${conversation['conversation_title']}',
      );
      _scrollToBottom();
    } catch (e) {
      print('❌ Error loading DIFY conversation: $e');
      print('📄 Conversation data: $conversation');

      if (mounted) {
        // Show user-friendly error in chat
        setState(() {
          messages.clear();
          messages.add(
            ChatMessage(
              id: 'error',
              text:
                  'Maaf, tidak dapat memuat riwayat percakapan ini. Riwayat mungkin rusak atau terlalu lama.\n\nSilakan mulai percakapan baru.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });

        // Also show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat percakapan: ${e.toString().contains('Exception:') ? e.toString().split('Exception: ')[1] : 'Error tidak dikenal'}',
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveChatToHistory(
    String userMessage,
    String botResponse,
  ) async {
    try {
      int conversationId;
      if (_chatService.currentConversationId == null) {
        conversationId = await _chatService.startNewConversation(
          userId: currentUser!.id,
          title: _generateConversationTitle(userMessage),
        );
        print('📝 Started new DIFY conversation: $conversationId');
      } else {
        conversationId = _chatService.currentConversationId!;
      }

      // Save user message manually
      await _saveMessageToStorage(
        conversationId: conversationId,
        messageType: 'user',
        content: userMessage,
      );

      // Save bot response manually
      await _saveMessageToStorage(
        conversationId: conversationId,
        messageType: 'system',
        content: botResponse,
      );

      print('💾 DIFY Chat saved to history (both user and bot messages)');

      if (mounted) {
        _loadChatHistory();
      }
    } catch (e) {
      print('❌ Error saving DIFY chat to history: $e');
    }
  }

  Future<void> _saveMessageToStorage({
    required int conversationId,
    required String messageType,
    required String content,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = 'n8n_messages_$conversationId';

      // Get existing messages
      final existingMessages = await _getStoredMessages(conversationId);

      // Create new message
      final newMessage = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'conversation_id': conversationId,
        'message_type': messageType,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': currentUser!.id,
      };

      // Add to list
      existingMessages.add(newMessage);

      // Save back to storage
      await prefs.setString(messagesKey, jsonEncode(existingMessages));

      print(
        '💾 Saved $messageType message to storage: ${content.substring(0, 50)}...',
      );
    } catch (e) {
      print('❌ Error saving message to storage: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getStoredMessages(
    int conversationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = 'n8n_messages_$conversationId';
      final messagesJson = prefs.getString(messagesKey);

      if (messagesJson != null && messagesJson.isNotEmpty) {
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        return List<Map<String, dynamic>>.from(messagesList);
      }

      return [];
    } catch (e) {
      print('❌ Error getting stored messages: $e');
      return [];
    }
  }

  String _generateConversationTitle(String message) {
    final cleanMessage = message.trim();
    String title;
    if (cleanMessage.length <= 25) {
      title = cleanMessage;
    } else {
      title = '${cleanMessage.substring(0, 25)}...';
    }
    // Add DIFY prefix to distinguish from N8N conversations
    return 'DIFY: $title';
  }

  Future<void> _autoCreateNewConversationIfNeeded() async {
    if (currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastProvider = prefs.getString('last_used_provider');
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final lastVisitTime = prefs.getInt('last_dify_visit_time') ?? 0;

      final shouldCreateNew =
          lastProvider != 'DIFY' || (currentTime - lastVisitTime) > 300000;

      if (shouldCreateNew) {
        final newConversationId = await _chatService.startNewConversation(
          userId: currentUser!.id,
          title:
              'DIFY Chat ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );

        await _chatService.setCurrentConversation(newConversationId);
        print('🆕 Auto-created new DIFY conversation: $newConversationId');

        await prefs.setString('last_used_provider', 'DIFY');
        await prefs.setInt('last_dify_visit_time', currentTime);

        _loadChatHistory();
      } else {
        await _chatService.loadCurrentConversation();
        print(
          '📖 Continuing existing DIFY conversation: ${_chatService.currentConversationId}',
        );
      }
    } catch (e) {
      print('❌ Error auto-creating DIFY conversation: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  void _showDeleteConversationDialog(Map<String, dynamic> conversation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: Text(
            'Hapus Percakapan',
            style: TextStyle(color: AppColors.primaryText),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus percakapan "${conversation['conversation_title']}"?',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
              },
              child: Text('Hapus', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    try {
      // Delete from storage using WebChatService
      await _chatService.deleteConversation(conversation['id']);

      // Remove from local list
      setState(() {
        _conversationHistory.removeWhere(
          (conv) => conv['id'] == conversation['id'],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Percakapan berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );

      print('✅ DIFY Conversation ${conversation['id']} deleted successfully');
    } catch (e) {
      print('❌ Error deleting DIFY conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus percakapan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/provider-selection',
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        drawer: _buildSidebar(),
        appBar: AppBar(
          leading: Builder(
            builder:
                (context) => IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.menu_rounded,
                      color: AppColors.gradientStart,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
          ),
          title: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientStart.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'Dify Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.whiteText,
                letterSpacing: 0.3,
              ),
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.primaryBackground,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            // Debug button for upload testing
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppColors.subtleGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bug_report,
                  color: AppColors.gradientStart,
                  size: 20,
                ),
              ),
              onPressed: () async {
                print('🔧 Testing Dify upload endpoint...');
                final difyService = DifyService();
                await difyService.testUploadEndpoint();
              },
            ),
            Container(
              margin: EdgeInsets.only(right: 16),
              child: Image.asset(
                'assets/images/tsel.png',
                height: 52,
                width: 52,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 52,
                    width: 52,
                    child: Icon(
                      Icons.business,
                      size: 24,
                      color: AppColors.gradientStart,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body:
            isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.accent),
                      SizedBox(height: 16),
                      Text(
                        'Memuat data pengguna...',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    // Chat Messages Area
                    Expanded(
                      child:
                          messages.isEmpty && !isAiThinking
                              ? ChatEmptyState()
                              : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.all(16),
                                itemCount:
                                    messages.length + (isAiThinking ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == messages.length &&
                                      isAiThinking) {
                                    return ModernThinkingBubble();
                                  }
                                  return ModernMessageBubble(
                                    message: messages[index],
                                    provider: 'DIFY',
                                  );
                                },
                              ),
                    ),

                    // Dify Message Input (simplified with file attachment)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            8,
                          ), // Reduced bottom padding
                          child: Column(
                            children: [
                              // Show selected file info if any
                              if (_selectedFile != null)
                                Container(
                                  margin: EdgeInsets.only(
                                    bottom: 8,
                                  ), // Reduced margin
                                  padding: EdgeInsets.all(
                                    10,
                                  ), // Reduced padding
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          6,
                                        ), // Reduced padding
                                        decoration: BoxDecoration(
                                          gradient: AppColors.subtleGradient,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.attach_file_rounded,
                                          color: AppColors.gradientStart,
                                          size: 18, // Reduced icon size
                                        ),
                                      ),
                                      SizedBox(width: 10), // Reduced spacing
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedFile!.name,
                                              style: TextStyle(
                                                color: AppColors.primaryText,
                                                fontSize:
                                                    13, // Reduced font size
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                              style: TextStyle(
                                                color: AppColors.secondaryText,
                                                fontSize:
                                                    11, // Reduced font size
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _removeSelectedFile,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.error,
                                          size: 18, // Reduced icon size
                                        ),
                                        padding: EdgeInsets.all(
                                          2,
                                        ), // Reduced padding
                                        constraints: BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),

                              // Message Input Row
                              Row(
                                children: [
                                  // File attachment button
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.subtleGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: _onFileSelected,
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            10,
                                          ), // Reduced padding
                                          child: Icon(
                                            Icons.attach_file_rounded,
                                            color: AppColors.gradientStart,
                                            size: 22, // Reduced icon size
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 10), // Reduced spacing

                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBackground,
                                        borderRadius: BorderRadius.circular(
                                          22,
                                        ), // Reduced border radius
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _messageController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Ketik pesan Anda untuk Dify...',
                                          hintStyle: TextStyle(
                                            color: AppColors.lightText,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 18, // Reduced padding
                                            vertical: 10, // Reduced padding
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: 14,
                                        ),
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction:
                                            TextInputAction.newline,
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10), // Reduced spacing
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(
                                        22,
                                      ), // Reduced border radius
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gradientStart
                                              .withOpacity(0.3),
                                          spreadRadius: 0,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap:
                                            isAiThinking ? null : _sendMessage,
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            10,
                                          ), // Reduced padding
                                          child: Icon(
                                            Icons.send_rounded,
                                            color: AppColors.whiteText,
                                            size: 22, // Reduced icon size
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // Sidebar Widget
  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: AppColors.primaryBackground,
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryBackground, AppColors.cardBackground],
          ),
        ),
        child: ListView(
          children: [
            // Dify Header
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.whiteText,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                child: Image.asset(
                                  'assets/images/dify-ai.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.gradientStart,
                                      size: 24,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dify Assistant',
                              style: TextStyle(
                                color: AppColors.whiteText,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'LLM-Powered Conversations',
                        style: TextStyle(
                          color: AppColors.whiteText.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Menu Items
            _buildSidebarItem(
              icon: Icons.home_rounded,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/provider-selection',
                  (route) => false,
                );
              },
            ),

            _buildSidebarItem(
              icon: Icons.add_circle_outline_rounded,
              title: 'New Conversation',
              onTap: () {
                Navigator.pop(context);
                _showNewChatConfirmation();
              },
            ),

            _buildSidebarItem(
              icon: Icons.cleaning_services_rounded,
              title: 'Clean Error Messages',
              onTap: () async {
                Navigator.pop(context);
                try {
                  // Clean error messages from current conversation
                  if (_chatService.currentConversationId != null) {
                    await _cleanErrorMessagesFromStorage(
                      _chatService.currentConversationId!,
                    );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Error messages cleaned successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadChatHistory();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to clean messages: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),

            _buildSidebarItem(
              icon: Icons.bug_report_outlined,
              title: 'Debug Dify Service',
              onTap: () {
                Navigator.pop(context);
                _debugDifyService();
              },
            ),

            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              height: 1,
              decoration: BoxDecoration(gradient: AppColors.subtleGradient),
            ),

            // History Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: AppColors.gradientStart,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'DIFY Chat History',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Spacer(),
                  if (_isLoadingHistory)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gradientMiddle,
                      ),
                    )
                  else
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppColors.gradientMiddle,
                        ),
                      ),
                      onPressed: _loadChatHistory,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Chat History List
            if (_conversationHistory.isEmpty && !_isLoadingHistory)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.lightText,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No DIFY conversations yet',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Start a new conversation to begin',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._conversationHistory.map((conversation) {
                final title = conversation['conversation_title'] as String;
                final updatedAt = DateTime.parse(
                  conversation['updated_at'] as String,
                );
                final timeAgo = _getTimeAgo(updatedAt);

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.subtleGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.gradientStart,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      title.length > 25
                          ? '${title.substring(0, 25)}...'
                          : title,
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      timeAgo,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _loadConversation(conversation);
                    },
                    onLongPress: () {
                      _showDeleteConversationDialog(conversation);
                    },
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.subtleGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.gradientStart, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}
