import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingEvent {
  final String? id;
  final double quantityGrams;
  final String trigger; // "manual" or "scheduled"
  final bool success;
  final DateTime timestamp;
  final String? scheduleId;

  const FeedingEvent({
    this.id,
    required this.quantityGrams,
    required this.trigger,
    required this.success,
    required this.timestamp,
    this.scheduleId,
  });

  factory FeedingEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingEvent(
      id: doc.id,
      quantityGrams: (data['quantity_grams'] ?? 0).toDouble(),
      trigger: data['trigger'] ?? 'manual',
      success: data['success'] ?? false,
      timestamp: _parseTimestamp(data['timestamp']),
      scheduleId: data['schedule_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quantity_grams': quantityGrams,
      'trigger': trigger,
      'success': success,
      'timestamp': FieldValue.serverTimestamp(),
      if (scheduleId != null) 'schedule_id': scheduleId,
    };
  }

  /// Parse timestamp from either Firestore Timestamp or ISO string (REST API)
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
