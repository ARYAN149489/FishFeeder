# AquaFeed — Firestore Schema Reference

> **For the hardware team (Arduino / ESP8266)**
> This document describes every Firestore collection, its field names, data types, and example documents.
> All collections live under the device path: `devices/device_001/`

---

## Device Path

```
devices/{deviceId}/
```

The app currently hardcodes `deviceId = "device_001"`. If you need multi-device support in the future, each physical device gets its own `deviceId`.

---

## 1. `sensor_readings` — Written by Arduino

**Path:** `devices/device_001/sensor_readings/{auto-id}`

The Arduino/ESP8266 writes a new document to this collection at regular intervals (e.g., every 30 seconds). The app reads the **most recent** document (sorted by `timestamp` descending, limit 1).

| Field | Type | Description | Example |
|---|---|---|---|
| `temperature` | `number` (double) | Water temperature in °C | `26.5` |
| `ph` | `number` (double) | pH level (0–14 scale) | `7.2` |
| `turbidity` | `number` (double) | Turbidity in NTU | `12.4` |
| `tds` | `number` (double) | Total Dissolved Solids in ppm | `320.0` |
| `feed_weight` | `number` (double) | Remaining feed in hopper, grams | `1850.0` |
| `battery_percent` | `number` (int) | Battery level 0–100 | `78` |
| `solar_charging` | `boolean` | Whether solar panel is actively charging | `true` |
| `timestamp` | `Timestamp` | Server timestamp of the reading | (auto) |

### Example Document
```json
{
  "temperature": 26.5,
  "ph": 7.2,
  "turbidity": 12.4,
  "tds": 320.0,
  "feed_weight": 1850.0,
  "battery_percent": 78,
  "solar_charging": true,
  "timestamp": "2026-09-09T10:00:00Z"
}
```

> **Tip:** Use `FieldValue.serverTimestamp()` (or the REST API equivalent) for the `timestamp` field to ensure consistent time.

---

## 2. `commands` — Written by App, Read by Arduino

**Path:** `devices/device_001/commands/{auto-id}`

The app writes a command document when the user taps "Start Feeding" or "Stop Feeding". The Arduino should poll this collection for documents where `status == "pending"`, act on them, then update the `status` field.

| Field | Type | Description | Values |
|---|---|---|---|
| `type` | `string` | Command type | `"start_feeding"` or `"stop_feeding"` |
| `status` | `string` | Command lifecycle state | `"pending"` → `"acknowledged"` → `"completed"` |
| `created_at` | `Timestamp` | When the command was issued | (auto) |

### Arduino Workflow
1. Query: `commands` where `status == "pending"`, ordered by `created_at` ascending, limit 1
2. Read the `type` field
3. Update `status` to `"acknowledged"` immediately
4. Execute the feeding action (start/stop motor)
5. Update `status` to `"completed"` when done

### Example Document (as written by app)
```json
{
  "type": "start_feeding",
  "status": "pending",
  "created_at": "2026-09-09T10:05:00Z"
}
```

---

## 3. `schedules` — Written by App, Read by Arduino

**Path:** `devices/device_001/schedules/{auto-id}`

The app manages feeding schedules. The Arduino should read active schedules and trigger feeding at the specified times.

| Field | Type | Description | Example |
|---|---|---|---|
| `time` | `string` | 24-hour time in `"HH:mm"` format | `"08:30"` |
| `days` | `array<string>` | Repeat days (3-letter abbreviations) | `["Mon", "Wed", "Fri"]` |
| `quantity_grams` | `number` (double) | Feed amount in grams | `50.0` |
| `active` | `boolean` | Whether schedule is enabled | `true` |
| `created_at` | `Timestamp` | When the schedule was created | (auto) |

### Day Abbreviations
`Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`

### Arduino Workflow
1. On boot, query all `schedules` where `active == true`
2. Compare current day-of-week + time against each schedule's `days` and `time`
3. When a match is found, dispense `quantity_grams` of feed
4. After dispensing, write a `feeding_history` document (see below)

### Example Document
```json
{
  "time": "07:00",
  "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
  "quantity_grams": 50.0,
  "active": true,
  "created_at": "2026-09-09T06:00:00Z"
}
```

---

## 4. `feeding_history` — Written by Arduino (or App)

**Path:** `devices/device_001/feeding_history/{auto-id}`

A log of every feeding event. Written by the Arduino after each feeding (manual or scheduled). The app displays these in the History tab.

| Field | Type | Description | Example |
|---|---|---|---|
| `quantity_grams` | `number` (double) | Amount of feed actually dispensed | `50.0` |
| `trigger` | `string` | What initiated the feeding | `"manual"` or `"scheduled"` |
| `success` | `boolean` | Whether feeding completed successfully | `true` |
| `timestamp` | `Timestamp` | When the feeding occurred | (auto) |
| `schedule_id` | `string` (optional) | Document ID of the schedule that triggered it | `"abc123"` or omitted |

### Example Document (scheduled, successful)
```json
{
  "quantity_grams": 50.0,
  "trigger": "scheduled",
  "success": true,
  "timestamp": "2026-09-09T07:00:05Z",
  "schedule_id": "abc123"
}
```

### Example Document (manual, failed)
```json
{
  "quantity_grams": 0.0,
  "trigger": "manual",
  "success": false,
  "timestamp": "2026-09-09T10:05:30Z"
}
```

---

## Summary: Who Reads / Writes What

| Collection | App (Flutter) | Arduino (ESP8266) |
|---|---|---|
| `sensor_readings` | **Reads** (stream) | **Writes** (periodically) |
| `commands` | **Writes** (on button tap) | **Reads** (polls for pending), **Updates** (status) |
| `schedules` | **Reads** (stream) + **Writes** (CRUD) | **Reads** (active schedules) |
| `feeding_history` | **Reads** (stream) | **Writes** (after each feeding) |

---

## Firestore Security Rules (Suggested)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all reads/writes for development
    // IMPORTANT: Replace with proper auth rules before production
    match /devices/{deviceId}/{document=**} {
      allow read, write: if true;
    }
  }
}
```

> **Warning:** The above rules allow unrestricted access. Before deploying to production, implement proper authentication and restrict access to authenticated users only.

---

## Firebase Project Setup

To connect this app to your Firebase project:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (e.g., "AquaFeed")
3. Add an **Android app** with package name: `com.aquafeed.aquafeed`
4. Download `google-services.json` and replace the placeholder at `android/app/google-services.json`
5. *(Optional)* Add an **iOS app** with bundle ID: `com.aquafeed.aquafeed`
6. Download `GoogleService-Info.plist` and place it in `ios/Runner/`
7. Enable **Cloud Firestore** in the Firebase Console
8. Set the security rules (see above)
