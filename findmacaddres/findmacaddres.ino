#include <WiFi.h>

void setup(){
  Serial.begin(115200);

  WiFi.mode(WIFI_STA);   // IMPORTANT
  delay(100);            // give time

  Serial.print("MAC: ");
  Serial.println(WiFi.macAddress());
}

void loop(){}