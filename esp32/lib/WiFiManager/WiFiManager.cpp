#include "WiFiManager.h"
#include "EEPROMmanager.h"
#include <EEPROM.h>
#include <WiFi.h>
#include "ServerManager.h"

#define EEPROM_SIZE 512 

bool isAPMode = false;

void startAccessPoint() {
    WiFi.mode(WIFI_AP);
    WiFi.softAP("ESP32_Config");
    Serial.println("Access Point ESP32_Config aktif!");
    Serial.print("AP IP Address: ");
    Serial.println(WiFi.softAPIP());
    isAPMode = true; 
    setupServer();
}

void connectToWiFi() {
    Serial.println("Mencoba menyambungkan ke WiFi...");
    WiFi.mode(WIFI_STA);

    preferences.begin("device_config", true);
    String ssid = preferences.getString("ssid", "");
    String pass = preferences.getString("wifi_password", "");
    preferences.end();

    WiFi.begin(ssid.c_str(), pass.c_str());

    unsigned long startAttemptTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 20000) {  
        delay(50);
        Serial.print(".");
        checkResetButton();
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi Terhubung!");
        Serial.print("IP Address: ");
        Serial.println(WiFi.localIP());
        server.stop();
    } else {
        Serial.println("\nGagal menyambungkan ke WiFi. Masuk mode Access Point...");
    }
}

void resetConfig() {
    Serial.println("Menghapus semua konfigurasi di EEPROM (Preferences)...");

    preferences.begin("device_config", false);
    preferences.clear();  
    preferences.end();

    Serial.println("Konfigurasi berhasil dihapus! Restart ESP32...");
    isAPMode = true;
    delay(1000);
    ESP.restart();  
}

void checkResetButton() {
    pinMode(RESET_PIN, INPUT_PULLUP);  

    if (digitalRead(RESET_PIN) == LOW) {  
        Serial.println("Tombol Reset ditekan! Menghapus konfigurasi...");
        delay(3000); 

        if (digitalRead(RESET_PIN) == LOW) { 
            resetConfig();
        }
    }
}
