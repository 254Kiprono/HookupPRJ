enum TransactionType {
  earning,
  withdrawal,
}

enum TransactionStatus {
  pending,
  completed,
  failed,
}

class WalletTransaction {
  final String transactionId;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime timestamp;
  final String? reference;
  final String? description;
  
  // For earnings
  final String? bnbId;
  final String? bnbName;
  final String? clientName;
  final String? bookingId;
  
  // For withdrawals
  final String? withdrawalMethod;
  final String? accountDetails;

  WalletTransaction({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.status,
    required this.timestamp,
    this.reference,
    this.description,
    this.bnbId,
    this.bnbName,
    this.clientName,
    this.bookingId,
    this.withdrawalMethod,
    this.accountDetails,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      transactionId: json['transaction_id']?.toString() ?? json['id']?.toString() ?? '',
      type: _typeFromString(json['type']?.toString() ?? ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: _statusFromString(json['status']?.toString() ?? ''),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
      reference: json['reference']?.toString(),
      description: json['description']?.toString(),
      bnbId: json['bnb_id']?.toString(),
      bnbName: json['bnb_name']?.toString(),
      clientName: json['client_name']?.toString(),
      bookingId: json['booking_id']?.toString(),
      withdrawalMethod: json['withdrawal_method']?.toString(),
      accountDetails: json['account_details']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'type': type == TransactionType.earning ? 'earning' : 'withdrawal',
      'amount': amount,
      'status': status == TransactionStatus.completed ? 'completed' : status == TransactionStatus.pending ? 'pending' : 'failed',
      'timestamp': timestamp.toIso8601String(),
      'reference': reference,
      'description': description,
      'bnb_id': bnbId,
      'bnb_name': bnbName,
      'client_name': clientName,
      'booking_id': bookingId,
      'withdrawal_method': withdrawalMethod,
      'account_details': accountDetails,
    };
  }

  static TransactionType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'earning':
      case 'earnings':
      case 'income':
        return TransactionType.earning;
      case 'withdrawal':
      case 'withdraw':
      case 'payout':
        return TransactionType.withdrawal;
      default:
        return TransactionType.earning;
    }
  }

  static TransactionStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
        return TransactionStatus.completed;
      case 'pending':
        return TransactionStatus.pending;
      case 'failed':
      case 'failure':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
  }

  String get formattedAmount {
    final prefix = type == TransactionType.earning ? '+' : '-';
    return '$prefix KES ${amount.toStringAsFixed(2)}';
  }

  String get displayDescription {
    if (description != null && description!.isNotEmpty) {
      return description!;
    }
    
    if (type == TransactionType.earning) {
      if (bnbName != null && clientName != null) {
        return '$bnbName – paid by $clientName';
      } else if (bnbName != null) {
        return 'Earning from $bnbName';
      } else if (clientName != null) {
        return 'Payment from $clientName';
      }
      return 'Earning';
    } else {
      return 'Withdrawal${reference != null ? ' - $reference' : ''}';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}






