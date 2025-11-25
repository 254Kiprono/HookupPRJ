// lib/models/message_models.dart

// ============================================================================
// MESSAGE MODELS
// ============================================================================

class Message {
  String id;
  int senderId;
  int receiverId;
  DateTime timestamp;
  dynamic content; // Can be TextContent, MediaContent, BookingProposal, PaymentConfirmation, EncryptedContent
  Map<String, String> metadata;
  String? contentType; // 'TEXT', 'MEDIA', 'BOOKING', 'PAYMENT', 'ENCRYPTED'

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    this.content,
    this.metadata = const {},
    this.contentType,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'metadata': metadata,
    };

    if (content != null) {
      if (content is TextContent) {
        json['text'] = (content as TextContent).toJson();
        json['content_type'] = 'TEXT';
      } else if (content is MediaContent) {
        json['media'] = (content as MediaContent).toJson();
        json['content_type'] = 'MEDIA';
      } else if (content is BookingProposal) {
        json['booking'] = (content as BookingProposal).toJson();
        json['content_type'] = 'BOOKING';
      } else if (content is PaymentConfirmation) {
        json['payment'] = (content as PaymentConfirmation).toJson();
        json['content_type'] = 'PAYMENT';
      } else if (content is EncryptedContent) {
        json['encrypted'] = (content as EncryptedContent).toJson();
        json['content_type'] = 'ENCRYPTED';
      }
    }

    return json;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    dynamic content;
    String? contentType;

    // Determine content type and parse accordingly
    if (json.containsKey('text')) {
      content = TextContent.fromJson(json['text']);
      contentType = 'TEXT';
    } else if (json.containsKey('media')) {
      content = MediaContent.fromJson(json['media']);
      contentType = 'MEDIA';
    } else if (json.containsKey('booking')) {
      content = BookingProposal.fromJson(json['booking']);
      contentType = 'BOOKING';
    } else if (json.containsKey('payment')) {
      content = PaymentConfirmation.fromJson(json['payment']);
      contentType = 'PAYMENT';
    } else if (json.containsKey('encrypted')) {
      content = EncryptedContent.fromJson(json['encrypted']);
      contentType = 'ENCRYPTED';
    } else if (json.containsKey('content')) {
      // Fallback for legacy format
      final contentData = json['content'];
      if (contentData is Map<String, dynamic>) {
        if (contentData.containsKey('body')) {
          content = TextContent(body: contentData['body']);
          contentType = 'TEXT';
        }
      }
    }

    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id'] as int? ?? 0,
      receiverId: json['receiver_id'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      content: content,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      contentType: contentType,
    );
  }
}

// ============================================================================
// CONTENT TYPES
// ============================================================================

class TextContent {
  String body;

  TextContent({required this.body});

  Map<String, dynamic> toJson() => {'body': body};

  factory TextContent.fromJson(Map<String, dynamic> json) =>
      TextContent(body: json['body'] as String? ?? '');
}

class MediaContent {
  String url;
  String? mimeType;
  String? thumbnail;
  int? durationSec;

  MediaContent({
    required this.url,
    this.mimeType,
    this.thumbnail,
    this.durationSec,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        if (mimeType != null) 'mime_type': mimeType,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (durationSec != null) 'duration_sec': durationSec,
      };

  factory MediaContent.fromJson(Map<String, dynamic> json) => MediaContent(
        url: json['url'] as String? ?? '',
        mimeType: json['mime_type'] as String?,
        thumbnail: json['thumbnail'] as String?,
        durationSec: json['duration_sec'] as int?,
      );
}

class EncryptedContent {
  String ciphertext;
  String keyId;
  String? iv;
  String? authTag;

  EncryptedContent({
    required this.ciphertext,
    required this.keyId,
    this.iv,
    this.authTag,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'key_id': keyId,
        if (iv != null) 'iv': iv,
        if (authTag != null) 'auth_tag': authTag,
      };

  factory EncryptedContent.fromJson(Map<String, dynamic> json) =>
      EncryptedContent(
        ciphertext: json['ciphertext'] as String? ?? '',
        keyId: json['key_id'] as String? ?? '',
        iv: json['iv'] as String?,
        authTag: json['auth_tag'] as String?,
      );
}

class BookingProposal {
  String proposalId;
  int? bnbId;
  DateTime? proposedTime;
  String meetingPurpose;
  String termsHash;

  BookingProposal({
    required this.proposalId,
    this.bnbId,
    this.proposedTime,
    required this.meetingPurpose,
    required this.termsHash,
  });

  Map<String, dynamic> toJson() => {
        'booking': {
          'proposal_id': proposalId,
          if (bnbId != null) 'bnb_id': bnbId,
          if (proposedTime != null)
            'proposed_time': proposedTime!.toUtc().toIso8601String(),
          'meeting_purpose': meetingPurpose,
          'terms_hash': termsHash,
        },
      };

  factory BookingProposal.fromJson(Map<String, dynamic> json) {
    // Handle both wrapped and unwrapped formats
    final data = json.containsKey('booking') ? json['booking'] : json;
    
    return BookingProposal(
      proposalId: data['proposal_id'] as String? ?? '',
      bnbId: data['bnb_id'] as int?,
      proposedTime: data['proposed_time'] != null
          ? DateTime.parse(data['proposed_time'] as String)
          : null,
      meetingPurpose: data['meeting_purpose'] as String? ?? '',
      termsHash: data['terms_hash'] as String? ?? '',
    );
  }
}

class PaymentConfirmation {
  String transactionId;
  double amount;
  String currency;
  String? receiptUrl;

  PaymentConfirmation({
    required this.transactionId,
    required this.amount,
    required this.currency,
    this.receiptUrl,
  });

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'amount': amount,
        'currency': currency,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
      };

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) =>
      PaymentConfirmation(
        transactionId: json['transaction_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'KES',
        receiptUrl: json['receipt_url'] as String?,
      );
}

// ============================================================================
// CONVERSATION MODEL
// ============================================================================

class Conversation {
  int participantA;
  int participantB;
  Message? lastMessage;
  int unreadCount;

  Conversation({
    required this.participantA,
    required this.participantB,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        participantA: json['participant_a'] as int? ?? 0,
        participantB: json['participant_b'] as int? ?? 0,
        lastMessage: json['last_message'] != null
            ? Message.fromJson(json['last_message'])
            : null,
        unreadCount: json['unread_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'participant_a': participantA,
        'participant_b': participantB,
        if (lastMessage != null) 'last_message': lastMessage!.toJson(),
        'unread_count': unreadCount,
      };
}

// ============================================================================
// REQUEST MODELS
// ============================================================================

class MessageRequest {
  String requestId;
  int senderId;
  int receiverId;
  dynamic content; // TextContent, MediaContent, BookingProposal, PaymentConfirmation, EncryptedContent
  DateTime timestamp;

  MessageRequest({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'request_id': requestId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };

    if (content != null) {
      if (content is TextContent) {
        json['text'] = (content as TextContent).toJson();
      } else if (content is MediaContent) {
        json['media'] = (content as MediaContent).toJson();
      } else if (content is BookingProposal) {
        json['booking'] = (content as BookingProposal).toJson()['booking'];
      } else if (content is PaymentConfirmation) {
        json['payment'] = (content as PaymentConfirmation).toJson();
      } else if (content is EncryptedContent) {
        json['encrypted'] = (content as EncryptedContent).toJson();
      }
    }

    return json;
  }
}

class MessageDeleteRequest {
  String messageId;
  int requesterId;
  String scope; // 'FOR_ME' or 'FOR_EVERYONE'

  MessageDeleteRequest({
    required this.messageId,
    required this.requesterId,
    required this.scope,
  });

  Map<String, dynamic> toJson() => {
        'message_id': messageId,
        'requester_id': requesterId,
        'scope': scope,
      };
}

class BookingRequest {
  String proposalId;
  int clientId;
  int providerId;
  DateTime proposedTime;
  int? bnbId;
  String termsHash;

  BookingRequest({
    required this.proposalId,
    required this.clientId,
    required this.providerId,
    required this.proposedTime,
    this.bnbId,
    required this.termsHash,
  });

  Map<String, dynamic> toJson() => {
        'proposal_id': proposalId,
        'client_id': clientId,
        'provider_id': providerId,
        'proposed_time': proposedTime.toUtc().toIso8601String(),
        if (bnbId != null) 'bnb_id': bnbId,
        'terms_hash': termsHash,
      };
}

class BookingResponseRequest {
  String proposalId;
  String decision; // 'ACCEPTED', 'REJECTED', 'CANCELLED'
  String message;

  BookingResponseRequest({
    required this.proposalId,
    required this.decision,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'proposal_id': proposalId,
        'decision': decision,
        'message': message,
      };
}

class SMSRequest {
  String phoneNumber;
  String message;

  SMSRequest({
    required this.phoneNumber,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'message': message,
      };
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

class MessageResponse {
  String messageId;
  DateTime? serverTime;
  String status; // 'PENDING', 'DELIVERED', 'FAILED'

  MessageResponse({
    required this.messageId,
    this.serverTime,
    required this.status,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(
        messageId: json['message_id'] as String? ?? '',
        serverTime: json['server_time'] != null
            ? DateTime.parse(json['server_time'] as String)
            : null,
        status: json['status'] as String? ?? 'PENDING',
      );
}

class OperationResponse {
  bool success;
  String? errorMessage;
  DateTime? timestamp;

  OperationResponse({
    required this.success,
    this.errorMessage,
    this.timestamp,
  });

  factory OperationResponse.fromJson(Map<String, dynamic> json) =>
      OperationResponse(
        success: json['success'] as bool? ?? false,
        errorMessage: json['error_message'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      );
}

class BookingResponse {
  String bookingId;
  String status; // 'PENDING', 'CONFIRMED', 'DECLINED', 'EXPIRED'
  DateTime? responseTime;
  int? bnbReservationId;

  BookingResponse({
    required this.bookingId,
    required this.status,
    this.responseTime,
    this.bnbReservationId,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) =>
      BookingResponse(
        bookingId: json['booking_id'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        responseTime: json['response_time'] != null
            ? DateTime.parse(json['response_time'] as String)
            : null,
        bnbReservationId: json['bnb_reservation_id'] as int?,
      );
}

class SMSResponse {
  bool success;
  String messageId;
  String? errorMessage;

  SMSResponse({
    required this.success,
    required this.messageId,
    this.errorMessage,
  });

  factory SMSResponse.fromJson(Map<String, dynamic> json) => SMSResponse(
        success: json['success'] as bool? ?? false,
        messageId: json['message_id'] as String? ?? '',
        errorMessage: json['error_message'] as String?,
      );
}

// ============================================================================
// WEBSOCKET EVENT MODELS
// ============================================================================

class ServerEvent {
  String eventType; // 'message', 'booking', 'payment', 'presence', 'typing'
  dynamic data; // Message, BookingAlert, PaymentNotice, OnlineStatusUpdate, TypingUpdate

  ServerEvent({
    required this.eventType,
    required this.data,
  });

  factory ServerEvent.fromJson(Map<String, dynamic> json) {
    String eventType = '';
    dynamic data;

    if (json.containsKey('message')) {
      eventType = 'message';
      data = Message.fromJson(json['message']);
    } else if (json.containsKey('booking')) {
      eventType = 'booking';
      data = BookingAlert.fromJson(json['booking']);
    } else if (json.containsKey('payment')) {
      eventType = 'payment';
      data = PaymentNotice.fromJson(json['payment']);
    } else if (json.containsKey('presence')) {
      eventType = 'presence';
      data = OnlineStatusUpdate.fromJson(json['presence']);
    } else if (json.containsKey('typing')) {
      eventType = 'typing';
      data = TypingUpdate.fromJson(json['typing']);
    }

    return ServerEvent(eventType: eventType, data: data);
  }
}

class BookingAlert {
  String bookingId;
  String type; // 'NEW_REQUEST', 'ACCEPTED', 'REJECTED', 'CANCELLED', 'REMINDER'
  String message;
  DateTime eventTime;

  BookingAlert({
    required this.bookingId,
    required this.type,
    required this.message,
    required this.eventTime,
  });

  factory BookingAlert.fromJson(Map<String, dynamic> json) => BookingAlert(
        bookingId: json['booking_id'] as String? ?? '',
        type: json['type'] as String? ?? 'NEW_REQUEST',
        message: json['message'] as String? ?? '',
        eventTime: json['event_time'] != null
            ? DateTime.parse(json['event_time'] as String)
            : DateTime.now(),
      );
}

class PaymentNotice {
  String transactionId;
  double amount;
  String currency;
  String status; // 'PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'

  PaymentNotice({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.status,
  });

  factory PaymentNotice.fromJson(Map<String, dynamic> json) => PaymentNotice(
        transactionId: json['transaction_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'KES',
        status: json['status'] as String? ?? 'PENDING',
      );
}

class OnlineStatusUpdate {
  int userId;
  bool isOnline;
  DateTime lastSeen;
  String? currentApp;

  OnlineStatusUpdate({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
    this.currentApp,
  });

  factory OnlineStatusUpdate.fromJson(Map<String, dynamic> json) =>
      OnlineStatusUpdate(
        userId: json['user_id'] as int? ?? 0,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: json['last_seen'] != null
            ? DateTime.parse(json['last_seen'] as String)
            : DateTime.now(),
        currentApp: json['current_app'] as String?,
      );
}

class TypingUpdate {
  int conversationId;
  int userId;
  bool isTyping;

  TypingUpdate({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  factory TypingUpdate.fromJson(Map<String, dynamic> json) => TypingUpdate(
        conversationId: json['conversation_id'] as int? ?? 0,
        userId: json['user_id'] as int? ?? 0,
        isTyping: json['is_typing'] as bool? ?? false,
      );
}
