import 'package:flutter/material.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/messaging_service.dart';
import 'package:hook_app/models/message_models.dart';
import 'package:hook_app/screens/main_app/messages_screen.dart' as messages;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/utils/responsive.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/nav.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
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
    super.build(context);
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Nav.safePop(context);
            } else {
              Navigator.of(context).pushReplacementNamed(Routes.home);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadConversations,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchOverlay(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _conversations.isEmpty
                        ? _buildEmptyWidget()
                        : RefreshIndicator(
                            onRefresh: _loadConversations,
                            color: AppConstants.primaryColor,
                            backgroundColor: AppConstants.cardNavy,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(20),
                              itemCount: _conversations.length,
                              itemBuilder: (context, index) {
                                final conversation = _conversations[index];
                                final otherUserId = _userId != null
                                    ? (conversation.participantA == _userId
                                        ? conversation.participantB
                                        : conversation.participantA)
                                    : conversation.participantB;
                                return _buildConversationItem(conversation, otherUserId);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: TextStyle(color: AppConstants.mutedGray),
            border: InputBorder.none,
            icon: Icon(Icons.search_rounded, color: AppConstants.mutedGray, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(Conversation conversation, int otherUserId) {
    final lastMessage = conversation.lastMessage;
    String lastMessageText = 'Start a conversation';
    
    if (lastMessage != null && lastMessage.content != null) {
      if (lastMessage.content is TextContent) {
        lastMessageText = (lastMessage.content as TextContent).body;
      } else if (lastMessage.content is BookingProposal) {
        lastMessageText = '📅 Booking proposal';
      }
    }

    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  child: Text('U$otherUserId', style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppConstants.successColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.cardNavy, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('User $otherUserId', style: const TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.bold)),
                      if (lastMessage != null)
                        Text(_formatTime(lastMessage.timestamp), style: const TextStyle(color: AppConstants.mutedGray, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessageText,
                          style: TextStyle(color: conversation.unreadCount > 0 ? Colors.white : AppConstants.mutedGray, fontSize: 13, fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppConstants.primaryColor, borderRadius: BorderRadius.circular(10)),
                          child: Text('${conversation.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppConstants.mutedGray.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No conversations yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Find providers to start a chat', style: TextStyle(color: AppConstants.mutedGray)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AppConstants.errorColor),
          const SizedBox(height: 16),
          const Text('Something went wrong', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(_errorMessage!, style: const TextStyle(color: AppConstants.mutedGray)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadConversations, child: const Text('Retry')),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0) return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}