#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>
#include <NTPClient.h>
#include <WiFiUdp.h>

#define DHTPIN 5    
#define DHTTYPE DHT11

struct DeviceConfig {
    String deviceName, deviceType, deviceLocation, orgName, orgType, topic, deviceId;
    String wifiSSID, wifiPassword;
    String userId, email, authToken, fcmToken;
};

extern DeviceConfig deviceConfig;
extern unsigned long previousMillis;
extern const long interval;
extern bool scheduleTriggered;
extern int previousDay;  

extern int targethour;
extern int targetminute;
extern bool targetdaily;

float readTemperature();
float readHumidity();
bool getSocketStatus();
float readBrightness();
bool checkNTPTime(NTPClient &timeClient);

void schedule();
void setData();

#endif
