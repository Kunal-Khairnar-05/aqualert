import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/user_service.dart'; // Import the UserService

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _location;
  double? _latitude;
  double? _longitude;
  String? _name;
  String? _email;
  String? _phone;
  String? _age;
  String? _role;
  final _formKey = GlobalKey<FormState>();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final UserService _userService = UserService();
  
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isFetching = true);
    try {
      // Initialize UserService
      await _userService.initialize();
      // Get user profile (cache-first strategy)
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null) {
        setState(() {
          _name = userProfile['name'];
          _email = userProfile['email'];
          _phone = userProfile['phone'];
          _age = userProfile['age'];
          _role = userProfile['role'];
          _profileImageUrl = userProfile['profileImageUrl'];
          _location = userProfile['location'];
          _latitude = userProfile['latitude'] is double ? userProfile['latitude'] : (userProfile['latitude'] is num ? (userProfile['latitude'] as num).toDouble() : null);
          _longitude = userProfile['longitude'] is double ? userProfile['longitude'] : (userProfile['longitude'] is num ? (userProfile['longitude'] as num).toDouble() : null);
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _refreshProfile() async {
    setState(() => _isFetching = true);
    try {
      // Force refresh from Firebase
      final userProfile = await _userService.getUserProfile(forceRefresh: true);
      if (userProfile != null) {
        setState(() {
          _name = userProfile['name'];
          _email = userProfile['email'];
          _phone = userProfile['phone'];
          _age = userProfile['age'];
          _role = userProfile['role'];
          _profileImageUrl = userProfile['profileImageUrl'];
          _location = userProfile['location'];
          _latitude =
              userProfile['latitude'] is double
                  ? userProfile['latitude']
                  : (userProfile['latitude'] is num
                      ? (userProfile['latitude'] as num).toDouble()
                      : null);
          _longitude =
              userProfile['longitude'] is double
                  ? userProfile['longitude']
                  : (userProfile['longitude'] is num
                      ? (userProfile['longitude'] as num).toDouble()
                      : null);
        });
      }
    } catch (e) {
      print('Error refreshing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    
    try {
      // Prepare updates
      final updates = {
        'name': _name,
        'email': _email,
        'phone': _phone,
        'age': _age,
        'role': _role,
      };
      
      // Update using UserService
      await _userService.updateUserProfile(updates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh to get latest data
      await _refreshProfile();
      
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        final imageFile = File(pickedFile.path);
        setState(() {
          _profileImage = imageFile;
        });
        
        // Upload immediately after selection
        await _uploadAndSaveProfileImage(imageFile);
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

  Future<void> _uploadAndSaveProfileImage(File imageFile) async {
    setState(() => _isUploadingImage = true);
    
    try {
      final userId = _userService.getCurrentUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      print('Starting image upload for user: $userId');
      
      // Upload to Cloudinary
      String profileImageUrl = await _cloudinaryService
          .uploadUserProfileImage(imageFile, userId);
      
      print('Image uploaded successfully: $profileImageUrl');
      
      // Update local state
      setState(() {
        _profileImageUrl = profileImageUrl;
      });
      
      // Update using UserService
      await _userService.updateProfileImageUrl(profileImageUrl);
      
      print('Profile image URL saved successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('Error uploading profile image: $e');
      
      // Reset the local image if upload failed
      setState(() {
        _profileImage = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _logout() async {
    try {
      await _userService.clearAllUserData();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // void _clearCache() async {
  //   try {
  //     await _userService.clearUserCache();
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Cache cleared successfully!'),
  //         backgroundColor: Colors.blue,
  //       ),
  //     );
  //     await _refreshProfile();
  //   } catch (e) {
  //     print('Error clearing cache: $e');
  //   }
  // }

  String _formatTimeAgo(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile image with loading indicator
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (_profileImageUrl != null 
                                  ? NetworkImage(_profileImageUrl!) 
                                  : null),
                          child: _profileImage == null && _profileImageUrl == null
                              ? const Icon(
                                  Icons.camera_alt, 
                                  size: 40, 
                                  color: Colors.white70,
                                )
                              : null,
                        ),
                        if (_isUploadingImage)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Sync indicator
                        if (_isFetching && !_isUploadingImage)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.sync,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_location != null && _location!.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _location!,
                            style: const TextStyle(fontSize: 14, color: Colors.blue),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (_latitude != null && _longitude != null)
                    Text('Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    _isUploadingImage 
                        ? 'Uploading image...'
                        : _isFetching 
                            ? 'Syncing data...'
                            : 'Tap to change photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isUploadingImage || _isFetching 
                          ? Colors.blue 
                          : Colors.grey[600],
                      fontWeight: _isUploadingImage || _isFetching 
                          ? FontWeight.w500 
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Form fields
                  TextFormField(
                    key: ValueKey('name_${_name ?? ''}'),
                    initialValue: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => 
                        value == null || value.trim().isEmpty ? 'Enter name' : null,
                    onSaved: (value) => _name = value?.trim(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    key: ValueKey('email_${_email ?? ''}'),
                    initialValue: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
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
                    onSaved: (value) => _email = value?.trim(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    key: ValueKey('phone_${_phone ?? ''}'),
                    initialValue: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) => 
                        value == null || value.trim().isEmpty ? 'Enter phone number' : null,
                    onSaved: (value) => _phone = value?.trim(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    key: ValueKey('age_${_age ?? ''}'),
                    initialValue: _age,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter age';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 1 || age > 120) {
                        return 'Enter a valid age (1-120)';
                      }
                      return null;
                    },
                    onSaved: (value) => _age = value?.trim(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    key: ValueKey('role_${_role ?? ''}'),
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    validator: (value) => 
                        value == null || value.trim().isEmpty ? 'Enter role' : null,
                    onSaved: (value) => _role = value?.trim(),
                  ),
                  const SizedBox(height: 32),
                  
                  // Update button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isUploadingImage || _isFetching) 
                          ? null 
                          : _updateProfile,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'Updating...' : 'Update Profile',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Cache info
                  FutureBuilder<Duration?>(
                    future: Future.value(_userService.getCacheAge()),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final cacheAge = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Last synced: ${_formatTimeAgo(cacheAge)} ago',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
             
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}