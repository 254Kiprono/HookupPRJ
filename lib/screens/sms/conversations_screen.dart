import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:hook_app/screens/main_app/messages_screen.dart';
import 'package:hook_app/utils/constants.dart';

class Conversation {
  final int otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      otherUserId: json['participantB'] as int? ?? json['participantA'] as int,
      otherUserName: json['otherUserName'] as String? ?? 'Unknown',
      lastMessage: json['lastMessage']?['content']?['body'] as String? ?? '',
      lastMessageTime: DateTime.parse(
          json['lastMessage']?['timestamp'] as String? ??
              DateTime.now().toIso8601String()),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _userId;
  late IOWebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _initAndFetchUserId();
  }

  Future<void> _initAndFetchUserId() async {
    try {
      final authToken = await StorageService.getAuthToken();

      if (authToken == null ||
          authToken.isEmpty ||
          JwtDecoder.isExpired(authToken)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid or expired auth token. Please log in.';
        });
        return;
      }

      final decodedToken = JwtDecoder.decode(authToken);
      _userId = _extractUserIdFromToken(decodedToken);

      if (_userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid user ID in token.';
        });
        return;
      }

      await _fetchConversations(authToken);
      _connectWebSocket(authToken);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading conversations: ${e.toString()}';
      });
    }
  }

  int? _extractUserIdFromToken(Map<String, dynamic> decodedToken) {
    final userIdStr = decodedToken['userId'] as String?;
    return userIdStr != null ? int.tryParse(userIdStr) : null;
  }

  void _connectWebSocket(String authToken) {
    _channel = IOWebSocketChannel.connect(
      Uri.parse('${AppConstants.websocketUrl}?userId=$_userId'),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        final eventType = data['eventType'] as String?;

        if (eventType == 'message') {
          setState(() {
            _fetchConversations(authToken); // Refresh conversations
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
  }

  Future<void> _fetchConversations(String authToken) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.conversations}?user_id=$_userId&limit=20&offset=0'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final conversationsData = responseData['data'] as List<dynamic>;
          final conversations = conversationsData
              .map((json) => Conversation.fromJson(json))
              .toList();

          setState(() {
            _conversations = conversations;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                responseData['message'] ?? 'Failed to load conversations';
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

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
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
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No conversations yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        final authToken = await StorageService.getAuthToken();
                        if (authToken != null) {
                          await _fetchConversations(authToken);
                        }
                      },
                      child: ListView.builder(
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 30,
                              backgroundImage: const NetworkImage(
                                'https://via.placeholder.com/150', // Placeholder image
                              ),
                              onBackgroundImageError: (exception, stackTrace) {

                              },
                            ),
                            title: Text(
                              conversation.otherUserName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              conversation.lastMessage.isNotEmpty
                                  ? conversation.lastMessage
                                  : 'No messages yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _formatTime(conversation.lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            onTap: () {
                              if (conversation.otherUserName.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MessagesScreen(
                                      otherUserId: conversation.otherUserId,
                                      otherUserName: conversation.otherUserName,
                                    ),
                                    settings:
                                        const RouteSettings(name: 'Chats'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid user name.'),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return _weekdays[time.weekday] ?? '';
    }
    return '${time.day}/${time.month}';
  }

  static const _weekdays = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };
}
