import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String time;
  final String type;
  bool isRead;
  bool isExpanded;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
    this.isExpanded = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    String rawTime = json['created_at'] ?? json['time'] ?? '';
    String formattedTime = rawTime.length >= 10
        ? rawTime.substring(0, 10)
        : 'Just now';

    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      time: formattedTime,
      type: json['type'] ?? 'Account',
      isRead: json['is_read'] == true || json['is_read'] == 1,
    );
  }

  String get shortPreview {
    if (message.length > 45) {
      return "${message.substring(0, 45)}...";
    }
    return message;
  }
}

class Notifications extends StatefulWidget {
  const Notifications({Key? key}) : super(key: key);

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  String? currentUserRole;
  int? currentUserId;

  final String baseUrl = "http://10.242.103.201:5000";

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchNotifications();
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io from Notifications Screen');
      socket!.emit('join-personal-room', {
        'role': currentUserRole,
        'id': currentUserId,
      });
    });

    final notificationEvents = [
      'new_booking_notification',
      'trip_request_approved',
      'trip_request_rejected',
      'account_status_changed',
      'report_status_updated',
      'user_banned_live',
    ];

    for (var event in notificationEvents) {
      socket!.on(event, (_) {
        if (mounted) _fetchNotifications(showLoader: false);
      });
    }
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    return currentUserRole == 'Zamil'
        ? const Color(0xFF1D9E75)
        : const Color(0xFF185FA5);
  }

  Future<void> _loadUserAndFetchNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    int? zamilId =
        prefs.getInt('zamil_id') ??
        prefs.getInt('userId') ??
        prefs.getInt('id');
    int? captainId =
        prefs.getInt('captain_id') ??
        prefs.getInt('userId') ??
        prefs.getInt('id');

    String role = prefs.getString('userRole') ?? 'Zamil';

    setState(() {
      currentUserRole = role;
      currentUserId = role == 'Captain' ? captainId : zamilId;
    });

    print(
      "🕵️‍♂️ DEBUG: Role is [$currentUserRole], User ID is [$currentUserId]",
    );

    if (currentUserId != null && currentUserId != 0) {
      _fetchNotifications(showLoader: true);
      _initSocket();
    } else {
      setState(() => _isLoading = false);
      print("❌ DEBUG: User ID not found or equal to 0!");
    }
  }

  Future<void> _fetchNotifications({bool showLoader = true}) async {
    if (currentUserId == null || currentUserId == 0) return;

    if (showLoader && mounted) setState(() => _isLoading = true);

    try {
      String endpoint = currentUserRole == 'Captain'
          ? '/api/captain/notifications/$currentUserId'
          : '/api/zamil/notifications/$currentUserId';

      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['notifications'] != null) {
          if (mounted) {
            setState(() {
              _notifications = (data['notifications'] as List)
                  .map((item) => NotificationModel.fromJson(item))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      print("❌ Network error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    setState(() {
      notification.isRead = true;
    });

    try {
      String endpoint = currentUserRole == 'Captain'
          ? '/api/captain/notifications/${notification.id}/read'
          : '/api/zamil/notifications/${notification.id}/read';

      final response = await http.put(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        socket?.emit('notification_read_update', {
          'role': currentUserRole,
          'id': currentUserId,
        });
      }
    } catch (e) {
      print("❌ Error marking as read: $e");
      setState(() {
        notification.isRead = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () => _fetchNotifications(showLoader: true),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : _notifications.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  return _buildNotificationCard(_notifications[index]);
                },
              ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Booking':
        return _primaryColor;
      case 'Account':
        return const Color(0xFF50C878);
      case 'TripClaim':
        return Colors.deepOrangeAccent;
      default:
        return _primaryColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Booking':
        return Icons.directions_bus_rounded;
      case 'Account':
        return Icons.verified_user_rounded;
      case 'TripClaim':
        return Icons.map_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    Color typeColor = _getTypeColor(notification.type);

    return GestureDetector(
      onTap: () {
        setState(() {
          notification.isExpanded = !notification.isExpanded;
        });
        if (!notification.isRead) {
          _markAsRead(notification);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        margin: EdgeInsets.symmetric(
          horizontal: notification.isExpanded ? 12.0 : 20.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: notification.isExpanded
                  ? Colors.black.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: notification.isExpanded ? 20 : 10,
              offset: Offset(0, notification.isExpanded ? 10 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width: double.infinity,
                color: notification.isRead ? Colors.grey.shade400 : typeColor,
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: notification.isRead
                                ? Colors.grey.shade200
                                : typeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getTypeIcon(notification.type),
                            size: 20,
                            color: notification.isRead
                                ? Colors.grey.shade500
                                : typeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w900,
                                  color: notification.isRead
                                      ? Colors.grey.shade700
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.isExpanded
                                ? notification.message
                                : notification.shortPreview,
                            style: TextStyle(
                              fontSize: 14,
                              color: notification.isRead
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade800,
                              height: 1.6,
                            ),
                            maxLines: notification.isExpanded ? null : 2,
                            overflow: notification.isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.center,
                            child: AnimatedRotation(
                              turns: notification.isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
