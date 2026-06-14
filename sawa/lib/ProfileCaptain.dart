import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ProfileCaptain extends StatefulWidget {
  final String? specificCaptainEmail;

  const ProfileCaptain({super.key, this.specificCaptainEmail});

  @override
  State<ProfileCaptain> createState() => _ProfileCaptainState();
}

class _ProfileCaptainState extends State<ProfileCaptain> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgWhite = const Color(0xFFF9F9F9);
  final Color primaryGreen = const Color(0xFF1D9E75);

  final String baseUrl = "http://10.242.103.201:5000";

  int? loggedInUserId;
  int? viewedCaptainId;

  String? _serverBusImageUrl;

  String userName = "Loading...";
  String phoneNumber = "Loading...";
  String email = "";
  String viewerRole = "";

  String busName = "Loading...";
  String busType = "Loading...";
  List<String> busFeatures = [];

  File? _profileImage;
  String? _serverImageUrl;
  final ImagePicker _picker = ImagePicker();

  int unreadNotificationsCount = 0;

  List<dynamic> historyTrips = [];
  bool isLoadingHistory = true;

  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchData();
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io from ProfileCaptain');
      if (viewerRole == 'Captain' && loggedInUserId != null) {
        socket!.emit('join-personal-room', {
          'role': 'Captain',
          'id': loggedInUserId,
        });
      }
    });

    final eventsToListen = [
      'new_booking_notification',
      'notification_read_update',
      'trip_request_approved',
      'trip_request_rejected',
    ];

    for (var event in eventsToListen) {
      socket!.on(event, (_) {
        if (mounted && viewerRole == 'Captain') {
          _fetchUnreadNotificationsCount();
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

  IconData _getFeatureIcon(String feature) {
    String lower = feature.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('a/c') || lower.contains('ac')) return Icons.ac_unit;
    if (lower.contains('usb')) return Icons.usb;
    if (lower.contains('tv')) return Icons.tv;
    if (lower.contains('power')) return Icons.electrical_services;
    if (lower.contains('wheelchair')) return Icons.accessible;
    if (lower.contains('pet')) return Icons.pets;
    if (lower.contains('luggage')) return Icons.luggage;
    return Icons.check_circle_outline;
  }

  Future<void> _loadUserAndFetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('userEmail');
    String? savedRole = prefs.getString('userRole');

    dynamic savedId =
        prefs.get('zamil_id') ?? prefs.get('userId') ?? prefs.get('id');

    setState(() {
      if (savedId != null) {
        loggedInUserId = (savedId is int)
            ? savedId
            : int.tryParse(savedId.toString());
      }
    });

    if (widget.specificCaptainEmail != null &&
        widget.specificCaptainEmail!.isNotEmpty) {
      setState(() {
        email = widget.specificCaptainEmail!;
        viewerRole = savedRole ?? "Zamil";
      });
      _fetchProfileData();
    } else if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        email = savedEmail;
        viewerRole = savedRole ?? "Captain";
      });
      _fetchProfileData();
    } else {
      setState(() {
        userName = "Guest Captain";
        email = "Not Logged In";
        isLoadingHistory = false;
      });
    }

    if (savedRole == 'Captain' &&
        loggedInUserId != null &&
        loggedInUserId != 0) {
      _fetchUnreadNotificationsCount();
      _initSocket();
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/captain/profile/get-data'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data['id'] != null) {
            viewedCaptainId = int.tryParse(data['id'].toString());
          } else if (data['captain_id'] != null) {
            viewedCaptainId = int.tryParse(data['captain_id'].toString());
          }

          userName = data['full_name'] ?? "No Name";
          phoneNumber = data['phone'] ?? "No Phone";
          busName = data['bus_name'] ?? "No Bus Name";
          busType = data['bus_type'] ?? "No Model Info";

          if (data['bus_interior_image'] != null &&
              data['bus_interior_image'].isNotEmpty) {
            _serverBusImageUrl =
                "$baseUrl/${data['bus_interior_image'].replaceAll('\\', '/')}";
          }

          if (data['selfie_image'] != null && data['selfie_image'].isNotEmpty) {
            _serverImageUrl =
                "$baseUrl/${data['selfie_image'].replaceAll('\\', '/')}";
          }

          if (data['features'] != null) {
            busFeatures = (data['features'] is String)
                ? List<String>.from(jsonDecode(data['features']))
                : List<String>.from(data['features']);
          } else {
            busFeatures = [];
          }
        });

        if (viewerRole == 'Captain' && viewedCaptainId != null) {
          _fetchCaptainHistory();
        } else {
          setState(() => isLoadingHistory = false);
        }
      } else {
        setState(() {
          userName = "Captain Not Found";
          phoneNumber = "N/A";
          isLoadingHistory = false;
        });
        _showSnackBar("Profile not found in database.");
      }
    } catch (e) {
      setState(() {
        userName = "Connection Error";
        phoneNumber = "N/A";
        isLoadingHistory = false;
      });
      _showSnackBar("Error fetching data: $e");
    }
  }

  Future<void> _fetchCaptainHistory() async {
    if (viewedCaptainId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/captain/history/get-history/$viewedCaptainId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            historyTrips = data['history'] ?? [];
            isLoadingHistory = false;
          });
        } else {
          setState(() => isLoadingHistory = false);
        }
      } else {
        setState(() => isLoadingHistory = false);
      }
    } catch (e) {
      print("Error fetching history: $e");
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _fetchUnreadNotificationsCount() async {
    if (loggedInUserId == null || loggedInUserId == 0) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/captain/notifications/$loggedInUserId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['notifications'] != null) {
          final List notifications = data['notifications'];

          int unreadCount = notifications.where((n) {
            var isRead = n['is_read'];
            return isRead == false ||
                isRead == 0 ||
                isRead == 'false' ||
                isRead == '0';
          }).length;

          if (mounted) {
            setState(() {
              unreadNotificationsCount = unreadCount;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching notifications count: $e");
    }
  }

  Future<void> _updateProfile(
    String newName,
    String newPhone,
    String newEmail,
    String newBusName,
    String newBusType,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/captain/profile/update-info'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "currentEmail": email,
          "newName": newName,
          "newPhone": newPhone,
          "newEmail": newEmail,
          "newBusName": newBusName,
          "newBusType": newBusType,
          "newFeatures": busFeatures,
        }),
      );

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', newEmail);

        setState(() {
          userName = newName;
          phoneNumber = newPhone;
          email = newEmail;
          busName = newBusName;
          busType = newBusType;
        });
        _showSnackBar("Profile updated successfully!");

        if (viewerRole == 'Captain' && loggedInUserId != null) {
          _fetchUnreadNotificationsCount();
        }
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
        Uri.parse('$baseUrl/api/captain/profile/update-image'),
      );
      request.fields['email'] = email;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _profileImage = imageFile;
          _serverImageUrl =
              "$baseUrl/${data['imagePath'].replaceAll('\\', '/')}";
        });
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
        setState(() {
          _profileImage = selectedImage;
        });
        _uploadImage(selectedImage);
      }
    } catch (e) {
      _showSnackBar("Failed to pick image.");
    }
  }

  Future<void> _uploadBusImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/captain/profile/update-bus-image'),
      );
      request.fields['email'] = email;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        _showSnackBar("Bus photo updated!");
        _fetchProfileData();
      } else {
        _showSnackBar("Failed to upload: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Network Error: $e");
    }
  }

  Future<void> _pickBusImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        File selectedImage = File(pickedFile.path);
        _uploadBusImage(selectedImage);
      }
    } catch (e) {
      _showSnackBar("Failed to pick bus image.");
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: primaryBlue));
  }

  void _showPassengersDialog(List<dynamic> passengers) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.people_alt, color: primaryBlue),
              const SizedBox(width: 10),
              const Text(
                "Trip Passengers",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (passengers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No passengers were on this trip.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: passengers.length,
                      itemBuilder: (context, index) {
                        var zamil = passengers[index];
                        return Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryBlue.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: primaryBlue,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              zamil['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              "Tap to view profile",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              context.push(
                                '/profileZamil',
                                extra: zamil['email'],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(
      text: userName,
    );
    TextEditingController phoneController = TextEditingController(
      text: phoneNumber,
    );
    TextEditingController emailController = TextEditingController(text: email);
    TextEditingController busNameController = TextEditingController(
      text: busName,
    );
    TextEditingController busTypeController = TextEditingController(
      text: busType,
    );

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Update Profile & Bus Info",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                _buildSimpleField(
                  nameController,
                  "Full Name",
                  Icons.person_outline,
                ),
                const SizedBox(height: 15),
                _buildSimpleField(
                  phoneController,
                  "Phone Number",
                  Icons.phone_outlined,
                ),
                const SizedBox(height: 15),
                _buildSimpleField(
                  emailController,
                  "Email Address",
                  Icons.email_outlined,
                ),
                const Divider(height: 30, thickness: 1),
                const Text(
                  "Bus Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 15),
                _buildSimpleField(
                  busNameController,
                  "Bus Name",
                  Icons.directions_bus_outlined,
                ),
                const SizedBox(height: 15),
                _buildSimpleField(
                  busTypeController,
                  "Bus Model/Type",
                  Icons.model_training,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
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
                        busNameController.text,
                        busTypeController.text,
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
          ),
        );
      },
    );
  }

  Widget _buildSimpleField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
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
              ListTile(
                leading: Icon(Icons.camera_alt, color: primaryBlue),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primaryBlue),
                title: const Text('Choose from Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinPrivateGroup(int captainId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic idData =
        prefs.get('userId') ?? prefs.get('zamil_id') ?? prefs.get('id');
    String zamilId = idData.toString();

    if (zamilId == "null") {
      _showSnackBar("Error: User ID not found, please login again.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/zamil/chat/join-private-group'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"zamil_id": zamilId, "captain_id": captainId}),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Joined the group successfully!");
      } else {
        _showSnackBar("Failed to join.");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    }
  }

  Future<void> _showPrivateGroupsList(int captainId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/zamil/chat/captain-private-groups/$captainId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List groups = data['groups'];

      if (groups.isEmpty) {
        _showSnackBar("No private groups available.");
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Select a Group to Join",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var group = groups[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryGreen.withOpacity(0.1),
                              child: Icon(Icons.group, color: primaryGreen),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group['group_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "Private Group",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _performJoin(group['group_id']);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text("Join"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _performJoin(int groupId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    dynamic idData =
        prefs.get('zamil_id') ?? prefs.get('userId') ?? prefs.get('id');

    if (idData == null) {
      _showSnackBar("Error: User ID not found, please login again.");
      return;
    }

    String zamilId = idData.toString();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/zamil/chat/join-private-group'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"zamil_id": zamilId, "group_id": groupId}),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Joined group successfully!");
      } else {
        _showSnackBar("Failed to join.");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    }
  }

  void _showBusImageOptions() {
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
              ListTile(
                leading: Icon(Icons.camera_alt, color: primaryBlue),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickBusImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primaryBlue),
                title: const Text('Choose from Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickBusImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        backgroundColor: bgWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          viewerRole == 'Zamil' ? 'Captain Profile' : 'My Profile',
          style: TextStyle(
            color: primaryBlue,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (viewerRole == 'Captain') ...[
            Badge(
              isLabelVisible: unreadNotificationsCount > 0,
              label: Text(
                '$unreadNotificationsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.redAccent,
              offset: const Offset(-5, 5),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black,
                  size: 28,
                ),
                tooltip: 'Notifications',
                onPressed: () async {
                  setState(() {
                    unreadNotificationsCount = 0;
                  });

                  await context.push('/notifications');

                  _fetchUnreadNotificationsCount();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.report_problem_outlined,
                color: Colors.orangeAccent,
              ),
              onPressed: () {
                context.push(
                  '/reports/Captain',
                  extra: {
                    'name': userName,
                    'email': email,
                    'phone': phoneNumber,
                  },
                );
              },
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: GestureDetector(
                onTap: viewerRole == 'Captain' ? _showImageOptions : null,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: primaryBlue.withOpacity(0.1),
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_serverImageUrl != null
                                    ? NetworkImage(_serverImageUrl!)
                                    : null)
                                as ImageProvider?,
                      child: (_profileImage == null && _serverImageUrl == null)
                          ? Icon(Icons.person, size: 60, color: primaryBlue)
                          : null,
                    ),
                    if (viewerRole == 'Captain')
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryBlue,
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  email,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  phoneNumber,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (viewerRole == 'Captain') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: Icon(Icons.edit, color: primaryBlue, size: 18),
                    label: Text(
                      "Edit Profile",
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBlue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 18,
                    ),
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
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            _buildSectionHeader("Vehicle Information"),
            const SizedBox(height: 12),

            if (_serverBusImageUrl != null)
              Container(
                height: 180,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(_serverBusImageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            _buildInfoCard(
              icon: Icons.directions_bus_filled_outlined,
              title: busName,
              subtitle: busType,
            ),

            if (viewerRole == 'Captain')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: _showBusImageOptions,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("Change Bus Photo"),
                ),
              ),

            const SizedBox(height: 16),

            if (busFeatures.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Verified Bus Features",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: busFeatures.map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryBlue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFeatureIcon(feature),
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            feature,
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 16),

            if (viewerRole == 'Zamil' && viewedCaptainId != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPrivateGroupsList(viewedCaptainId!),
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    label: const Text(
                      "Join Private Group",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader("Trip History"),
            const SizedBox(height: 12),

            if (viewerRole == 'Captain')
              if (isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (historyTrips.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No past trips found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...historyTrips.map((trip) {
                  return GestureDetector(
                    onTap: () =>
                        _showPassengersDialog(trip['passengers'] ?? []),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip['route'] ?? "Unknown Route",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${trip['date']} at ${trip['time']}\n${(trip['passengers'] as List).length} Passengers",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: Colors.grey.shade300,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Trips history is private.",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryBlue, size: 30),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
