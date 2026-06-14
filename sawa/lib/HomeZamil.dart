import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeZamil extends StatefulWidget {
  const HomeZamil({Key? key}) : super(key: key);

  @override
  State<HomeZamil> createState() => _HomeZamilState();
}

class _HomeZamilState extends State<HomeZamil> {
  GoogleMapController? mapController;
  Position? _currentLocation;
  int _currentIndex = 0;
  final Color primaryGreen = const Color(0xFF1D9E75);

  bool isLoadingBooking = true;
  Map<String, dynamic>? activeTrip;
  bool isTripStarted = false;
  int remainingMinutes = 0;

  List<LatLng> _fullRouteCoordinates = [];

  Set<Marker> _markers = {};
  Set<Marker> _searchMarkers = {};
  Set<Polyline> _polylines = {};
  Marker? _busMarker;

  final TextEditingController _searchController = TextEditingController();
  final String baseUrl = "http://10.242.103.201:5000";

  IO.Socket? socket;

  bool hasUnreadNotifications = false;
  bool hasUnreadChats = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _getUserLocation();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic idData =
        prefs.get('zamil_id') ?? prefs.get('id') ?? prefs.get('userId');
    String? zamilId = idData?.toString();

    await _fetchUpcomingTrip();

    if (zamilId != null) {
      _checkUnreadNotifications(zamilId);
      _checkUnreadChats(zamilId);
      _initSocket(zamilId);
    }
  }

  Future<void> _checkUnreadNotifications(String zamilId) async {
    try {
      String url = '$baseUrl/api/zamil/notifications/check-unread/$zamilId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            hasUnreadNotifications = data['hasUnread'];
          });
        }
      }
    } catch (e) {
      print("❌ [DEBUG] Error checking notifications: $e");
    }
  }

  Future<void> _checkUnreadChats(String zamilId) async {
    try {
      String url = '$baseUrl/api/zamil/chat/unread-chats/$zamilId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            hasUnreadChats = data['hasUnreadChats'];
          });
        }
      }
    } catch (e) {
      print("💥 [DEBUG] Exception in _checkUnreadChats: $e");
    }
  }

  void _initSocket(String zamilId) {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Zamil connected successfully to Socket.io server');
      socket!.emit('join-personal-room', {'role': 'Zamil', 'id': zamilId});
    });

    socket!.on('trip_completed', (data) {
      if (activeTrip != null &&
          data['trip_id'].toString() == activeTrip!['id'].toString()) {
        if (mounted) {
          setState(() {
            activeTrip = null;
            isTripStarted = false;
            _markers.clear();
            _polylines.clear();
            _busMarker = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "You have reached your destination! Trip Completed.",
              ),
              backgroundColor: Color(0xFF1D9E75),
            ),
          );
        }
      }
    });

    socket!.on('new_message', (_) {
      if (mounted) _checkUnreadChats(zamilId);
    });

    socket!.on('report_status_updated', (_) {
      if (mounted) _checkUnreadNotifications(zamilId);
    });

    socket!.on('notification_read_update', (_) {
      if (mounted) _checkUnreadNotifications(zamilId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Searching..."),
        duration: Duration(seconds: 1),
      ),
    );

    String googleAPiKey = "AIzaSyAyw0YsaMPZnp1-PJs7HqWcac-gofup67Y";
    String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$googleAPiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          LatLng searchLatLng = LatLng(location['lat'], location['lng']);

          setState(() {
            _searchMarkers.clear();
            _searchMarkers.add(
              Marker(
                markerId: const MarkerId('search_result'),
                position: searchLatLng,
                infoWindow: InfoWindow(title: query),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            );
          });

          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(searchLatLng, 14.5),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Location not found!")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching location.")),
      );
    }
  }

  Future<void> _fetchUpcomingTrip() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? zamilEmail =
          prefs.getString('userEmail') ?? prefs.getString('email');

      if (zamilEmail == null) {
        setState(() {
          activeTrip = null;
          isLoadingBooking = false;
        });
        return;
      }

      String apiUrl = "$baseUrl/api/zamil/trips/current-trip?email=$zamilEmail";
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['trip'] != null) {
          var tripData = data['trip'];

          if (mounted) {
            setState(() {
              activeTrip = {
                "id": tripData['trip_id'],
                "from": tripData['departure'],
                "to": tripData['destination'],
                "date": "Today - ${tripData['trip_time']}",
                "duration": "Calculating...",
                "start_lat": tripData['start_lat'],
                "start_lng": tripData['start_lng'],
                "dest_lat": tripData['dest_lat'],
                "dest_lng": tripData['dest_lng'],
                "captain_name": tripData['captain_name'],
                "captain_phone": tripData['captain_phone'],
              };
            });
          }

          await _fetchRealPolyline();
          _startLiveTracking();
        } else {
          if (mounted) {
            setState(() {
              activeTrip = null;
              _polylines.clear();
              _busMarker = null;
              isTripStarted = false;
            });
          }
        }
      } else {
        if (mounted)
          setState(() {
            activeTrip = null;
          });
      }
    } catch (e) {
      print("❌ Error fetching upcoming trip: $e");
      if (mounted)
        setState(() {
          activeTrip = null;
        });
    } finally {
      if (mounted) setState(() => isLoadingBooking = false);
    }
  }

  Future<void> _fetchRealPolyline() async {
    if (activeTrip == null) return;

    double startLat =
        double.tryParse(activeTrip!['start_lat']?.toString() ?? '') ?? 0.0;
    double startLng =
        double.tryParse(activeTrip!['start_lng']?.toString() ?? '') ?? 0.0;
    double destLat =
        double.tryParse(activeTrip!['dest_lat']?.toString() ?? '') ?? 0.0;
    double destLng =
        double.tryParse(activeTrip!['dest_lng']?.toString() ?? '') ?? 0.0;

    if (startLat == 0.0 || startLng == 0.0 || destLat == 0.0 || destLng == 0.0)
      return;

    String googleAPiKey = "AIzaSyAyw0YsaMPZnp1-PJs7HqWcac-gofup67Y";
    PolylinePoints polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleAPiKey,
      request: PolylineRequest(
        origin: PointLatLng(startLat, startLng),
        destination: PointLatLng(destLat, destLng),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      if (mounted) {
        setState(() {
          _fullRouteCoordinates = result.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: _fullRouteCoordinates,
              color: Colors.blueAccent,
              width: 6,
            ),
          );

          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('start'),
              position: LatLng(startLat, startLng),
              infoWindow: InfoWindow(title: activeTrip!['from']),
            ),
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('end'),
              position: LatLng(destLat, destLng),
              infoWindow: InfoWindow(title: activeTrip!['to']),
            ),
          );
        });
      }

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(startLat, startLng), 12.5),
      );
    }
  }

  void _startLiveTracking() {
    if (activeTrip == null || socket == null) return;

    String tripId = activeTrip!['id'].toString();
    double destLat =
        double.tryParse(activeTrip!['dest_lat']?.toString() ?? '') ?? 0.0;
    double destLng =
        double.tryParse(activeTrip!['dest_lng']?.toString() ?? '') ?? 0.0;

    socket!.emit('join-trip', tripId);

    socket!.off('location-updated');

    socket!.on('location-updated', (data) {
      if (data != null && data['lat'] != null && data['lng'] != null) {
        double captainLat = double.parse(data['lat'].toString());
        double captainLng = double.parse(data['lng'].toString());

        int updatedMinutes = remainingMinutes;
        if (destLat != 0.0 && destLng != 0.0) {
          double distance = Geolocator.distanceBetween(
            captainLat,
            captainLng,
            destLat,
            destLng,
          );
          updatedMinutes = (distance / 1000).ceil();
          if (distance < 500) updatedMinutes = 0;
        }

        if (mounted) {
          setState(() {
            isTripStarted = true;
            remainingMinutes = updatedMinutes;
            _busMarker = Marker(
              markerId: const MarkerId('active_bus'),
              position: LatLng(captainLat, captainLng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              anchor: const Offset(0.5, 0.5),
              zIndex: 10,
              infoWindow: InfoWindow(
                title: "${activeTrip!['captain_name']}'s Bus",
              ),
            );
          });
        }
      }
    });
  }

  void _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position userLocation = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => _currentLocation = userLocation);

    if (!isTripStarted && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(userLocation.latitude, userLocation.longitude),
          14.0,
        ),
      );
    }
  }

  void _cancelTrip() async {
    if (activeTrip == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? currentZamilId;
      dynamic idData =
          prefs.get('zamil_id') ?? prefs.get('id') ?? prefs.get('userId');

      if (idData != null) {
        if (idData is int)
          currentZamilId = idData;
        else if (idData is String)
          currentZamilId = int.tryParse(idData);
      }

      if (currentZamilId != null) {
        String tripId = activeTrip!['id'].toString();

        final response = await http.put(
          Uri.parse('$baseUrl/api/zamil/trips/cancel-booking'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"trip_id": tripId, "zamil_id": currentZamilId}),
        );

        Navigator.pop(context);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Booking Cancelled Successfully!"),
                backgroundColor: Colors.red,
              ),
            );

            if (mounted) {
              setState(() {
                activeTrip = null;
                isTripStarted = false;
                _markers.clear();
                _searchMarkers.clear();
                _polylines.clear();
                _busMarker = null;
              });
            }
            _getUserLocation();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? "Error cancelling trip"),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server Error: ${response.statusCode}")),
          );
        }
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Zamil ID not found!")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Network Error!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(33.8938, 35.5018),
              zoom: 12.0,
            ),
            markers: _busMarker != null
                ? {..._markers, ..._searchMarkers, _busMarker!}
                : {..._markers, ..._searchMarkers},
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            trafficEnabled: true,
          ),

          if (!isTripStarted)
            Positioned(
              top: 50,
              left: 15,
              right: 15,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 5),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _searchLocation(value),
                  decoration: InputDecoration(
                    hintText: "Search for an area...",
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: primaryGreen),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchMarkers.clear();
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: 120,
            right: 15,
            child: FloatingActionButton(
              heroTag: "loc_home",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: activeTrip != null ? 0.35 : 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
                ),
                child: RefreshIndicator(
                  color: primaryGreen,
                  onRefresh: () async {
                    setState(() => isLoadingBooking = true);
                    await _fetchUpcomingTrip();
                  },
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isLoadingBooking)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (activeTrip != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isTripStarted
                                  ? "Bus Is En Route 🚌"
                                  : "Your Confirmed Ride Today",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        _TripCard(
                          trip: activeTrip!,
                          themeColor: primaryGreen,
                          isTripStarted: isTripStarted,
                          remainingMinutes: remainingMinutes,
                        ),

                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _cancelTrip,
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            "Cancel Booking",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Welcome to SAWA!",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.refresh,
                                color: primaryGreen,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() => isLoadingBooking = true);
                                _fetchUpcomingTrip();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Where would you like to go today? Intercity transit made easy.",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => context.push('/booking'),
                          child: const Text(
                            "Book a New Ride",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      selectedItemColor: primaryGreen,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        if (i == 1)
          context.push('/chatList');
        else if (i == 2)
          context.push('/booking');
        else if (i == 3)
          context.push('/profile');
        else
          setState(() => _currentIndex = i);
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          label: 'Chat',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline),
              if (hasUnreadChats)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.directions_bus),
          label: 'Bus',
        ),
        BottomNavigationBarItem(
          label: 'Profile',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.person_outline),
              if (hasUnreadNotifications)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final Color themeColor;
  final bool isTripStarted;
  final int remainingMinutes;

  const _TripCard({
    required this.trip,
    required this.themeColor,
    required this.isTripStarted,
    required this.remainingMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${trip['from']} → ${trip['to']}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            if (trip['captain_name'] != null) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: themeColor),
                  const SizedBox(width: 6),
                  Text(
                    "Captain: ${trip['captain_name']}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            Wrap(
              spacing: 15.0,
              runSpacing: 8.0,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month, size: 16, color: themeColor),
                    const SizedBox(width: 4),
                    Text(
                      trip['date'],
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_sharp, size: 16, color: themeColor),
                    const SizedBox(width: 4),
                    Text(
                      isTripStarted
                          ? "$remainingMinutes min to destination"
                          : "Waiting for Captain...",
                      style: TextStyle(
                        color: isTripStarted
                            ? Colors.blueAccent
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
