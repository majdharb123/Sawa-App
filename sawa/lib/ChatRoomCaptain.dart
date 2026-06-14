import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatRoomCaptain extends StatefulWidget {
  final int groupId;
  final String groupName;

  const ChatRoomCaptain({
    super.key, 
    required this.groupId, 
    required this.groupName,
  });

  @override
  State<ChatRoomCaptain> createState() => _ChatRoomCaptainState();
}

class _ChatRoomCaptainState extends State<ChatRoomCaptain> {
  final TextEditingController _messageController = TextEditingController();
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgWhite = const Color(0xFFF9F9F9);

  final String baseUrl = "http://10.242.103.201:5000"; 
  int currentCaptainId = 0;
  
  List<dynamic> _messages = [];
  bool isLoading = true;
  
  String? pinnedAnnouncement; 

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _loadCaptainDataAndMessages();
    initSocket(); 
  }

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from ChatRoomCaptain');
      socket.emit('join-chat-group', widget.groupId);
    });

    socket.on('new_message', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        _fetchMessages(showLoader: false);
      }
    });

    socket.on('message_deleted', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        _fetchMessages(showLoader: false);
      }
    });

    socket.on('group_members_updated', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        String action = data['action'] == 'joined' ? 'joined' : 'left';
        Color snackColor = action == 'joined' ? Colors.green : Colors.orange;
        _showSnackBar("A passenger has $action the trip.", snackColor);
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptainDataAndMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentCaptainId = prefs.getInt('captain_id') ?? prefs.getInt('userId') ?? 0;
    });

    if (currentCaptainId != 0) {
      _fetchMessages(showLoader: true);
    }
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
        Uri.parse('$baseUrl/api/captain/chat/messages/${widget.groupId}'),
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempMsg = {
      'id': 0, 
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _messages.add(tempMsg);
      _messageController.clear();
      _updatePinnedAnnouncement(); 
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/captain/chat/send-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'group_id': widget.groupId,
          'captain_id': currentCaptainId,
          'content': text,
        }),
      );

      if (response.statusCode == 200) {
        _fetchMessages(showLoader: false);
      } else {
        _showSnackBar("Failed to send message", Colors.red);
        setState(() {
          _messages.remove(tempMsg);
          _updatePinnedAnnouncement(); 
        });
      }
    } catch (e) {
      _showSnackBar("Network error", Colors.red);
      setState(() {
        _messages.remove(tempMsg);
        _updatePinnedAnnouncement();
      });
    }
  }

  Future<void> _deleteMessage(int messageId, int index) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/captain/chat/delete-message/$messageId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.removeAt(index);
        });
        _updatePinnedAnnouncement(); 
        _showSnackBar("Message deleted", Colors.grey);
      } else {
        _showSnackBar("Failed to delete", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Network error", Colors.red);
    }
  }

  void _confirmDelete(int messageId, int index) {
    if (messageId == 0) return; 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Are you sure you want to delete this message?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId, index);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "";
    try {
      final date = DateTime.parse(isoTime).toLocal();
      int hour = date.hour;
      String amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      String minute = date.minute.toString().padLeft(2, '0');
      return "$hour:$minute $amPm";
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
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () {
            context.push('/passengers', extra: {'groupId': widget.groupId}); 
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryBlue.withOpacity(0.1),
                child: Icon(Icons.campaign, color: primaryBlue, size: 20), 
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.groupName, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("Tap to see passengers", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: pinnedAnnouncement != null ? Colors.red.shade50 : Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(
                  color: pinnedAnnouncement != null ? Colors.red.shade200 : Colors.orange.shade200
                )
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin, 
                  size: 18, 
                  color: pinnedAnnouncement != null ? Colors.red.shade700 : Colors.orange.shade700
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pinnedAnnouncement ?? "This is a broadcast channel. Passengers can read but cannot reply.",
                    style: TextStyle(
                      color: pinnedAnnouncement != null ? Colors.red.shade800 : Colors.orange.shade800, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w600
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
              ? Center(child: CircularProgressIndicator(color: primaryBlue))
              : _messages.isEmpty
                ? const Center(child: Text("No announcements yet.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, index);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _confirmDelete(msg['id'], index), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.symmetric(vertical: 4),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg['content'] ?? "",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg['created_at']),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.done_all, size: 12, color: Colors.white70), 
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_alert_rounded, color: primaryBlue),
              onPressed: () {
                _messageController.text = "📢 Announcement: ";
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Send update to passengers...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                backgroundColor: primaryBlue,
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}