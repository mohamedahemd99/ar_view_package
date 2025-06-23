import 'package:flutter/material.dart';

import 'annotations.dart';

class AnnotationView extends StatelessWidget {
  const AnnotationView({
    super.key,
    required this.annotation,
  });

  final Annotation annotation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getColorForType(annotation.type).withOpacity(0.8),
              _getColorForType(annotation.type).withOpacity(0.6),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIconForType(annotation.type),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _getTitleForType(annotation.type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Distance: ${(annotation.distanceFromUser / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.pharmacy:
        return Colors.blue;
      case AnnotationType.hotel:
        return Colors.orange;
      case AnnotationType.library:
        return Colors.green;
    }
  }

  IconData _getIconForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.pharmacy:
        return Icons.local_pharmacy;
      case AnnotationType.hotel:
        return Icons.hotel;
      case AnnotationType.library:
        return Icons.local_library;
    }
  }

  String _getTitleForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.pharmacy:
        return 'Pharmacy';
      case AnnotationType.hotel:
        return 'Hotel';
      case AnnotationType.library:
        return 'Library';
    }
  }
}
