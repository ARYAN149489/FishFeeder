/*
 * AquaFeed — ESP8266 (ESP-01) WiFi Bridge
 * =========================================
 * This sketch runs on the ESP8266 ESP-01 module.
 * It bridges the Arduino Uno R4 to Firebase Firestore via WiFi.
 *
 * Responsibilities:
 *   1. Receive sensor data from Arduino via Serial -> POST to Firestore
 *   2. Poll Firestore for pending feeding commands -> Send to Arduino
 *   3. Poll active schedules -> Trigger feeding at scheduled times
 *   4. Log feeding history to Firestore after each feed event
 *
 * Wiring:
 *   ESP-01 TX  -> Arduino Pin 7
 *   ESP-01 RX  <- Arduino Pin 8 (via voltage divider!)
 *   ESP-01 VCC -> 3.3V
 *   ESP-01 GND -> GND
 *   ESP-01 CH_PD -> 3.3V
 *   ESP-01 GPIO0 -> 3.3V
 *
 * Required Libraries (install via Arduino IDE Library Manager):
 *   - ESP8266WiFi (comes with ESP8266 board package)
 *   - ESP8266HTTPClient
 *   - ArduinoJson
 *
 * Board Setup in Arduino IDE:
 *   1. File -> Preferences -> Additional Board Manager URLs:
 *      http://arduino.esp8266.com/stable/package_esp8266com_index.json
 *   2. Tools -> Board -> Board Manager -> search "ESP8266" -> install
 *   3. Tools -> Board -> ESP8266 Boards -> Generic ESP8266 Module
 *   4. Tools -> Flash Size -> 1MB (FS:64KB OTA:~470KB)
 *
 * IMPORTANT: Flash this sketch to the ESP-01 SEPARATELY from the Arduino.
 * You need an ESP-01 USB programmer/adapter to flash this.
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecureBearSSL.h>
#include <ArduinoJson.h>

// ─── WiFi CREDENTIALS ───────────────────────────────────────
// CHANGE THESE to your WiFi network name and password!
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ─── FIREBASE CONFIGURATION ─────────────────────────────────
// These values come from your Firebase project (aquafeed-ebe01)
const char* FIREBASE_PROJECT_ID = "aquafeed-ebe01";
const char* FIREBASE_API_KEY    = "AIzaSyB549YsaHAGXsxoibFrKtBLTplq56QQnv4";

// Firestore REST API base URL
const String FIRESTORE_BASE = "https://firestore.googleapis.com/v1/projects/"
                              + String(FIREBASE_PROJECT_ID)
                              + "/databases/(default)/documents/";

// Device path in Firestore
const String DEVICE_PATH = "devices/device_001/";

// ─── TIMING ──────────────────────────────────────────────────
#define COMMAND_POLL_INTERVAL  5000   // Poll commands every 5 seconds
#define SCHEDULE_POLL_INTERVAL 60000  // Poll schedules every 60 seconds
#define NTP_SYNC_INTERVAL      3600000 // Sync time every hour

unsigned long lastCommandPoll = 0;
unsigned long lastSchedulePoll = 0;
unsigned long lastNTPSync = 0;

// ─── STATE ───────────────────────────────────────────────────
float lastWeightBeforeFeed = 0;
String currentCommandId = "";

// ─── NTP TIME ────────────────────────────────────────────────
#include <time.h>
const char* NTP_SERVER = "pool.ntp.org";
const long  GMT_OFFSET = 19800; // IST = UTC+5:30 = 19800 seconds
const int   DST_OFFSET = 0;

// ─── SETUP ───────────────────────────────────────────────────
void setup() {
  Serial.begin(9600); // Communication with Arduino
  delay(1000);

  Serial.println("ESP8266 AquaFeed Bridge Starting...");

  // Connect to WiFi
  connectWiFi();

  // Initialize NTP for time-based scheduling
  configTime(GMT_OFFSET, DST_OFFSET, NTP_SERVER);
  Serial.println("NTP time sync initiated");

  // Wait for time to sync
  delay(2000);
  printCurrentTime();
}

// ─── MAIN LOOP ───────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // Ensure WiFi is connected
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // 1. Check for data from Arduino (sensor readings, feed complete, etc.)
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    handleArduinoMessage(line);
  }

  // 2. Poll Firestore for pending commands
  if (now - lastCommandPoll >= COMMAND_POLL_INTERVAL) {
    lastCommandPoll = now;
    pollCommands();
  }

  // 3. Poll and check feeding schedules
  if (now - lastSchedulePoll >= SCHEDULE_POLL_INTERVAL) {
    lastSchedulePoll = now;
    checkSchedules();
  }

  yield(); // Feed the ESP8266 watchdog
}

// ─── WiFi CONNECTION ─────────────────────────────────────────

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection FAILED! Will retry...");
  }
}

// ─── HANDLE MESSAGES FROM ARDUINO ────────────────────────────

void handleArduinoMessage(String message) {
  // Try to parse as JSON
  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, message);

  if (err) {
    // Not JSON, handle as plain text
    if (message == "READY") {
      Serial.println("Arduino is ready!");
    }
    else if (message == "FEED_STARTED") {
      // Update command status to "acknowledged"
      if (currentCommandId.length() > 0) {
        updateCommandStatus(currentCommandId, "acknowledged");
      }
    }
    else if (message == "FEED_STOPPED") {
      // Feeding was stopped manually
    }
    else if (message == "PONG") {
      // Arduino alive
    }
    return;
  }

  // Handle JSON messages
  String cmd = doc["cmd"].as<String>();

  if (cmd == "SENSOR_DATA") {
    // Arduino sent sensor readings -> upload to Firestore
    float temp   = doc["temp"];
    float ph     = doc["ph"];
    float tds    = doc["tds"];
    float turb   = doc["turb"];
    float weight = doc["weight"];
    int   batt   = doc["batt"];
    bool  solar  = doc["solar"];

    lastWeightBeforeFeed = weight;
    uploadSensorReading(temp, ph, tds, turb, weight, batt, solar);
  }
  else if (cmd == "FEED_COMPLETE") {
    // Arduino finished feeding -> log to history
    float weightAfter = doc["weight_after"];
    float dispensed = lastWeightBeforeFeed - weightAfter;
    if (dispensed < 0) dispensed = 0;

    // Update command status to completed
    if (currentCommandId.length() > 0) {
      updateCommandStatus(currentCommandId, "completed");
      logFeedingHistory(dispensed, "manual", true);
      currentCommandId = "";
    }
  }
}

// ─── FIRESTORE: UPLOAD SENSOR READING ────────────────────────

void uploadSensorReading(float temp, float ph, float tds, float turb,
                          float weight, int batt, bool solar) {
  if (WiFi.status() != WL_CONNECTED) return;

  String url = FIRESTORE_BASE + DEVICE_PATH + "sensor_readings?key=" + FIREBASE_API_KEY;

  // Build Firestore document JSON
  // Firestore REST API uses a specific format with typed fields
  String payload = "{\"fields\":{"
    "\"temperature\":{\"doubleValue\":" + String(temp, 1) + "},"
    "\"ph\":{\"doubleValue\":" + String(ph, 1) + "},"
    "\"tds\":{\"doubleValue\":" + String(tds, 1) + "},"
    "\"turbidity\":{\"doubleValue\":" + String(turb, 1) + "},"
    "\"feed_weight\":{\"doubleValue\":" + String(weight, 0) + "},"
    "\"battery_percent\":{\"integerValue\":\"" + String(batt) + "\"},"
    "\"solar_charging\":{\"booleanValue\":" + String(solar ? "true" : "false") + "},"
    "\"timestamp\":{\"timestampValue\":\"" + getISOTimestamp() + "\"}"
  "}}";

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure(); // Skip certificate verification (OK for development)

  HTTPClient http;
  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);

  if (httpCode == 200 || httpCode == 201) {
    Serial.println("Sensor data uploaded to Firestore!");
  } else {
    Serial.print("Firestore upload failed. HTTP code: ");
    Serial.println(httpCode);
    Serial.println(http.getString());
  }

  http.end();
}

// ─── FIRESTORE: POLL FOR PENDING COMMANDS ────────────────────

void pollCommands() {
  if (WiFi.status() != WL_CONNECTED) return;

  // Use Firestore REST API structured query to find pending commands
  String url = FIRESTORE_BASE + DEVICE_PATH + "commands?key=" + FIREBASE_API_KEY
               + "&orderBy=created_at&pageSize=1";

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();

  HTTPClient http;
  http.begin(*client, url);

  int httpCode = http.GET();

  if (httpCode == 200) {
    String response = http.getString();

    StaticJsonDocument<2048> doc;
    DeserializationError err = deserializeJson(doc, response);

    if (!err && doc.containsKey("documents")) {
      JsonArray documents = doc["documents"].as<JsonArray>();

      for (JsonObject document : documents) {
        String status = document["fields"]["status"]["stringValue"].as<String>();

        if (status == "pending") {
          String type = document["fields"]["type"]["stringValue"].as<String>();

          // Extract document ID from the full path
          String fullPath = document["name"].as<String>();
          int lastSlash = fullPath.lastIndexOf('/');
          currentCommandId = fullPath.substring(lastSlash + 1);

          Serial.print("Found pending command: ");
          Serial.print(type);
          Serial.print(" (ID: ");
          Serial.print(currentCommandId);
          Serial.println(")");

          // Send command to Arduino
          if (type == "start_feeding") {
            Serial.println("START_FEED");
          } else if (type == "stop_feeding") {
            Serial.println("STOP_FEED");
          }

          break; // Only process one command at a time
        }
      }
    }
  } else {
    Serial.print("Command poll failed. HTTP: ");
    Serial.println(httpCode);
  }

  http.end();
}

// ─── FIRESTORE: UPDATE COMMAND STATUS ────────────────────────

void updateCommandStatus(String commandId, String newStatus) {
  if (WiFi.status() != WL_CONNECTED) return;

  String url = FIRESTORE_BASE + DEVICE_PATH + "commands/" + commandId
               + "?key=" + FIREBASE_API_KEY
               + "&updateMask.fieldPaths=status";

  String payload = "{\"fields\":{\"status\":{\"stringValue\":\"" + newStatus + "\"}}}";

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();

  HTTPClient http;
  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.PATCH(payload);

  if (httpCode == 200) {
    Serial.print("Command status updated to: ");
    Serial.println(newStatus);
  } else {
    Serial.print("Status update failed. HTTP: ");
    Serial.println(httpCode);
  }

  http.end();
}

// ─── FIRESTORE: LOG FEEDING HISTORY ─────────────────────────

void logFeedingHistory(float quantity, String trigger, bool success) {
  if (WiFi.status() != WL_CONNECTED) return;

  String url = FIRESTORE_BASE + DEVICE_PATH + "feeding_history?key=" + FIREBASE_API_KEY;

  String payload = "{\"fields\":{"
    "\"quantity_grams\":{\"doubleValue\":" + String(quantity, 1) + "},"
    "\"trigger\":{\"stringValue\":\"" + trigger + "\"},"
    "\"success\":{\"booleanValue\":" + String(success ? "true" : "false") + "},"
    "\"timestamp\":{\"timestampValue\":\"" + getISOTimestamp() + "\"}"
  "}}";

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();

  HTTPClient http;
  http.begin(*client, url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);

  if (httpCode == 200 || httpCode == 201) {
    Serial.println("Feeding history logged!");
  } else {
    Serial.print("History log failed. HTTP: ");
    Serial.println(httpCode);
  }

  http.end();
}

// ─── FIRESTORE: CHECK SCHEDULES ─────────────────────────────

void checkSchedules() {
  if (WiFi.status() != WL_CONNECTED) return;

  // Get current time
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to get time for schedule check");
    return;
  }

  // Get current day abbreviation
  const char* dayNames[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
  String currentDay = dayNames[timeinfo.tm_wday];

  // Get current time as HH:MM
  char currentTime[6];
  sprintf(currentTime, "%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min);

  Serial.print("Schedule check - Day: ");
  Serial.print(currentDay);
  Serial.print(" Time: ");
  Serial.println(currentTime);

  // Query active schedules
  String url = FIRESTORE_BASE + DEVICE_PATH + "schedules?key=" + FIREBASE_API_KEY;

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();

  HTTPClient http;
  http.begin(*client, url);

  int httpCode = http.GET();

  if (httpCode == 200) {
    String response = http.getString();

    DynamicJsonDocument doc(4096);
    DeserializationError err = deserializeJson(doc, response);

    if (!err && doc.containsKey("documents")) {
      JsonArray documents = doc["documents"].as<JsonArray>();

      for (JsonObject document : documents) {
        bool active = document["fields"]["active"]["booleanValue"].as<bool>();
        if (!active) continue;

        String schedTime = document["fields"]["time"]["stringValue"].as<String>();

        // Check if current time matches schedule time
        if (String(currentTime) == schedTime) {
          // Check if current day is in the schedule's days array
          JsonArray days = document["fields"]["days"]["arrayValue"]["values"].as<JsonArray>();

          for (JsonVariant dayVal : days) {
            String day = dayVal["stringValue"].as<String>();
            if (day == currentDay) {
              float quantity = document["fields"]["quantity_grams"]["doubleValue"].as<float>();

              Serial.print("Schedule triggered! Dispensing ");
              Serial.print(quantity);
              Serial.println("g of feed");

              // Tell Arduino to start feeding
              Serial.println("START_FEED");

              // Log to feeding history
              delay(5000); // Wait for feeding to happen
              logFeedingHistory(quantity, "scheduled", true);

              break;
            }
          }
        }
      }
    }
  }

  http.end();
}

// ─── UTILITY: GET ISO TIMESTAMP ──────────────────────────────

String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-01-01T00:00:00Z"; // Fallback
  }

  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buf);
}

// ─── UTILITY: PRINT CURRENT TIME ─────────────────────────────

void printCurrentTime() {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    Serial.print("Current time: ");
    Serial.println(&timeinfo, "%Y-%m-%d %H:%M:%S");
  } else {
    Serial.println("Time not yet available");
  }
}

bool getLocalTime(struct tm *info) {
  time_t now = time(nullptr);
  if (now < 100000) return false; // Time not yet synced
  localtime_r(&now, info);
  return true;
}
