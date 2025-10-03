#include <Arduino.h>
#include <FirebaseClient.h>
#include <WiFiClientSecure.h>
#include "WiFiManager.h"
#include "ServerManager.h"
#include "EEPROMManager.h"
#include "Auth.h"
#include "Config.h"

#define led_pin 2

unsigned long lastReconnectAttempt = 0;

bool taskComplete = false;

unsigned long lastUpdate = 0;
const unsigned long updateInterval = 300000;


void setup() {
    Serial.begin(115200);
    checkResetButton();
    pinMode(led_pin, OUTPUT);
    digitalWrite(led_pin, LOW);
    loadConfigFromEEPROM();
    if (isWiFiConfigured()) {
        Serial.println("Mencoba menyambungkan...");
        connectToWiFi();
        timeClient.begin();
        initializeFirebase();
    } else {
        startAccessPoint();
    }
}

void loop() {
    unsigned long currentMillis = millis();
    if (currentMillis - lastUpdate >= updateInterval) {
        lastUpdate = currentMillis;
        if (checkNTPTime(timeClient)) {
            updateData(); 
        } else {
            Serial.println("Update data ditunda karena gagal mendapatkan waktu NTP.");
        }
    }
    if (currentMillis - previousMillis >= interval) {
        previousMillis = currentMillis;  

        timeClient.update();  

        schedule();
    }
    if (!isAPMode && WiFi.status() != WL_CONNECTED && (currentMillis - lastReconnectAttempt >= 10000)) {
        digitalWrite(led_pin, LOW);
        Serial.println("WiFi terputus! Mencoba reconnect...");
        WiFi.disconnect();
        connectToWiFi();
        lastReconnectAttempt = currentMillis;
    }
    if (WiFi.status() == WL_CONNECTED) {
        digitalWrite(led_pin, HIGH);
    }
    if (isAPMode) { 
        server.handleClient();
        return;
    }
    JWT.loop(app.getAuth());
    checkResetButton();
    messaging.loop();
    app.loop();
    Database.loop();
    if(app.ready() && !taskComplete){
      taskComplete = true;
      setData();
    }
}


