import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:uuid/uuid.dart';

class CloudinaryService {
  final CloudinaryPublic _cloudinary;
  final Uuid _uuid = const Uuid();
  static const String defaultCloudName = 'dof22v3n1';
  static const String defaultUploadPreset = 'aqualert';

  CloudinaryService({String? cloudName, String? uploadPreset})
      : _cloudinary = CloudinaryPublic(
          cloudName ?? defaultCloudName,
          uploadPreset ?? defaultUploadPreset,
          cache: false,
        );

  Future<String> uploadUserProfileImage(File image, String userId) async {
    final folder = 'users/$userId';
    return uploadImage(image, folder);
  }

  Future<String> uploadImage(File image, String folder) async {
    try {
      // Validate image file
      if (!image.existsSync()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = image.lengthSync();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      // Check if file size is reasonable (e.g., under 10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file is too large (max 10MB)');
      }

      print('Uploading image to Cloudinary folder: $folder');
      print('Image path: ${image.path}');
      print('Image size: $fileSize bytes');

      final uniqueFileName = _uuid.v4();
      print('Generated unique file name: $uniqueFileName');

      final cloudinaryFile = CloudinaryFile.fromFile(
        image.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
        publicId: uniqueFileName, // Use unique filename as public ID
      );

      print('CloudinaryFile created, starting upload...');
      
      final response = await _cloudinary.uploadFile(cloudinaryFile);
      
      if (response.secureUrl.isEmpty) {
        throw Exception('Upload successful but no URL returned');
      }

      print('Upload successful!');
      print('Image URL: ${response.secureUrl}');
      
      return response.secureUrl;
    } catch (e) {
      print('Error in uploadImage: $e');
      // Re-throw the error so calling methods can handle it appropriately
      throw Exception('Failed to upload image to Cloudinary: $e');
    }
  }
}