import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  final Position userPosition;
  MapScreen({required this.userPosition});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];
  List<Destination> _destinations = [];
  List<LatLng> _pathPoints = [];
  double? roadDistanceToTappedPoint;

  final Distance distance = Distance(); // For calculating distances
  final double selectionRadius = 100.0; // Radius in meters

  @override
  void initState() {
    super.initState();
    _fetchShopsAndAddMarkers();

    // Add the user's location marker
    _markers.add(
      Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(widget.userPosition.latitude, widget.userPosition.longitude),
        builder: (ctx) => Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }



  Future<void> _fetchShopsAndAddMarkers() async {
    final url = Uri.parse("https://my-service-xcbx.onrender.com/getShops");
    final headers = {"Content-Type": "application/json"};
    final body = json.encode({
      "lat": widget.userPosition.latitude,
      "long": widget.userPosition.longitude,
      "radius": 500,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);

        // Iterate over the list and add destination markers
        for (var shop in jsonResponse) {
          final double latitude = double.parse(shop["latitude"].toString());
          final double longitude = double.parse(shop["longitude"].toString());
          final String shopName = shop["shopName"] ?? "Unknown Shop";

          setState(() {
            _destinations.add(Destination(
              shopName: shopName, // Shop name from API
              location: LatLng(latitude, longitude), // Shop location from API
            ));
            _markers.add(
              Marker(
                width: 120.0, // Adjusted for the label
                height: 80.0,
                point: LatLng(latitude, longitude),
                builder: (ctx) => Column(
                  children: [
                    Text(
                      shopName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ],
                ),
              ),
            );
          });
        }
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred: $e");
    }
  }

  Future<void> _getRouteAndDistance(
      double startLat, double startLon, double endLat, double endLon) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0];
      final distance = route['distance'] / 1000; // Convert to km
      final geometry = route['geometry']['coordinates'];

      setState(() {
        roadDistanceToTappedPoint = distance;
        _pathPoints = geometry.map<LatLng>((point) => LatLng(point[1], point[0])).toList();
      });
    } else {
      print("Failed to fetch route");
    }
  }

  void _onTap(LatLng tappedPoint) async {
    Destination? nearestPoint;
    double nearestDistance = double.infinity;

    // Find the nearest marker within the selection radius
    for (var destination in _destinations) {
      double currentDistance = distance.as(
        LengthUnit.Meter,
        tappedPoint,
        destination.location,
      );
      if (currentDistance < nearestDistance && currentDistance <= selectionRadius) {
        nearestDistance = currentDistance;
        nearestPoint = destination;
      }
    }

    if (nearestPoint != null) {
      print('Nearest Shop: ${nearestPoint.shopName}, Distance: ${nearestDistance.toStringAsFixed(2)} meters');

      // Update the route and markers
      await _getRouteAndDistance(
        widget.userPosition.latitude,
        widget.userPosition.longitude,
        nearestPoint.location.latitude,
        nearestPoint.location.longitude,
      );

      setState(() {
        _markers = [
          Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(widget.userPosition.latitude, widget.userPosition.longitude),
            builder: (ctx) => Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
          ),
        ];

        for (var destination in _destinations) {
          _markers.add(
            Marker(
              width: 120.0,
              height: 80.0,
              point: destination.location,
              builder: (ctx) => Column(
                children: [
                  Text(
                    destination.shopName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: destination == nearestPoint ? Colors.green : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Icon(
                    Icons.location_on,
                    color: destination == nearestPoint ? Colors.green : Colors.red,
                    size: 40,
                  ),
                ],
              ),
            ),
          );
        }
      });
    } else {
      print('No marker found within 100 meters of the tapped point.');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Map with Shop Markers"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: LatLng(
                widget.userPosition.latitude,
                widget.userPosition.longitude,
              ),
              zoom: 14.0,
              onTap: (_, tappedPoint) => _onTap(tappedPoint), // Handle map taps
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _markers,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _pathPoints,
                    strokeWidth: 4.0,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Text(
              "© OpenStreetMap contributors",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
          if (roadDistanceToTappedPoint != null)
            Positioned(
              bottom: 30,
              left: 10,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(8),
                child: Text(
                  "Road distance to tapped point: ${roadDistanceToTappedPoint!.toStringAsFixed(2)} km",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class Destination {
  final String shopName;
  final LatLng location;

  Destination({required this.shopName, required this.location});
}

