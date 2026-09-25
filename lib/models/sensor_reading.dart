import 'package:cloud_firestore/cloud_firestore.dart';

class SensorReading {
  final String? id;
  final double temperature;
  final double ph;
  final double turbidity;
  final double tds;
  final double feedWeight;
  final int batteryPercent;
  final bool solarCharging;
  final DateTime timestamp;

  const SensorReading({
    this.id,
    required this.temperature,
    required this.ph,
    required this.turbidity,
    required this.tds,
    required this.feedWeight,
    required this.batteryPercent,
    required this.solarCharging,
    required this.timestamp,
  });

  factory SensorReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SensorReading(
      id: doc.id,
      temperature: (data['temperature'] ?? 0).toDouble(),
      ph: (data['ph'] ?? 0).toDouble(),
      turbidity: (data['turbidity'] ?? 0).toDouble(),
      tds: (data['tds'] ?? 0).toDouble(),
      feedWeight: (data['feed_weight'] ?? 0).toDouble(),
      batteryPercent: (data['battery_percent'] ?? 0).toInt(),
      solarCharging: data['solar_charging'] ?? false,
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'ph': ph,
      'turbidity': turbidity,
      'tds': tds,
      'feed_weight': feedWeight,
      'battery_percent': batteryPercent,
      'solar_charging': solarCharging,
      'timestamp': FieldValue.serverTimestamp(),
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
