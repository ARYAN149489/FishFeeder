/*
 * AquaFeed — Arduino Uno R4 Minima Main Sketch
 * ==============================================
 * This sketch runs on the Arduino Uno R4 Minima.
 * It reads all water quality sensors, controls the servo feeder,
 * and communicates with the ESP8266 WiFi module via Software Serial.
 *
 * Pin Assignments:
 *   Pin 2  - HX711 DOUT (load cell data)
 *   Pin 3  - HX711 SCK  (load cell clock)
 *   Pin 5  - SG90 Servo  (feed dispenser)
 *   Pin 7  - ESP8266 TX -> Arduino RX (SoftwareSerial)
 *   Pin 8  - Arduino TX -> ESP8266 RX (SoftwareSerial)
 *   Pin 9  - DS18B20 Temperature (OneWire)
 *   A0     - Battery Voltage (via voltage divider)
 *   A1     - pH Sensor Module
 *   A2     - TDS Sensor Module
 *   A3     - Turbidity Sensor Module
 *   A4     - Solar Panel Voltage (via voltage divider)
 *
 * Required Libraries (install via Arduino IDE Library Manager):
 *   - OneWire
 *   - DallasTemperature
 *   - HX711
 *   - Servo (built-in)
 *   - SoftwareSerial (built-in)
 *   - ArduinoJson
 */

#include <SoftwareSerial.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <HX711.h>
#include <Servo.h>
#include <ArduinoJson.h>

// ─── PIN DEFINITIONS ─────────────────────────────────────────
#define ESP_RX_PIN       7    // Arduino receives FROM ESP8266
#define ESP_TX_PIN       8    // Arduino sends TO ESP8266
#define TEMP_PIN         9    // DS18B20 OneWire data
#define SERVO_PIN        5    // SG90 servo signal
#define HX711_DOUT_PIN   2    // HX711 data
#define HX711_SCK_PIN    3    // HX711 clock
#define PH_PIN           A1   // pH sensor analog
#define TDS_PIN          A2   // TDS sensor analog
#define TURBIDITY_PIN    A3   // Turbidity sensor analog
#define BATTERY_PIN      A0   // Battery voltage divider
#define SOLAR_PIN        A4   // Solar panel voltage divider

// ─── CALIBRATION CONSTANTS ───────────────────────────────────
// pH Sensor: Adjust these after calibrating with pH 4.0 and pH 7.0 buffers
#define PH_OFFSET        0.0  // Offset adjustment
#define PH_SLOPE         1.0  // Slope adjustment (default 1.0)

// TDS Sensor: Reference voltage
#define TDS_VREF         5.0  // Arduino reference voltage
#define TDS_TEMP_COEFF   0.02 // Temperature compensation coefficient

// Turbidity: Voltage to NTU mapping (approximate)
#define TURB_CLEAN_V     4.2  // Voltage in clean water
#define TURB_MAX_NTU     3000 // Max NTU reading

// HX711: Calibration factor (find this by calibrating with a known weight)
#define HX711_CALIBRATION_FACTOR  -7050.0  // Adjust after calibration!

// Battery: Voltage divider ratio (10k/10k = 2:1)
#define BATTERY_DIVIDER_RATIO  2.0
#define BATTERY_MAX_V    8.4   // Fully charged 2S LiPo
#define BATTERY_MIN_V    6.0   // Empty 2S LiPo

// Solar: Threshold voltage to detect charging
#define SOLAR_THRESHOLD_V  1.0

// Servo: Positions for feeding
#define SERVO_CLOSED     0     // Closed position (degrees)
#define SERVO_OPEN       90    // Open position (degrees)
#define FEED_DURATION_MS 3000  // How long to keep gate open per feeding (ms)

// ─── TIMING ──────────────────────────────────────────────────
#define SENSOR_INTERVAL_MS    30000  // Read sensors every 30 seconds
#define COMMAND_POLL_MS       5000   // Check for commands every 5 seconds

// ─── OBJECTS ─────────────────────────────────────────────────
SoftwareSerial espSerial(ESP_RX_PIN, ESP_TX_PIN);

OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensor(&oneWire);

HX711 scale;
Servo feedServo;

// ─── STATE VARIABLES ─────────────────────────────────────────
unsigned long lastSensorRead = 0;
unsigned long lastCommandPoll = 0;
bool isFeeding = false;
unsigned long feedStartTime = 0;

// Latest sensor values
float temperature = 0.0;
float phValue = 0.0;
float tdsValue = 0.0;
float turbidityNTU = 0.0;
float feedWeight = 0.0;
int   batteryPercent = 0;
bool  solarCharging = false;

// ─── SETUP ───────────────────────────────────────────────────
void setup() {
  // Debug serial (USB)
  Serial.begin(115200);
  Serial.println(F("AquaFeed Arduino Starting..."));

  // ESP8266 serial
  espSerial.begin(9600);

  // Temperature sensor
  tempSensor.begin();
  Serial.println(F("DS18B20 initialized"));

  // HX711 Load Cell
  scale.begin(HX711_DOUT_PIN, HX711_SCK_PIN);
  scale.set_scale(HX711_CALIBRATION_FACTOR);
  scale.tare(); // Reset to zero on startup
  Serial.println(F("HX711 initialized and tared"));

  // Servo
  feedServo.attach(SERVO_PIN);
  feedServo.write(SERVO_CLOSED);
  Serial.println(F("Servo initialized (closed)"));

  // Analog pins (input by default, but be explicit)
  pinMode(PH_PIN, INPUT);
  pinMode(TDS_PIN, INPUT);
  pinMode(TURBIDITY_PIN, INPUT);
  pinMode(BATTERY_PIN, INPUT);
  pinMode(SOLAR_PIN, INPUT);

  Serial.println(F("All sensors initialized. Waiting for ESP8266..."));

  // Give ESP8266 time to boot
  delay(3000);

  // Send a ready signal to ESP8266
  sendToESP("READY");

  Serial.println(F("AquaFeed Arduino Ready!"));
}

// ─── MAIN LOOP ───────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // 1. Read sensors periodically
  if (now - lastSensorRead >= SENSOR_INTERVAL_MS) {
    lastSensorRead = now;
    readAllSensors();
    sendSensorData();
  }

  // 2. Check for commands from ESP8266
  if (espSerial.available()) {
    String cmd = espSerial.readStringUntil('\n');
    cmd.trim();
    handleCommand(cmd);
  }

  // 3. Handle ongoing feeding (auto-close after duration)
  if (isFeeding && (now - feedStartTime >= FEED_DURATION_MS)) {
    stopFeeding();
  }
}

// ─── SENSOR READING FUNCTIONS ────────────────────────────────

void readAllSensors() {
  Serial.println(F("--- Reading All Sensors ---"));

  readTemperature();
  readPH();
  readTDS();
  readTurbidity();
  readFeedWeight();
  readBattery();
  readSolar();

  // Print to debug serial
  Serial.print(F("Temp: ")); Serial.print(temperature); Serial.println(F(" C"));
  Serial.print(F("pH: ")); Serial.println(phValue);
  Serial.print(F("TDS: ")); Serial.print(tdsValue); Serial.println(F(" ppm"));
  Serial.print(F("Turbidity: ")); Serial.print(turbidityNTU); Serial.println(F(" NTU"));
  Serial.print(F("Feed Weight: ")); Serial.print(feedWeight); Serial.println(F(" g"));
  Serial.print(F("Battery: ")); Serial.print(batteryPercent); Serial.println(F("%"));
  Serial.print(F("Solar: ")); Serial.println(solarCharging ? "Charging" : "Not Charging");
}

void readTemperature() {
  tempSensor.requestTemperatures();
  float t = tempSensor.getTempCByIndex(0);

  // DS18B20 returns -127.0 on error
  if (t != -127.0 && t != 85.0) {
    temperature = t;
  }
}

void readPH() {
  // Take multiple samples and average for stability
  long total = 0;
  for (int i = 0; i < 10; i++) {
    total += analogRead(PH_PIN);
    delay(10);
  }
  float avgAnalog = total / 10.0;

  // Convert analog reading to voltage (0-1023 -> 0-5V)
  float voltage = avgAnalog * (5.0 / 1023.0);

  // Convert voltage to pH
  // Most pH modules output: pH 7 = 2.5V, with ~0.18V per pH unit
  // Adjust PH_OFFSET and PH_SLOPE after calibration
  phValue = (PH_SLOPE * (3.5 * voltage)) + PH_OFFSET;

  // Clamp to valid range
  phValue = constrain(phValue, 0.0, 14.0);
}

void readTDS() {
  // Take multiple samples
  long total = 0;
  for (int i = 0; i < 10; i++) {
    total += analogRead(TDS_PIN);
    delay(10);
  }
  float avgAnalog = total / 10.0;

  // Convert to voltage
  float voltage = avgAnalog * (TDS_VREF / 1023.0);

  // Temperature compensation
  float compensationCoefficient = 1.0 + TDS_TEMP_COEFF * (temperature - 25.0);
  float compensatedVoltage = voltage / compensationCoefficient;

  // Convert voltage to TDS (ppm)
  // Formula from common TDS sensor modules
  tdsValue = (133.42 * compensatedVoltage * compensatedVoltage * compensatedVoltage
              - 255.86 * compensatedVoltage * compensatedVoltage
              + 857.39 * compensatedVoltage) * 0.5;

  if (tdsValue < 0) tdsValue = 0;
}

void readTurbidity() {
  // Take multiple samples
  long total = 0;
  for (int i = 0; i < 10; i++) {
    total += analogRead(TURBIDITY_PIN);
    delay(10);
  }
  float avgAnalog = total / 10.0;

  // Convert to voltage
  float voltage = avgAnalog * (5.0 / 1023.0);

  // Convert voltage to NTU
  // Clean water ~4.2V, very turbid water ~0V
  if (voltage >= TURB_CLEAN_V) {
    turbidityNTU = 0;
  } else {
    turbidityNTU = map(voltage * 100, 0, TURB_CLEAN_V * 100, TURB_MAX_NTU, 0);
  }

  if (turbidityNTU < 0) turbidityNTU = 0;
}

void readFeedWeight() {
  if (scale.is_ready()) {
    feedWeight = scale.get_units(5); // Average of 5 readings
    if (feedWeight < 0) feedWeight = 0;
  }
}

void readBattery() {
  int raw = analogRead(BATTERY_PIN);
  float voltage = (raw / 1023.0) * 5.0 * BATTERY_DIVIDER_RATIO;

  // Map voltage to percentage
  batteryPercent = map(voltage * 100, BATTERY_MIN_V * 100, BATTERY_MAX_V * 100, 0, 100);
  batteryPercent = constrain(batteryPercent, 0, 100);
}

void readSolar() {
  int raw = analogRead(SOLAR_PIN);
  float voltage = (raw / 1023.0) * 5.0 * 2.0; // Assuming same divider ratio
  solarCharging = (voltage > SOLAR_THRESHOLD_V);
}

// ─── COMMUNICATION WITH ESP8266 ─────────────────────────────

void sendSensorData() {
  // Build JSON string to send to ESP8266
  StaticJsonDocument<256> doc;
  doc["cmd"] = "SENSOR_DATA";
  doc["temp"] = round(temperature * 10.0) / 10.0;
  doc["ph"] = round(phValue * 10.0) / 10.0;
  doc["tds"] = round(tdsValue * 10.0) / 10.0;
  doc["turb"] = round(turbidityNTU * 10.0) / 10.0;
  doc["weight"] = round(feedWeight);
  doc["batt"] = batteryPercent;
  doc["solar"] = solarCharging;

  String jsonStr;
  serializeJson(doc, jsonStr);
  espSerial.println(jsonStr);

  Serial.print(F("Sent to ESP: "));
  Serial.println(jsonStr);
}

void sendToESP(const char* message) {
  espSerial.println(message);
}

// ─── COMMAND HANDLING ────────────────────────────────────────

void handleCommand(String cmd) {
  Serial.print(F("Received command: "));
  Serial.println(cmd);

  if (cmd == "START_FEED") {
    startFeeding();
    sendToESP("FEED_STARTED");
  }
  else if (cmd == "STOP_FEED") {
    stopFeeding();
    sendToESP("FEED_STOPPED");
  }
  else if (cmd == "READ_SENSORS") {
    readAllSensors();
    sendSensorData();
  }
  else if (cmd == "TARE_SCALE") {
    scale.tare();
    sendToESP("SCALE_TARED");
    Serial.println(F("Scale tared!"));
  }
  else if (cmd == "PING") {
    sendToESP("PONG");
  }
}

// ─── FEEDING CONTROL ────────────────────────────────────────

void startFeeding() {
  if (!isFeeding) {
    Serial.println(F("Starting feeding - opening servo gate..."));
    feedServo.write(SERVO_OPEN);
    isFeeding = true;
    feedStartTime = millis();
  }
}

void stopFeeding() {
  if (isFeeding) {
    Serial.println(F("Stopping feeding - closing servo gate..."));
    feedServo.write(SERVO_CLOSED);
    isFeeding = false;

    // Read weight after feeding to determine how much was dispensed
    delay(500); // Let things settle
    readFeedWeight();

    // Notify ESP8266 that feeding is complete
    StaticJsonDocument<128> doc;
    doc["cmd"] = "FEED_COMPLETE";
    doc["weight_after"] = feedWeight;
    String jsonStr;
    serializeJson(doc, jsonStr);
    espSerial.println(jsonStr);

    Serial.println(F("Feeding complete."));
  }
}
