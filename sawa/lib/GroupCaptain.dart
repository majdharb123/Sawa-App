import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GroupCaptain extends StatefulWidget {
  const GroupCaptain({super.key});

  @override
  State<GroupCaptain> createState() => _GroupCaptainState();
}

class _GroupCaptainState extends State<GroupCaptain> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color lightBlueBg = const Color(0xFFE3F2FD);
  final Color bgWhite = const Color(0xFFF9F9F9);

  final String baseUrl = "http://10.242.103.201:5000";
  int currentCaptainId = 0;
  String captainName = "Captain";

  List<dynamic> chatGroups = [];
  bool isLoading = true;

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _loadCaptainData();
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from GroupCaptain');
    });

    socket.on('trip_request_approved', (data) {
      if (data['captainId'] == currentCaptainId && mounted) {
        _fetchGroups(showLoader: false);
      }
    });

    socket.on('daily_trips_generated', (_) {
      if (mounted) _fetchGroups(showLoader: false);
    });

    socket.on('recurrent_routes_expired', (_) {
      if (mounted) _fetchGroups(showLoader: false);
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _loadCaptainData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentCaptainId =
          prefs.getInt('captain_id') ?? prefs.getInt('userId') ?? 0;
      captainName = prefs.getString('userName') ?? "Captain";
    });

    if (currentCaptainId != 0) {
      _fetchGroups(showLoader: true);
      _initSocket();
    } else {
      setState(() => isLoading = false);
      _showSnackBar("Captain ID not found. Please login again.", Colors.red);
    }
  }

  Future<void> _fetchGroups({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/captain/chat/groups/$currentCaptainId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            chatGroups = data['groups'] ?? [];
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
        _showSnackBar("Failed to load groups.", Colors.red);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar("Network Error: Could not fetch groups.", Colors.red);
    }
  }

  Future<void> _createPrivateGroup(String groupName) async {
    Navigator.pop(context);

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/captain/chat/create-private'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'captain_id': currentCaptainId,
          'trip_id': 101,
          'group_name': groupName,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Group '$groupName' created successfully!", primaryBlue);
        _fetchGroups(showLoader: true);
      } else {
        _showSnackBar("Failed to create group.", Colors.red);
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Network Error.", Colors.red);
      setState(() => isLoading = false);
    }
  }

  Future<void> _deletePrivateGroup(int groupId) async {
    Navigator.pop(context);
    setState(() => isLoading = true);

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/captain/chat/delete-group/$groupId'),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Group deleted successfully.", Colors.grey);
        _fetchGroups(showLoader: true);
      } else {
        _showSnackBar("Failed to delete group.", Colors.red);
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Network Error.", Colors.red);
      setState(() => isLoading = false);
    }
  }

  void _showDeleteConfirmation(int groupId, String groupName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Group",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          "Are you sure you want to delete '$groupName'? All messages and data will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _deletePrivateGroup(groupId),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog() {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Create Private Group",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: "Enter Group Name (e.g. Beirut Express)",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createPrivateGroup(nameController.text.trim());
                } else {
                  _showSnackBar("Group name cannot be empty!", Colors.orange);
                }
              },
              child: const Text(
                "Done",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: const Text(
          "Trip Groups",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _showCreateGroupDialog,
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text(
          "Create Private",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : chatGroups.isEmpty
          ? _buildEmptyStateUI()
          : _buildGroupsListUI(),
    );
  }

  Widget _buildEmptyStateUI() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_off_outlined, size: 80, color: primaryBlue),
          ),
          const SizedBox(height: 30),
          const Text(
            "No Active Groups",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Your approved Recurrent trips will appear here automatically. You can also create Private groups using the button below.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsListUI() {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 80),
      itemCount: chatGroups.length,
      itemBuilder: (context, index) {
        final group = chatGroups[index];
        final isRecurrent = group['trip_type'] == 'Recurrent';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: isRecurrent ? lightBlueBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: isRecurrent
                  ? primaryBlue.withOpacity(0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isRecurrent ? primaryBlue : Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRecurrent ? Icons.directions_bus_filled : Icons.lock_clock,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              group['group_name'] ?? "Unnamed Group",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isRecurrent ? primaryBlue : Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isRecurrent
                    ? "Auto-Broadcast Group"
                    : "Private Trip Group\n(Long press to delete)",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              context
                  .push(
                    '/chatCaptainRoom',
                    extra: {
                      'groupId': group['id'],
                      'groupName': group['group_name'],
                    },
                  )
                  .then((_) {
                    _fetchGroups(showLoader: false);
                  });
            },
            onLongPress: () {
              if (!isRecurrent) {
                _showDeleteConfirmation(
                  group['id'],
                  group['group_name'] ?? "this group",
                );
              } else {
                _showSnackBar(
                  "Recurrent groups are managed automatically.",
                  Colors.grey,
                );
              }
            },
          ),
        );
      },
    );
  }
}
