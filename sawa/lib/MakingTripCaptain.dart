import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MakingTripCaptain extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const MakingTripCaptain({Key? key, this.tripData}) : super(key: key);

  @override
  _MakingTripCaptainState createState() => _MakingTripCaptainState();
}

class _MakingTripCaptainState extends State<MakingTripCaptain> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final String baseUrl = "http://10.242.103.201:5000";

  final TextEditingController fromController = TextEditingController();
  final TextEditingController meetingPointController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dropoffPointController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int selectedHours = 1;
  int selectedMinutes = 0;

  final List<int> hourOptions = List.generate(13, (index) => index);
  final List<int> minuteOptions = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];

  bool isReadOnly = false;
  bool showMenu = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.tripData != null) {
      isReadOnly = true;
      showMenu = true;

      fromController.text = widget.tripData!['from']?.toString() ?? '';
      meetingPointController.text =
          widget.tripData!['meetingPoint']?.toString() ?? '';
      toController.text = widget.tripData!['to']?.toString() ?? '';
      dropoffPointController.text =
          widget.tripData!['dropoffPoint']?.toString() ?? '';
      seatsController.text = widget.tripData!['seats']?.toString() ?? '';
      priceController.text = widget.tripData!['price']?.toString() ?? '';

      if (widget.tripData!['duration'] != null) {
        String dur = widget.tripData!['duration'].toString();
        if (dur.contains('h')) {
          selectedHours = int.tryParse(dur.split('h')[0].trim()) ?? 1;
        }
        if (dur.contains('m')) {
          String minStr = dur.split('h').last.replaceAll('m', '').trim();
          selectedMinutes = int.tryParse(minStr) ?? 0;
        }
      }
    }
  }

  @override
  void dispose() {
    fromController.dispose();
    meetingPointController.dispose();
    toController.dispose();
    dropoffPointController.dispose();
    seatsController.dispose();
    priceController.dispose();
    super.dispose();
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
        title: Text(
          showMenu ? "Trip Details" : "Create New Trip",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: showMenu
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'update') {
                      setState(() {
                        isReadOnly = false;
                      });
                    } else if (value == 'delete') {
                      _showDeleteDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    _buildPopupItem(
                      'update',
                      Icons.edit,
                      "Update",
                      const Color(0xFF185FA5),
                    ),
                    _buildPopupItem(
                      'delete',
                      Icons.delete,
                      "Delete",
                      Colors.redAccent,
                    ),
                  ],
                ),
              ]
            : null,
      ),

      body: _isLoading && isReadOnly
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Route Details"),
                  const SizedBox(height: 10),
                  _buildRouteInputs(),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Schedule & Duration"),
                  const SizedBox(height: 10),
                  _buildScheduleInputs(context),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Capacity & Pricing"),
                  const SizedBox(height: 10),
                  _buildCapacityAndPriceInputs(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomSheet: isReadOnly ? null : _buildBottomCreateBar(context),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String text,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: color == Colors.redAccent
                  ? Colors.redAccent
                  : Colors.black,
            ),
          ),
        ],
      ),
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

  Widget _buildRouteInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          _buildInputField(
            controller: fromController,
            label: "Departure City (From)",
            hint: "e.g., Tripoli",
            icon: Icons.location_city,
          ),
          const SizedBox(height: 15),
          _buildInputField(
            controller: meetingPointController,
            label: "Exact Meeting Point",
            hint: "e.g., Al Nour Square",
            icon: Icons.my_location,
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 15),
          _buildInputField(
            controller: toController,
            label: "Destination City (To)",
            hint: "e.g., Beirut",
            icon: Icons.location_city,
          ),
          const SizedBox(height: 15),
          _buildInputField(
            controller: dropoffPointController,
            label: "Exact Drop-off Point",
            hint: "e.g., Dora Highway",
            icon: Icons.location_on,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInputs(BuildContext context) {
    String dateToDisplay = selectedDate != null
        ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
        : (widget.tripData?['date'] ?? "Select Date");
    String timeToDisplay = selectedTime != null
        ? selectedTime!.format(context)
        : (widget.tripData?['time'] ?? "Select Time");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPickerField(
                  label: "Date",
                  value: dateToDisplay,
                  icon: Icons.calendar_month,
                  onTap: isReadOnly ? () {} : () => _selectDate(context),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildPickerField(
                  label: "Time",
                  value: timeToDisplay,
                  icon: Icons.access_time_filled,
                  onTap: isReadOnly ? () {} : () => _selectTime(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Estimated Duration",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDurationDropdown(
                  value: selectedHours,
                  items: hourOptions,
                  label: "Hours",
                  onChanged: isReadOnly
                      ? null
                      : (val) => setState(() => selectedHours = val!),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDurationDropdown(
                  value: selectedMinutes,
                  items: minuteOptions,
                  label: "Mins",
                  onChanged: isReadOnly
                      ? null
                      : (val) => setState(() => selectedMinutes = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityAndPriceInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          _buildInputField(
            controller: seatsController,
            label: "Available Seats",
            hint: "Seats",
            icon: Icons.airline_seat_recline_normal,
            isNumber: true,
          ),
          const SizedBox(height: 15),
          _buildInputField(
            controller: priceController,
            label: "Price per Seat (LBP)",
            hint: "e.g., 250000",
            icon: Icons.payments_outlined,
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              color: isReadOnly ? Colors.grey : primaryBlue,
              size: 20,
            ),
            filled: true,
            fillColor: isReadOnly ? Colors.transparent : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isReadOnly ? Colors.transparent : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isReadOnly ? Colors.grey : primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationDropdown({
    required int value,
    required List<int> items,
    required String label,
    required ValueChanged<int?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.transparent : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items
              .map<DropdownMenuItem<int>>(
                (int val) => DropdownMenuItem<int>(
                  value: val,
                  child: Text("$val $label"),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBottomCreateBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: _isLoading ? null : () => _handlePublishOrUpdate(),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.tripData != null ? "Save Changes" : "Publish Trip",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handlePublishOrUpdate() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        seatsController.text.isEmpty ||
        priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? captainEmail = prefs.getString('userEmail');

      String formattedDate = selectedDate == null
          ? (widget.tripData?['date'] ??
                DateTime.now().toString().split(' ')[0])
          : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

      String formattedTime = selectedTime == null
          ? (widget.tripData?['time'] ?? "08:00 AM")
          : selectedTime!.format(context);

      String googleApiKey = "AIzaSyAyw0YsaMPZnp1-PJs7HqWcac-gofup67Y";
      String startQuery =
          "${meetingPointController.text}, ${fromController.text}, Lebanon";
      String destQuery =
          "${dropoffPointController.text}, ${toController.text}, Lebanon";

      double? startLat, startLng, destLat, destLng;

      var startResponse = await http.get(
        Uri.parse(
          "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(startQuery)}&key=$googleApiKey",
        ),
      );
      var startData = jsonDecode(startResponse.body);
      if (startData['status'] == 'OK' && startData['results'].isNotEmpty) {
        startLat = startData['results'][0]['geometry']['location']['lat'];
        startLng = startData['results'][0]['geometry']['location']['lng'];
      }

      var destResponse = await http.get(
        Uri.parse(
          "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(destQuery)}&key=$googleApiKey",
        ),
      );
      var destData = jsonDecode(destResponse.body);
      if (destData['status'] == 'OK' && destData['results'].isNotEmpty) {
        destLat = destData['results'][0]['geometry']['location']['lat'];
        destLng = destData['results'][0]['geometry']['location']['lng'];
      }

      if (startLat == null || destLat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Warning: Could not fetch exact map coordinates for these locations.",
              style: TextStyle(color: Colors.yellow),
            ),
          ),
        );
      }

      final payloadData = {
        'email': captainEmail,
        'from': fromController.text,
        'to': toController.text,
        'meetingPoint': meetingPointController.text,
        'dropoffPoint': dropoffPointController.text,
        'date': formattedDate,
        'time': formattedTime,
        'duration': "${selectedHours}h ${selectedMinutes}m",
        'seats': seatsController.text.toString(),
        'price': priceController.text.toString(),
        'start_lat': startLat,
        'start_lng': startLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
      };

      var response;
      if (widget.tripData != null) {
        response = await http.put(
          Uri.parse(
            '$baseUrl/api/captain/trips/update/${widget.tripData!['id']}',
          ),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payloadData),
        );
      } else {
        response = await http.post(
          Uri.parse('$baseUrl/api/captain/trips/create'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payloadData),
        );
      }

      var data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSuccessAlert(tripDataToPassBack: payloadData);
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['message'] ?? "Schedule conflict!",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Error occurred")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Network Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Delete Trip"),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this trip? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _executeDeleteTrip();
            },
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

  Future<void> _executeDeleteTrip() async {
    if (widget.tripData == null || widget.tripData!['id'] == null) return;

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? captainEmail = prefs.getString('userEmail');

      if (captainEmail != null) {
        final tripId = widget.tripData!['id'];
        final response = await http.delete(
          Uri.parse(
            '$baseUrl/api/captain/trips/delete/$tripId?email=$captainEmail',
          ),
        );

        var data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trip deleted successfully!"),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pop(context, 'deleted');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Failed to delete trip."),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Network Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessAlert({Map<String, dynamic>? tripDataToPassBack}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: const Text(
          "Trip Published Successfully!",
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, tripDataToPassBack);
              },
              child: const Text("Back to Dashboard"),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }
}
