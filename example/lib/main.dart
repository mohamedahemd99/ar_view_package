import 'package:ar_location_view/ar_location_view.dart';
import 'package:ar_location_view_example/annotation_view.dart';
import 'package:ar_location_view_example/annotations.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Annotation> annotations = [];
  bool isLargeDataset = false;
  bool isLoading = true;
  Position? lastPosition;
  bool needsCompassCalibration = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Request location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
          'Current position: ${position.latitude}, ${position.longitude}');
      lastPosition = position;
      if (mounted) {
        _generateTestData(position);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      // If getting location fails, use a default position (Cairo, Egypt)
      final defaultPosition = Position(
        latitude: 30.0444,
        longitude: 31.2357,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      debugPrint(
          'Using default position: ${defaultPosition.latitude}, ${defaultPosition.longitude}');
      lastPosition = defaultPosition;
      if (mounted) {
        _generateTestData(defaultPosition);
      }
    }
  }

  void _generateTestData(Position position) {
    if (!mounted) return;

    final newAnnotations = generateTestAnnotations(position);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          annotations = newAnnotations;
        });
      }
    });
  }

  void _handleLocationChange(Position position) {
    if (isLoading) return;

    // Only update if position has changed significantly
    if (lastPosition == null ||
        Geolocator.distanceBetween(
              lastPosition!.latitude,
              lastPosition!.longitude,
              position.latitude,
              position.longitude,
            ) >
            10) {
      debugPrint(
          'Location changed: ${position.latitude}, ${position.longitude}');
      lastPosition = position;
      _generateTestData(position);
    }
  }

  void _handleCompassCalibration(bool needsCalibration) {
    if (mounted && needsCompassCalibration != needsCalibration) {
      setState(() {
        needsCompassCalibration = needsCalibration;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('AR Widget annotations count: \\${annotations.length}');
    if (annotations.isNotEmpty) {
      print(
          'First annotation position: \\${annotations.first.position.latitude}, \\${annotations.first.position.longitude}');
    }
    return MaterialApp(
      title: 'AR Location View Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('AR Location View Example'),
          actions: [
            IconButton(
              icon: Icon(isLargeDataset ? Icons.speed : Icons.speed_outlined),
              onPressed: () {
                setState(() {
                  isLargeDataset = !isLargeDataset;
                  isLoading = true;
                  annotations = [];
                });
                _initializeLocation();
              },
              tooltip: 'Toggle Large Dataset',
            ),
          ],
        ),
        body: Stack(
          children: [
            ArLocationWidget(
              annotations: annotations,
              showDebugInfoSensor: true,
              maxVisibleAnnotations: isLargeDataset ? 100 : 50,
              updateInterval: isLargeDataset ? 100000 : 500,
              minDistanceReload: 10.0,
              maxVisibleDistance: 2000.0,
              annotationViewBuilder: (context, annotation) {
                return AnnotationView(
                  key: ValueKey(annotation.uid),
                  annotation: annotation as Annotation,
                );
              },
              onLocationChange: _handleLocationChange,
              onCompassCalibration: _handleCompassCalibration,
            ),
            if (isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            if (needsCompassCalibration)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.compass_calibration,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Please calibrate your compass\nby moving your device in a figure-8 pattern',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dataset Size: \\${annotations.length} POIs',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Mode: \\${isLargeDataset ? "Large Dataset" : "Normal"}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (lastPosition != null)
                        Text(
                          'Location: \\${lastPosition!.latitude.toStringAsFixed(4)}, \\${lastPosition!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
