import 'dart:math';

import 'package:ar_location_view/ar_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

enum AnnotationType { pharmacy, hotel, library }

class Annotation extends ArAnnotation {
  final AnnotationType type;

  Annotation({required super.uid, required super.position, required this.type});
}

class AnnotationGenerator {
  static final Random _random = Random.secure();
  static final List<AnnotationType> _types = AnnotationType.values.toList();
  static const Uuid _uuid = Uuid();

  static AnnotationType getRandomAnnotation() {
    return _types[_random.nextInt(_types.length)];
  }

  static List<Annotation> generateAnnotations({
    required Position position,
    int distance = 1500,
    int numberMaxPoi = 100,
  }) {
    // Pre-calculate deltas for better performance
    final latDelta = distance / 100000;
    final lonDelta = distance / 100000;
    final centerLat = position.latitude;
    final centerLon = position.longitude;

    return List<Annotation>.generate(
      numberMaxPoi,
      (index) {
        // Generate random offsets
        final latOffset = -(latDelta / 2) + _random.nextDouble() * latDelta;
        final lonOffset = -(lonDelta / 2) + _random.nextDouble() * lonDelta;

        // Create position
        final pos = Position(
          longitude: centerLon + lonOffset,
          latitude: centerLat + latOffset,
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 1,
          heading: 1,
          speed: 1,
          speedAccuracy: 1,
          altitudeAccuracy: 1,
          headingAccuracy: 1,
        );

        return Annotation(
          uid: _uuid.v1(),
          position: pos,
          type: getRandomAnnotation(),
        );
      },
    );
  }
}

// For backward compatibility
List<Annotation> fakeAnnotation({
  required Position position,
  int distance = 1500,
  int numberMaxPoi = 100,
}) {
  return AnnotationGenerator.generateAnnotations(
    position: position,
    distance: distance,
    numberMaxPoi: numberMaxPoi,
  );
}

List<Annotation> generateTestAnnotations(Position devicePosition) {
  return [
    Annotation(
      uid: '1',
      position: Position(
        latitude: devicePosition.latitude + 0.0001,
        longitude: devicePosition.longitude + 0.0001,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
      type: AnnotationType.hotel,
    ),
    Annotation(
      uid: '2',
      position: Position(
        latitude: devicePosition.latitude - 0.0001,
        longitude: devicePosition.longitude - 0.0001,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
      type: AnnotationType.pharmacy,
    ),
    Annotation(
      uid: '3',
      position: Position(
        latitude: devicePosition.latitude + 0.0002,
        longitude: devicePosition.longitude - 0.0002,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
      type: AnnotationType.library,
    ),
  ];
}
