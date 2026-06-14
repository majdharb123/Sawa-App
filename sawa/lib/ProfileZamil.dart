import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ProfileZamil extends StatefulWidget {
  final String? specificZamilEmail;

  const ProfileZamil({Key? key, this.specificZamilEmail}) : super(key: key);

  @override
  State<ProfileZamil> createState() => _ProfileZamilState();
}

class _ProfileZamilState extends State<ProfileZamil> {
  final String baseUrl = "http://10.242.103.201:5000";

  String userName = "Loading...";
  String phoneNumber = "Loading...";
  String email = "";
  int currentUserId = 0;

  File? _profileImage;
  String? _serverImageUrl;
  final ImagePicker _picker = ImagePicker();

  List<dynamic> tripHistory = [];
  bool isHistoryLoading = true;
  String historyError = "";

  int unreadNotificationsCount = 0;
  bool isViewingAnotherUser = false;

  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    if (widget.specificZamilEmail != null &&
        widget.specificZamilEmail!.isNotEmpty) {
      isViewingAnotherUser = true;
      email = widget.specificZamilEmail!;
      _fetchProfileData();
    } else {
      _loadUserAndFetchData();
    }
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io from ProfileZamil');
      if (!isViewingAnotherUser && currentUserId != 0) {
        socket!.emit('join-personal-room', {
          'role': 'Zamil',
          'id': currentUserId,
        });
      }
    });

    final eventsToListen = [
      'new_booking_notification',
      'notification_read_update',
      'report_status_updated',
    ];

    for (var event in eventsToListen) {
      socket!.on(event, (_) {
        if (mounted && !isViewingAnotherUser) {
          _fetchUnreadNotificationCount();
        }
      });
    }
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndFetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('userEmail');

    dynamic idData =
        prefs.get('zamil_id') ?? prefs.get('userId') ?? prefs.get('id');
    int? savedId;
    if (idData != null) {
      if (idData is int) {
        savedId = idData;
      } else if (idData is String) {
        savedId = int.tryParse(idData);
      }
    }

    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        email = savedEmail;
        if (savedId != null) currentUserId = savedId;
      });
      _fetchProfileData();
      _fetchUnreadNotificationCount();
      _fetchHistory();
      _initSocket();
    } else {
      setState(() {
        userName = "Guest User";
        email = "Not Logged In";
        isHistoryLoading = false;
      });
    }
  }

  Future<void> _fetchUnreadNotificationCount() async {
    if (currentUserId == 0) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/zamil/notifications/$currentUserId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          List notifs = data['notifications'] ?? [];
          int count = notifs
              .where((n) => n['is_read'] == 0 || n['is_read'] == false)
              .length;
          if (mounted) {
            setState(() {
              unreadNotificationsCount = count;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching unread count: $e");
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/zamil/profile/get-data'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            userName = data['full_name'] ?? "No Name";
            phoneNumber = data['phone'] ?? "No Phone";

            if (data['selfie_image'] != null &&
                data['selfie_image'].isNotEmpty) {
              _serverImageUrl =
                  "$baseUrl/${data['selfie_image'].replaceAll('\\', '/')}";
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userName = "User Not Found";
            phoneNumber = "N/A";
          });
        }
        _showSnackBar("Profile not found in database.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userName = "Connection Error";
          phoneNumber = "N/A";
        });
      }
      _showSnackBar("Error fetching data: $e");
    }
  }

  Future<void> _fetchHistory() async {
    if (currentUserId == 0) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/zamil/history/$currentUserId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              tripHistory = data['history'] ?? [];
              isHistoryLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              historyError = data['message'] ?? "Failed to load history.";
              isHistoryLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            historyError = "Server Error.";
            isHistoryLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          historyError = "Network Error.";
          isHistoryLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile(
    String newName,
    String newPhone,
    String newEmail,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/zamil/profile/update-info'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "currentEmail": email,
          "newName": newName,
          "newPhone": newPhone,
          "newEmail": newEmail,
        }),
      );

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', newEmail);

        if (mounted) {
          setState(() {
            userName = newName;
            phoneNumber = newPhone;
            email = newEmail;
          });
        }
        _showSnackBar("Profile updated successfully!");
      } else {
        _showSnackBar("Failed to update profile.");
      }
    } catch (e) {
      _showSnackBar("Network Error.");
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/zamil/profile/update-image'),
      );
      request.fields['email'] = email;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _profileImage = imageFile;
            _serverImageUrl =
                "$baseUrl/${data['imagePath'].replaceAll('\\', '/')}";
          });
        }
        _showSnackBar("Profile picture updated!");
      } else {
        _showSnackBar("Failed to upload image.");
      }
    } catch (e) {
      _showSnackBar("Image upload failed.");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        File selectedImage = File(pickedFile.path);
        if (mounted) {
          setState(() {
            _profileImage = selectedImage;
          });
        }
        _uploadImage(selectedImage);
      }
    } catch (e) {
      _showSnackBar("Failed to pick image.");
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to log out?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (context.mounted) Navigator.pop(context);

              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(
      text: userName,
    );
    TextEditingController phoneController = TextEditingController(
      text: phoneNumber,
    );
    TextEditingController emailController = TextEditingController(text: email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Update Profile Info",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                nameController,
                "Full Name",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                phoneController,
                "Phone Number",
                Icons.phone_outlined,
                isPhone: true,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                emailController,
                "Email Address",
                Icons.email_outlined,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _updateProfile(
                      nameController.text,
                      phoneController.text,
                      emailController.text,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTypeTile(
                Icons.camera_alt,
                'Take a Photo',
                ImageSource.camera,
              ),
              ListTypeTile(
                Icons.photo_library,
                'Choose from Library',
                ImageSource.gallery,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget ListTypeTile(IconData icon, String title, ImageSource source) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1D9E75)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        _pickImage(source);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> trip) {
    bool isCompleted = trip['booking_status'] == 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${trip['trip_date']} at ${trip['trip_time']}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trip['booking_status'],
                    style: TextStyle(
                      color: isCompleted ? Colors.green[700] : Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1, color: Color(0xFFF5F5F5)),
            Row(
              children: [
                const Icon(
                  Icons.directions_bus,
                  color: Colors.black87,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${trip['departure']} → ${trip['destination']}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  "${trip['price']} LBP",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF1D9E75).withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 12,
                    color: Color(0xFF1D9E75),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  trip['captain_name'] != null &&
                          trip['captain_name'].toString().isNotEmpty
                      ? "Captain ${trip['captain_name']}"
                      : "Captain Unknown",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isViewingAnotherUser ? 'Zamil Profile' : 'My Profile',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),

        actions: isViewingAnotherUser
            ? []
            : [
                Badge(
                  isLabelVisible: unreadNotificationsCount > 0,
                  label: Text(
                    '$unreadNotificationsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                  offset: const Offset(-3, 3),
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                      size: 28,
                    ),
                    tooltip: 'Notifications',
                    onPressed: () {
                      setState(() {
                        unreadNotificationsCount = 0;
                      });
                      context.push('/notifications');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.orangeAccent,
                    size: 28,
                  ),
                  tooltip: 'Submit a Report',
                  onPressed: () {
                    context.push(
                      '/reports/Zamil',
                      extra: {
                        'name': userName,
                        'email': email,
                        'phone': phoneNumber,
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: isViewingAnotherUser ? null : _showImageOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_serverImageUrl != null
                                    ? NetworkImage(_serverImageUrl!)
                                    : null)
                                as ImageProvider?,
                      child: (_profileImage == null && _serverImageUrl == null)
                          ? const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isViewingAnotherUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D9E75),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              phoneNumber,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            Text(
              email,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            if (!isViewingAnotherUser)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_note, color: Color(0xFF1D9E75)),
                    label: const Text(
                      "Edit Details",
                      style: TextStyle(
                        color: Color(0xFF1D9E75),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF1D9E75),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 35),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Past Trips",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  if (isViewingAnotherUser)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Trips history is private.",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isHistoryLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF1D9E75),
                        ),
                      ),
                    )
                  else if (historyError.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          historyError,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (tripHistory.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_car_filled_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "No trips yet!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tripHistory.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(tripHistory[index]);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
