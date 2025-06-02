// lib/screens/main_app/messages_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/models/message_models.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:uuid/uuid.dart';

class MessagesScreen extends StatefulWidget {
  final int otherUserId;
  const MessagesScreen({super.key, required this.otherUserId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int? _userId;
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _otherUserName; // To display the other user's name
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _bookingPurposeController =
      TextEditingController();
  bool _otherUserTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initAndFetchUserId();
  }

  Future<void> _initAndFetchUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.authTokenKey);
      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No auth token found. Please log in.';
        });
        return;
      }

      if (JwtDecoder.isExpired(authToken)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Auth token has expired. Please log in again.';
        });
        return;
      }

      final decodedToken = JwtDecoder.decode(authToken);
      print('Decoded Token: $decodedToken'); // Debug token structure
      final userId =
          decodedToken['sub'] ?? decodedToken['user_id'] ?? decodedToken['id'];
      if (userId == null || userId is! String) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid token format: missing user ID claim.';
        });
        return;
      }

      _userId = int.tryParse(userId);
      if (_userId == null || _userId == 0) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid user ID in token.';
        });
        return;
      }

      await _fetchUserName();
      await _fetchMessages();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Initialization error: $e';
      });
    }
  }

  Future<void> _fetchUserName() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.getuserprofile}'), // Uses user service
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _otherUserName =
              data['name'] as String? ?? 'User ${widget.otherUserId}';
        });
      } else {
        setState(() {
          _otherUserName = 'User ${widget.otherUserId}';
        });
      }
    } catch (e) {
      setState(() {
        _otherUserName = 'User ${widget.otherUserId}';
      });
    }
  }

  Future<void> _fetchMessages() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.conversations}?user_id=$_userId&other_user_id=${widget.otherUserId}'),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final messages = data.map((json) => Message.fromJson(json)).toList();
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch messages: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching messages: $e';
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (_userId == null || text.trim().isEmpty) return;

    final request = MessageRequest(
      requestId: const Uuid().v4(),
      senderId: _userId!,
      receiverId: widget.otherUserId,
      content: TextContent(body: text),
      timestamp: DateTime.now(),
    );

    try {
      final response = await http.post(
        Uri.parse(AppConstants.messages + '/send'),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final messageResponse = MessageResponse.fromJson(responseData);
        if (messageResponse.status == 'DELIVERED') {
          setState(() {
            _messages.add(Message(
              id: messageResponse.messageId,
              senderId: _userId!,
              receiverId: widget.otherUserId,
              timestamp: request.timestamp,
              content: request.content,
            ));
          });
          _messageController.clear();
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error sending message: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    if (_userId == null) return;

    final request = MessageDeleteRequest(
      messageId: messageId,
      requesterId: _userId!,
      scope: forEveryone ? 'FOR_EVERYONE' : 'FOR_ME',
    );

    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.messages}/$messageId'),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final operationResponse = OperationResponse.fromJson(responseData);
        if (operationResponse.success) {
          setState(() {
            if (forEveryone) {
              _messages.removeWhere((msg) => msg.id == messageId);
            } else {
              _messages.removeWhere(
                  (msg) => msg.id == messageId && msg.senderId == _userId);
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error deleting message: ${operationResponse.errorMessage}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting message: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  Future<void> _initiateBooking() async {
    if (_userId == null) return;

    final request = BookingRequest(
      proposalId: const Uuid().v4(),
      clientId: _userId!,
      providerId: widget.otherUserId,
      proposedTime: DateTime.now().add(const Duration(days: 1)),
      termsHash: 'sample_terms_hash',
    );

    try {
      final response = await http.post(
        Uri.parse(AppConstants.bookingInitiate),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final bookingResponse = BookingResponse.fromJson(responseData);
        if (bookingResponse.status == 'PENDING') {
          final message = Message(
            id: bookingResponse.bookingId,
            senderId: _userId!,
            receiverId: widget.otherUserId,
            timestamp: DateTime.now(),
            content: BookingProposal(
              proposalId: bookingResponse.bookingId,
              proposedTime: request.proposedTime,
              meetingPurpose: _bookingPurposeController.text,
              termsHash: request.termsHash,
            ),
          );
          setState(() {
            _messages.add(message);
          });
          _sendSMSNotification('Booking proposal sent');
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error initiating booking: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating booking: $e')),
      );
    }
  }

  Future<void> _respondToBooking(String proposalId, String decision) async {
    final request = BookingResponseRequest(
      proposalId: proposalId,
      decision: decision,
      message: decision == 'ACCEPTED'
          ? 'Booking accepted'
          : decision == 'REJECTED'
              ? 'Booking rejected'
              : 'Booking cancelled',
    );

    try {
      final response = await http.post(
        Uri.parse(AppConstants.bookingRespond),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final operationResponse = OperationResponse.fromJson(responseData);
        if (operationResponse.success) {
          _sendSMSNotification('Booking response: ${request.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking response sent')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error responding to booking: ${operationResponse.errorMessage}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error responding to booking: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to booking: $e')),
      );
    }
  }

  Future<void> _sendSMSNotification(String message) async {
    if (_userId == null) return;

    final request = SMSRequest(
      phoneNumber: '+1234567890', // Replace with actual phone number
      message: message,
    );

    try {
      final response = await http.post(
        Uri.parse(AppConstants.notificationsSms),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final smsResponse = SMSResponse.fromJson(responseData);
        if (smsResponse.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SMS notification sent')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error sending SMS: ${smsResponse.errorMessage}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending SMS: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SMS: $e')),
      );
    }
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.authTokenKey) ?? '';
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
              backgroundColor: AppConstants.primaryColor,
            ),
            child: const Text('Send Proposal',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBookingResponseDialog(String proposalId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Booking'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToBooking(proposalId, 'ACCEPTED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToBooking(proposalId, 'REJECTED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToBooking(proposalId, 'CANCELLED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUserName ?? 'Chat with User ${widget.otherUserId}'),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: _showBookingDialog,
            tooltip: 'Initiate Booking',
          ),
        ],
      ),
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
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initAndFetchUserId();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
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
              : Column(
                  children: [
                    if (_otherUserTyping)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Typing...',
                          style: TextStyle(
                              color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              _messages[_messages.length - 1 - index];
                          final isSentByUser = message.senderId == _userId;
                          return GestureDetector(
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Message'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteMessage(message.id, false);
                                      },
                                      child: const Text('Delete for Me'),
                                    ),
                                    if (isSentByUser)
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteMessage(message.id, true);
                                        },
                                        child:
                                            const Text('Delete for Everyone'),
                                      ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Align(
                              alignment: isSentByUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSentByUser
                                      ? AppConstants.primaryColor
                                          .withOpacity(0.8)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                                          color: isSentByUser
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      )
                                    else if (message.content is BookingProposal)
                                      GestureDetector(
                                        onTap: () => _showBookingResponseDialog(
                                            (message.content as BookingProposal)
                                                .proposalId),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color:
                                                    AppConstants.primaryColor),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            color: Colors.white,
                                          ),
                                          child: Text(
                                            'Booking Proposal - ${(message.content as BookingProposal).meetingPurpose}',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.timestamp
                                          .toLocal()
                                          .toString()
                                          .substring(11, 16),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSentByUser
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _messageController.clear(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: AppConstants.primaryColor,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: () =>
                                  _sendMessage(_messageController.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
