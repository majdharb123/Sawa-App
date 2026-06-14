import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChattingZamil extends StatefulWidget {
  const ChattingZamil({Key? key}) : super(key: key);

  @override
  State<ChattingZamil> createState() => _ChattingZamilState();
}

class _ChattingZamilState extends State<ChattingZamil> {
  final Color primaryGreen = const Color(0xFF1D9E75);
  final String baseUrl = "http://10.242.103.201:5000";

  List<dynamic> chatGroups = [];
  bool isLoading = true;

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchMyChatGroups();
    initSocket();
  }

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from ChattingZamil (Chat List)');
    });

    socket.on('new_message', (_) {
      if (mounted) _fetchMyChatGroups(showLoader: false);
    });

    socket.on('message_deleted', (_) {
      if (mounted) _fetchMyChatGroups(showLoader: false);
    });

    socket.on('group_members_updated', (_) {
      if (mounted) _fetchMyChatGroups(showLoader: false);
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _fetchMyChatGroups({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => isLoading = true);
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? zamilId = prefs.getInt('zamil_id') ?? prefs.getInt('userId');

      if (zamilId == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/zamil/chat/my-groups/$zamilId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (mounted) {
            setState(() {
              chatGroups = data['groups'];
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching chat groups: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "";
    try {
      DateTime dt = DateTime.parse(dateString).toLocal();
      DateTime now = DateTime.now();

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat.jm().format(dt);
      } else {
        return DateFormat('MMM d').format(dt);
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "My Conversations",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D9E75),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: () async {
                await _fetchMyChatGroups();
              },
              child: chatGroups.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: _buildEmptyState(),
                      ),
                    )
                  : _buildChatList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "No chats found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Your conversations with captains and other riders will appear here once you book your first SAWA trip.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: chatGroups.length,
      itemBuilder: (context, index) {
        final chat = chatGroups[index];

        String groupTitle =
            chat['group_name'] ?? chat['captainName'] ?? "Group";
        String subtitle = chat['lastMsg'] ?? "Tap to start chatting!";
        String timeText = _formatTime(chat['lastMsgTime']);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                chat['trip_type'] == 'Recurrent'
                    ? Icons.groups_rounded
                    : Icons.directions_bus,
                color: primaryGreen,
                size: 28,
              ),
            ),
            title: Text(
              groupTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: chat['lastMsg'] == null
                      ? primaryGreen
                      : Colors.grey[600],
                  fontStyle: chat['lastMsg'] == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (timeText.isNotEmpty)
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
            onTap: () {
              context
                  .push(
                    '/chatRoom',
                    extra: {
                      'groupId': chat['group_id'],
                      'groupName': groupTitle,
                      'tripType': chat['trip_type'],
                    },
                  )
                  .then((_) {
                    _fetchMyChatGroups(showLoader: false);
                  });
            },
          ),
        );
      },
    );
  }
}
