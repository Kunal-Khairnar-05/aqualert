import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ReportDescScreen extends StatefulWidget {
  final String imagePath;
  const ReportDescScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<ReportDescScreen> createState() => _ReportDescScreenState();
}

class _ReportDescScreenState extends State<ReportDescScreen> {
  Map<String, dynamic>? _finalReportJson;
  Map<String, dynamic>? _mlkitResult;
  bool _isMLKitLoading = false;

  final TextEditingController _descController = TextEditingController();
  String _selectedHazard = 'High Waves';
  final List<String> _hazardTypes = [
    'High Waves',
    'Flooding',
    'Debris',
    'Oil Spill',
  ];

  // ML Kit related variables
  List<ImageLabel>? _labels;
  Map<String, bool?> _userAnswers = {};
  bool _showQuestions = false;
  bool _showConfirm = false;
  String? _finalHazard;
  double? _finalScore;
  String? _userHazard;

  final Map<String, String> _labelToHazard = {
    'wave': 'High Waves',
    'flood': 'Flooding',
    'debris': 'Debris',
    'oil': 'Oil Spill',
    'water': 'High Waves',
    'sea': 'High Waves',
    'ocean': 'High Waves',
    'storm': 'High Waves',
    'rain': 'Flooding',
    'wet': 'Flooding',
    'pollution': 'Oil Spill',
    'waste': 'Debris',
    'trash': 'Debris',
    'garbage': 'Debris',
  };

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
    _setLocation(
      lat: _defaultLat,
      lng: _defaultLng,
      address: _defaultAddress,
      country: _defaultCountry,
      city: _defaultCity,
    );
    _runMLKitAnalysis();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _runMLKitAnalysis() async {
    setState(() => _isMLKitLoading = true);
    
    try {
      final file = File(widget.imagePath);
      final inputImage = InputImage.fromFile(file);
      
      // Use ML Kit base model
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
      final imageLabeler = ImageLabeler(options: options);
      final labels = await imageLabeler.processImage(inputImage);
      imageLabeler.close();

      // Check for hazard types in labels
      Map<String, bool?> userAnswers = {};
      for (final l in labels.take(10)) {
        final lower = l.label.toLowerCase();
        _labelToHazard.forEach((key, hazard) {
          if (lower.contains(key)) {
            userAnswers[hazard] = null;
          }
        });
      }

      // For testing purposes, always show questions if no hazards detected
      if (userAnswers.isEmpty) {
        userAnswers = {
          'High Waves': null,
          'Flooding': null,
          'Debris': null,
          'Oil Spill': null,
        };
      }

      // Compose ML Kit metadata
      _mlkitResult = {
        "labels": labels
            .map(
              (l) => {
                "label": l.label,
                "confidence": l.confidence,
                "index": l.index,
              },
            )
            .toList(),
        "detected_hazards": userAnswers.keys.where((k) => userAnswers[k] == null).toList(),
        "timestamp": DateTime.now().toIso8601String(),
      };

      setState(() {
        _labels = labels;
        _isMLKitLoading = false;
        _showQuestions = true;
        _userAnswers = userAnswers;
      });
    } catch (e) {
      setState(() {
        _mlkitResult = {"error": e.toString()};
        _isMLKitLoading = false;
      });
    }
  }

  void _onQuestionsSubmit() {
    // Process user answers and determine final hazard
    Map<String, int> hazardCounts = {};
    
    _userAnswers.forEach((hazard, answer) {
      if (answer == true) {
        hazardCounts[hazard] = (hazardCounts[hazard] ?? 0) + 1;
      }
    });

    if (hazardCounts.isNotEmpty) {
      // Find hazard with highest user confirmation
      String topHazard = hazardCounts.keys.first;
      int maxCount = hazardCounts[topHazard] ?? 0;
      
      hazardCounts.forEach((hazard, count) {
        if (count > maxCount) {
          topHazard = hazard;
          maxCount = count;
        }
      });

      _finalHazard = topHazard;
      _finalScore = 0.65 + (0.30 * (DateTime.now().millisecondsSinceEpoch % 100) / 100); // Random confidence between 0.65-0.95
      _selectedHazard = topHazard; // Update the selected hazard
    }

    setState(() {
      _showQuestions = false;
      _showConfirm = true;
    });
  }

  void _onFinalConfirm(String? hazardType) {
    if (hazardType != null) {
      setState(() {
        _selectedHazard = hazardType;
        _showConfirm = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hazard "$hazardType" has been confirmed.')),
      );
    }
  }

  void _setLocation({
    required double lat,
    required double lng,
    required String address,
    required String country,
    required String city,
  }) {
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
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      _setLocation(
        lat: position.latitude,
        lng: position.longitude,
        address:
            place != null
                ? [
                  place.name,
                  place.locality,
                  place.administrativeArea,
                  place.country,
                ].whereType<String>().where((e) => e.isNotEmpty).join(', ')
                : 'Unknown',
        country: place?.country ?? 'Unknown',
        city: place?.locality ?? 'Unknown',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    // Build metadata JSON
    final Map<String, dynamic> reportMeta = {
      "mlkit_analysis": _mlkitResult,
      "user_report": {
        "hazard_type": _selectedHazard,
        "description": _descController.text,
        "location": {
          "lat": _lat,
          "lng": _lng,
          "address": _address,
          "country": _country,
          "city": _city,
        },
        "datetime": DateTime.now().toIso8601String(),
      },
      "ml_confirmation": {
        "final_hazard": _finalHazard,
        "confidence_score": _finalScore,
        "user_answers": _userAnswers,
      }
    };

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                try {
                  final file = File(widget.imagePath);
                  final fileStat = await file.stat();
                  final now = DateTime.now();
                  
                  // Compose the result JSON
                  _finalReportJson = {
                    "hazard": _finalHazard ?? _selectedHazard,
                    "intensity": "Medium", // You can derive this from confidence
                    "confidence": _finalScore ?? 0.5,
                    "location":
                        _lat != null && _lng != null
                            ? "${_lat!.toStringAsFixed(4)},${_lng!.toStringAsFixed(4)}"
                            : null,
                    "timestamp": now.toUtc().toIso8601String(),
                    "extracted_text": "Danger", // Placeholder
                    "image_metadata": {
                      "file_size": fileStat.size,
                      "capture_time": fileStat.modified.toUtc().toIso8601String(),
                    },
                    "device_info": {
                      "app_version": "1.0.0",
                      "model_version": "MLKit_v1.0",
                    },
                    "mlkit_labels": _labels?.map((l) => {
                      "label": l.label,
                      "confidence": l.confidence,
                    }).toList(),
                    "user_confirmation": {
                      "confirmed_hazard": _selectedHazard,
                      "description": _descController.text,
                      "user_answers": _userAnswers,
                    }
                  };
                  
                  // Print to terminal
                  print("=== Report Submitted ===");
                  print(
                    const JsonEncoder.withIndent('  ').convert(_finalReportJson),
                  );
                  
                  // Show visual confirmation
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print("Error submitting report: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error submitting report: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Submit Report',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                if (_lat != null &&
                    _lng != null &&
                    _address != null &&
                    _country != null &&
                    _city != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_pin,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _address!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: const [
                              Icon(
                                Icons.wb_sunny,
                                color: Colors.amber,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Temp: Sunny HOT, 30°',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Country ${_country!}, City ${_city!}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Lat: ${_lat!.toStringAsFixed(4)}  Lng: ${_lng!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Date: $_dateString  Time: $_timeString',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
            
            // ML Kit Analysis Section
            if (_isMLKitLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_mlkitResult != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AI Results:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Confidence > 0.5',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filtered: ${_mlkitResult!['high_confidence_labels']} of ${_mlkitResult!['total_labels']} labels accepted',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(reportMeta),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Questions Section
            if (_showQuestions)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please verify what you see in this image:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(_userAnswers.isEmpty ? _hazardTypes : _userAnswers.keys.toList())
                        .map((hazard) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade600),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Do you see $hazard in this image?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: _userAnswers[hazard],
                                        onChanged: (val) {
                                          setState(() {
                                            if (_userAnswers.isEmpty) {
                                              for (String h in _hazardTypes) {
                                                _userAnswers[h] = null;
                                              }
                                            }
                                            _userAnswers[hazard] = val;
                                          });
                                        },
                                      ),
                                      const Text('Yes', style: TextStyle(color: Colors.white)),
                                      const SizedBox(width: 20),
                                      Radio<bool>(
                                        value: false,
                                        groupValue: _userAnswers[hazard],
                                        onChanged: (val) {
                                          setState(() {
                                            if (_userAnswers.isEmpty) {
                                              for (String h in _hazardTypes) {
                                                _userAnswers[h] = null;
                                              }
                                            }
                                            _userAnswers[hazard] = val;
                                          });
                                        },
                                      ),
                                      const Text('No', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _userAnswers.values.any((v) => v != null) 
                            ? _onQuestionsSubmit 
                            : null,
                        child: const Text('Continue Analysis'),
                      ),
                    ),
                  ],
                ),
              ),

            // Confirmation Section
            if (_showConfirm)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Suggestion:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_finalHazard != null)
                      Text(
                        'Detected Hazard: $_finalHazard (Confidence: ${(_finalScore ?? 0) * 100}%)',
                        style: const TextStyle(color: Colors.white),
                      ),
                    if (_finalHazard == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No clear agreement. Please select the correct hazard type:',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _userHazard,
                            dropdownColor: Colors.grey[800],
                            items: _hazardTypes
                                .map((hazard) => DropdownMenuItem(
                                      value: hazard,
                                      child: Text(hazard, style: const TextStyle(color: Colors.white)),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _userHazard = val),
                            decoration: const InputDecoration(
                              labelText: 'Select Hazard Type',
                              labelStyle: TextStyle(color: Colors.white),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: (_finalHazard != null || _userHazard != null)
                            ? () => _onFinalConfirm(_finalHazard ?? _userHazard)
                            : null,
                        child: const Text('Confirm Hazard', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

            const Text(
              'Select Hazard Type',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _hazardTypes.map((type) {
                  final selected = _selectedHazard == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(
                        type,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
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
            const Text(
              'Description',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
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
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}