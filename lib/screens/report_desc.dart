import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:flutter/material.dart';

class ReportDescScreen extends StatefulWidget {
  final String imagePath;
  const ReportDescScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<ReportDescScreen> createState() => _ReportDescScreenState();
}

class _ReportDescScreenState extends State<ReportDescScreen> {

  double? _lat;
  double? _lng;
  String? _address;
  String? _country;
  String? _city;

  // Default registration location (replace with actual user data)
  final double _defaultLat = 50.1247;
  final double _defaultLng = 30.2450;
  final String _defaultAddress = 'Greenvally road, Water City';
  final String _defaultCountry = 'Turkey';
  final String _defaultCity = 'Istanbul';

  @override
  void initState() {
    super.initState();
    // Use default registration location initially
    _setLocation(
      lat: _defaultLat,
      lng: _defaultLng,
      address: _defaultAddress,
      country: _defaultCountry,
      city: _defaultCity,
    );
  }

  void _setLocation({required double lat, required double lng, required String address, required String country, required String city}) {
    setState(() {
      _lat = lat;
      _lng = lng;
      _address = address;
      _country = country;
      _city = city;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      _setLocation(
        lat: position.latitude,
        lng: position.longitude,
        address: place != null ? [place.name, place.locality, place.administrativeArea, place.country].whereType<String>().where((e) => e.isNotEmpty).join(', ') : 'Unknown',
        country: place?.country ?? 'Unknown',
        city: place?.locality ?? 'Unknown',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get current location: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String get _dateString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  String get _timeString {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
  final TextEditingController _descController = TextEditingController();
  String _selectedHazard = 'High Waves';
  final List<String> _hazardTypes = ['High Waves', 'Flooding', 'Debris'];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Aqualert', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Center(
            child: Text(
          'Report Submission',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(widget.imagePath),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_lat != null && _lng != null && _address != null && _country != null && _city != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/pin_img.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(_address!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Row(
                            children: const [
                              Icon(Icons.wb_sunny, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text('Temp: Sunny HOT, 30°', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                          Text('Country ${_country!}, City ${_city!}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text('Lat: ${_lat!.toStringAsFixed(4)}  Lng: ${_lng!.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text('Date: $_dateString  Time: $_timeString', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
                    onPressed: _getCurrentLocation,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.location_pin),
                    label: const Text('Use Default'),
                    onPressed: () {
                      _setLocation(
                        lat: _defaultLat,
                        lng: _defaultLng,
                        address: _defaultAddress,
                        country: _defaultCountry,
                        city: _defaultCity,
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Text('Select Hazard Type', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
          children: _hazardTypes.map((type) {
            final selected = _selectedHazard == type;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
            label: Text(type, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
            selected: selected,
            selectedColor: Colors.blue,
            backgroundColor: Colors.grey[900],
            onSelected: (_) => setState(() => _selectedHazard = type),
              ),
            );
          }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
          hintText: 'Enter details about the hazard...',
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            // TODO: Submit report logic
          },
          child: const Text('Submit Report', style: TextStyle(fontSize: 18,color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
        ],
          ),
        ),
      ),
      );
  }
}
