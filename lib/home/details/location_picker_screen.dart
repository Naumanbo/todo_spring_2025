import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation;
  String? _locationName;
  final TextEditingController _searchController = TextEditingController();
  final String _mapboxAccessToken = 'pk.eyJ1IjoibG93Z2FuMTIzIiwiYSI6ImNsb2hxbjRsdzE2Ymcyam8zbjd2ZDM1dnkifQ.B1nWWfxYH14iftwUR33STQ';

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  Future<void> _searchLocation(String query) async {
    final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$_mapboxAccessToken');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'] != null && data['features'].isNotEmpty) {
        final firstResult = data['features'][0];
        final double lat = firstResult['center'][1];
        final double lng = firstResult['center'][0];
        final String name = firstResult['place_name'];

        setState(() {
          _pickedLocation = LatLng(lat, lng);
          _locationName = name;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to search location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {'location': _pickedLocation, 'name': _locationName});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _searchLocation(_searchController.text);
                    }
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: _pickedLocation ?? LatLng(37.7749, -122.4194), // Default to San Francisco
                zoom: 13.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _pickedLocation = point;
                    _locationName = null; // Clear location name if manually selected
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                  additionalOptions: {
                    'accessToken': _mapboxAccessToken,
                    'id': 'mapbox.streets',
                  },
                ),
                if (_pickedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pickedLocation!,
                        builder: (ctx) => const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}