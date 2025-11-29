import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/message_models.dart';

class MessagingService {
  static WebSocketChannel? _channel;
  static StreamController<ServerEvent>? _eventController;
  static bool _isConnected = false;

  // Core Messaging APIs

  /// Send a text message to another user
  static Future<MessageResponse> sendMessage({
    required int receiverId,
    required String text,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    final response = await http.post(
      Uri.parse(AppConstants.sendMessage),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'request_id': requestId,
        'receiver_id': receiverId,
        'text': {
          'body': text,
        },
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MessageResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to send message');
    }
  }

  /// Send a booking proposal message
  static Future<MessageResponse> sendBookingMessage({
    required int receiverId,
    required BookingProposal booking,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    final response = await http.post(
      Uri.parse(AppConstants.sendMessage),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'request_id': requestId,
        'receiver_id': receiverId,
        'booking': booking.toJson()['booking'],
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MessageResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to send booking message');
    }
  }

  /// Get conversation history with another user
  static Future<List<Message>> getConversation({
    required int otherUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final uri = Uri.parse('${AppConstants.conversations}/$otherUserId')
        .replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Handle the wrapped response format
      if (data is Map && data.containsKey('success') && data['success'] == true) {
        final messagesData = data['data'] as List<dynamic>? ?? [];
        return messagesData.map((json) => Message.fromJson(json)).toList();
      } else if (data is List) {
        return data.map((json) => Message.fromJson(json)).toList();
      }
      
      return [];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to load conversation');
    }
  }

  /// Get all conversations for the current user
  static Future<List<Conversation>> getAllConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final uri = Uri.parse(AppConstants.conversations)
        .replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Handle the wrapped response format
      if (data is Map && data.containsKey('success') && data['success'] == true) {
        final conversationsData = data['data'] as List<dynamic>? ?? [];
        return conversationsData.map((json) => Conversation.fromJson(json)).toList();
      } else if (data is List) {
        return data.map((json) => Conversation.fromJson(json)).toList();
      }
      
      return [];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to load conversations');
    }
  }

  /// Delete a message
  static Future<OperationResponse> deleteMessage({
    required String messageId,
    required String scope, // 'FOR_ME' or 'FOR_EVERYONE'
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.delete(
      Uri.parse('${AppConstants.messages}/$messageId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scope': scope,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return OperationResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to delete message');
    }
  }


  /// Initiate a booking proposal
  static Future<BookingResponse> initiateBooking({
    required int providerId,
    required DateTime proposedTime,
    String? meetingPurpose,
    int? bnbId,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final proposalId = DateTime.now().millisecondsSinceEpoch.toString();
    final termsHash = 'terms_${DateTime.now().millisecondsSinceEpoch}';

    final response = await http.post(
      Uri.parse(AppConstants.bookingInitiate),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'proposal_id': proposalId,
        'provider_id': providerId,
        'proposed_time': proposedTime.toUtc().toIso8601String(),
        'bnb_id': bnbId,
        'terms_hash': termsHash,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BookingResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to initiate booking');
    }
  }

  /// Respond to a booking proposal
  static Future<OperationResponse> respondToBooking({
    required String proposalId,
    required String decision, // 'ACCEPTED', 'REJECTED', 'CANCELLED'
    String? message,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
      Uri.parse(AppConstants.bookingRespond),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'proposal_id': proposalId,
        'decision': decision.toUpperCase(),
        'message': message ?? '',
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return OperationResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to respond to booking');
    }
  }

  // SMS Notification API

  /// Send SMS notification
  static Future<SMSResponse> sendSMSNotification({
    required String phoneNumber,
    required String message,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
      Uri.parse(AppConstants.notificationsSms),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone_number': phoneNumber,
        'message': message,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return SMSResponse.fromJson(data);
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded: 10 SMS per 24 hours');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error_message'] ?? 'Failed to send SMS');
    }
  }

  // WebSocket Streaming

  /// Connect to WebSocket for real-time updates
  static Stream<ServerEvent> connectWebSocket() async* {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    if (_isConnected && _eventController != null) {
      yield* _eventController!.stream;
      return;
    }

    _eventController = StreamController<ServerEvent>.broadcast();
    _isConnected = true;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConstants.websocketUrl),
      );

      // Send authentication
      _channel!.sink.add(jsonEncode({
        'auth': {
          'token': token,
        }
      }));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            final event = ServerEvent.fromJson(data);
            _eventController!.add(event);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _eventController?.addError(error);
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _eventController?.close();
          _eventController = null;
        },
      );

      yield* _eventController!.stream;
    } catch (e) {
      _isConnected = false;
      _eventController?.close();
      _eventController = null;
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  /// Send typing status update via WebSocket
  static void sendTypingStatus({
    required int conversationId,
    required bool isTyping,
  }) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'typing': {
          'conversation_id': conversationId,
          'is_typing': isTyping,
        }
      }));
    }
  }

  /// Send message acknowledgment via WebSocket
  static void sendMessageAck({
    required String messageId,
    required String status, // 'DELIVERED' or 'READ'
  }) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'ack': {
          'message_id': messageId,
          'status': status.toUpperCase(),
        }
      }));
    }
  }

  /// Send user status update via WebSocket
  static void sendUserStatus({
    required String status, // 'ONLINE', 'OFFLINE', 'AWAY', 'BUSY'
    String? customStatus,
  }) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'status': {
          'status': status.toUpperCase(),
          'custom_status': customStatus,
        }
      }));
    }
  }

  /// Close WebSocket connection
  static void closeWebSocket() {
    _channel?.sink.close();
    _eventController?.close();
    _channel = null;
    _eventController = null;
    _isConnected = false;
  }

  /// Check if WebSocket is connected
  static bool get isConnected => _isConnected;
}
