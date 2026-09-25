# AquaFeed — Arduino Hardware Setup & Wiring Guide

> **Complete guide to connect your Arduino Uno R4 Minima + ESP8266 WiFi module to Firebase Firestore**

---

## Components You Need

### What You Already Have
| Component | Pin | Type |
|---|---|---|
| Arduino Uno R4 Minima | — | Main microcontroller |
| DS18B20 Temperature Probe | Pin 9 (digital) | OneWire digital sensor |
| pH Sensor Module (MOD-QC3432) | Pin A1 (analog) | Analog 0–5V output |
| TDS Sensor Module | Pin A2 (analog) | Analog 0–5V output |
| Turbidity Sensor (MOD-QC2771) | Pin A3 (analog) | Analog 0–5V output |
| HX711 + Load Cell (feed weight) | DOUT→Pin 2, SCK→Pin 3 | Digital interface |
| Battery + Solar Panel | — | Power system |

### What You Need to Buy

| Component | Why | Approx Cost (INR) |
|---|---|---|
| **ESP8266 ESP-01 WiFi Module** | Connects Arduino to internet/Firebase | ₹150–250 |
| **ESP-01 Adapter / Breadboard Adapter** | Makes wiring ESP-01 easier (has 3.3V regulator) | ₹50–100 |
| **AMS1117 3.3V Voltage Regulator** (if no adapter) | ESP-01 runs on 3.3V, Arduino outputs 5V | ₹20 |
| **SG90 Servo Motor** | Rotates a flap/gate to dispense fish feed | ₹100–150 |
| **4.7kΩ Resistor** (1 piece) | Pull-up resistor for DS18B20 temperature sensor | ₹5 |
| **Voltage Divider Resistors** (10kΩ + 10kΩ) | To read battery voltage safely on analog pin | ₹10 |
| **Logic Level Shifter** (optional but recommended) | Safe 5V↔3.3V communication between Arduino and ESP-01 | ₹50 |

> **Recommended Servo:** The **SG90 Micro Servo** is perfect for a fish feeder. It rotates 0–180 degrees to open/close a feed gate or turn an auger. It runs directly on 5V from the Arduino.

---

## Complete Pin Assignment

| Arduino Pin | Connected To | Signal Type |
|---|---|---|
| **Pin 2** | HX711 DOUT | Digital (load cell data) |
| **Pin 3** | HX711 SCK | Digital (load cell clock) |
| **Pin 5** | SG90 Servo Signal (orange wire) | PWM |
| **Pin 7** | ESP8266 TX (via voltage divider) | Software Serial RX |
| **Pin 8** | ESP8266 RX | Software Serial TX |
| **Pin 9** | DS18B20 Data (with 4.7k pull-up to 5V) | OneWire Digital |
| **A0** | Battery Voltage (via voltage divider) | Analog |
| **A1** | pH Sensor Module Output | Analog |
| **A2** | TDS Sensor Module Output | Analog |
| **A3** | Turbidity Sensor Module Output | Analog |
| **A4** | Solar Panel Voltage (via voltage divider) | Analog |
| **5V** | Servo VCC (red), HX711 VCC, Sensor VCCs | Power |
| **3.3V** | ESP8266 VCC (via regulator or adapter) | Power |
| **GND** | All GNDs (common ground) | Ground |

---

## Critical Wiring Notes

### 1. DS18B20 Temperature Sensor
The 4.7k pull-up resistor between Data and 5V is MANDATORY. Without it, you will get -127 degree readings.
- DS18B20 Data pin -> Pin 9 (also connect 4.7k resistor from Data to 5V)
- DS18B20 VCC -> 5V
- DS18B20 GND -> GND

### 2. ESP8266 ESP-01 Module (3.3V ONLY!)
- VCC -> 3.3V (NEVER 5V, it will burn!)
- GND -> GND
- TX -> Pin 7 (Arduino SoftwareSerial RX)
- RX -> Pin 8 (Arduino SoftwareSerial TX) via voltage divider (1k + 2k)
- CH_PD (EN) -> 3.3V (tie HIGH to enable)
- GPIO0 -> 3.3V (tie HIGH for normal operation)

**Voltage Divider for Arduino TX to ESP8266 RX:**
Arduino Pin 8 outputs 5V which can damage ESP8266 RX. Use: Arduino Pin 8 -> 1k resistor -> ESP8266 RX, and 2k resistor from ESP8266 RX to GND.

### 3. Battery Voltage Monitoring
Use a voltage divider (10k + 10k) from Battery V+ to A0. This halves the voltage so a 0-8.4V LiPo reads as 0-4.2V (safe for Arduino 0-5V analog input).

### 4. Solar Panel Detection
Use a voltage divider (10k + 10k) from Solar Panel V+ to A4. If voltage on A4 is above a threshold (~1V), solar is charging.

### 5. SG90 Servo Motor
- Servo Orange (Signal) -> Pin 5
- Servo Red (VCC) -> 5V
- Servo Brown (GND) -> GND

---

## How the System Works

**Data Flow:**
1. **Sensor to Firebase:** Arduino reads sensors every 30s -> sends JSON to ESP8266 via Serial -> ESP8266 sends HTTP POST to Firestore REST API -> App reads it in real-time
2. **App to Arduino:** User taps Start Feeding -> writes command to Firestore -> ESP8266 polls for pending commands -> sends to Arduino via Serial -> Arduino activates servo motor
3. **Schedules:** ESP8266 polls active schedules from Firestore -> compares with current time -> tells Arduino to feed when schedule matches
