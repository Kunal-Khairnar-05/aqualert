import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'package:aqualert/screens/report_desc.dart';

import 'dart:io';

import 'package:camera/camera.dart';


  

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {


  Future<void> _captureImage() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        final image = await _controller!.takePicture();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image.path.isNotEmpty)
                  Image.file(
                    File(image.path),
                    fit: BoxFit.contain,
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportDescScreen(imagePath: image.path),
                          ),
                        );
                      },
                      child: const Text('Submit'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retake'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.isNotEmpty ? cameras.first : null;
    if (camera != null) {
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    final userProfile = userService.getCachedUserProfile();
    final profileImageUrl = userProfile != null ? userProfile['profileImageUrl'] : null;
    final userName = userProfile != null && userProfile['name'] != null && userProfile['name'].toString().isNotEmpty
        ? userProfile['name']
        : 'User';
    final userLocation = userProfile != null && userProfile['location'] != null && userProfile['location'].toString().isNotEmpty
        ? userProfile['location']
        : '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: _controller != null && _initializeControllerFuture != null
                  ? FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller!);
                        } else {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }
                      },
                    )
                  : const Center(child: Icon(Icons.camera_alt, color: Colors.white54, size: 120)),
            ),
            Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 16), // left padding
                  Image.asset('assets/images/aqualert_without_bg.png', height: 48, width: 48),
                   // left padding for symmetry
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          userName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (userLocation.isNotEmpty)
                          Text(
                            userLocation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    child: CircleAvatar(
                      radius: 24,
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                          color: Colors.lightBlueAccent,
                          width: 2.0,
                          ),
                        ),
                        ),
                      backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                    ),
                  ),
                  SizedBox(width: 16), // right padding
                ],
              ),
            ),
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  
                  GestureDetector(
                    onTap: _captureImage,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white10,
                      ),
                      child: const Icon(Icons.camera, color: Colors.white, size: 40),
                    ),
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}