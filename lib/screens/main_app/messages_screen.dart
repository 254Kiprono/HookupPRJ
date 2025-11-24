import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

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
  bool _otherUserTyping = false;
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
            setState(() {
              _otherUserTyping = typingData['is_typing'] as bool;
            });
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
        setState(() {
          _otherUserTyping = false;
        });
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF40C4FF),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF40C4FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Center(
          child: Text(
            'Chats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event, color: Colors.white),
            onPressed: _showBookingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _initAndFetchUserId,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF40C4FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSentByUser = message.senderId == _userId;
                          return _buildMessageBubble(message, isSentByUser);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isSentByUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSentByUser ? const Color(0xFF40C4FF) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: isSentByUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.content is TextContent)
                Text(
                  (message.content as TextContent).body,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSentByUser ? Colors.white : Colors.black87,
                  ),
                )
              else if (message.content is BookingProposal)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      top: BorderSide(color: Color(0xFF40C4FF)),
                      left: BorderSide(color: Color(0xFF40C4FF)),
                      right: BorderSide(color: Color(0xFF40C4FF)),
                      bottom: BorderSide(color: Color(0xFF40C4FF)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking Proposal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF40C4FF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (message.content as BookingProposal).meetingPurpose,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (!isSentByUser)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _respondToBooking(message.id, 'ACCEPTED'),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _respondToBooking(message.id, 'REJECTED'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isSentByUser ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: InputDecoration(
                hintText: 'Type here',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onChanged: (text) {
                _channel.sink.add(jsonEncode({
                  'typing': {
                    'conversation_id': widget.otherUserId,
                    'user_id': _userId,
                    'is_typing': text.isNotEmpty,
                  },
                }));
              },
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) _sendMessage(text);
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF40C4FF),
            child: IconButton(
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _messageController.text.trim().isEmpty
                  ? null
                  : () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
