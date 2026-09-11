import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingCommand {
  final String? id;
  final String type; // "start_feeding" or "stop_feeding"
  final String status; // "pending", "acknowledged", "completed"
  final DateTime createdAt;

  const FeedingCommand({
    this.id,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory FeedingCommand.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedingCommand(
      id: doc.id,
      type: data['type'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'status': status,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
