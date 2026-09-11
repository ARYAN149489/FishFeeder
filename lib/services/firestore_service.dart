import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sensor_reading.dart';
import '../models/feeding_schedule.dart';
import '../models/feeding_event.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String deviceId = 'device_001';

  // Base path for the device
  String get _devicePath => 'devices/$deviceId';

  // ──────────────────────────────────────────────
  // Sensor Readings
  // ──────────────────────────────────────────────

  /// Stream the latest sensor reading (ordered by timestamp desc, limit 1)
  Stream<SensorReading?> streamLatestSensorReading() {
    return _db
        .collection('$_devicePath/sensor_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SensorReading.fromFirestore(snapshot.docs.first);
    });
  }

  // ──────────────────────────────────────────────
  // Commands
  // ──────────────────────────────────────────────

  /// Send a feeding command ("start_feeding" or "stop_feeding")
  Future<void> sendCommand(String type) async {
    await _db.collection('$_devicePath/commands').add({
      'type': type,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────
  // Schedules
  // ──────────────────────────────────────────────

  /// Stream all feeding schedules
  Stream<List<FeedingSchedule>> streamSchedules() {
    return _db
        .collection('$_devicePath/schedules')
        .orderBy('time')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedingSchedule.fromFirestore(doc))
            .toList());
  }

  /// Add a new feeding schedule
  Future<void> addSchedule({
    required String time,
    required List<String> days,
    required double quantityGrams,
  }) async {
    await _db.collection('$_devicePath/schedules').add({
      'time': time,
      'days': days,
      'quantity_grams': quantityGrams,
      'active': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle schedule active state
  Future<void> updateScheduleActive(String scheduleId, bool active) async {
    await _db
        .collection('$_devicePath/schedules')
        .doc(scheduleId)
        .update({'active': active});
  }

  /// Delete a schedule
  Future<void> deleteSchedule(String scheduleId) async {
    await _db
        .collection('$_devicePath/schedules')
        .doc(scheduleId)
        .delete();
  }

  // ──────────────────────────────────────────────
  // Feeding History
  // ──────────────────────────────────────────────

  /// Stream feeding history (most recent first)
  Stream<List<FeedingEvent>> streamFeedingHistory({int limit = 50}) {
    return _db
        .collection('$_devicePath/feeding_history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedingEvent.fromFirestore(doc))
            .toList());
  }

  // ──────────────────────────────────────────────
  // Sample Data Seeding (for testing)
  // ──────────────────────────────────────────────

  /// Seed sample data into all collections for UI testing
  Future<void> seedSampleData() async {
    print('FirestoreService: Seeding sample data to $_devicePath...');
    final batch = _db.batch();

    // Sample sensor reading
    final sensorRef =
        _db.collection('$_devicePath/sensor_readings').doc();
    batch.set(sensorRef, {
      'temperature': 26.5,
      'ph': 7.2,
      'turbidity': 12.4,
      'tds': 320.0,
      'feed_weight': 1850.0,
      'battery_percent': 78,
      'solar_charging': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Sample schedules
    final schedules = [
      {
        'time': '07:00',
        'days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        'quantity_grams': 50.0,
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'time': '12:30',
        'days': ['Mon', 'Wed', 'Fri'],
        'quantity_grams': 30.0,
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'time': '18:00',
        'days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        'quantity_grams': 45.0,
        'active': false,
        'created_at': FieldValue.serverTimestamp(),
      },
    ];
    for (final schedule in schedules) {
      final ref = _db.collection('$_devicePath/schedules').doc();
      batch.set(ref, schedule);
    }

    // Sample feeding history
    final now = DateTime.now();
    final historyEntries = List.generate(20, (i) {
      final ts = now.subtract(Duration(hours: i * 6));
      return {
        'quantity_grams': 25.0 + (i % 5) * 10.0,
        'trigger': i % 3 == 0 ? 'manual' : 'scheduled',
        'success': i != 7, // one failure for demo
        'timestamp': Timestamp.fromDate(ts),
      };
    });
    for (final entry in historyEntries) {
      final ref = _db.collection('$_devicePath/feeding_history').doc();
      batch.set(ref, entry);
    }

    await batch.commit();
    print('FirestoreService: Sample data committed successfully!');
  }

  /// Clear all data in all device subcollections for testing / fresh reset
  Future<void> clearAllData() async {
    final subcollections = [
      '$_devicePath/sensor_readings',
      '$_devicePath/schedules',
      '$_devicePath/feeding_history',
      '$_devicePath/commands',
    ];

    for (final colPath in subcollections) {
      final snapshot = await _db.collection(colPath).get();
      if (snapshot.docs.isNotEmpty) {
        // Firestore batches can hold up to 500 operations
        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }
}
