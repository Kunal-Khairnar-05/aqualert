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

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
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
  bool _obscurePassword = true;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  LatLng? _selectedLatLng;
  String? _selectedAddress;
  bool _isLocating = false;

  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _waveAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

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
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to pick image: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to get location: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a profile image.'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select your location.'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Account created successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Signup failed: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blue.shade200),
      prefixIcon: Icon(icon, color: Colors.blue.shade300),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade800),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade800),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1828), // Deep ocean dark
              Color(0xFF1B2951), // Deeper blue
              Color(0xFF2E5984), // Ocean blue
              Color(0xFF1B2951), // Back to deeper blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo Section
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Image(
                                  image: AssetImage('assets/images/aqualert_without_bg.png'),
                                  fit: BoxFit.contain,
                                ),   
                      ),

                      const SizedBox(height: 20),
                      
                      // App Title
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.blue.shade300,
                            Colors.cyan.shade200,
                            Colors.blue.shade400,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Join AQUALERT',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create Your Marine Safety Account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade200,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Signup Form Container
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Profile Image Section
                            GestureDetector(
                              onTap: _isLoading ? null : _pickImage,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue.shade400,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.grey.shade800,
                                  backgroundImage: _profileImage != null 
                                      ? FileImage(_profileImage!) 
                                      : null,
                                  child: _profileImage == null
                                      ? Icon(
                                          Icons.camera_alt, 
                                          size: 32, 
                                          color: Colors.blue.shade300,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                color: Colors.blue.shade200,
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Location Section
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade800),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.blue.shade300, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedAddress != null
                                              ? 'Location: $_selectedAddress'
                                              : 'No location selected',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _selectedAddress != null 
                                                ? Colors.white 
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: _isLocating
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.blue.shade300,
                                                ),
                                              )
                                            : Icon(Icons.my_location, color: Colors.blue.shade300),
                                        tooltip: 'Use current location',
                                        onPressed: _isLocating ? null : _getCurrentLocation,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 140,
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
                                                  width: 30,
                                                  height: 30,
                                                  point: _selectedLatLng!,
                                                  child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Form Fields
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration('Name', Icons.person_outline),
                              validator: (value) => 
                                  value == null || value.trim().isEmpty ? 'Enter name' : null,
                              onChanged: (value) => name = value,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration('Email', Icons.email_outlined),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                              onChanged: (value) => email = value,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                              keyboardType: TextInputType.phone,
                              validator: (value) => 
                                  value == null || value.trim().isEmpty ? 'Enter phone number' : null,
                              onChanged: (value) => phone = value,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                           TextFormField(
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _buildInputDecoration('Age', Icons.cake_outlined),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter age';
                                      }
                                      final ageInt = int.tryParse(value);
                                      if (ageInt == null || ageInt < 1 || ageInt > 120) {
                                        return 'Enter valid age';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) => age = value,
                                    enabled: !_isLoading,
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                 DropdownButtonFormField<String>(
                                    value: role,
                                    style: const TextStyle(color: Colors.white),
                                    dropdownColor: Colors.grey.shade800,
                                    items: roles
                                        .map((r) => DropdownMenuItem(
                                              value: r, 
                                              child: Text(r, style: const TextStyle(color: Colors.white)),
                                            ))
                                        .toList(),
                                    onChanged: _isLoading 
                                        ? null 
                                        : (value) => setState(() => role = value ?? 'Citizen'),
                                    decoration: _buildInputDecoration('Role', Icons.work_outline),
                                  ),
                                
                            
                            const SizedBox(height: 16),

                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(color: Colors.blue.shade200),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade300),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.blue.shade300,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade800),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade800),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.red.shade400),
                                ),
                              ),
                              obscureText: _obscurePassword,
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
                            const SizedBox(height: 28),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: _isLoading
                                  ? Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue.shade600, Colors.blue.shade800],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Creating Account...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _signup,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.blue.shade600, Colors.blue.shade800],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person_add, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text(
                                                'Create Account',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login Link
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 16),
                            children: [
                              TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(color: Colors.grey.shade300),
                              ),
                              TextSpan(
                                text: "Sign in",
                                style: TextStyle(
                                  color: Colors.blue.shade300,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield, color: Colors.blue.shade300, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Your Safety, Our Priority',
                              style: TextStyle(
                                color: Colors.blue.shade200,
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}