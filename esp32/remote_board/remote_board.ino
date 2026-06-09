#include <WiFi.h>
#include <esp_now.h>

// ============================================
// UPLOAD-TIME CONFIGURATION
// ============================================
// Set the relay count to match your Main Board (usually 8)
const uint8_t relayCount = 8; 

// Enter the MAC Address of your Main Board here.
// You can find the Main Board's MAC address in the Main Board's Serial Monitor or Setup Portal.
// Replace the placeholder values below with your Main Board's actual MAC bytes (e.g. 0x24, 0x0A, etc.)
const uint8_t mainMAC[6] = {0x3C, 0x8A, 0x1F, 0x0B, 0x042, 0x48}; 

// ============================================
// PIN DEFINITIONS
// ============================================
const uint8_t buttonPins[8] = {4, 16, 17, 5, 18, 19, 21, 22};
#define STATUS_LED    2

// ============================================
// CONSTANTS
// ============================================
#define MAX_BUTTONS    8
#define DEBOUNCE_DELAY 50

// ============================================
// ESP-NOW STRUCTURE (Must match main board)
// ============================================
typedef struct {
  uint8_t cmd;        // 1 = toggle relay
  uint8_t relayNum;
} Message;

// ============================================
// GLOBAL VARIABLES
// ============================================
Message msg;
bool lastButtonState[8] = {false};
unsigned long lastDebounceTime[8] = {0};

// ============================================
// FUNCTION DECLARATIONS
// ============================================
void setupPins();
void initESPNow();
void sendCommand(uint8_t relay);
void checkButtons();
void blinkLED(int times, int duration);

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=========================================");
  Serial.println("Smart Home - Remote Board (Simple Upload-Time Config)");
  Serial.println("=========================================\n");
  
  setupPins();
  
  // ESP-NOW requires WiFi mode to be STA, but no connection to router is needed!
  WiFi.mode(WIFI_STA);
  delay(100);
  
  // Print this board's MAC address (in case the user needs it for the main board)
  Serial.print("Remote Board MAC Address: ");
  Serial.println(WiFi.macAddress());
  
  initESPNow();
  
  // Keep STATUS_LED solid ON to show powered and ready status
  digitalWrite(STATUS_LED, HIGH);
  Serial.println("\nRemote Board Ready!");
  Serial.printf("Configured Main Board MAC: %02X:%02X:%02X:%02X:%02X:%02X\n", 
                mainMAC[0], mainMAC[1], mainMAC[2], mainMAC[3], mainMAC[4], mainMAC[5]);
  Serial.printf("Relay Count: %d\n", relayCount);
  
  blinkLED(2, 200);
  digitalWrite(STATUS_LED, HIGH); // Stay solid ON
}

// ============================================
// LOOP
// ============================================
void loop() {
  checkButtons();
}

// ============================================
// ESP-NOW FUNCTIONS
// ============================================
void initESPNow() {
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED!");
    blinkLED(5, 100);
    return;
  }
  
  Serial.println("ESP-NOW init SUCCESS");
  
  // Register main board peer
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, mainMAC, 6);
  peer.channel = 0;
  peer.encrypt = false;
  peer.ifidx = WIFI_IF_STA;
  
  if (esp_now_add_peer(&peer) == ESP_OK) {
    Serial.println("Main board peer registered successfully!");
  } else {
    Serial.println("Failed to register main board peer!");
    blinkLED(4, 150);
  }
}

void sendCommand(uint8_t relay) {
  msg.cmd = 1;
  msg.relayNum = relay;
  
  Serial.printf("Sending ESP-NOW command for relay %d...\n", relay + 1);
  esp_err_t result = esp_now_send(mainMAC, (uint8_t*)&msg, sizeof(msg));
  
  if (result == ESP_OK) {
    Serial.println("Send Success!");
    // Briefly blink status LED to give feedback
    digitalWrite(STATUS_LED, LOW);
    delay(50);
    digitalWrite(STATUS_LED, HIGH);
  } else {
    Serial.println("Send Failed!");
    // Fast double blink to indicate error
    blinkLED(2, 50);
    digitalWrite(STATUS_LED, HIGH);
  }
}

// ============================================
// HARDWARE FUNCTIONS
// ============================================
void setupPins() {
  for (int i = 0; i < MAX_BUTTONS; i++) {
    pinMode(buttonPins[i], INPUT_PULLUP);
    lastButtonState[i] = digitalRead(buttonPins[i]);
  }
  
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);
  Serial.println("Button pins and Status LED initialized.");
}

void checkButtons() {
  for (int i = 0; i < MAX_BUTTONS; i++) {
    bool currentState = digitalRead(buttonPins[i]);
    
    if (currentState != lastButtonState[i]) {
      if (millis() - lastDebounceTime[i] > DEBOUNCE_DELAY) {
        if (currentState == LOW) {
          if (i < relayCount) {
            sendCommand(i);
            Serial.printf("Button %d pressed -> Toggled relay %d\n", i + 1, i + 1);
          } else {
            Serial.printf("Button %d pressed -> Ignored (Relay index exceeds relayCount of %d)\n", i + 1, relayCount);
            blinkLED(2, 100);
            digitalWrite(STATUS_LED, HIGH);
          }
        }
        lastDebounceTime[i] = millis();
      }
    }
    lastButtonState[i] = currentState;
  }
}

void blinkLED(int times, int duration) {
  for (int i = 0; i < times; i++) {
    digitalWrite(STATUS_LED, HIGH);
    delay(duration);
    digitalWrite(STATUS_LED, LOW);
    delay(duration);
  }
}