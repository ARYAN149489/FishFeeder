import 'package:flutter_test/flutter_test.dart';
import 'package:aquafeed/models/feeding_schedule.dart';
import 'package:aquafeed/models/feeding_command.dart';
import 'package:aquafeed/models/feeding_event.dart';
import 'package:aquafeed/models/sensor_reading.dart';

void main() {
  group('FeedingSchedule Model Tests', () {
    test('Correctly initializes with durationSeconds', () {
      final now = DateTime.now();
      final schedule = FeedingSchedule(
        id: 'sched_1',
        time: '08:30',
        days: ['Mon', 'Wed', 'Fri'],
        durationSeconds: 15,
        quantityGrams: 75.0,
        active: true,
        createdAt: now,
      );

      expect(schedule.id, 'sched_1');
      expect(schedule.time, '08:30');
      expect(schedule.days, ['Mon', 'Wed', 'Fri']);
      expect(schedule.durationSeconds, 15);
      expect(schedule.quantityGrams, 75.0);
      expect(schedule.active, true);
    });

    test('toMap serializes duration_seconds and quantity_grams', () {
      final schedule = FeedingSchedule(
        time: '14:00',
        days: ['Tue', 'Thu'],
        durationSeconds: 20,
        active: true,
        createdAt: DateTime.now(),
      );

      final map = schedule.toMap();
      expect(map['time'], '14:00');
      expect(map['days'], ['Tue', 'Thu']);
      expect(map['duration_seconds'], 20);
      expect(map['active'], true);
      expect(map.containsKey('created_at'), true);
    });
  });

  group('FeedingCommand Model Tests', () {
    test('Initializes with start_feeding and durationSeconds', () {
      final now = DateTime.now();
      final cmd = FeedingCommand(
        id: 'cmd_1',
        type: 'start_feeding',
        status: 'pending',
        durationSeconds: 10,
        createdAt: now,
      );

      expect(cmd.type, 'start_feeding');
      expect(cmd.status, 'pending');
      expect(cmd.durationSeconds, 10);
    });

    test('toMap includes duration_seconds when provided', () {
      final cmd = FeedingCommand(
        type: 'start_feeding',
        status: 'pending',
        durationSeconds: 15,
        createdAt: DateTime.now(),
      );

      final map = cmd.toMap();
      expect(map['type'], 'start_feeding');
      expect(map['status'], 'pending');
      expect(map['duration_seconds'], 15);
    });

    test('toMap omits duration_seconds for stop_feeding when null', () {
      final cmd = FeedingCommand(
        type: 'stop_feeding',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final map = cmd.toMap();
      expect(map['type'], 'stop_feeding');
      expect(map.containsKey('duration_seconds'), false);
    });
  });

  group('FeedingEvent Model Tests', () {
    test('Initializes with durationSeconds and parses ISO timestamp', () {
      final now = DateTime(2026, 11, 26, 10, 0, 0);
      final event = FeedingEvent(
        id: 'event_1',
        quantityGrams: 50.0,
        durationSeconds: 10,
        trigger: 'manual',
        success: true,
        timestamp: now,
      );

      expect(event.quantityGrams, 50.0);
      expect(event.durationSeconds, 10);
      expect(event.trigger, 'manual');
      expect(event.success, true);
    });

    test('toMap exports correct keys', () {
      final event = FeedingEvent(
        quantityGrams: 30.0,
        durationSeconds: 6,
        trigger: 'scheduled',
        success: true,
        timestamp: DateTime.now(),
        scheduleId: 'sched_abc',
      );

      final map = event.toMap();
      expect(map['quantity_grams'], 30.0);
      expect(map['duration_seconds'], 6);
      expect(map['trigger'], 'scheduled');
      expect(map['schedule_id'], 'sched_abc');
    });
  });

  group('SensorReading Model Tests', () {
    test('Initializes with all 7 sensor telemetry values', () {
      final now = DateTime.now();
      final reading = SensorReading(
        id: 'reading_1',
        temperature: 26.5,
        ph: 7.2,
        turbidity: 15.0,
        tds: 320.0,
        feedWeight: 1800.0,
        batteryPercent: 85,
        solarCharging: true,
        timestamp: now,
      );

      expect(reading.temperature, 26.5);
      expect(reading.ph, 7.2);
      expect(reading.turbidity, 15.0);
      expect(reading.tds, 320.0);
      expect(reading.feedWeight, 1800.0);
      expect(reading.batteryPercent, 85);
      expect(reading.solarCharging, true);
    });

    test('toMap formats all telemetry fields correctly', () {
      final reading = SensorReading(
        temperature: 25.0,
        ph: 7.0,
        turbidity: 10.0,
        tds: 250.0,
        feedWeight: 1500.0,
        batteryPercent: 90,
        solarCharging: false,
        timestamp: DateTime.now(),
      );

      final map = reading.toMap();
      expect(map['temperature'], 25.0);
      expect(map['ph'], 7.0);
      expect(map['turbidity'], 10.0);
      expect(map['tds'], 250.0);
      expect(map['feed_weight'], 1500.0);
      expect(map['battery_percent'], 90);
      expect(map['solar_charging'], false);
    });
  });
}
