import 'package:flutter/material.dart';

import 'ar_location_view.dart';


class ArLocationWidget extends StatefulWidget {
  const ArLocationWidget({
    super.key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.onLocationChange,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.frame,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    this.accessory,
    this.minDistanceReload = 50,
    this.scaleWithDistance = true,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
    this.maxVisibleAnnotations = 50,
    this.updateInterval = 150, // Match ar_view.dart
    this.onCompassCalibration,
  });

  final List<ArAnnotation> annotations;
  final AnnotationViewBuilder annotationViewBuilder;
  final double annotationWidth;
  final double annotationHeight;
  final double maxVisibleDistance;
  final Size? frame;
  final ChangeLocationCallback onLocationChange;
  final bool showDebugInfoSensor;
  final double paddingOverlap;
  final double? yOffsetOverlap;
  final Widget? accessory;
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
  State<ArLocationWidget> createState() => _ArLocationWidgetState();
}

class _ArLocationWidgetState extends State<ArLocationWidget> {
  bool initCam = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black, // Debug background
          child: ArCamera(
            onCameraError: (String error) {
              initCam = false;
              setState(() {});
            },
            onCameraSuccess: () {
              initCam = true;
              setState(() {});
            },
          ),
        ),
        if (initCam)
          ArView(
            annotations: widget.annotations,
            annotationViewBuilder: widget.annotationViewBuilder,
            frame: widget.frame ?? const Size(100, 75),
            onLocationChange: widget.onLocationChange,
            annotationWidth: widget.annotationWidth,
            annotationHeight: widget.annotationHeight,
            maxVisibleDistance: widget.maxVisibleDistance,
            showDebugInfoSensor: widget.showDebugInfoSensor,
            paddingOverlap: widget.paddingOverlap,
            yOffsetOverlap: widget.yOffsetOverlap,
            minDistanceReload: widget.minDistanceReload,
            scaleWithDistance: widget.scaleWithDistance,
            markerColor: widget.markerColor,
            backgroundRadar: widget.backgroundRadar,
            radarPosition: widget.radarPosition,
            showRadar: widget.showRadar,
            radarWidth: widget.radarWidth,
            maxVisibleAnnotations: widget.maxVisibleAnnotations,
            updateInterval: widget.updateInterval,
          ),
        if (initCam && widget.accessory != null) widget.accessory!
      ],
    );
  }
}
