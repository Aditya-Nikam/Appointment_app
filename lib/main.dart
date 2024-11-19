import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Map Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LocationPermissionScreen(),
    );
  }
}

class LocationPermissionScreen extends StatefulWidget {
  @override
  _LocationPermissionScreenState createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _loading = false;

  Future<void> _requestLocationPermission() async {
    setState(() {
      _loading = true;
    });

    LocationPermission permission;
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _loading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Permission granted, fetch location
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _loading = false;
    });

    // Navigate to MapScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapScreen(userPosition: position),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Location Permission"),
      ),
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _requestLocationPermission,
          child: Text("Request Location Permission"),
        ),
      ),
    );
  }
}
