import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingSchedule {
  final String? id;
  final String time; // "HH:mm" format, e.g. "08:30"
  final List<String> days; // e.g. ["Mon", "Wed", "Fri"]
  final double quantityGrams;
  final bool active;
  final DateTime createdAt;

  const FeedingSchedule({
    this.id,
    required this.time,
    required this.days,
    required this.quantityGrams,
    required this.active,
    required this.createdAt,
  });

  factory FeedingSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingSchedule(
      id: doc.id,
      time: data['time'] ?? '00:00',
      days: List<String>.from(data['days'] ?? []),
      quantityGrams: (data['quantity_grams'] ?? 0).toDouble(),
      active: data['active'] ?? false,
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'days': days,
      'quantity_grams': quantityGrams,
      'active': active,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
