import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'TripDetailsZamil.dart'; 

class BookingTripZamil extends StatefulWidget {
  @override
  _BookingTripZamilState createState() => _BookingTripZamilState();
}

class _BookingTripZamilState extends State<BookingTripZamil> {
  final Color sawaGreen = const Color(0xFF1D9E75);
  final String baseUrl = "http://10.242.103.201:5000"; 

  bool isSearching = false;
  bool _isLoading = true;

  TextEditingController searchController = TextEditingController();

  List<dynamic> allTrips = []; 
  List<dynamic> filteredTrips = []; 

  int selectedFilterIndex = 0; 
  
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    fetchAvailableTrips(showLoader: true); 
    initSocket(); 
  }

  void initSocket() {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.io from BookingTripZamil');
    });

    final eventsToListen = [
      'new_trip_available',    
      'trip_updated',          
      'trip_deleted',          
      'seat_booked',           
      'booking_cancelled',     
      'seat_available',        
      'daily_trips_generated'  
    ];

    for (var event in eventsToListen) {
      socket.on(event, (_) {
        if (mounted) {
          fetchAvailableTrips(showLoader: false);
        }
      });
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAvailableTrips({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      var response = await http.get(
        Uri.parse('$baseUrl/api/zamil/trips/available'),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              allTrips = (data['trips'] as List).map((trip) {
                return {
                  'id': trip['id'],
                  'from': trip['departure'],
                  'to': trip['destination'],
                  'meetingPoint': trip['meeting_point'] ?? '',
                  'dropoffPoint': trip['dropoff_point'] ?? '',
                  'date': trip['trip_date'].toString().split('T')[0],
                  'time': trip['trip_time'],
                  'duration': trip['duration'],
                  'seats': trip['available_seats'],
                  'amenities': trip['amenities'],
                  'isRecurrent': trip['recurrent_route_id'] != null && 
                                 trip['recurrent_route_id'].toString() != '0' && 
                                 trip['recurrent_route_id'].toString().trim().isNotEmpty && 
                                 trip['recurrent_route_id'].toString().toLowerCase() != 'null',
                  'captainName': trip['captainName'] ?? trip['captain_name'] ?? 'Unknown Captain',
                  'busName': trip['busName'] ?? trip['bus_name'] ?? 'Sawa Bus',
                  'captainEmail': trip['captainEmail'] ?? trip['email'] ?? '',
                };
              }).toList();

              _filterTrips(); 
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

  void _filterTrips() {
    String searchStr = searchController.text.trim().toLowerCase();

    setState(() {
      filteredTrips = allTrips.where((trip) {
        bool isRecurrent = trip['isRecurrent'] ?? false;
        if (selectedFilterIndex == 1 && isRecurrent) return false; 
        if (selectedFilterIndex == 2 && !isRecurrent) return false; 

        if (searchStr.isEmpty) return true;

        String fromStr = trip['from'].toString().toLowerCase();
        String toStr = trip['to'].toString().toLowerCase();

        if (fromStr.contains(searchStr) || toStr.contains(searchStr)) return true;

        String cleanedSearch = searchStr.replaceAll(RegExp(r'\s+(to|-|la|ila|->)\s+'), ' ');
        List<String> searchWords = cleanedSearch.split(' ')..removeWhere((word) => word.trim().isEmpty);
        String routeStr = "$fromStr $toStr";
        
        return searchWords.every((word) => routeStr.contains(word));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: isSearching
            ? _buildStandardSearchBar()
            : Text(
                "Book your Trip",
                style: TextStyle(
                  color: sawaGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              isSearching ? Icons.close : Icons.search,
              color: sawaGreen,
              size: 28,
            ),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchController.clear();
                  _filterTrips(); 
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: sawaGreen))
          : Column(
              children: [
                _buildFilterTabs(), 
                Expanded(
                  child: filteredTrips.isEmpty
                      ? _buildEmptyState()
                      : _buildTripList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildTabButton(index: 0, title: "All Trips"),
          _buildTabButton(index: 1, title: "Private"),
          _buildTabButton(index: 2, title: "Fixed Lines"),
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required String title}) {
    bool isSelected = selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilterIndex = index;
            _filterTrips(); 
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? sawaGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected
                ? [BoxShadow(color: sawaGreen.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardSearchBar() {
    return TextField(
      controller: searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.black),
      decoration: const InputDecoration(
        hintText: "e.g., Tripoli to Beirut...",
        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
        border: InputBorder.none,
      ),
      onChanged: (value) => _filterTrips(), 
    );
  }

  Widget _buildTripList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      itemCount: filteredTrips.length,
      itemBuilder: (context, index) {
        return _TripCard(trip: filteredTrips[index], themeColor: sawaGreen);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bus_alert, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            selectedFilterIndex == 1 
                ? "No private trips found" 
                : selectedFilterIndex == 2 
                    ? "No fixed lines found" 
                    : "No trips found",
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Color themeColor;

  const _TripCard({required this.trip, required this.themeColor});

  @override
  __TripCardState createState() => __TripCardState();
}

class __TripCardState extends State<_TripCard> {
  bool isHovered = false;
  bool isBookedByMe = false; 

  final String baseUrl = "http://10.167.130.201:5000"; 

  @override
  void initState() {
    super.initState();
    _checkBookingStatus(); 
  }

  Future<void> _checkBookingStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('userId');
      
      if (userId == null) return;

      final url = Uri.parse('$baseUrl/api/zamil/trips/check-booking/${widget.trip['id']}/$userId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isBooked'] == true || data['booked'] == true) {
          if (mounted) {
            setState(() {
              isBookedByMe = true; 
            });
          }
        }
      }
    } catch (e) {
      print("Error checking status for card: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRecurrent = widget.trip['isRecurrent'] ?? false;

    Color cardColor = isBookedByMe ? widget.themeColor : Colors.white;
    Color textColor = isBookedByMe ? Colors.white : Colors.black87;
    Color subTextColor = isBookedByMe ? Colors.white.withOpacity(0.8) : Colors.grey[700]!;
    Color iconColor = isBookedByMe ? Colors.white : widget.themeColor;

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
          color: cardColor, 
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isBookedByMe 
                ? widget.themeColor 
                : (isHovered ? widget.themeColor.withOpacity(0.5) : Colors.grey.withOpacity(0.1)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.themeColor.withOpacity(isHovered ? 0.15 : 0.05),
              blurRadius: isHovered ? 20 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailsZamil(trip: widget.trip),
              ),
            );
            _checkBookingStatus();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${widget.trip['from']} → ${widget.trip['to']}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor, 
                            ),
                          ),
                          if (isRecurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isBookedByMe ? Colors.white.withOpacity(0.2) : widget.themeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.loop, size: 12, color: iconColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Fixed", 
                                    style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            )
                          ],
                          if (isBookedByMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: widget.themeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Booked", 
                                    style: TextStyle(fontSize: 10, color: widget.themeColor, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: iconColor),
                          const SizedBox(width: 6),
                          Text("${widget.trip['date']} - ${widget.trip['time']}", style: TextStyle(color: subTextColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.airline_seat_recline_normal, size: 16, color: iconColor),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.trip['seats']} seats left",
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 20),
                          Icon(Icons.timer_sharp, size: 16, color: iconColor),
                          const SizedBox(width: 6),
                          Text(widget.trip['duration'], style: TextStyle(color: subTextColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBookedByMe 
                        ? Colors.white.withOpacity(0.2) 
                        : (isHovered ? widget.themeColor : widget.themeColor.withOpacity(0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isBookedByMe ? Colors.white : (isHovered ? Colors.white : widget.themeColor),
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