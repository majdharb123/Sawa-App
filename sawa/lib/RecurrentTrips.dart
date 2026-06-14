import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class RecurrentTripModel {
  final String id;
  final String from;
  final String to;
  final String time;
  final String days;
  final String duration;

  final String priceLbp;
  final String priceUsd;
  final String startDate;
  final String endDate;
  final String minPassengers;
  final String maxPassengers;

  final List<String> stops;
  String status;
  bool isExpanded;

  RecurrentTripModel({
    required this.id,
    required this.from,
    required this.to,
    required this.time,
    required this.days,
    required this.duration,
    required this.priceLbp,
    required this.priceUsd,
    required this.startDate,
    required this.endDate,
    required this.minPassengers,
    required this.maxPassengers,
    required this.stops,
    this.status = 'Available',
    this.isExpanded = false,
  });
}

class RecurrentTrips extends StatefulWidget {
  final String? captainEmail;

  const RecurrentTrips({Key? key, this.captainEmail}) : super(key: key);

  @override
  State<RecurrentTrips> createState() => _RecurrentTripsState();
}

class _RecurrentTripsState extends State<RecurrentTrips> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgLight = const Color(0xFFF4F6F9);

  final String baseUrl = "http://10.242.103.201:5000";

  List<RecurrentTripModel> _trips = [];
  bool _isLoading = true;

  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    _fetchRecurrentTrips(showLoader: true);
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io from RecurrentTrips');
    });

    socket!.on('new_recurrent_route_created', (_) {
      if (mounted) _fetchRecurrentTrips(showLoader: false);
    });

    socket!.on('trip_request_approved', (data) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? captainId = prefs.getInt('captain_id') ?? prefs.getInt('userId');
      if (data['captainId'] == captainId && mounted) {
        _fetchRecurrentTrips(showLoader: false);
      }
    });

    socket!.on('trip_request_rejected', (data) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? captainId = prefs.getInt('captain_id') ?? prefs.getInt('userId');
      if (data['captainId'] == captainId && mounted) {
        _fetchRecurrentTrips(showLoader: false);
      }
    });

    socket!.on('recurrent_routes_expired', (_) {
      if (mounted) _fetchRecurrentTrips(showLoader: false);
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _fetchRecurrentTrips({bool showLoader = true}) async {
    if (showLoader && mounted) setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentEmail = prefs.getString('userEmail');

      if (currentEmail == null) {
        _showSnackBar("Error: Not logged in properly.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/captain/trips/recurrent?email=$currentEmail'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> routesData = data['routes'];

          DateTime today = DateTime.now();
          DateTime todayDateOnly = DateTime(today.year, today.month, today.day);

          final filteredRoutes = routesData.where((route) {
            if (route['end_date'] == null) return true;

            try {
              String endDateStr = route['end_date'].toString().substring(0, 10);
              DateTime endDate = DateTime.parse(endDateStr);
              return !endDate.isBefore(todayDateOnly);
            } catch (e) {
              return true;
            }
          }).toList();

          if (mounted) {
            setState(() {
              _trips = filteredRoutes.map((route) {
                String rawTime = route['departure_time'] ?? "00:00";
                String formattedTime = rawTime;
                if (rawTime.split(':').length >= 2) {
                  formattedTime =
                      "${rawTime.split(':')[0]}:${rawTime.split(':')[1]}";
                }

                var daysData = route['operational_days'];
                String formattedDays = "N/A";
                if (daysData is List) {
                  formattedDays = daysData.join(', ');
                } else if (daysData is String) {
                  formattedDays = daysData.replaceAll(RegExp(r'[\[\]"]'), '');
                }

                String startDate = route['start_date'] != null
                    ? route['start_date'].toString().substring(0, 10)
                    : "N/A";
                String endDate = route['end_date'] != null
                    ? route['end_date'].toString().substring(0, 10)
                    : "Open";

                return RecurrentTripModel(
                  id: route['id'].toString(),
                  from: route['from_city'] ?? "Unknown",
                  to: route['to_city'] ?? "Unknown",
                  time: formattedTime,
                  days: formattedDays,
                  duration: route['estimated_duration'] ?? "N/A",

                  priceLbp: route['price_lbp']?.toString() ?? "0",
                  priceUsd: route['price_usd']?.toString() ?? "0",
                  startDate: startDate,
                  endDate: endDate,
                  minPassengers: route['min_passengers']?.toString() ?? "1",
                  maxPassengers: route['max_passengers']?.toString() ?? "14",

                  stops: List<String>.from(route['stops'] ?? []),
                  status: route['status'] ?? 'Available',
                );
              }).toList();

              _trips.sort((a, b) {
                int getPriority(String status) {
                  String s = status.toLowerCase();
                  if (s == 'active' || s == 'approved') return 0;
                  if (s == 'pending') return 1;
                  if (s == 'rejected') return 2;
                  return 3;
                }

                return getPriority(a.status).compareTo(getPriority(b.status));
              });

              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
          _showSnackBar("Failed to load trips from server.");
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showSnackBar("Server error. Status: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching recurrent trips: $e");
      _showSnackBar("Network Error: Could not connect to the server.");
    }
  }

  void _showPriceAdjustmentDialog(RecurrentTripModel trip) {
    double? parsedPrice = double.tryParse(
      trip.priceLbp.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    String basePrice = parsedPrice != null
        ? parsedPrice.toInt().toString()
        : "0";

    TextEditingController priceController = TextEditingController(
      text: basePrice,
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Adjust Trip Price",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "Admin suggested base price is "),
                        TextSpan(
                          text: "$basePrice LBP (\$${trip.priceUsd})",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ". You can adjust it based on your bus features (AC, WiFi, etc.) before requesting.",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Proposed Price (LBP)",
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF185FA5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF185FA5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (priceController.text.trim().isEmpty) return;
                          setStateDialog(() => isSubmitting = true);

                          await _submitRequest(
                            trip,
                            priceController.text.trim(),
                          );

                          if (context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "Confirm & Request",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRequest(
    RecurrentTripModel trip,
    String proposedPrice,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentEmail = prefs.getString('userEmail');

    if (currentEmail == null) {
      _showSnackBar("Error: Captain email is missing. Please log in again.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/captain/trips/request-route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': currentEmail,
          'routeId': trip.id,
          'proposedPrice': proposedPrice,
        }),
      );

      final data = jsonDecode(response.body);

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data['success'] == true) {
        if (mounted) setState(() => _isLoading = true);
        await _fetchRecurrentTrips(showLoader: true);
        _showSnackBar(
          "Request sent successfully! Waiting for Admin approval.",
          isSuccess: true,
        );
      } else {
        _showSnackBar(data['message'] ?? "Failed to request trip.");
      }
    } catch (e) {
      print("Error submitting route request: $e");
      _showSnackBar("Network Error: Could not send request to server.");
    }
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text(
          'Recurrent Trips',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryBlue),
      ),
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () => _fetchRecurrentTrips(showLoader: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Browse & Request Routes",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose a predefined recurrent trip established by the Admin. Once approved, you become the official Captain for this route.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryBlue))
                  : _trips.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Text(
                            "No official trips available at the moment.",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _trips.length,
                      itemBuilder: (context, index) {
                        return _buildTripCard(_trips[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(RecurrentTripModel trip) {
    bool isPending = trip.status.toLowerCase() == 'pending';
    bool isActive =
        trip.status.toLowerCase() == 'active' ||
        trip.status.toLowerCase() == 'approved';
    bool isRejected = trip.status.toLowerCase() == 'rejected';

    double? tempPrice = double.tryParse(
      trip.priceLbp.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    String displayPriceLbp = tempPrice != null
        ? tempPrice.toInt().toString()
        : "0";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.shade50.withOpacity(0.3)
            : (isRejected ? Colors.red.shade50.withOpacity(0.3) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? Colors.green.shade400
              : (isPending
                    ? Colors.orange.shade300
                    : (isRejected ? Colors.red.shade300 : Colors.white)),
          width: isActive || isRejected ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.green.withOpacity(0.1)
                : (isRejected
                      ? Colors.red.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04)),
            blurRadius: isActive || isRejected ? 25 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(trip.status),
                      Row(
                        children: [
                          if (isActive)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Transform.rotate(
                                angle: 0.5,
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                              ),
                            ),
                          Text(
                            "Trip ID: RT-${trip.id}",
                            style: TextStyle(
                              color: isActive
                                  ? Colors.green.shade700
                                  : (isRejected
                                        ? Colors.red.shade700
                                        : Colors.grey.shade500),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: primaryBlue, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        trip.from,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                      Text(
                        trip.to,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive || isRejected ? Colors.white : bgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(Icons.access_time_rounded, trip.time),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: _buildInfoItem(
                              Icons.calendar_month_rounded,
                              trip.days,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: trip.isExpanded
                  ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withOpacity(0.3),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Trip Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDetailCol(
                                  "Est. Duration",
                                  trip.duration,
                                  Icons.timer_outlined,
                                ),
                              ),
                              Expanded(
                                child: _buildDetailCol(
                                  "Base Price",
                                  "$displayPriceLbp LBP\n\$${trip.priceUsd}",
                                  Icons.payments_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDetailCol(
                                  "Validity Dates",
                                  "${trip.startDate}\nTo: ${trip.endDate}",
                                  Icons.date_range_rounded,
                                ),
                              ),
                              Expanded(
                                child: _buildDetailCol(
                                  "Capacity",
                                  "${trip.minPassengers} - ${trip.maxPassengers} Pax",
                                  Icons.people_alt_outlined,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            "Route Stops",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStopsTimeline(trip.stops),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.shade50.withOpacity(0.5)
                    : (isRejected
                          ? Colors.red.shade50.withOpacity(0.5)
                          : Colors.white),
                border: Border(
                  top: BorderSide(
                    color: isActive
                        ? Colors.green.shade100
                        : (isRejected
                              ? Colors.red.shade100
                              : Colors.grey.shade100),
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        trip.isExpanded = !trip.isExpanded;
                      });
                    },
                    icon: Icon(
                      trip.isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade700,
                    ),
                    label: Text(
                      trip.isExpanded ? "Less" : "Details",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),

                  Flexible(
                    child: ElevatedButton(
                      onPressed: (isPending || isActive)
                          ? null
                          : () => _showPriceAdjustmentDialog(trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRejected
                            ? Colors.red.shade600
                            : primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isActive
                            ? Colors.green.shade600
                            : (isPending
                                  ? Colors.orange.shade400
                                  : Colors.grey),
                        disabledForegroundColor: Colors.white,
                        elevation: (isPending || isActive) ? 0 : 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isActive
                              ? "Approved ✅"
                              : (isPending
                                    ? "Pending..."
                                    : (isRejected
                                          ? "Re-apply 🔄"
                                          : "Request Trip")),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsTimeline(List<String> stops) {
    if (stops.isEmpty) {
      return Text(
        "No specific stops provided.",
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }

    return Column(
      children: stops.asMap().entries.map((entry) {
        int idx = entry.key;
        String stop = entry.value;
        bool isLast = idx == stops.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isLast ? primaryBlue : Colors.white,
                      border: Border.all(color: primaryBlue, width: 3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: primaryBlue.withOpacity(0.3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  stop,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey.shade700,
                    fontWeight: isLast || idx == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCol(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String lowerStatus = status.toLowerCase();
    bool isAvailable = lowerStatus == 'available';
    bool isActive = lowerStatus == 'active' || lowerStatus == 'approved';
    bool isRejected = lowerStatus == 'rejected';

    Color bgColor = Colors.orange.shade50;
    Color borderColor = Colors.orange.shade200;
    Color iconColor = Colors.orange.shade700;
    IconData icon = Icons.hourglass_empty;

    if (isAvailable) {
      bgColor = Colors.blueGrey.shade50;
      borderColor = Colors.blueGrey.shade200;
      iconColor = Colors.blueGrey.shade700;
      icon = Icons.radio_button_unchecked;
    } else if (isActive) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
      icon = Icons.check_circle;
    } else if (isRejected) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      iconColor = Colors.red.shade700;
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            status.isEmpty
                ? ''
                : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}',
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
