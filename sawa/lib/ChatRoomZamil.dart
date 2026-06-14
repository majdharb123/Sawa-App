import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatRoomZamil extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? tripType;

  const ChatRoomZamil({
    super.key,
    required this.groupId,
    required this.groupName,
    this.tripType,
  });

  @override
  State<ChatRoomZamil> createState() => _ChatRoomZamilState();
}

class _ChatRoomZamilState extends State<ChatRoomZamil> {
  final Color primaryGreen = const Color(0xFF1D9E75);
  final Color bgWhite = const Color(0xFFF9F9F9);

  final String baseUrl = "http://10.242.103.201:5000";

  List<dynamic> _messages = [];
  bool isLoading = true;
  String? pinnedAnnouncement;

  int currentZamilId = 0;

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _loadZamilIdAndMessages();
    _markMessagesAsRead();
    initSocket();
  }

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from ChatRoomZamil');
      socket.emit('join-chat-group', widget.groupId);
    });

    socket.on('new_message', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        _fetchMessages(showLoader: false);
        _markMessagesAsRead();
      }
    });

    socket.on('message_deleted', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        _fetchMessages(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/zamil/chat/mark-read/${widget.groupId}'),
      );

      if (response.statusCode == 200) {
        print("✅ [DEBUG] Messages marked as read for group ${widget.groupId}");
      } else {
        print("⚠️ [DEBUG] Failed to mark messages as read.");
      }
    } catch (e) {
      print("❌ [DEBUG] Error marking messages as read: $e");
    }
  }

  Future<void> _loadZamilIdAndMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic savedId =
        prefs.get('zamil_id') ?? prefs.get('userId') ?? prefs.get('id');

    if (savedId != null) {
      currentZamilId = (savedId is int)
          ? savedId
          : int.tryParse(savedId.toString()) ?? 0;
    }

    _fetchMessages(showLoader: true);
  }

  void _updatePinnedAnnouncement() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      String content = _messages[i]['content'] ?? "";
      if (content.contains("📢 Announcement")) {
        setState(() {
          pinnedAnnouncement = content;
        });
        return;
      }
    }
    setState(() {
      pinnedAnnouncement = null;
    });
  }

  Future<void> _fetchMessages({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/zamil/chat/messages/${widget.groupId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _messages = data['messages'] ?? [];
            isLoading = false;
          });
          _updatePinnedAnnouncement();
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar("Error fetching messages", Colors.red);
    }
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Leave Group"),
          ],
        ),
        content: const Text(
          "Are you sure you want to leave this chat group? You will stop receiving updates from the captain.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup();
            },
            child: const Text(
              "Leave",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    if (currentZamilId == 0) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/zamil/chat/leave-group'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "zamil_id": currentZamilId,
          "group_id": widget.groupId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _showSnackBar("You left the group successfully.", Colors.grey);
          if (mounted) {
            context.pop();
          }
        } else {
          _showSnackBar("Failed to leave group.", Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar("Network error.", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "";
    try {
      final date = DateTime.parse(isoTime).toLocal();
      return DateFormat.jm().format(date);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryGreen, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryGreen.withOpacity(0.1),
              child: Icon(
                widget.tripType == 'Recurrent'
                    ? Icons.groups_rounded
                    : Icons.directions_bus,
                color: primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "Updates from Captain",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            tooltip: "Leave Group",
            onPressed: _confirmLeaveGroup,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: pinnedAnnouncement != null
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(
                  color: pinnedAnnouncement != null
                      ? Colors.red.shade200
                      : Colors.orange.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: 18,
                  color: pinnedAnnouncement != null
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pinnedAnnouncement ??
                        "This is a broadcast channel. Passengers can read but cannot reply.",
                    style: TextStyle(
                      color: pinnedAnnouncement != null
                          ? Colors.red.shade800
                          : Colors.orange.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryGreen))
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      "No announcements yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    color: primaryGreen,
                    onRefresh: () => _fetchMessages(showLoader: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildMessageBubble(msg);
                      },
                    ),
                  ),
          ),
          _buildReadOnlyBanner(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['content'] ?? "",
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg['created_at']),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            "Only the captain can send messages.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
