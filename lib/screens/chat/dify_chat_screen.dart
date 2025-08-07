import 'package:difychatbot/services/api/me_api_service.dart';
import 'package:difychatbot/utils/string_capitalize.dart';
import 'package:difychatbot/constants/app_colors.dart';
import 'package:difychatbot/services/dify/dify_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/chat_message.dart';
import '../../models/me_response.dart';
import '../../components/index.dart';

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

  // Chat state
  String _selectedModel = 'General Chat'; // Fixed model for Dify
  PlatformFile? _selectedFile; // Add file attachment capability

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
      // Simulate new conversation creation for Dify
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

      Navigator.pop(context);
      _scrollToBottom();
    } catch (e) {
      print('❌ Error creating new Dify conversation: $e');
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
            Container(
              margin: EdgeInsets.only(right: 16),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gradientStart.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/tsel.png',
                height: 52,
                width: 52,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.gradientStart,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.business,
                      size: 14,
                      color: AppColors.whiteText,
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
                            child: Icon(
                              Icons.psychology_outlined,
                              color: AppColors.gradientMiddle,
                              size: 24,
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
              icon: Icons.bug_report_outlined,
              title: 'Debug Dify Service',
              onTap: () {
                Navigator.pop(context);
                _debugDifyService();
              },
            ),
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
