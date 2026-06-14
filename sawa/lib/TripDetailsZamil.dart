import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TripDetailsZamil extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailsZamil({Key? key, required this.trip}) : super(key: key);

  @override
  _TripDetailsZamilState createState() => _TripDetailsZamilState();
}

class _TripDetailsZamilState extends State<TripDetailsZamil> {
  final Color sawaGreen = const Color(0xFF1D9E75);
  TextEditingController noteController = TextEditingController();

  bool isLoading = false;
  bool isBooked = false;
  int? currentZamilId;

  final String baseUrl = "http://10.242.103.201:5000";

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentZamilId = prefs.getInt('userId');
    });

    if (currentZamilId != null) {
      _checkIfAlreadyBooked();
    }
  }

  Future<void> _checkIfAlreadyBooked() async {
    try {
      final url = Uri.parse(
        '$baseUrl/api/zamil/trips/check-booking/${widget.trip['id']}/$currentZamilId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isBooked'] == true || data['booked'] == true) {
          setState(() {
            isBooked = true;
          });
        }
      }
    } catch (e) {
      print("Error checking booking status: $e");
    }
  }

  Future<void> _bookTrip(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);

    if (currentZamilId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Authentication error. Please login again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('$baseUrl/api/zamil/trips/book');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trip_id': widget.trip['id'],
          'zamil_id': currentZamilId,
          'special_request': noteController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        setState(() {
          isBooked = true;
        });
        _showSuccessAlert();
      } else if (response.statusCode == 400) {
        setState(() {
          isBooked = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? "You have already booked this trip!",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Booking failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Trip Details",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteDetails(),
            const SizedBox(height: 25),
            _buildSectionTitle("Captain Details"),
            const SizedBox(height: 10),
            _buildCaptainProfile(),
            const SizedBox(height: 25),
            _buildSectionTitle("Bus Amenities"),
            const SizedBox(height: 10),
            _buildAmenitiesGrid(),
            const SizedBox(height: 25),
            _buildSectionTitle("Special Request (Optional)"),
            const SizedBox(height: 10),
            _buildNoteField(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomBookBar(context),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildRouteDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationColumn(
                city: widget.trip['from'] ?? "Tripoli",
                label: "Departure",
                exactPoint: widget.trip['meetingPoint'] ?? "Not specified",
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 15,
                ),
                child: Icon(Icons.arrow_right_alt, color: sawaGreen, size: 30),
              ),
              _buildLocationColumn(
                city: widget.trip['to'] ?? "Beirut",
                label: "Destination",
                exactPoint: widget.trip['dropoffPoint'] ?? "Not specified",
              ),
            ],
          ),
          Divider(height: 30, color: Colors.grey[200]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: sawaGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "${widget.trip['date']} - ${widget.trip['time']}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.timer_sharp, color: sawaGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.trip['duration'] ?? "1h",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationColumn({
    required String city,
    required String label,
    required String exactPoint,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            city,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: sawaGreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.my_location, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  exactPoint,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainProfile() {
    return GestureDetector(
      onTap: () {
        String targetCaptainEmail = widget.trip['captainEmail'] ?? "";

        if (targetCaptainEmail.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Captain details are currently unavailable."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        context.push('/profileCaptain', extra: targetCaptainEmail);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: sawaGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: sawaGreen.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: sawaGreen.withOpacity(0.2),
              child: Icon(Icons.person, color: sawaGreen, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trip['captainName'] ?? "Captain",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.trip['busName'] ?? "Sawa Bus",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesGrid() {
    List<dynamic> amenities = [];

    var amData =
        widget.trip['amenities'] ??
        widget.trip['bus_amenities'] ??
        widget.trip['busAmenities'] ??
        widget.trip['bus_features'] ??
        widget.trip['features'];

    if (amData != null && amData.toString().trim().isNotEmpty) {
      if (amData is List) {
        amenities = amData;
      } else if (amData is String) {
        try {
          var decoded = jsonDecode(amData);
          if (decoded is List) {
            amenities = decoded;
          } else {
            amenities = [decoded];
          }
        } catch (e) {
          amenities = amData
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    if (amenities.isEmpty) {
      return const Text(
        "No special amenities listed.",
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: amenities.map((amenity) {
        String label = amenity.toString();
        IconData icon = Icons.check_circle_outline;

        if (label.toLowerCase().contains('wifi')) icon = Icons.wifi;
        if (label.toLowerCase().contains('a/c') ||
            label.toLowerCase().contains('ac'))
          icon = Icons.ac_unit;
        if (label.toLowerCase().contains('usb')) icon = Icons.usb;
        if (label.toLowerCase().contains('tv')) icon = Icons.tv;
        if (label.toLowerCase().contains('power'))
          icon = Icons.electrical_services;
        if (label.toLowerCase().contains('wheelchair')) icon = Icons.accessible;
        if (label.toLowerCase().contains('pet')) icon = Icons.pets;
        if (label.toLowerCase().contains('luggage')) icon = Icons.luggage;

        return _buildAmenityChip(icon, label);
      }).toList(),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: sawaGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sawaGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: sawaGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: sawaGreen,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "E.g., Window seat please, or drop me off at City Mall...",
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: sawaGreen),
        ),
      ),
    );
  }

  Widget _buildBottomBookBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isBooked ? Colors.grey[400] : sawaGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: isBooked ? 0 : 2,
          ),
          onPressed: (isLoading || isBooked)
              ? null
              : () => _showPaymentSheet(context),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  isBooked ? "Seat Booked" : "Book Trip",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildPaymentOption(
              title: "Cash on Board",
              subtitle:
                  "Pay directly to ${widget.trip['captainName'] ?? 'the Captain'}",
              icon: Icons.money,
              iconColor: Colors.green,
              onTap: () {
                _bookTrip(sheetContext);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSuccessAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(25),
          title: Column(
            children: [
              Icon(Icons.check_circle, color: sawaGreen, size: 65),
              const SizedBox(height: 15),
              Text(
                "Booking Successful!",
                style: TextStyle(
                  color: sawaGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          content: const Text(
            "Your trip has been booked and the captain is notified.\nEnjoy your ride!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          actions: [
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sawaGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go('/home');
                  },
                  child: const Text(
                    "Track Trip in Home",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
