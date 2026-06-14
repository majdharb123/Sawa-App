import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class Passengers extends StatefulWidget {
  final int groupId;

  const Passengers({super.key, required this.groupId});

  @override
  State<Passengers> createState() => _PassengersState();
}

class _PassengersState extends State<Passengers> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgWhite = const Color(0xFFF9F9F9);
  final String baseUrl = "http://10.242.103.201:5000";

  bool isLoading = true;
  String groupName = "Group Info";
  Map<String, dynamic>? captainInfo;
  List<dynamic> passengersList = [];

  IO.Socket? socket;

  final List<Color> avatarColors = [
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.blueGrey,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails(showLoader: true);
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io from Passengers Screen');
      socket!.emit('join-chat-group', widget.groupId);
    });

    socket!.on('group_members_updated', (data) {
      if (data['groupId'] == widget.groupId && mounted) {
        _fetchGroupDetails(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupDetails({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/captain/chat/group-details/${widget.groupId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && mounted) {
          setState(() {
            groupName = data['group_name'] ?? "Group Info";
            captainInfo = data['captain'];
            passengersList = data['passengers'] ?? [];
            isLoading = false;
          });
        } else {
          if (mounted) setState(() => isLoading = false);
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching group details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          groupName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "${passengersList.length + 1} Participants", // +1 عشان الكابتن
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF0F0F0),
                        ),

                        if (captainInfo != null) ...[
                          _buildCaptainRow(),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF0F0F0),
                          ),
                        ],

                        if (passengersList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30.0),
                            child: Center(
                              child: Text(
                                "No passengers have joined yet.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: passengersList.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF0F0F0),
                            ),
                            itemBuilder: (context, index) {
                              final passenger = passengersList[index];
                              final color =
                                  avatarColors[index % avatarColors.length];
                              return _buildPassengerRow(passenger, color);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCaptainRow() {
    String capName = captainInfo?['name'] ?? "Unknown";
    String initials = capName.length > 1
        ? capName.substring(0, 2).toUpperCase()
        : "CA";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: primaryBlue,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 14),
            ),
          ),
        ],
      ),
      title: Text(
        capName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        captainInfo?['phone'] ?? "Captain",
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "Group Admin",
          style: TextStyle(
            color: primaryBlue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerRow(Map<String, dynamic> passenger, Color avatarColor) {
    String fullName = passenger['full_name'] ?? "Unknown";
    String initial = fullName.isNotEmpty
        ? fullName.substring(0, 1).toUpperCase()
        : "Z";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: avatarColor.withOpacity(0.2),
        child: Text(
          initial,
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        fullName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        passenger['phone'] ?? "No phone",
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
