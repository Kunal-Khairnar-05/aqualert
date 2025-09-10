import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class UserService {
  static const String _userDataBoxName = 'userDataBox';
  static const String _userBoxName = 'userBox';
  static const String _userProfileKey = 'userProfile';
  
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  Box? _userDataBox;
  Box? _userBox;

  // Initialize Hive boxes
  Future<void> initialize() async {
    try {
      _userDataBox = await Hive.openBox(_userDataBoxName);
      _userBox = await Hive.openBox(_userBoxName);
    } catch (e) {
      print('Error initializing UserService: $e');
      rethrow;
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _userBox?.get('userId');
  }

  // Save user ID to Hive
  Future<void> saveUserId(String userId) async {
    await _userBox?.put('userId', userId);
  }

  // Get user profile from Hive cache
  Map<String, dynamic>? getCachedUserProfile() {
    final userData = _userDataBox?.get(_userProfileKey);
    if (userData != null && userData is Map) {
      return Map<String, dynamic>.from(userData);
    }
    return null;
  }

  // Save user profile to Hive cache
  Future<void> cacheUserProfile(Map<String, dynamic> userProfile) async {
    userProfile['lastUpdated'] = DateTime.now().toIso8601String();
    await _userDataBox?.put(_userProfileKey, userProfile);
  }

  // Fetch user profile from Firebase
  Future<Map<String, dynamic>?> fetchUserProfileFromFirebase() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'age': data['age'] ?? '',
          'role': data['role'] ?? '',
          'profileImageUrl': data['profileImageUrl'],
        };
      }
      return null;
    } catch (e) {
      print('Error fetching user profile from Firebase: $e');
      rethrow;
    }
  }

  // Get user profile with cache-first strategy
  Future<Map<String, dynamic>?> getUserProfile({bool forceRefresh = false}) async {
    try {
      // Return cached data first if not forcing refresh
      if (!forceRefresh) {
        final cachedProfile = getCachedUserProfile();
        if (cachedProfile != null) {
          // Check if cache is not too old (optional, e.g., 24 hours)
          final lastUpdated = cachedProfile['lastUpdated'];
          if (lastUpdated != null) {
            final updateTime = DateTime.parse(lastUpdated);
            final cacheAge = DateTime.now().difference(updateTime);
            
            // If cache is less than 24 hours old, return it
            if (cacheAge.inHours < 24) {
              return cachedProfile;
            }
          }
        }
      }

      // Fetch fresh data from Firebase
      final freshProfile = await fetchUserProfileFromFirebase();
      if (freshProfile != null) {
        // Cache the fresh data
        await cacheUserProfile(freshProfile);
        return freshProfile;
      }

      // Fallback to cached data if Firebase fails
      return getCachedUserProfile();
    } catch (e) {
      print('Error getting user profile: $e');
      // Return cached data as fallback
      return getCachedUserProfile();
    }
  }

  // Update user profile in Firebase and cache
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Update in Firebase
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updates);

      // Update cache
      final cachedProfile = getCachedUserProfile() ?? {};
      cachedProfile.addAll(updates);
      cachedProfile.remove('updatedAt'); // Remove server timestamp for cache
      await cacheUserProfile(cachedProfile);

    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Update profile image URL
  Future<void> updateProfileImageUrl(String imageUrl) async {
    await updateUserProfile({'profileImageUrl': imageUrl});
  }

  // Clear user cache
  Future<void> clearUserCache() async {
    await _userDataBox?.delete(_userProfileKey);
  }

  // Clear all user data (for logout)
  Future<void> clearAllUserData() async {
    await _userDataBox?.clear();
    await _userBox?.clear();
  }

  // Check if user data exists in cache
  bool hasUserDataInCache() {
    return getCachedUserProfile() != null;
  }

  // Get cache age
  Duration? getCacheAge() {
    final cachedProfile = getCachedUserProfile();
    if (cachedProfile != null) {
      final lastUpdated = cachedProfile['lastUpdated'];
      if (lastUpdated != null) {
        final updateTime = DateTime.parse(lastUpdated);
        return DateTime.now().difference(updateTime);
      }
    }
    return null;
  }

  // Create new user profile
  Future<String> createUserProfile(Map<String, dynamic> userProfile) async {
    try {
      userProfile['createdAt'] = FieldValue.serverTimestamp();
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .add(userProfile);

      // Save user ID
      await saveUserId(docRef.id);
      
      // Cache the profile
      final profileForCache = Map<String, dynamic>.from(userProfile);
      profileForCache.remove('createdAt'); // Remove server timestamp for cache
      await cacheUserProfile(profileForCache);

      return docRef.id;
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Listen to real-time updates (optional)
  Stream<Map<String, dynamic>?> getUserProfileStream() {
    final userId = getCurrentUserId();
    if (userId == null) {
      return Stream.value(null);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final profile = {
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'age': data['age'] ?? '',
          'role': data['role'] ?? '',
          'profileImageUrl': data['profileImageUrl'],
        };
        
        // Update cache in background
        cacheUserProfile(profile);
        
        return profile;
      }
      return null;
    });
  }

  // Dispose resources
  void dispose() {
    // Don't close boxes here as they might be used elsewhere
  }
}