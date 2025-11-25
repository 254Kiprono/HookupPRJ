import 'package:flutter/material.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/messaging_service.dart';
import 'package:hook_app/models/message_models.dart';
import 'package:hook_app/screens/main_app/messages_screen.dart' as messages;
import 'package:hook_app/utils/constants.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user ID from token
      final authToken = await StorageService.getAuthToken();
      if (authToken != null) {
        _userId = await TokenUtils.extractUserId(authToken);
      }

      // Fetch conversations
      final conversations = await MessagingService.getAllConversations(
        limit: 50,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Don't show error for empty conversations, just show empty state
          if (e.toString().contains('No auth token') ||
              e.toString().contains('expired')) {
            _errorMessage = 'Please log in to view conversations';
          } else {
            // For other errors, just show empty state
            _conversations = [];
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.softWhite,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: AppConstants.primaryColor.withOpacity(0.5),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: AppConstants.softWhite,
                      ),
                      onPressed: _loadConversations,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppConstants.errorColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppConstants.errorColor,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _loadConversations,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 32,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppConstants.softWhite,
                                    ),
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
                                      Icons.forum_outlined,
                                      size: 80,
                                      color: AppConstants.mutedGray.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No conversations yet',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.softWhite.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start chatting with providers',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.mutedGray.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadConversations,
                                color: AppConstants.primaryColor,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _conversations.length,
                                  itemBuilder: (context, index) {
                                    final conversation = _conversations[index];
                                    
                                    // Determine the other user ID
                                    final otherUserId = _userId != null
                                        ? (conversation.participantA == _userId
                                            ? conversation.participantB
                                            : conversation.participantA)
                                        : conversation.participantB;

                                    return _buildConversationCard(
                                      conversation,
                                      otherUserId,
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation, int otherUserId) {
    final lastMessage = conversation.lastMessage;
    String lastMessageText = 'No messages yet';
    
    if (lastMessage != null && lastMessage.content != null) {
      if (lastMessage.content is TextContent) {
        lastMessageText = (lastMessage.content as TextContent).body;
      } else if (lastMessage.content is BookingProposal) {
        lastMessageText = '📅 Booking proposal';
      } else if (lastMessage.content is MediaContent) {
        lastMessageText = '📷 Media';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.7),
            AppConstants.surfaceColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          width: 1.5,
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppConstants.primaryColor.withOpacity(0.3),
                AppConstants.accentColor.withOpacity(0.3),
              ],
            ),
          ),
          child: const Icon(
            Icons.person,
            color: AppConstants.softWhite,
            size: 28,
          ),
        ),
        title: Text(
          'User $otherUserId',
          style: const TextStyle(
            color: AppConstants.softWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            lastMessageText,
            style: TextStyle(
              color: AppConstants.mutedGray.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessage != null)
              Text(
                _formatTime(lastMessage.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.mutedGray.withOpacity(0.6),
                ),
              ),
            if (conversation.unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => messages.MessagesScreen(
                otherUserId: otherUserId,
                otherUserName: 'User $otherUserId',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}
