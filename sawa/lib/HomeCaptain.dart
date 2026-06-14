import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeCaptain extends StatefulWidget {
  const HomeCaptain({Key? key}) : super(key: key);

  @override
  State<HomeCaptain> createState() => _HomeCaptainState();
}

class _HomeCaptainState extends State<HomeCaptain> {
  GoogleMapController? mapController;
  Position? _currentLocation;
  int _currentIndex = 0;

  final Color primaryBlue = const Color(0xFF185FA5);
  final Color lightBlueBg = const Color(0xFFE3F2FD);

  bool isTripStarted = false;
  int remainingMinutes = 0;
  Timer? _trackingTimer;

  List<LatLng> _fullRouteCoordinates = [];

  Set<Marker> _markers = {};
  Set<Marker> _searchMarkers = {};
  Set<Polyline> _polylines = {};
  Marker? _busMarker;

  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? nextTrip;
  bool isLoadingTrip = true;
  final String baseUrl = "http://10.242.103.201:5000";

  IO.Socket? socket;

  bool hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _getUserLocation();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? captainId =
        prefs.getInt('captain_id')?.toString() ??
        prefs.getInt('userId')?.toString() ??
        prefs.getString('userId');

    _fetchNextTrip();
    _checkUnreadNotifications(captainId);

    if (captainId != null) {
      _initSocket(captainId);
    }
  }

  Future<void> _checkUnreadNotifications(String? captainId) async {
    try {
      if (captainId == null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        captainId =
            prefs.getInt('captain_id')?.toString() ??
            prefs.getInt('userId')?.toString() ??
            prefs.getString('userId');
      }

      if (captainId != null) {
        String url =
            '$baseUrl/api/captain/notifications/check-unread/$captainId';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          if (data['success'] == true && mounted) {
            setState(() {
              hasUnreadNotifications = data['hasUnread'];
            });
          }
        }
      }
    } catch (e) {
      print("❌ [DEBUG] Error checking notifications: $e");
    }
  }

  void _initSocket(String captainId) {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.io Server from HomeCaptain');
      socket!.emit('join-personal-room', {'role': 'Captain', 'id': captainId});
    });

    socket!.on('new_booking_notification', (_) {
      if (mounted) {
        _checkUnreadNotifications(captainId);
        _fetchNextTrip();
      }
    });

    socket!.on('notification_read_update', (_) {
      if (mounted) _checkUnreadNotifications(captainId);
    });

    socket!.on('booking_cancelled', (_) {
      if (mounted) _fetchNextTrip();
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _searchController.dispose();
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Searching..."),
        backgroundColor: primaryBlue,
        duration: const Duration(seconds: 1),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location not found!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error searching location."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchNextTrip() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? captainEmail = prefs.getString('userEmail');

      if (captainEmail != null) {
        final response = await http.get(
          Uri.parse('$baseUrl/api/captain/trips/next-trip?email=$captainEmail'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] && data['trip'] != null) {
            if (mounted) {
              setState(() {
                nextTrip = data['trip'];
              });
            }
            await _fetchRealPolyline();
          } else {
            if (mounted) {
              setState(() {
                nextTrip = null;
                _polylines.clear();
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching next trip: $e");
    } finally {
      if (mounted) setState(() => isLoadingTrip = false);
    }
  }

  Future<void> _fetchRealPolyline() async {
    if (nextTrip == null) return;

    double startLat =
        double.tryParse(nextTrip!['start_lat']?.toString() ?? '') ?? 0.0;
    double startLng =
        double.tryParse(nextTrip!['start_lng']?.toString() ?? '') ?? 0.0;
    double destLat =
        double.tryParse(nextTrip!['dest_lat']?.toString() ?? '') ?? 0.0;
    double destLng =
        double.tryParse(nextTrip!['dest_lng']?.toString() ?? '') ?? 0.0;

    if (startLat == 0.0 ||
        startLng == 0.0 ||
        destLat == 0.0 ||
        destLng == 0.0) {
      print("❌ Missing coordinates in database for this trip.");
      return;
    }

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
              color: primaryBlue,
              width: 6,
            ),
          );
        });
      }
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(startLat, startLng), 14.0),
      );
    } else {
      print("Polyline Error: ${result.errorMessage}");
    }
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
    if (mounted) {
      setState(() => _currentLocation = userLocation);
    }

    if (!isTripStarted && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(userLocation.latitude, userLocation.longitude),
          15.0,
        ),
      );
    }
  }

  void _startTripNavigation() {
    if (nextTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No upcoming trips to start!")),
      );
      return;
    }

    String tripId = nextTrip!['id'].toString();

    double destLat =
        double.tryParse(nextTrip!['dest_lat']?.toString() ?? '') ?? 0.0;
    double destLng =
        double.tryParse(nextTrip!['dest_lng']?.toString() ?? '') ?? 0.0;

    if (_currentLocation != null && destLat != 0.0 && destLng != 0.0) {
      double initialDistance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        destLat,
        destLng,
      );
      remainingMinutes = (initialDistance / 1000).ceil();
      if (initialDistance < 500) remainingMinutes = 0;
    }

    setState(() {
      isTripStarted = true;
    });

    socket?.emit('join-trip', tripId);
    print("📡 Joined Trip Room: trip_$tripId");

    _trackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        Position currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        socket?.emit('send-location', {
          'trip_id': tripId,
          'lat': currentPos.latitude,
          'lng': currentPos.longitude,
        });

        int updatedMinutes = remainingMinutes;
        if (destLat != 0.0 && destLng != 0.0) {
          double distanceInMeters = Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            destLat,
            destLng,
          );

          updatedMinutes = (distanceInMeters / 1000).ceil();
          if (distanceInMeters < 500) {
            updatedMinutes = 0;
          }
        }

        if (mounted) {
          setState(() {
            remainingMinutes = updatedMinutes;
            _busMarker = Marker(
              markerId: const MarkerId('active_bus'),
              position: LatLng(currentPos.latitude, currentPos.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              anchor: const Offset(0.5, 0.5),
              zIndex: 5,
            );
          });
        }

        mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(currentPos.latitude, currentPos.longitude),
          ),
        );
      } catch (e) {
        print("Error getting GPS location: $e");
      }
    });
  }

  void _finishTrip() async {
    _trackingTimer?.cancel();

    if (nextTrip != null) {
      try {
        String tripId = nextTrip!['id'].toString();
        final response = await http.put(
          Uri.parse('$baseUrl/api/captain/trips/complete/$tripId'),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200) {
          print("✅ Trip Completed successfully in Database.");
          socket?.emit('trip_completed', {'trip_id': tripId});
        } else {
          print("⚠️ Failed to complete trip in DB: ${response.body}");
        }
      } catch (e) {
        print("❌ Error calling complete API: $e");
      }
    }

    setState(() {
      isTripStarted = false;
      _markers.clear();
      _searchMarkers.clear();
      _polylines.clear();
      _busMarker = null;
      isLoadingTrip = true;
      nextTrip = null;
    });

    await _fetchNextTrip();
    _getUserLocation();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Trip Completed successfully!"),
        backgroundColor: primaryBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(34.4346, 35.8362),
              zoom: 14.0,
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
                padding: const EdgeInsets.symmetric(horizontal: 15),
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
                    hintText: 'Search for routes or stations...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: primaryBlue),
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
            bottom: MediaQuery.of(context).size.height * 0.40,
            right: 20,
            child: FloatingActionButton(
              heroTag: "loc_cap",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: Icon(Icons.my_location, color: primaryBlue),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
                ),
                child: RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: () async {
                    setState(() => isLoadingTrip = true);
                    await _fetchNextTrip();
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                isTripStarted
                                    ? "Navigating..."
                                    : "Next Trip Schedule",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!isTripStarted)
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: primaryBlue,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() => isLoadingTrip = true);
                                    _fetchNextTrip();
                                  },
                                ),
                            ],
                          ),
                          if (!isTripStarted && nextTrip != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${nextTrip!['passenger_count'] ?? 0} Passengers",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildTripCard(),
                      if (isTripStarted) ...[
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _finishTrip,
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Complete Trip",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildTripCard() {
    if (isLoadingTrip) return const Center(child: CircularProgressIndicator());
    if (nextTrip == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            "No upcoming trips today.",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    String from = nextTrip!['departure'] ?? nextTrip!['from_city'] ?? "Unknown";
    String to = nextTrip!['destination'] ?? nextTrip!['to_city'] ?? "Unknown";
    String time =
        nextTrip!['trip_time'] ?? nextTrip!['departure_time'] ?? "Unknown";
    bool isRecurrent = nextTrip!['is_recurrent'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "$from → $to",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isRecurrent) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.loop, size: 16, color: primaryBlue),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isTripStarted
                      ? "$remainingMinutes min to arrival"
                      : "Departure: $time",
                  style: TextStyle(
                    color: isTripStarted ? primaryBlue : Colors.grey,
                    fontWeight: isTripStarted
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!isTripStarted)
            GestureDetector(
              onTap: _startTripNavigation,
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: 0.785,
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      selectedItemColor: primaryBlue,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        if (i == 1) {
          context.push('/availableTripCaptain');
        } else if (i == 2) {
          context.push('/recurrentTrips');
        } else if (i == 3) {
          context.push('/groupCaptain');
        } else if (i == 4) {
          context.push('/profileCaptain');
        } else {
          setState(() => _currentIndex = i);
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.departure_board),
          label: 'My Trips',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.route),
          label: 'Fixed Lines',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chats',
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
