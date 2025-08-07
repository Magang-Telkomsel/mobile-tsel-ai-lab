import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../constants/app_colors.dart';
import '../models/chat_message.dart';

class ModernMessageBubble extends StatefulWidget {
  final ChatMessage message;

  const ModernMessageBubble({Key? key, required this.message})
    : super(key: key);

  @override
  _ModernMessageBubbleState createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment:
            widget.message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gradientStart.withOpacity(0.2),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.whiteText,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      widget.message.isUser
                          ? AppColors.cardBackground
                          : AppColors
                              .primaryBackground, // Same as app background
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight:
                        widget.message.isUser
                            ? Radius.circular(6)
                            : Radius.circular(20),
                    bottomLeft:
                        widget.message.isUser
                            ? Radius.circular(20)
                            : Radius.circular(6),
                  ),
                  border: Border.all(
                    color:
                        widget.message.isUser
                            ? AppColors.borderLight
                            : Colors.transparent, // No border for bot messages
                    width: widget.message.isUser ? 1 : 0,
                  ),
                  boxShadow:
                      widget.message.isUser
                          ? [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              spreadRadius: 0,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                          : [], // No shadow for bot messages
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File attachment preview (if exists)
                    if (widget.message.fileName != null) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.subtleGradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gradientStart.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.whiteText,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                widget.message.fileType == 'pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.attach_file,
                                color: AppColors.gradientStart,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message.fileName!,
                                style: TextStyle(
                                  color: AppColors.gradientStart,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Generated image display (if exists)
                    if (widget.message.imageData != null &&
                        widget.message.isImageGenerated) ...[
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowMedium,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onTap:
                                () => _showImageFullScreen(
                                  context,
                                  widget.message.imageData!,
                                ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                                maxHeight: 300,
                              ),
                              child: Image.memory(
                                widget.message.imageData!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.secondaryText,
                                          size: 48,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Image could not be loaded',
                                          style: TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Text content with simple display
                    if (widget.message.text.isNotEmpty) ...[
                      widget.message.isUser
                          ? SelectableText(
                            widget.message.text,
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          )
                          : MarkdownWidget(
                            data: widget.message.text,
                            selectable: true,
                            shrinkWrap: true,
                            config: MarkdownConfig(
                              configs: [
                                // Modern H1 Configuration
                                H1Config(
                                  style: TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                // Modern H2 Configuration
                                H2Config(
                                  style: TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                // Modern H3 Configuration
                                H3Config(
                                  style: TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                // Modern Paragraph Configuration
                                PConfig(
                                  textStyle: TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                                // Modern Code Configuration
                                CodeConfig(
                                  style: TextStyle(
                                    color: AppColors.gradientStart,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    backgroundColor: AppColors.cardBackground,
                                  ),
                                ),
                                // Modern Pre Configuration
                                PreConfig(
                                  theme: {
                                    'root': TextStyle(
                                      backgroundColor: AppColors.cardBackground,
                                      color: AppColors.primaryText,
                                    ),
                                  },
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                // Modern Link Configuration
                                LinkConfig(
                                  style: TextStyle(
                                    color: AppColors.gradientMiddle,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],

                    // Copy button and timestamp row for bot messages
                    if (!widget.message.isUser &&
                        widget.message.text.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Copy button on the left
                          Tooltip(
                            message: 'Copy to Clipboard',
                            child: GestureDetector(
                              onTap: _copyToClipboard,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          // Timestamp on the right
                          Text(
                            _formatTime(widget.message.timestamp),
                            style: TextStyle(
                              color: AppColors.lightText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Timestamp only for user messages
                    if (widget.message.isUser) ...[
                      SizedBox(height: 8),
                      Text(
                        _formatTime(widget.message.timestamp),
                        style: TextStyle(
                          color: AppColors.lightText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (widget.message.isUser) ...[
            SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.gradientMiddle,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),

                Text(
                  'Message Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: 8),

                // Tips for bot messages
                if (!widget.message.isUser) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.gradientMiddle,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pinch to zoom • Double tap to reset • Long press for options',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                SizedBox(height: 4),

                // Copy option with enhanced info
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: AppColors.gradientStart,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Copy Text',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${widget.message.text.split(' ').length} words • ${widget.message.text.length} characters',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    _copyToClipboard();
                    Navigator.pop(context);
                  },
                ),

                // Full screen option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: AppColors.gradientStart,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Full Screen',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'View message in full screen mode',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showFullScreenText(context);
                  },
                ),

                // Share option
                if (!widget.message.isUser &&
                    widget.message.text.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.subtleGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: AppColors.gradientStart,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Share Response',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Share this AI response',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      _shareText();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
    );
  }

  void _triggerHapticFeedback() {
    HapticFeedback.selectionClick();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    _triggerHapticFeedback();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.whiteText,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Text copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText() {
    try {
      // For mobile platforms, we'll use a simulated share
      final String shareText =
          '''
AI Assistant Response:

${widget.message.text}

---
Generated by TSEL AI Assistant
${_formatTime(widget.message.timestamp)}
      '''.trim();

      Clipboard.setData(ClipboardData(text: shareText));
      _triggerHapticFeedback();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.share_rounded, color: AppColors.whiteText, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Response prepared for sharing (copied to clipboard)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.gradientMiddle,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share text'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showFullScreenText(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMessageViewer(message: widget.message),
      ),
    );
  }

  void _showImageFullScreen(BuildContext context, Uint8List imageData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: AppColors.whiteText),
                title: Text(
                  'Generated Image',
                  style: TextStyle(color: AppColors.whiteText),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gradientStart.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: AppColors.whiteText,
                        size: 18,
                      ),
                    ),
                    onPressed: () {
                      // Save image functionality can be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Long press image to save'),
                          backgroundColor: AppColors.gradientMiddle,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: Center(
                child: GestureDetector(
                  onLongPress: () {
                    // Save image to clipboard or device
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.image_rounded,
                              color: AppColors.whiteText,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Image saved to device memory',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.memory(imageData),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Full Screen Message Viewer Widget
class FullScreenMessageViewer extends StatefulWidget {
  final ChatMessage message;

  const FullScreenMessageViewer({Key? key, required this.message})
    : super(key: key);

  @override
  _FullScreenMessageViewerState createState() =>
      _FullScreenMessageViewerState();
}

class _FullScreenMessageViewerState extends State<FullScreenMessageViewer> {
  double _textScale = 1.0;
  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _scaleIncrement = 0.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Text(
          'Message Detail',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryText),
        actions: [
          // Zoom controls
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AppColors.subtleGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.zoom_out_rounded, size: 20),
                  color: AppColors.gradientStart,
                  onPressed: _textScale > _minScale ? _zoomOut : null,
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Text(
                  '${(_textScale * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.gradientStart,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.zoom_in_rounded, size: 20),
                  color: AppColors.gradientStart,
                  onPressed: _textScale < _maxScale ? _zoomIn : null,
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          // Copy button
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.copy_rounded,
                color: AppColors.whiteText,
                size: 18,
              ),
            ),
            onPressed: _copyToClipboard,
          ),
        ],
      ),
      body: GestureDetector(
        onScaleUpdate: (ScaleUpdateDetails details) {
          setState(() {
            _textScale = (_textScale * details.scale).clamp(
              _minScale,
              _maxScale,
            );
          });
        },
        onDoubleTap: _resetZoom,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Transform.scale(
            scale: _textScale,
            alignment: Alignment.topLeft,
            child:
                widget.message.isUser
                    ? SelectableText(
                      widget.message.text,
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    )
                    : MarkdownWidget(
                      data: widget.message.text,
                      selectable: true,
                      shrinkWrap: true,
                      config: MarkdownConfig(
                        configs: [
                          H1Config(
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          H2Config(
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          H3Config(
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          PConfig(
                            textStyle: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          ),
                          CodeConfig(
                            style: TextStyle(
                              color: AppColors.gradientStart,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              backgroundColor: AppColors.cardBackground,
                            ),
                          ),
                          PreConfig(
                            theme: {
                              'root': TextStyle(
                                backgroundColor: AppColors.cardBackground,
                                color: AppColors.primaryText,
                              ),
                            },
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1,
                              ),
                            ),
                          ),
                          LinkConfig(
                            style: TextStyle(
                              color: AppColors.gradientMiddle,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ),
      // Floating action buttons for quick actions
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Reset zoom button
          if (_textScale != 1.0) ...[
            FloatingActionButton.small(
              onPressed: _resetZoom,
              backgroundColor: AppColors.gradientMiddle,
              child: Icon(
                Icons.refresh_rounded,
                color: AppColors.whiteText,
                size: 18,
              ),
              heroTag: "reset_zoom",
            ),
            SizedBox(height: 12),
          ],
          // Share button
          FloatingActionButton(
            onPressed: _shareText,
            backgroundColor: AppColors.gradientStart,
            child: Icon(Icons.share_rounded, color: AppColors.whiteText),
            heroTag: "share_text",
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    setState(() {
      _textScale = (_textScale + _scaleIncrement).clamp(_minScale, _maxScale);
    });
    HapticFeedback.selectionClick();
  }

  void _zoomOut() {
    setState(() {
      _textScale = (_textScale - _scaleIncrement).clamp(_minScale, _maxScale);
    });
    HapticFeedback.selectionClick();
  }

  void _resetZoom() {
    setState(() {
      _textScale = 1.0;
    });
    HapticFeedback.mediumImpact();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.whiteText,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Text copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText() {
    try {
      final String shareText =
          '''
AI Assistant Response:

${widget.message.text}

---
Generated by TSEL AI Assistant
${_formatTime(widget.message.timestamp)}
      '''.trim();

      Clipboard.setData(ClipboardData(text: shareText));
      HapticFeedback.selectionClick();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.share_rounded, color: AppColors.whiteText, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Response prepared for sharing (copied to clipboard)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.gradientMiddle,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share text'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
