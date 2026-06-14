import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'MakingTripCaptain.dart';

class AvailableTripCaptain extends StatefulWidget {
  const AvailableTripCaptain({super.key});

  @override
  State<AvailableTripCaptain> createState() => _AvailableTripCaptainState();
}

class _AvailableTripCaptainState extends State<AvailableTripCaptain> {
  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgWhite = const Color(0xFFF9F9F9);
  final String baseUrl = "http://10.242.103.201:5000";

  List<dynamic> myTrips = [];
  bool _isLoading = true;

  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    fetchMyTrips(showLoader: true);
    initSocket();
  }

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from AvailableTripCaptain');
    });

    socket.on('seat_booked', (data) {
      if (mounted) fetchMyTrips(showLoader: false);
    });

    socket.on('booking_cancelled', (data) {
      if (mounted) fetchMyTrips(showLoader: false);
    });

    socket.on('trip_updated', (data) {
      if (mounted) fetchMyTrips(showLoader: false);
    });

    socket.on('trip_deleted', (data) {
      if (mounted) fetchMyTrips(showLoader: false);
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> fetchMyTrips({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? captainEmail = prefs.getString('userEmail');

      if (captainEmail == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      var response = await http.get(
        Uri.parse('$baseUrl/api/captain/trips/my-trips?email=$captainEmail'),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              DateTime today = DateTime.now();
              DateTime todayDateOnly = DateTime(
                today.year,
                today.month,
                today.day,
              );

              myTrips = (data['trips'] as List)
                  .where((trip) {
                    try {
                      String dateString = trip['trip_date'].toString().split(
                        'T',
                      )[0];
                      DateTime tripDate = DateTime.parse(dateString);
                      return !tripDate.isBefore(todayDateOnly);
                    } catch (e) {
                      return true;
                    }
                  })
                  .map((trip) {
                    return {
                      'id': trip['id'],
                      'from': trip['departure'],
                      'to': trip['destination'],
                      'meetingPoint': trip['meeting_point'],
                      'dropoffPoint': trip['dropoff_point'],
                      'date': trip['trip_date'].toString().split('T')[0],
                      'time': trip['trip_time'],
                      'duration': trip['duration'],
                      'seats': trip['available_seats'],
                      'price': trip['price'],
                      'status': trip['status'],
                    };
                  })
                  .toList();

              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching trips: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: const Text(
          "My Schedule",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : myTrips.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: myTrips.length,
              itemBuilder: (context, index) {
                return _TripCaptainCard(
                  trip: myTrips[index],
                  themeColor: primaryBlue,
                  onTapCard: () async {
                    final updatedTrip = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MakingTripCaptain(tripData: myTrips[index]),
                      ),
                    );

                    if (updatedTrip != null) {
                      fetchMyTrips(showLoader: true);
                    }
                  },
                  onStartTrip: () {
                    context.push('/homeCaptain', extra: myTrips[index]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Starting trip... Redirecting to Home."),
                        backgroundColor: Color(0xFF185FA5),
                      ),
                    );
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        onPressed: () async {
          final newTrip = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MakingTripCaptain()),
          );

          if (newTrip != null) {
            fetchMyTrips(showLoader: true);
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy, size: 70, color: primaryBlue),
            ),
            const SizedBox(height: 25),
            const Text(
              "No Scheduled Trips",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "You haven't created any trips yet.\nTap the + button below to add your first trip.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCaptainCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Color themeColor;
  final VoidCallback onTapCard;
  final VoidCallback onStartTrip;

  const _TripCaptainCard({
    required this.trip,
    required this.themeColor,
    required this.onTapCard,
    required this.onStartTrip,
  });

  @override
  State<_TripCaptainCard> createState() => _TripCaptainCardState();
}

class _TripCaptainCardState extends State<_TripCaptainCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 18),
        transform: isHovered
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHovered
                ? widget.themeColor.withOpacity(0.5)
                : Colors.grey.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.themeColor.withOpacity(isHovered ? 0.15 : 0.05),
              blurRadius: isHovered ? 25 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTapCard,
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.trip['from']} → ${widget.trip['to']}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: widget.themeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.trip['date'] ?? "N/A",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_sharp,
                                size: 16,
                                color: widget.themeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.trip['duration'] ?? "1h",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.airline_seat_recline_normal,
                                size: 16,
                                color: widget.themeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${widget.trip['seats'] ?? '0'} seats",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 16,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${widget.trip['price'] ?? '0'} LBP",
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onStartTrip,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? widget.themeColor
                          : widget.themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Start",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isHovered ? Colors.white : widget.themeColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.play_arrow,
                          size: 18,
                          color: isHovered ? Colors.white : widget.themeColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
