import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/utils/responsive.dart';
import 'package:hook_app/utils/nav.dart';

class Message {
  final String id;
  final int senderId;
  final int receiverId;
  final DateTime timestamp;
  final dynamic content;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    dynamic content;
    final contentType = json['contentType']?.toLowerCase() ?? '';
    switch (contentType) {
      case 'text':
        content = TextContent.fromJson(json['content']);
        break;
      case 'booking':
        content = BookingProposal.fromJson(json['content']);
        break;
      case 'media':
      case 'payment':
        content = json['content'];
        break;
      default:
        content = json['content'];
    }
    return Message(
      id: json['id'] as String,
      senderId: json['senderId'] as int? ?? 0,
      receiverId: json['receiverId'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: content,
    );
  }
}

class TextContent {
  final String body;

  TextContent({required this.body});

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(body: json['body'] as String);
  }
}

class BookingProposal {
  final String proposalId;
  final DateTime proposedTime;
  final String meetingPurpose;
  final String termsHash;

  BookingProposal({
    required this.proposalId,
    required this.proposedTime,
    required this.meetingPurpose,
    required this.termsHash,
  });

  factory BookingProposal.fromJson(Map<String, dynamic> json) {
    return BookingProposal(
      proposalId: json['proposalId'] as String,
      proposedTime: DateTime.parse(json['proposedTime'] as String),
      meetingPurpose: json['meetingPurpose'] as String,
      termsHash: json['termsHash'] as String? ?? 'sample_terms_hash',
    );
  }
}

class MessagesScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUserName;

  const MessagesScreen({
    super.key,
    required this.otherUserId,
    this.otherUserName = 'Unknown',
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int? _userId;
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final TextEditingController _bookingPurposeController =
      TextEditingController();
  late IOWebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _initAndFetchUserId();
  }

  Future<void> _initAndFetchUserId() async {
    try {
      final authToken = await StorageService.getAuthToken();

      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Missing auth token. Please log in.';
        });
        return;
      }

      if (JwtDecoder.isExpired(authToken)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Auth token expired. Please log in again.';
        });
        return;
      }

      _userId = await TokenUtils.extractUserId(authToken);

      if (_userId == null) {
        final refreshToken = await StorageService.getRefreshToken();
        if (refreshToken != null) {
          final newToken = await TokenUtils.refreshToken(refreshToken);
          if (newToken != null) {
            await StorageService.saveAuthToken(newToken);
            _userId = await TokenUtils.extractUserId(newToken);
          }
        }
      }

      if (_userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid user ID in token. Please log in again.';
        });
        return;
      }

      await _fetchMessages(authToken);
      _connectWebSocket(authToken);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing: ${e.toString()}';
      });
    }
  }

  void _connectWebSocket(String authToken) {
    _channel = IOWebSocketChannel.connect(
      Uri.parse(AppConstants.websocketUrl),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (data.containsKey('message')) {
          final msg = Message.fromJson(data['message']);
          if (msg.senderId != _userId && msg.receiverId == _userId) {
            setState(() {
              _messages.add(msg);
              _scrollController
                  .jumpTo(_scrollController.position.maxScrollExtent);
            });
          }
        } else if (data.containsKey('typing')) {
          final typingData = data['typing'] as Map<String, dynamic>;
          if (typingData['user_id'] == widget.otherUserId) {
          }
        } else if (data.containsKey('booking')) {
          final bookingData = data['booking'] as Map<String, dynamic>;
          final bookingMsg = Message(
            id: bookingData['booking_id'],
            senderId: widget.otherUserId,
            receiverId: _userId!,
            timestamp: DateTime.now(),
            content: BookingProposal(
              proposalId: bookingData['booking_id'],
              proposedTime: DateTime.parse(bookingData['proposed_time'] ??
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .toIso8601String()),
              meetingPurpose: bookingData['message'] ?? 'Meeting',
              termsHash: bookingData['terms_hash'] ?? 'sample_terms_hash',
            ),
          );
          setState(() {
            _messages.add(bookingMsg);
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        }
      },
      onError: (error) {
        setState(() {
          _errorMessage = 'WebSocket error: $error';
        });
      },
      onDone: () {
        _connectWebSocket(authToken); // Reconnect on disconnect
      },
    );

    _channel.sink.add(jsonEncode({
      'typing': {
        'conversation_id': widget.otherUserId,
        'user_id': _userId,
        'is_typing': false,
      }
    }));
  }

  Future<void> _fetchMessages(String authToken) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var currentToken = authToken;
      if (JwtDecoder.isExpired(currentToken)) {
        final refreshToken = await StorageService.getRefreshToken();
        if (refreshToken != null) {
          final newToken = await TokenUtils.refreshToken(refreshToken);
          if (newToken != null) {
            await StorageService.saveAuthToken(newToken);
            currentToken = newToken;
          } else {
            throw Exception('Session expired. Please log in again.');
          }
        }
      }

      final response = await http.get(
        Uri.parse('${AppConstants.conversations}/${widget.otherUserId}'),
        headers: {
          'Authorization': 'Bearer $currentToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final messagesData = responseData['data'] as List<dynamic>? ?? [];
          final messages =
              messagesData.map((json) => Message.fromJson(json)).toList();

          setState(() {
            _messages = messages;
            _isLoading = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController
                  .jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                responseData['message'] ?? 'Failed to load messages';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: ${e.toString()}';
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final authToken = await StorageService.getAuthToken();

      if (authToken == null) return;

      final response = await http.post(
        Uri.parse(AppConstants.sendMessage),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiver_id': widget.otherUserId,
          'content': {
            'text': {'body': text},
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final newMessage = Message(
            id: responseData['message_id'] as String,
            senderId: _userId!,
            receiverId: widget.otherUserId,
            timestamp: DateTime.now(),
            content: TextContent(body: text),
          );

          setState(() {
            _messages.add(newMessage);
          });

          _messageController.clear();
          _messageFocusNode.unfocus();

          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(responseData['message'] ?? 'Failed to send message'),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.toString()}')),
      );
    }
  }

  Future<void> _initiateBooking() async {
    if (_bookingPurposeController.text.isEmpty) return;

    try {
      final authToken = await StorageService.getAuthToken();

      if (authToken == null) return;

      final response = await http.post(
        Uri.parse(AppConstants.bookingInitiate),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'provider_id': widget.otherUserId,
          'proposed_time':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'meeting_purpose': _bookingPurposeController.text,
          'terms_hash': 'sample_terms_hash',
          'proposal_id': DateTime.now().millisecondsSinceEpoch.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final bookingMessage = Message(
            id: responseData['booking_id'] ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: _userId!,
            receiverId: widget.otherUserId,
            timestamp: DateTime.now(),
            content: BookingProposal(
              proposalId: responseData['booking_id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              proposedTime: DateTime.now().add(const Duration(days: 1)),
              meetingPurpose: _bookingPurposeController.text,
              termsHash: 'sample_terms_hash',
            ),
          );
          setState(() {
            _messages.add(bookingMessage);
            _bookingPurposeController.clear();
          });

          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(responseData['message'] ?? 'Failed to initiate booking'),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating booking: ${e.toString()}')),
      );
    }
  }

  Future<void> _respondToBooking(String proposalId, String decision) async {
    try {
      final authToken = await StorageService.getAuthToken();

      if (authToken == null) return;

      final response = await http.post(
        Uri.parse(AppConstants.bookingRespond),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'proposal_id': proposalId,
          'decision': decision.toUpperCase(),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking ${decision.toLowerCase()} successfully'),
            ),
          );
          await _fetchMessages(authToken); // Refresh messages
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  responseData['message'] ?? 'Failed to respond to booking'),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to booking: ${e.toString()}')),
      );
    }
  }

  void _showBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initiate Booking'),
        content: TextField(
          controller: _bookingPurposeController,
          decoration: const InputDecoration(
            hintText: 'Purpose of meeting',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Nav.safePop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Nav.safePop(context);
              _initiateBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
            ),
            child: const Text(
              'Send Proposal',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bookingPurposeController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          return true;
        }
        Navigator.of(context).pushReplacementNamed(Routes.home);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppConstants.darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed(Routes.home);
                }
              },
            ),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                child: Text(widget.otherUserName[0], style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
                    const Text('Online', style: TextStyle(color: AppConstants.successColor, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : _errorMessage != null
                      ? _buildErrorPlaceholder()
                      : _messages.isEmpty
                          ? _buildEmptyPlaceholder()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                            ),
            ),
            _buildMessageInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _userId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? AppConstants.primaryColor : AppConstants.cardNavy,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              boxShadow: [
                if (isMe) BoxShadow(color: AppConstants.primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: _buildMessageContent(message),
          ),
          const SizedBox(height: 6),
          Text(
            _formatMessageTime(message.timestamp),
            style: const TextStyle(color: AppConstants.mutedGray, fontSize: 10),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Message message) {
    if (message.content is TextContent) {
      return Text(
        (message.content as TextContent).body,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
      );
    } else if (message.content is BookingProposal) {
      final proposal = message.content as BookingProposal;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Booking Proposal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(proposal.meetingPurpose, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            'Time: ${_formatDateTime(proposal.proposedTime)}',
            style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (message.senderId != _userId) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respondToBooking(message.id, 'ACCEPTED'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                    child: const Text('Accept', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToBooking(message.id, 'REJECTED'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppConstants.errorColor), padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                    child: const Text('Reject', style: TextStyle(color: AppConstants.errorColor, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showBookingDialog,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: AppConstants.primaryColor, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppConstants.mutedGray),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  _channel.sink.add(jsonEncode({
                    'typing': {
                      'conversation_id': widget.otherUserId,
                      'user_id': _userId,
                      'is_typing': val.isNotEmpty,
                    },
                  }));
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(color: AppConstants.mutedGray, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppConstants.errorColor),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextButton(onPressed: _initAndFetchUserId, child: const Text('Retry')),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
