// lib/models/message_models.dart
class Message {
  String id;
  int senderId;
  int receiverId;
  DateTime timestamp;
  dynamic content; // Can be TextContent or BookingProposal
  Map<String, String> metadata;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    this.content,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'content': content?.toJson(),
        'metadata': metadata,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['sender_id'] as int,
        receiverId: json['receiver_id'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        content: json['content'] != null
            ? (json['content'] as Map<String, dynamic>).containsKey('text')
                ? TextContent.fromJson({'text': json['content']})
                : (json['content'] as Map<String, dynamic>)
                        .containsKey('booking')
                    ? BookingProposal.fromJson({'booking': json['content']})
                    : null
            : null,
        metadata: (json['metadata'] as Map<String, dynamic>?)
                ?.cast<String, String>() ??
            {},
      );
}

class TextContent {
  String body;

  TextContent({required this.body});

  Map<String, dynamic> toJson() => {
        'text': {'body': body}
      };

  factory TextContent.fromJson(Map<String, dynamic> json) =>
      TextContent(body: json['text']['body'] as String);
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
          'bnb_id': bnbId,
          'proposed_time': proposedTime?.toUtc().toIso8601String(),
          'meeting_purpose': meetingPurpose,
          'terms_hash': termsHash,
        },
      };

  factory BookingProposal.fromJson(Map<String, dynamic> json) =>
      BookingProposal(
        proposalId: json['booking']['proposal_id'] as String,
        bnbId: json['booking']['bnb_id'] as int?,
        proposedTime: json['booking']['proposed_time'] != null
            ? DateTime.parse(json['booking']['proposed_time'] as String)
            : null,
        meetingPurpose: json['booking']['meeting_purpose'] as String? ?? '',
        termsHash: json['booking']['terms_hash'] as String,
      );
}

class MessageRequest {
  String requestId;
  int senderId;
  int receiverId;
  dynamic content; // TextContent or BookingProposal
  DateTime timestamp;

  MessageRequest({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content?.toJson(),
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

class MessageDeleteRequest {
  String messageId;
  int requesterId;
  String scope;

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
        'bnb_id': bnbId,
        'terms_hash': termsHash,
      };
}

class BookingResponseRequest {
  String proposalId;
  String decision;
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

class MessageResponse {
  String messageId;
  DateTime? serverTime;
  String status;

  MessageResponse({
    required this.messageId,
    this.serverTime,
    required this.status,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(
        messageId: json['message_id'] as String,
        serverTime: json['server_time'] != null
            ? DateTime.parse(json['server_time'] as String)
            : null,
        status: json['status'] as String,
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
        success: json['success'] as bool,
        errorMessage: json['error_message'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      );
}

class BookingResponse {
  String bookingId;
  String status;
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
        bookingId: json['booking_id'] as String,
        status: json['status'] as String,
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
        success: json['success'] as bool,
        messageId: json['message_id'] as String,
        errorMessage: json['error_message'] as String?,
      );
}
