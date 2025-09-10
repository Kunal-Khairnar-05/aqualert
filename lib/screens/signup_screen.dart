import 'package:aqualert/services/user_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String phone = '';
  String password = '';
  String age = '';
  String role = 'Citizen';
  final List<String> roles = ['Citizen', 'Fishermen', 'Marine Official'];
  File? _profileImage;
  bool _isLoading = false;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  LatLng? _selectedLatLng;
  String? _selectedAddress;
  bool _isLocating = false;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _selectedLatLng = LatLng(position.latitude, position.longitude);
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _selectedAddress = [place.name, place.locality, place.administrativeArea, place.country].where((e) => e != null && e.isNotEmpty).join(', ');
      } else {
        _selectedAddress = null;
      }
      setState(() {});
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  final UserService _userService = UserService();

  Future<void> _signup() async {

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a profile image.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your location.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Initialize Firebase if not already done
      await Firebase.initializeApp();
      
      // Initialize UserService
      await _userService.initialize();
      
      print('Creating user document...');
      
      // Prepare user profile data
      final userProfileData = {
  'name': name.trim(),
  'email': email.trim().toLowerCase(),
  'password': password, // Note: In production, never store plain text passwords
  'phone': phone.trim(),
  'age': age.trim(),
  'role': role,
  'profileImageUrl': null, // Will be updated after image upload
  'location': _selectedAddress ?? '',
  'latitude': _selectedLatLng?.latitude,
  'longitude': _selectedLatLng?.longitude,
      };
      
      // Create user profile using UserService
      final userId = await _userService.createUserProfile(userProfileData);
      
      print('User document created with ID: $userId');
      
      // Upload profile image to Cloudinary
      print('Starting image upload...');
      String profileImageUrl = await _cloudinaryService
          .uploadUserProfileImage(_profileImage!, userId);
      
      print('Image uploaded successfully: $profileImageUrl');
      
      // Update profile image URL using UserService
      await _userService.updateProfileImageUrl(profileImageUrl);
      
      print('User document updated with profile image URL');
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to main screen
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print('Signup error: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileImage != null 
                        ? FileImage(_profileImage!) 
                        : null,
                    child: _profileImage == null
                        ? const Icon(
                            Icons.camera_alt, 
                            size: 40, 
                            color: Colors.white70,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Location picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAddress != null
                                ? 'Location: $_selectedAddress'
                                : 'No location selected',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: _isLocating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location),
                          tooltip: 'Use current location',
                          onPressed: _isLocating ? null : _getCurrentLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: FlutterMap(
                        options: MapOptions(
                          maxZoom: 5,
                          onTap: (tapPosition, latlng) async {
                            setState(() {
                              _selectedLatLng = latlng;
                              _isLocating = true;
                            });
                            try {
                              List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(latlng.latitude, latlng.longitude);
                              if (placemarks.isNotEmpty) {
                                final place = placemarks.first;
                                _selectedAddress = [place.name, place.locality, place.administrativeArea, place.country].where((e) => e != null && e.isNotEmpty).join(', ');
                              } else {
                                _selectedAddress = null;
                              }
                            } catch (e) {
                              _selectedAddress = null;
                            }
                            setState(() {
                              _isLocating = false;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          if (_selectedLatLng != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _selectedLatLng!,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => 
                      value == null || value.trim().isEmpty ? 'Enter name' : null,
                  onChanged: (value) => name = value,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  onChanged: (value) => email = value,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => 
                      value == null || value.trim().isEmpty ? 'Enter phone number' : null,
                  onChanged: (value) => phone = value,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter age';
                    }
                    final ageInt = int.tryParse(value);
                    if (ageInt == null || ageInt < 1 || ageInt > 120) {
                      return 'Enter a valid age (1-120)';
                    }
                    return null;
                  },
                  onChanged: (value) => age = value,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  items: roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: _isLoading 
                      ? null 
                      : (value) => setState(() => role = value ?? 'Citizen'),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  onChanged: (value) => password = value,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: _isLoading
                      ? ElevatedButton(
                          onPressed: null,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Creating Account...'),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _signup,
                          child: const Text('Sign Up'),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}