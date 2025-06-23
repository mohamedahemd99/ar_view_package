import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'ar_location_view.dart';

typedef AnnotationViewBuilder = Widget Function(
    BuildContext context, ArAnnotation annotation);

typedef ChangeLocationCallback = void Function(Position position);

class ArView extends StatefulWidget {
  const ArView({
    super.key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.frame,
    required this.onLocationChange,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    required this.minDistanceReload,
    this.scaleWithDistance = true,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
    this.maxVisibleAnnotations = 50,
    this.updateInterval = 100,
    this.onCompassCalibration,
  });

  final List<ArAnnotation> annotations;
  final AnnotationViewBuilder annotationViewBuilder;
  final double annotationWidth;
  final double annotationHeight;
  final double maxVisibleDistance;
  final Size frame;
  final ChangeLocationCallback onLocationChange;
  final bool showDebugInfoSensor;
  final double paddingOverlap;
  final double? yOffsetOverlap;
  final double minDistanceReload;
  final bool scaleWithDistance;
  final Color? markerColor;
  final Color? backgroundRadar;
  final RadarPosition? radarPosition;
  final bool showRadar;
  final double? radarWidth;
  final int maxVisibleAnnotations;
  final int updateInterval;
  final void Function(bool)? onCompassCalibration;

  @override
  State<ArView> createState() => _ArViewState();
}

class _ArViewState extends State<ArView> with TickerProviderStateMixin {
  ArStatus arStatus = ArStatus();
  Position? position;
  DateTime? _lastUpdate;
  List<ArAnnotation> _visibleAnnotations = [];
  final Map<String, Offset> _annotationPositions = {};
  final Map<String, AnimationController> _animationControllers = {};

  // Enhanced filtering to reduce vibration
  final Map<String, double> _smoothedAzimuths = {};
  final Map<String, double> _smoothedDistances = {};

  // Performance optimization
  Timer? _updateTimer;
  bool _isProcessing = false;

  // Compass calibration
  double _compassOffset = 0.0;
  bool _isCalibrating = false;

  @override
  void initState() {
    ArSensorManager.instance.init();
    _initializeUpdateTimer();
    super.initState();
  }

  void _initializeUpdateTimer() {
    _updateTimer = Timer.periodic(
      Duration(milliseconds: widget.updateInterval),
      (timer) {
        if (!_isProcessing && mounted) {
          _processAnnotations();
        }
      },
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    ArSensorManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return StreamBuilder(
      stream: ArSensorManager.instance.arSensor,
      builder: (context, data) {
        if (data.hasData && data.data != null) {
          final arSensor = data.data!;
          if (arSensor.location == null) {
            return _buildLoadingWidget();
          }

          _calculateFOV(arSensor.orientation, width, height);
          _updatePosition(arSensor.location!);
          _updateCompassCalibration(arSensor);

          return _buildArView(context, arSensor, width, height);
        }
        return _buildLoadingWidget();
      },
    );
  }

  Widget _buildArView(
      BuildContext context, ArSensor arSensor, double width, double height) {
    return Stack(
      children: [
        // Debug info
        if (kDebugMode && widget.showDebugInfoSensor)
          Positioned(
            bottom: 0,
            child: _buildDebugInfo(context, arSensor),
          ),

        // Annotations with smooth animations
        _buildAnnotationsLayer(height),

        // Radar
        if (widget.showRadar) _buildRadar(context, arSensor.heading, width),

        // Compass calibration indicator
        if (_isCalibrating) _buildCalibrationIndicator(),
      ],
    );
  }

  Widget _buildAnnotationsLayer(double height) {
    if (_visibleAnnotations.isEmpty) {
      // Fallback UI if no annotations are visible
      return const Center(
        child: Text(
          'No AR annotations found nearby.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }
    return Stack(
      children: _visibleAnnotations.map((annotation) {
        final key = annotation.uid ?? annotation.toString();

        // Create animation controller if not exists
        if (!_animationControllers.containsKey(key)) {
          final controller = AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: this,
          );
          _animationControllers[key] = controller;
          controller.forward();
        }

        final controller = _animationControllers[key]!;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: annotation.arPosition.dx - (widget.annotationWidth / 2),
              top: annotation.arPosition.dy + height * 0.5,
              child: Transform.translate(
                offset: Offset(0, annotation.arPositionOffset.dy),
                child: Transform.scale(
                  scale: _calculateScale(annotation) * controller.value,
                  child: Opacity(
                    opacity: controller.value,
                    child: SizedBox(
                      width: widget.annotationWidth,
                      height: widget.annotationHeight,
                      child: widget.annotationViewBuilder(context, annotation),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildRadar(BuildContext context, double heading, double width) {
    return _positionRadar(
      context,
      widget.radarPosition ?? RadarPosition.topLeft,
      heading + _compassOffset, // Apply compass calibration
      widget.radarWidth != null ? (widget.radarWidth! * 2) : width,
    );
  }

  Widget _buildCalibrationIndicator() {
    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rotate_right, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Move your device in a figure-8 pattern to calibrate compass',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateScale(ArAnnotation annotation) {
    if (!widget.scaleWithDistance) return 1.0;

    final scale =
        1 - (annotation.distanceFromUser / (widget.maxVisibleDistance + 280));
    return scale.clamp(0.3, 1.0); // Prevent annotations from becoming too small
  }

  void _processAnnotations() {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final deviceLocation = position;
      if (deviceLocation == null) return;

      final annotations = _filterAndSortArAnnotation(
        widget.annotations,
        deviceLocation,
      );

      _transformAnnotations(annotations);
      _cleanupUnusedControllers();

      if (mounted) {
        setState(() {
          _visibleAnnotations = annotations;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _cleanupUnusedControllers() {
    final visibleKeys =
        _visibleAnnotations.map((a) => a.uid ?? a.toString()).toSet();
    final controllersToRemove = <String>[];

    for (final key in _animationControllers.keys) {
      if (!visibleKeys.contains(key)) {
        _animationControllers[key]?.dispose();
        controllersToRemove.add(key);
      }
    }

    for (final key in controllersToRemove) {
      _animationControllers.remove(key);
      _annotationPositions.remove(key);
      _smoothedAzimuths.remove(key);
      _smoothedDistances.remove(key);
    }
  }

  void _calculateFOV(
      NativeDeviceOrientation orientation, double width, double height) {
    double hFov = 0;
    double vFov = 0;
    const tempFOv = 58.0;

    if (orientation == NativeDeviceOrientation.landscapeLeft ||
        orientation == NativeDeviceOrientation.landscapeRight) {
      hFov = tempFOv;
      vFov = (2 * atan(tan((hFov / 2).toRadians) * (height / width))).toDegrees;
    } else {
      vFov = tempFOv;
      hFov = (2 * atan(tan((vFov / 2).toRadians) * (width / height))).toDegrees;
    }

    arStatus.hFov = hFov;
    arStatus.vFov = vFov;
    arStatus.hPixelPerDegree = hFov > 0 ? (width / hFov) : 0;
    arStatus.vPixelPerDegree = vFov > 0 ? (height / vFov) : 0;
  }

  List<ArAnnotation> _filterAndSortArAnnotation(
    List<ArAnnotation> annotations,
    Position deviceLocation,
  ) {
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!).inMilliseconds < widget.updateInterval) {
      return _visibleAnnotations;
    }
    _lastUpdate = now;

    final filteredAnnotations = <ArAnnotation>[];

    for (final annotation in annotations) {
      // Calculate distance and azimuth
      final distance = Geolocator.distanceBetween(
        deviceLocation.latitude,
        deviceLocation.longitude,
        annotation.position.latitude,
        annotation.position.longitude,
      );

      final rawAzimuth = ArMath.bearingFromUserToLocation(
        deviceLocation,
        annotation.position,
      );

      // Apply smoothing to reduce vibration (tuned filter factors)
      final key = annotation.uid ?? annotation.toString();
      final smoothedAzimuth = _applySmoothingFilter(
        key,
        rawAzimuth,
        _smoothedAzimuths,
        isCircular: true,
        filterFactor: 0.5, // less vibration
      );
      final smoothedDistance = _applySmoothingFilter(
        key,
        distance,
        _smoothedDistances,
        isCircular: false,
        filterFactor: 0.3, // less vibration
      );

      annotation.distanceFromUser = smoothedDistance;
      annotation.azimuth = smoothedAzimuth;

      // Loosen filtering: allow more annotations to be visible
      const minDistance = 0.0; // allow all close annotations
      final maxDistance = widget.maxVisibleDistance * 1.5; // allow further

      if (distance >= minDistance && distance <= maxDistance) {
        annotation.isVisible = true;
        filteredAnnotations.add(annotation);
      } else {
        annotation.isVisible = false;
        // Debug: log why filtered out
        debugPrint(
            'Filtered out annotation ${annotation.uid}: distance=$distance, azimuth=$rawAzimuth');
      }
    }

    // Sort by distance
    filteredAnnotations
        .sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    // Debug: log how many annotations are visible
    debugPrint('Visible annotations: \\${filteredAnnotations.length}');

    return filteredAnnotations.take(widget.maxVisibleAnnotations).toList();
  }

  double _applySmoothingFilter(
    String key,
    double newValue,
    Map<String, double> cache, {
    required bool isCircular,
    double filterFactor = 0.2,
  }) {
    if (!cache.containsKey(key)) {
      cache[key] = newValue;
      return newValue;
    }

    final previousValue = cache[key]!;
    final smoothedValue = ArMath.exponentialFilter(
      newValue,
      previousValue,
      filterFactor,
      isCircular,
    );

    cache[key] = smoothedValue;
    return smoothedValue;
  }

  void _transformAnnotations(List<ArAnnotation> annotations) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    for (final annotation in annotations) {
      final key = annotation.uid ?? annotation.toString();

      // Calculate position with compass calibration
      final adjustedAzimuth = annotation.azimuth + _compassOffset;
      final newPosition = _calculateAnnotationPosition(
        adjustedAzimuth,
        annotation.distanceFromUser,
        width,
        height,
      );

      // Smooth position transitions
      final currentPosition = _annotationPositions[key];
      if (currentPosition != null) {
        const lerpFactor = 0.3;
        final smoothedPosition = Offset(
          currentPosition.dx +
              (newPosition.dx - currentPosition.dx) * lerpFactor,
          currentPosition.dy +
              (newPosition.dy - currentPosition.dy) * lerpFactor,
        );
        _annotationPositions[key] = smoothedPosition;
      } else {
        _annotationPositions[key] = newPosition;
      }

      annotation.arPosition = _annotationPositions[key]!;

      // Calculate overlap offset
      annotation.arPositionOffset =
          _calculateOverlapOffset(annotation, annotations);
    }
  }

  Offset _calculateAnnotationPosition(
    double azimuth,
    double distance,
    double width,
    double height,
  ) {
    // Convert azimuth to screen coordinates
    final normalizedAzimuth =
        ArMath.normalizeDegree2(azimuth - arStatus.heading);
    final x = (width / 2) + (normalizedAzimuth * arStatus.hPixelPerDegree);

    // Apply pitch-based vertical positioning
    final pitchOffset = arStatus.pitch * arStatus.vPixelPerDegree;
    final y = (height / 2) + pitchOffset;

    return Offset(x, y);
  }

  Offset _calculateOverlapOffset(
      ArAnnotation annotation, List<ArAnnotation> allAnnotations) {
    // Simple overlap avoidance
    double yOffset = 0;
    const overlapThreshold = 50.0;

    for (final other in allAnnotations) {
      if (other.uid == annotation.uid) continue;

      final distance = (annotation.arPosition - other.arPosition).distance;
      if (distance < overlapThreshold) {
        yOffset += widget.paddingOverlap;
      }
    }

    return Offset(0, yOffset);
  }

  void _updatePosition(Position newPosition) {
    if (position == null) {
      widget.onLocationChange(newPosition);
      position = newPosition;
    } else {
      final distance = Geolocator.distanceBetween(
        position!.latitude,
        position!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      if (distance > widget.minDistanceReload) {
        widget.onLocationChange(newPosition);
        position = newPosition;
      }
    }
  }

  void _updateCompassCalibration(ArSensor arSensor) {
    final needsCalibration = arSensor.compassAccuracy < 0.5;

    if (needsCalibration != _isCalibrating) {
      setState(() {
        _isCalibrating = needsCalibration;
      });
    }

    widget.onCompassCalibration?.call(needsCalibration);

    // Auto-calibrate compass based on device movement patterns
    if (!needsCalibration && arSensor.compassAccuracy > 0.8) {
      _calibrateCompass(arSensor.heading);
    }
  }

  void _calibrateCompass(double currentHeading) {
    // Simple compass calibration - could be enhanced with more sophisticated algorithms
    const calibrationThreshold = 5.0;

    if (_compassOffset.abs() > calibrationThreshold) {
      _compassOffset *= 0.95; // Gradually reduce offset
    }
  }

  Widget _positionRadar(
    BuildContext context,
    RadarPosition position,
    double heading,
    double width,
  ) {
    final radar = Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomPaint(
        size: Size(width / 2, width / 2),
        painter: RadarPainter(
          maxDistance: widget.maxVisibleDistance,
          arAnnotations: _visibleAnnotations, // Use filtered annotations
          heading: heading,
          background: widget.backgroundRadar ?? Colors.black,
          markerColor: widget.markerColor ?? Colors.red,
        ),
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    switch (position) {
      case RadarPosition.topCenter:
        return Positioned(
            top: 0, left: screenWidth / 2 - width / 4, child: radar);
      case RadarPosition.topRight:
        return Positioned(top: 0, right: 0, child: radar);
      case RadarPosition.bottomLeft:
        return Positioned(bottom: 0, left: 0, child: radar);
      case RadarPosition.bottomCenter:
        return Positioned(
            bottom: 80, left: screenWidth / 2 - width / 4, child: radar);
      case RadarPosition.bottomRight:
        return Positioned(bottom: 0, right: 0, child: radar);
      default:
        return Positioned(top: 0, left: 0, child: radar);
    }
  }

  Widget _buildDebugInfo(BuildContext context, ArSensor? arSensor) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lat: ${arSensor?.location?.latitude.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text('Lng: ${arSensor?.location?.longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text('Pitch: ${arSensor?.pitch.toStringAsFixed(1)}°',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text('Heading: ${arSensor?.heading.toStringAsFixed(1)}°',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text(
                'Compass Accuracy: ${arSensor?.compassAccuracy.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text('Visible Annotations: ${_visibleAnnotations.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}
