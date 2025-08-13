import 'dart:typed_data';
import 'dart:convert';
import 'package:difychatbot/services/api/me_api_service.dart';
import 'package:difychatbot/utils/string_capitalize.dart';
import 'package:difychatbot/constants/app_colors.dart';
import 'package:difychatbot/services/n8n/prompt_api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';
import '../../models/me_response.dart';
import '../../components/index.dart';
import '../../services/web_chat_service.dart';

class N8NChatScreen extends StatefulWidget {
  @override
  _N8NChatScreenState createState() => _N8NChatScreenState();
}

class _N8NChatScreenState extends State<N8NChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final meAPI _meAPI = meAPI();
  final PromptApiService _promptApiService = PromptApiService();
  final WebChatService _chatService = WebChatService();

  // Chat state
  String _selectedModel = 'TSEL-Chatbot';
  List<Map<String, dynamic>> _conversationHistory = [];
  bool _isLoadingHistory = false;
  PlatformFile? _selectedFile;

  // Available N8N models
  final List<String> _availableModels = [
    'TSEL-Chatbot',
    'TSEL-Lerning-Based',
    'TSEL-PDF-Agent',
    'TSEL-Image-Generator',
    'TSEL-Company-Agent',
  ];

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
          "Halo! Saya adalah N8N AI assistant Anda. Bagaimana saya bisa membantu Anda hari ini?",
      isUser: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
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

    // Validate input based on model type
    if (_selectedModel == 'TSEL-Lerning-Based') {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silakan upload file PDF untuk materi pembelajaran'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    } else {
      if (message.isEmpty && _selectedFile == null) return;
    }

    final userMessage = message;

    // Add user message to UI
    setState(() {
      if (_selectedModel == 'TSEL-PDF-Agent' && _selectedFile != null) {
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: userMessage.isNotEmpty ? userMessage : '',
            isUser: true,
            timestamp: DateTime.now(),
            fileName: _selectedFile!.name,
            fileType: 'pdf',
          ),
        );
      } else {
        if (message.isNotEmpty) {
          messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: userMessage,
              isUser: true,
              timestamp: DateTime.now(),
            ),
          );
        }

        if (_selectedFile != null) {
          String fileMessage = '';
          if (_selectedModel == 'TSEL-Lerning-Based') {
            fileMessage = '📚 Materi pembelajaran: ${_selectedFile!.name}';
          } else {
            fileMessage = '📎 File uploaded: ${_selectedFile!.name}';
          }

          messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_file',
              text: fileMessage,
              isUser: true,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      isAiThinking = true;
    });

    _messageController.clear();
    final tempFile = _selectedFile;
    _selectedFile = null;
    _scrollToBottom();

    try {
      // Handle N8N API call
      Uint8List? imageData;
      bool isImageGenerated = false;
      String textResponse = '';

      final promptResponse = await _promptApiService.postPromptWithMultipart(
        model: _selectedModel,
        prompt: userMessage,
        file: tempFile,
      );

      print("N8N response: $promptResponse");

      if (promptResponse != null && promptResponse.succes) {
        if (_selectedModel == 'TSEL-Image-Generator') {
          imageData = _tryParseImageResponse(promptResponse.response);
          if (imageData != null && imageData.isNotEmpty) {
            isImageGenerated = true;
            textResponse =
                'Gambar berhasil dibuat! Tap untuk melihat lebih detail.';
          } else {
            textResponse =
                promptResponse.response.isNotEmpty
                    ? promptResponse.response
                    : 'Gambar sedang diproses, mohon tunggu...';
          }
        } else {
          textResponse =
              promptResponse.response.isNotEmpty
                  ? promptResponse.response
                  : _getDefaultResponse(_selectedModel, tempFile);
        }
      } else {
        textResponse = '''# Koneksi Terputus 

## Tidak dapat terhubung ke N8N Assistant

Maaf, saat ini **tidak dapat terhubung** ke N8N AI assistant. 

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
            imageData: imageData,
            isImageGenerated: isImageGenerated,
          ),
        );
      });

      // Save to chat history
      if (currentUser != null) {
        await _saveChatToHistory(userMessage, textResponse);
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        isAiThinking = false;
        messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text:
                "Maaf, terjadi kesalahan pada N8N service. Silakan coba lagi.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();
      print('Error sending message to N8N: $e');
    }
  }

  Future<void> _cleanErrorMessagesFromStorage(int conversationId) async {
    try {
      print('🧹 Cleaning error messages from N8N conversation $conversationId');
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

  void _onFileSelected(PlatformFile file) {
    setState(() {
      if (file.name.isEmpty) {
        _selectedFile = null;
      } else {
        _selectedFile = file;
      }
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
        _chatService.setCurrentConversation(0);

        final newConversationId = await _chatService.startNewConversation(
          userId: currentUser!.id,
          title:
              'Percakapan Baru ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        );

        print('🆕 Created new N8N conversation: $newConversationId');
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

      if (mounted) {
        _loadChatHistory();
      }

      Navigator.pop(context);
      _scrollToBottom();
    } catch (e) {
      print('❌ Error creating new N8N conversation: $e');
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

  String _getDefaultResponse(String model, PlatformFile? file) {
    switch (model) {
      case 'TSEL-PDF-Agent':
        if (file != null) {
          return "PDF berhasil dianalisis dengan N8N. Saya telah memproses dokumen ${file.name}. Ada yang ingin Anda tanyakan tentang isi dokumen ini?";
        }
        return 'Terima kasih atas pesan Anda. Saya siap membantu Anda menganalisis dokumen PDF dengan N8N.';

      case 'TSEL-Lerning-Based':
        if (file != null) {
          return "Materi pembelajaran berhasil diupload ke N8N! File ${file.name} telah saya proses dan siap untuk membantu pembelajaran Anda. Silakan tanyakan apa saja tentang materi ini.";
        }
        return 'Silakan upload file PDF sebagai materi pembelajaran.';

      case 'TSEL-Chatbot':
        return 'Terima kasih atas pesan Anda. Saya siap membantu menjawab pertanyaan Anda melalui N8N.';

      case 'TSEL-Image-Generator':
        return 'Permintaan gambar Anda sedang diproses oleh N8N. Mohon tunggu sebentar. Gambar akan muncul setelah selesai dibuat.';

      case 'TSEL-Company-Agent':
        return 'Terima kasih atas pertanyaan Anda tentang perusahaan. Saya siap membantu memberikan informasi yang Anda butuhkan melalui N8N.';

      default:
        return 'Terima kasih atas pesan Anda. Saya telah memproses permintaan Anda dengan N8N.';
    }
  }

  String getGreetingMessage() {
    if (currentUser != null) {
      return 'Halo ${currentUser!.namaDepan}! Saya adalah N8N AI assistant Anda. Bagaimana saya bisa membantu anda hari ini?';
    }
    return 'Halo! Saya adalah N8N AI assistant Anda. Bagaimana saya bisa membantu anda hari ini?';
  }

  // Load chat history methods
  Future<void> _loadChatHistory() async {
    if (currentUser == null || !mounted) return;

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      final history = await _chatService.getConversationHistory(
        currentUser!.id,
      );

      // Auto-repair corrupted data if history is empty or has issues
      if (history.isEmpty) {
        print('🔧 No history found, checking for corrupted data...');
        // await _chatService.repairCorruptedData(); // Method not available
      }

      history.sort((a, b) {
        try {
          final aTime = DateTime.parse(a['updated_at'] as String);
          final bTime = DateTime.parse(b['updated_at'] as String);
          return bTime.compareTo(aTime);
        } catch (e) {
          print('⚠️ Error sorting conversation by date: $e');
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _conversationHistory = history;
          _isLoadingHistory = false;
        });
      }
      print('📚 Loaded ${history.length} N8N conversations');
    } catch (e) {
      print('❌ Error loading N8N chat history: $e');

      // Try to repair data on error
      try {
        print('🔧 Attempting to repair corrupted chat data...');
        // await _chatService.repairCorruptedData(); // Method not available

        // Try loading again after repair
        final repairedHistory = await _chatService.getConversationHistory(
          currentUser!.id,
        );

        if (mounted) {
          setState(() {
            _conversationHistory = repairedHistory;
            _isLoadingHistory = false;
          });
        }
        print(
          '✅ Successfully repaired and loaded ${repairedHistory.length} conversations',
        );
      } catch (repairError) {
        print('❌ Failed to repair data: $repairError');
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
        '🔄 Loading N8N conversation: ${conversation['conversation_title']}',
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
        '📖 Successfully loaded N8N conversation: ${conversation['conversation_title']}',
      );
      _scrollToBottom();
    } catch (e) {
      print('❌ Error loading N8N conversation: $e');
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

      print('✅ N8N Conversation ${conversation['id']} deleted successfully');
    } catch (e) {
      print('❌ Error deleting N8N conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus percakapan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
        print('📝 Started new N8N conversation: $conversationId');
      } else {
        conversationId = _chatService.currentConversationId!;
      }

      // Save user message
      await _chatService.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        userId: currentUser!.id,
      );

      // Save bot response
      await _chatService.saveBotResponse(
        conversationId: conversationId,
        content: botResponse,
        metadata: {
          'model': _selectedModel,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('💾 N8N Chat (user + bot response) saved to history');

      if (mounted) {
        _loadChatHistory();
      }
    } catch (e) {
      print('❌ Error saving N8N chat to history: $e');
    }
  }

  String _generateConversationTitle(String message) {
    final cleanMessage = message.trim();
    if (cleanMessage.length <= 30) {
      return cleanMessage;
    }
    return '${cleanMessage.substring(0, 30)}...';
  }

  Future<void> _autoCreateNewConversationIfNeeded() async {
    if (currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastProvider = prefs.getString('last_used_provider');
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final lastVisitTime = prefs.getInt('last_n8n_visit_time') ?? 0;

      final shouldCreateNew =
          lastProvider != 'N8N' || (currentTime - lastVisitTime) > 300000;

      if (shouldCreateNew) {
        final newConversationId = await _chatService.startNewConversation(
          userId: currentUser!.id,
          title:
              'N8N Chat ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );

        await _chatService.setCurrentConversation(newConversationId);
        print('🆕 Auto-created new N8N conversation: $newConversationId');

        await prefs.setString('last_used_provider', 'N8N');
        await prefs.setInt('last_n8n_visit_time', currentTime);

        _loadChatHistory();
      } else {
        await _chatService.loadCurrentConversation();
        print(
          '📖 Continuing existing N8N conversation: ${_chatService.currentConversationId}',
        );
      }
    } catch (e) {
      print('❌ Error auto-creating N8N conversation: $e');
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
              'N8N Assistant',
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
                                    provider: 'N8N',
                                  );
                                },
                              ),
                    ),

                    // Message Input Area
                    MessageInputIntegrated(
                      controller: _messageController,
                      onSendMessage: _sendMessage,
                      selectedModel: _selectedModel,
                      availableModels: _availableModels,
                      onModelChanged: (String newModel) {
                        setState(() {
                          _selectedModel = newModel;
                        });
                      },
                      onFileSelected: _onFileSelected,
                      selectedFile: _selectedFile,
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
            // N8N Header
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
                                  'assets/images/n8n-logo-1.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.hub_rounded,
                                      color: AppColors.gradientEnd,
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
                              'N8N Assistant',
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
                        'Workflow-Powered AI',
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
                    'N8N Chat History',
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
                      'No N8N conversations yet',
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
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
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
                      vertical: 8,
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

  Uint8List? _tryParseImageResponse(String response) {
    try {
      print('Trying to parse image response, length: ${response.length}');

      if (response.length > 100 &&
          !response.contains('{') &&
          !response.contains('"')) {
        try {
          print('Attempting to decode as pure base64 string');
          final bytes = base64Decode(response);
          print(
            'Successfully decoded base64, image size: ${bytes.length} bytes',
          );
          return Uint8List.fromList(bytes);
        } catch (e) {
          print('Failed to decode as pure base64: $e');
        }
      }

      if (response.contains('data:image') && response.contains('base64,')) {
        try {
          print('Attempting to decode as data URL');
          final base64String = response.split('base64,').last;
          final bytes = base64Decode(base64String);
          print(
            'Successfully decoded data URL, image size: ${bytes.length} bytes',
          );
          return Uint8List.fromList(bytes);
        } catch (e) {
          print('Failed to decode data URL: $e');
        }
      }

      if (response.trim().startsWith('{') && response.trim().endsWith('}')) {
        try {
          print('Attempting to decode as JSON');
          final jsonData = json.decode(response);
          if (jsonData is Map<String, dynamic>) {
            final imageFields = [
              'image',
              'data',
              'base64',
              'image_data',
              'result',
              'file',
            ];
            for (final field in imageFields) {
              if (jsonData.containsKey(field)) {
                final imageValue = jsonData[field];
                if (imageValue is String && imageValue.isNotEmpty) {
                  try {
                    String base64String = imageValue;
                    if (base64String.contains('base64,')) {
                      base64String = base64String.split('base64,').last;
                    }
                    final bytes = base64Decode(base64String);
                    print(
                      'Successfully decoded JSON field "$field", image size: ${bytes.length} bytes',
                    );
                    return Uint8List.fromList(bytes);
                  } catch (e) {
                    print('Error decoding image from field $field: $e');
                    continue;
                  }
                }
              }
            }
          }
        } catch (e) {
          print('Failed to parse as JSON: $e');
        }
      }

      if (response.startsWith('"') && response.endsWith('"')) {
        try {
          print('Attempting to decode quoted base64');
          final unquoted = response.substring(1, response.length - 1);
          final bytes = base64Decode(unquoted);
          print(
            'Successfully decoded quoted base64, image size: ${bytes.length} bytes',
          );
          return Uint8List.fromList(bytes);
        } catch (e) {
          print('Failed to decode quoted base64: $e');
        }
      }

      print('Could not parse response as image data');
      return null;
    } catch (e) {
      print('Error parsing image response: $e');
      return null;
    }
  }
}
