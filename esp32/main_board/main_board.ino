#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <DNSServer.h>
#include <esp_now.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ============================================
// SINRIC PRO CONFIGURATION (Google Voice Integration)
// ============================================
#define ENABLE_SINRIC_PRO  true  // Change to false to disable Sinric Pro

#if ENABLE_SINRIC_PRO
  #include "SinricPro.h"
  #include "SinricProSwitch.h"

  #define APP_KEY       "YOUR-SINRIC-APP-KEY"      // Replace with your Sinric Pro App Key
  #define APP_SECRET    "YOUR-SINRIC-APP-SECRET"   // Replace with your Sinric Pro App Secret

  // Place Switch Device IDs from Sinric Pro here.
  // Generate a switch for each relay you want to control.
  const char* SINRIC_SWITCH_IDS[8] = {
    "YOUR-DEVICE-ID-FOR-SWITCH-1",
    "YOUR-DEVICE-ID-FOR-SWITCH-2",
    "YOUR-DEVICE-ID-FOR-SWITCH-3",
    "YOUR-DEVICE-ID-FOR-SWITCH-4",
    "YOUR-DEVICE-ID-FOR-SWITCH-5",
    "YOUR-DEVICE-ID-FOR-SWITCH-6",
    "YOUR-DEVICE-ID-FOR-SWITCH-7",
    "YOUR-DEVICE-ID-FOR-SWITCH-8"
  };
#endif


// ============================================
// PIN DEFINITIONS
// ============================================

const uint8_t relayPins[8] = {13, 12, 14, 27, 26, 25, 33, 32};
const uint8_t switchPins[8] = {4, 16, 17, 5, 18, 19, 21, 22};

#define RESET_BUTTON  0
#define STATUS_LED    2

// ============================================
// CONSTANTS
// ============================================

#define MAX_RELAYS      8
#define DEBOUNCE_DELAY  50
#define BUTTON_DEBOUNCE 200
#define RESET_HOLD_TIME 5000
#define AP_TIMEOUT      300000
#define WIFI_TIMEOUT    15000
#define CLOUD_SYNC_INTERVAL 500

// Set your deployed backend API server URL here
// Replace with correct local IP address like "http://192.168.1.X:3000" or a cloud domain.
const char* SERVER_URL = "http://192.168.29.254:3000"; 

// ============================================
// ESP-NOW STRUCTURE
// ============================================

typedef struct {
  uint8_t cmd;        // 1 = toggle relay
  uint8_t relayNum;
} Message;

// ============================================
// GLOBAL VARIABLES
// ============================================

WebServer server(80);
Preferences prefs;
DNSServer dnsServer;

uint8_t relayCount = MAX_RELAYS;
bool relayState[8] = {false};
bool lastSwitchState[8] = {false};
unsigned long lastDebounceTime[8] = {0};

bool configured = false;
bool apModeActive = false;
unsigned long apStartTime = 0;

String wifiSSID = "";
String wifiPassword = "";
String deviceToken = "";
bool wifiConnected = false;

// Cloud Sync
unsigned long lastCloudSync = 0;
bool statusNeedsUpdate = true;

// ESP-NOW
Message incomingMsg;
uint8_t remoteMAC[6] = {0};
bool remotePaired = false;

// Button variables
unsigned long resetPressStart = 0;
bool resetTriggered = false;
bool lastResetState = HIGH;
unsigned long lastResetDebounce = 0;
bool resetButtonPressed = false;

// LED
unsigned long lastLedBlink = 0;
bool ledState = false;
String mainMAC = "";

// ============================================
// FUNCTION DECLARATIONS
// ============================================

void setupPins();
void loadConfiguration();
void saveConfiguration();
void initRelays();
void controlRelay(uint8_t relay, bool state, bool reportToCloud = true);
void toggleRelay(uint8_t relay, bool reportToCloud = true);
void checkManualSwitches();
void checkResetButton();
void connectToWiFi();
void startAPMode();
void stopAPMode();
void setupWebServer();
void handleRoot();
void handleConfig();
void handleControl();
void handleStatus();
void handleAddRemote();
void handleRemoveRemote();
void handleReset();
void factoryReset();
void blinkLED(int times, int duration);
void updateLEDStatus();
bool isValidRelayCount(uint8_t count);
String getMacAddress();

// ESP-NOW functions
void initESPNow();
void addRemotePeer(String macStr);

// Cloud Functions
void cloudRegister();
void fetchCloudCommands();
void sendCloudStatus();

#if ENABLE_SINRIC_PRO
bool onPowerState(const String &deviceId, bool &state);
void updateSinricState(int relayIndex, bool state);
#endif

// ============================================
// SINRIC PRO IMPLEMENTATIONS
// ============================================
#if ENABLE_SINRIC_PRO
bool onPowerState(const String &deviceId, bool &state) {
  int relayIndex = -1;
  for (int i = 0; i < relayCount; i++) {
    if (deviceId == SINRIC_SWITCH_IDS[i]) {
      relayIndex = i;
      break;
    }
  }
  
  if (relayIndex != -1) {
    Serial.printf("[SinricPro] Turn Relay %d %s\n", relayIndex + 1, state ? "ON" : "OFF");
    if (relayIndex < relayCount) {
      relayState[relayIndex] = state;
      digitalWrite(relayPins[relayIndex], state ? LOW : HIGH);
      statusNeedsUpdate = true;
      Serial.printf("Relay %d toggled via SinricPro to %s\n", relayIndex + 1, state ? "ON" : "OFF");
    }
    return true;
  }
  return false;
}

void updateSinricState(int relayIndex, bool state) {
  if (relayIndex >= 0 && relayIndex < 8) {
    if (strlen(SINRIC_SWITCH_IDS[relayIndex]) > 0 && String(SINRIC_SWITCH_IDS[relayIndex]) != "YOUR-DEVICE-ID-FOR-SWITCH-" + String(relayIndex+1)) {
      SinricProSwitch& mySwitch = SinricPro[SINRIC_SWITCH_IDS[relayIndex]];
      mySwitch.sendPowerStateEvent(state);
    }
  }
}
#endif

// ============================================
// SETUP
// ============================================

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=========================================");
  Serial.println("Smart Home System - Main Board");
  Serial.println("=========================================\n");
  
  setupPins();
  loadConfiguration();
  initRelays();
  
  WiFi.mode(WIFI_STA);
  delay(200);  
  
  mainMAC = getMacAddress();
  Serial.print("Main Board MAC Address: ");
  Serial.println(mainMAC);
  
  initESPNow();
  
  if (configured && wifiSSID.length() > 0) {
    connectToWiFi();
    if(wifiConnected && deviceToken.length() > 0) {
       cloudRegister();
       sendCloudStatus(); // Initial status push
       
       #if ENABLE_SINRIC_PRO
         // Register switches in SinricPro
         for (int i = 0; i < relayCount; i++) {
           if (strlen(SINRIC_SWITCH_IDS[i]) > 0 && String(SINRIC_SWITCH_IDS[i]) != "YOUR-DEVICE-ID-FOR-SWITCH-" + String(i+1)) {
             SinricProSwitch& mySwitch = SinricPro[SINRIC_SWITCH_IDS[i]];
             mySwitch.onPowerState(onPowerState);
           }
         }
         SinricPro.begin(APP_KEY, APP_SECRET);
         Serial.println("[SinricPro] Initialized and connected to SinricPro Server");
       #endif
    }
  } else {
    startAPMode();
  }
  
  setupWebServer();
  
  Serial.println("\nSystem Ready!");
  Serial.printf("Manual control active for %d relay(s)\n", relayCount);
  blinkLED(2, 200);
}

// ============================================
// CLOUD API COMMUNICATION
// ============================================

void cloudRegister() {
  if (WiFi.status() != WL_CONNECTED || deviceToken == "") return;
  
  HTTPClient http;
  String url = String(SERVER_URL) + "/api/device/register";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Device-Token", deviceToken);
  
  StaticJsonDocument<200> doc;
  doc["mainMAC"] = mainMAC;
  doc["relayCount"] = relayCount;
  
  String requestBody;
  serializeJson(doc, requestBody);
  
  int httpResponseCode = http.POST(requestBody);
  if(httpResponseCode > 0){
    Serial.printf("Cloud Register Success! Code: %d\n", httpResponseCode);
    String payload = http.getString();
    DynamicJsonDocument responseDoc(256);
    deserializeJson(responseDoc, payload);
    
    if(responseDoc.containsKey("relayCount")) {
      uint8_t newCount = responseDoc["relayCount"].as<uint8_t>();
      if (newCount != relayCount && newCount > 0 && newCount <= 16) {
        relayCount = newCount;
        Serial.printf("Cloud Config: Updating relay capability to %d\n", relayCount);
        prefs.begin("system", false);
        prefs.putUChar("relayCount", relayCount);
        prefs.end();
        initRelays();
      }
    }

    if(responseDoc.containsKey("remoteMAC")) {
      const char* rMac = responseDoc["remoteMAC"];
      if (rMac && strlen(rMac) > 0 && !remotePaired) {
        Serial.println("Received Remote MAC from server: " + String(rMac));
        addRemotePeer(String(rMac));
      }
    }
  } else {
    Serial.printf("Cloud Register Failed. Error: %s\n", http.errorToString(httpResponseCode).c_str());
  }
  http.end();
}

void fetchCloudCommands() {
  if (WiFi.status() != WL_CONNECTED || deviceToken == "") return;
  
  HTTPClient http;
  String url = String(SERVER_URL) + "/api/device/commands";
  http.begin(url);
  http.addHeader("Device-Token", deviceToken);
  
  int httpResponseCode = http.GET();
  if (httpResponseCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(512);
    deserializeJson(doc, payload);
    
    JsonObject commands = doc["commands"];
    if (!commands.isNull()) {
      bool changed = false;
      for (JsonPair kv : commands) {
        int relayIdx = String(kv.key().c_str()).toInt();
        bool desiredState = kv.value().as<bool>();
        
        if (relayIdx >= 0 && relayIdx < relayCount) {
          if (relayState[relayIdx] != desiredState) {
            controlRelay(relayIdx, desiredState, false); // Don't report back standard updates immediately
            changed = true;
          }
        }
      }
      if (changed) {
        statusNeedsUpdate = true;
      }
    }
  }
  http.end();
}

void sendCloudStatus() {
  if (WiFi.status() != WL_CONNECTED || deviceToken == "") return;
  
  HTTPClient http;
  String url = String(SERVER_URL) + "/api/device/update";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Device-Token", deviceToken);
  
  DynamicJsonDocument doc(512);
  JsonArray relaysArray = doc.createNestedArray("relays");
  for (int i=0; i<relayCount; i++) {
    relaysArray.add(relayState[i]);
  }
  
  String requestBody;
  serializeJson(doc, requestBody);
  
  int httpResponseCode = http.POST(requestBody);
  if(httpResponseCode == 200){
    statusNeedsUpdate = false;
  } else {
    Serial.println("Warning: Cloud update failed");
  }
  http.end();
}

// ============================================
// GET MAC ADDRESS
// ============================================

String getMacAddress() {
  WiFi.mode(WIFI_STA);
  delay(200);
  
  uint8_t mac[6];
  WiFi.macAddress(mac);
  
  char buffer[18];
  sprintf(buffer, "%02X:%02X:%02X:%02X:%02X:%02X", 
          mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  
  return String(buffer);
}

// ============================================
// ESP-NOW FUNCTIONS
// ============================================

void initESPNow() {
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED!");
    return;
  }
  
  Serial.println("ESP-NOW init SUCCESS");
  
  esp_now_register_recv_cb([](const esp_now_recv_info_t *info, const uint8_t *data, int len) {
    memcpy(&incomingMsg, data, sizeof(incomingMsg));
    
    if (incomingMsg.cmd == 1 && remotePaired) {
      if (incomingMsg.relayNum < relayCount) {
        toggleRelay(incomingMsg.relayNum, true); // Report to cloud!
        Serial.printf("Remote toggled relay %d\n", incomingMsg.relayNum + 1);
        blinkLED(1, 50);
      }
    }
  });

  if (remotePaired) {
    esp_now_peer_info_t peer;
    memset(&peer, 0, sizeof(peer));
    memcpy(peer.peer_addr, remoteMAC, 6);
    peer.channel = 0;
    peer.encrypt = false;
    peer.ifidx = WIFI_IF_STA;
    if (esp_now_add_peer(&peer) == ESP_OK) {
      Serial.println("Auto restored remote peer from flash!");
    }
  }
}

void addRemotePeer(String macStr) {
  int mac[6];
  sscanf(macStr.c_str(), "%x:%x:%x:%x:%x:%x", 
         &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]);
  
  for (int i = 0; i < 6; i++) remoteMAC[i] = (uint8_t)mac[i];
  
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, remoteMAC, 6);
  peer.channel = 0;
  peer.encrypt = false;
  peer.ifidx = WIFI_IF_STA;
  
  if (esp_now_add_peer(&peer) == ESP_OK) {
    remotePaired = true;
    prefs.begin("system", false);
    prefs.putBool("remotePaired", true);
    for (int i = 0; i < 6; i++) {
      prefs.putUChar(("remoteMAC" + String(i)).c_str(), remoteMAC[i]);
    }
    prefs.end();
    Serial.println("Remote peer added successfully!");
    blinkLED(3, 150);
  }
}

// ============================================
// HARDWARE FUNCTIONS
// ============================================

void setupPins() {
  for (int i = 0; i < MAX_RELAYS; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH);
    pinMode(switchPins[i], INPUT_PULLUP);
    lastSwitchState[i] = digitalRead(switchPins[i]);
  }
  pinMode(RESET_BUTTON, INPUT_PULLUP);
  pinMode(STATUS_LED, OUTPUT);
}

void initRelays() {
  for (int i = 0; i < relayCount; i++) {
    digitalWrite(relayPins[i], HIGH);
    relayState[i] = false;
  }
}

void controlRelay(uint8_t relay, bool state, bool reportToCloud) {
  if (relay >= relayCount) return;
  relayState[relay] = state;
  digitalWrite(relayPins[relay], state ? LOW : HIGH); // LOW is ON for most modules
  Serial.printf("Relay %d: %s\n", relay + 1, state ? "ON" : "OFF");
  
  if (reportToCloud) {
    statusNeedsUpdate = true;
  }

  #if ENABLE_SINRIC_PRO
    updateSinricState(relay, state);
  #endif
}

void toggleRelay(uint8_t relay, bool reportToCloud) {
  if (relay >= relayCount) return;
  controlRelay(relay, !relayState[relay], reportToCloud);
}

void checkManualSwitches() {
  for (int i = 0; i < relayCount; i++) {
    bool currentState = digitalRead(switchPins[i]);
    if (currentState != lastSwitchState[i]) {
      if (millis() - lastDebounceTime[i] > DEBOUNCE_DELAY) {
        if (currentState == LOW) {
          toggleRelay(i, true);
          blinkLED(1, 50);
        }
        lastDebounceTime[i] = millis();
      }
    }
    lastSwitchState[i] = currentState;
  }
}

void checkResetButton() {
  bool currentState = digitalRead(RESET_BUTTON);
  if (currentState != lastResetState) lastResetDebounce = millis();
  
  if ((millis() - lastResetDebounce) > BUTTON_DEBOUNCE) {
    if (currentState != resetButtonPressed) {
      resetButtonPressed = currentState;
      if (resetButtonPressed == LOW) {
        resetPressStart = millis();
        resetTriggered = false;
      } else {
        resetPressStart = 0;
      }
    }
  }
  lastResetState = currentState;
  
  if (resetButtonPressed == LOW && !resetTriggered && resetPressStart > 0) {
    unsigned long holdDuration = millis() - resetPressStart;
    if (holdDuration >= RESET_HOLD_TIME - 1000 && holdDuration < RESET_HOLD_TIME) {
      if ((millis() % 200) < 100) digitalWrite(STATUS_LED, HIGH);
      else digitalWrite(STATUS_LED, LOW);
    }
    if (holdDuration >= RESET_HOLD_TIME && !resetTriggered) {
      factoryReset();
      resetTriggered = true;
    }
  }
}

// ============================================
// WIFI FUNCTIONS
// ============================================

void connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startTime < WIFI_TIMEOUT) {
    delay(500);
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println("\nWiFi Connected!");
    blinkLED(3, 150);
  } else {
    wifiConnected = false;
    Serial.println("\nWiFi failed - Starting AP mode");
    startAPMode();
  }
}

void startAPMode() {
  WiFi.mode(WIFI_AP);
  bool apStarted = WiFi.softAP("HomeAuto_Setup", "12345678");
  if (apStarted) {
    dnsServer.start(53, "*", WiFi.softAPIP());
    apModeActive = true;
    apStartTime = millis();
    wifiConnected = false;
    blinkLED(5, 100);
    Serial.println("Started AP Setup on HomeAuto_Setup");
  }
}

void stopAPMode() {
  if (!apModeActive) return;
  dnsServer.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_OFF);
  apModeActive = false;
}

// ============================================
// CONFIGURATION STORAGE
// ============================================

void loadConfiguration() {
  prefs.begin("system", false);
  configured = prefs.getBool("configured", false);
  wifiSSID = prefs.getString("wifiSSID", "");
  wifiPassword = prefs.getString("wifiPass", "");
  deviceToken = prefs.getString("devToken", "");
  remotePaired = prefs.getBool("remotePaired", false);
  relayCount = prefs.getUChar("relayCount", MAX_RELAYS);
  
  if (remotePaired) {
    for (int i = 0; i < 6; i++) {
      remoteMAC[i] = prefs.getUChar(("remoteMAC" + String(i)).c_str(), 0);
    }
  }
  prefs.end();

}

void saveConfiguration() {
  prefs.begin("system", false);
  prefs.putBool("configured", true);
  prefs.putString("wifiSSID", wifiSSID);
  prefs.putString("wifiPass", wifiPassword);
  prefs.putString("devToken", deviceToken);
  prefs.putUChar("relayCount", relayCount);
  prefs.end();
  configured = true;
}

bool isValidRelayCount(uint8_t count) {
  return (count == 1 || count == 2 || count == 4 || count == 8);
}

// ============================================
// WEB SERVER (AP MODE ONLY / BASIC CONFIG)
// ============================================

void setupWebServer() {
  server.on("/", handleRoot);
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/control", HTTP_GET, handleControl);
  server.on("/addremote", HTTP_POST, handleAddRemote);
  server.on("/removeremote", HTTP_POST, handleRemoveRemote);
  server.on("/reset", handleReset);
  server.begin();
}

void handleRoot() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>Smart Home - Main Board</title>
    <style>
        body { font-family: Arial; background: #667eea; padding: 20px; color:#333;}
        .container { max-width: 500px; margin: auto; background: white; border-radius: 10px; overflow: hidden; padding: 20px;}
        input, select { width: 100%; padding: 10px; margin-bottom: 15px; border: 1px solid #ddd; box-sizing:border-box;}
        button { width: 100%; padding: 12px; background: #667eea; color: white; border: none; cursor: pointer; border-radius:5px;}
        .mac-box { background: #e3f2fd; padding: 10px; text-align: center; margin-bottom: 20px;}
    </style>
</head>
<body>
    <div class='container'>
        <h2 style='text-align:center;'>🏠 Main Board Setup</h2>
)rawliteral";

  if (!configured) {
    html += R"rawliteral(
        <form action='/config' method='POST'>
            <label>16-char Device Token (from Web Dashboard)</label>
            <input type='text' name='deviceToken' required placeholder='e.g. A1B2C3D4E5F6G7H8'>
            <label>WiFi SSID</label>
            <input type='text' name='ssid' required>
            <label>WiFi Password</label>
            <input type='password' name='password'>
            <button type='submit'>Save Configuration</button>
        </form>
)rawliteral";
  } else {
    html += "<div class='mac-box'><h3>MAC: " + mainMAC + "</h3></div>";
    html += "<p><b>Status: Configured</b><br>";
    html += "Running normally. Configuration is securely pulled from the cloud.</p>";
    if(remotePaired) {
      html += "<p style='color: green;'><b>Remote: Paired</b></p>";
    } else {
      html += "<p><b>Remote: Not Paired</b></p>";
    }
  }
  
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

void handleConfig() {
  if (server.hasArg("ssid")) {
    wifiSSID = server.arg("ssid");
    wifiPassword = server.arg("password");
    deviceToken = server.arg("deviceToken");
    
    saveConfiguration();
    initRelays();
    
    server.send(200, "text/html", "<h2>Saved. Restarting...</h2>");
    delay(2000);
    ESP.restart();
  }
}

void handleAddRemote() {
  if (server.hasArg("remotemac")) {
    addRemotePeer(server.arg("remotemac"));
    server.send(200, "text/html", "<h2>Remote added. Restarting...</h2>");
    delay(1000); ESP.restart();
  }
}

void handleRemoveRemote() {
  prefs.begin("system", false);
  prefs.putBool("remotePaired", false);
  for (int i = 0; i < 6; i++) prefs.putUChar(("remoteMAC" + String(i)).c_str(), 0);
  prefs.end();
  server.send(200, "text/html", "<h2>Removed. Restarting...</h2>");
  delay(1000); ESP.restart();
}

void handleControl() {
  if (server.hasArg("relay") && server.hasArg("state")) {
    int relay = server.arg("relay").toInt();
    int state = server.arg("state").toInt();
    controlRelay(relay, state == 1, true); // True to report to Cloud
    server.send(200, "text/plain", "OK");
  }
}

void handleReset() {
  factoryReset();
}

// ============================================
// SYSTEM FUNCTIONALITY
// ============================================

void factoryReset() {
  for (int i = 0; i < 15; i++) { digitalWrite(STATUS_LED, HIGH); delay(100); digitalWrite(STATUS_LED, LOW); delay(100); }
  prefs.begin("system", false);
  prefs.clear();
  prefs.end();
  delay(1000);
  ESP.restart();
}

void blinkLED(int times, int duration) {
  for (int i = 0; i < times; i++) {
    digitalWrite(STATUS_LED, HIGH); delay(duration);
    digitalWrite(STATUS_LED, LOW); delay(duration);
  }
}

void updateLEDStatus() {
  if (apModeActive) {
    if (millis() - lastLedBlink > 300) { ledState = !ledState; digitalWrite(STATUS_LED, ledState); lastLedBlink = millis(); }
  } else if (!configured) {
    if (millis() - lastLedBlink > 200) { ledState = !ledState; digitalWrite(STATUS_LED, ledState); lastLedBlink = millis(); }
  } else {
    digitalWrite(STATUS_LED, HIGH);
  }
}

// ============================================
// MAIN LOOP
// ============================================

void loop() {
  server.handleClient();
  checkManualSwitches();
  checkResetButton();
  updateLEDStatus();
  
  if (apModeActive) {
    dnsServer.processNextRequest();
  }
  
  // Cloud Sync Logic
  if (configured && !apModeActive && wifiConnected) {
    #if ENABLE_SINRIC_PRO
      SinricPro.handle();
    #endif

    if (millis() - lastCloudSync > CLOUD_SYNC_INTERVAL) {
      fetchCloudCommands(); // Acts as a ping + receiver
      if (statusNeedsUpdate) {
        sendCloudStatus();
      }
      lastCloudSync = millis();
    }
  }
}
