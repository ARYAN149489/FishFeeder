import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingCommand {
  final String? id;
  final String type; // "start_feeding" or "stop_feeding"
  final String status; // "pending", "acknowledged", "completed"
  final int? durationSeconds; // Duration in seconds if specified (0 or null for continuous)
  final DateTime createdAt;

  const FeedingCommand({
    this.id,
    required this.type,
    required this.status,
    this.durationSeconds,
    required this.createdAt,
  });

  factory FeedingCommand.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingCommand(
      id: doc.id,
      type: data['type'] ?? '',
      status: data['status'] ?? 'pending',
      durationSeconds: (data['duration_seconds'] as num?)?.toInt(),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'status': status,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
