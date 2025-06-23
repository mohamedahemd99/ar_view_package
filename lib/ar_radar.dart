import 'dart:math';

import 'package:flutter/material.dart';

import 'ar_location_view.dart';

enum RadarPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class RadarPainter extends CustomPainter {
  const RadarPainter({
    required this.maxDistance,
    required this.arAnnotations,
    required this.heading,
    required this.markerColor,
    required this.background,
    this.borderColor = Colors.grey,
    this.borderWidth = 2.0,
    this.minDistanceThreshold = 50.0, // Adjusted for consistency
  });

  final angle = pi / 7;

  final Color markerColor;
  final Color background;
  final double maxDistance;
  final List<ArAnnotation> arAnnotations;
  final double heading;
  final Color borderColor;
  final double borderWidth;
  final double minDistanceThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final angleView = -(angle + heading.toRadians);
    final angleView1 = -(-angle + heading.toRadians);
    final center = Offset(radius, radius);

    _drawBackground(canvas, center, radius);
    _drawFieldOfView(canvas, center, radius, angleView, angleView1);
    _drawBorder(canvas, center, radius);
    _drawOptimizedMarkers(canvas, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final Paint backgroundPaint = Paint()..color = background.withOpacity(0.6);
    canvas.drawCircle(center, radius, backgroundPaint);
  }

  void _drawFieldOfView(Canvas canvas, Offset center, double radius,
      double angleView, double angleView1) {
    final Path path = Path();
    final pointA =
        Offset(radius * (1 - sin(angleView)), radius * (1 - cos(angleView)));
    final pointB =
        Offset(radius * (1 - sin(angleView1)), radius * (1 - cos(angleView1)));

    path.moveTo(pointA.dx, pointA.dy);
    path.lineTo(radius, radius);
    path.lineTo(pointB.dx, pointB.dy);
    path.arcToPoint(pointA, radius: Radius.circular(radius));

    final Paint gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.grey.withAlpha(60),
          Colors.grey.withAlpha(20),
        ],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: radius,
      ))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, gradientPaint);
  }

  void _drawBorder(Canvas canvas, Offset center, double radius) {
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawOptimizedMarkers(Canvas canvas, double radius) {
    final Path clipPath = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius));
    canvas.save();
    canvas.clipPath(clipPath);

    final filteredAnnotations = arAnnotations
        .where(
            (annotation) => annotation.distanceFromUser >= minDistanceThreshold)
        .toList()
      ..sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    const maxMarkers = 50;
    final markersToShow = filteredAnnotations.take(maxMarkers).toList();

    for (final annotation in markersToShow) {
      final distanceInRadar =
          (annotation.distanceFromUser / maxDistance) * radius;
      final alpha = pi - annotation.azimuth.toRadians;
      final dx = distanceInRadar * sin(alpha);
      final dy = distanceInRadar * cos(alpha);
      final center = Offset(dx + radius, dy + radius);
      final opacity =
          (1 - (annotation.distanceFromUser / maxDistance)).clamp(0.3, 1.0);
      final paint = Paint()..color = markerColor.withOpacity(opacity);
      canvas.drawCircle(center, 3, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.arAnnotations.length != arAnnotations.length ||
        _hasSignificantChanges(oldDelegate);
  }

  bool _hasSignificantChanges(RadarPainter oldDelegate) {
    if (arAnnotations.length != oldDelegate.arAnnotations.length) return true;
    for (int i = 0; i < arAnnotations.length; i++) {
      final oldAnnotation = oldDelegate.arAnnotations[i];
      final newAnnotation = arAnnotations[i];
      if ((oldAnnotation.azimuth - newAnnotation.azimuth).abs() > 1.0 ||
          (oldAnnotation.distanceFromUser - newAnnotation.distanceFromUser)
                  .abs() >
              5.0) {
        return true;
      }
    }
    return false;
  }
}