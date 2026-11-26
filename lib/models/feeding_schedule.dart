import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingSchedule {
  final String? id;
  final String time; // "HH:mm" format, e.g. "08:30"
  final List<String> days; // e.g. ["Mon", "Wed", "Fri"]
  final int durationSeconds; // How long food is dispensed in seconds
  final double quantityGrams; // Approximate feed weight
  final bool active;
  final DateTime createdAt;

  const FeedingSchedule({
    this.id,
    required this.time,
    required this.days,
    required this.durationSeconds,
    this.quantityGrams = 50.0,
    required this.active,
    required this.createdAt,
  });

  factory FeedingSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse durationSeconds with backward-compatibility fallback
    int parseDuration() {
      if (data['duration_seconds'] != null) {
        return (data['duration_seconds'] as num).toInt();
      }
      if (data['quantity_grams'] != null) {
        final q = (data['quantity_grams'] as num).toDouble();
        return (q / 5).round().clamp(2, 120);
      }
      return 10;
    }

    final duration = parseDuration();
    final quantity = data['quantity_grams'] != null
        ? (data['quantity_grams'] as num).toDouble()
        : (duration * 5.0);

    return FeedingSchedule(
      id: doc.id,
      time: data['time'] ?? '00:00',
      days: List<String>.from(data['days'] ?? []),
      durationSeconds: duration,
      quantityGrams: quantity,
      active: data['active'] ?? false,
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'days': days,
      'duration_seconds': durationSeconds,
      'quantity_grams': quantityGrams,
      'active': active,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
