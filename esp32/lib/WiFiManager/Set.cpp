#include "Auth.h"
#include "EEPROMmanager.h"
#include "Config.h"
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <DHT.h>
#include <FirebaseClient.h>
#include <WiFiClientSecure.h>

WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 7 * 3600, 60000);

DHT dht(DHTPIN, DHTTYPE);

RealtimeDatabase Database;
Messaging messaging;

bool checkNTPTime(NTPClient &timeClient) {
    int ntpRetries = 5; 
    while (ntpRetries > 0) {
        timeClient.update();
        time_t epochTime = timeClient.getEpochTime();
        if (epochTime >= 1000000000) { // Waktu valid
            struct tm *timeInfo = gmtime(&epochTime);
            int tahun = timeInfo->tm_year + 1900; 
            int bulan = timeInfo->tm_mon + 1;     
            int tanggal = timeInfo->tm_mday;
            int jam = timeInfo->tm_hour;
            int menit = timeInfo->tm_min;
            int detik = timeInfo->tm_sec;
            Serial.print("Sinkronisasi NTP Berhasil: ");
            Serial.printf("%04d-%02d-%02d %02d:%02d:%02d UTC\n", tahun, bulan, tanggal, jam, menit, detik);
            return true;
        }
        Serial.println("NTP Sync Gagal! Mencoba ulang...");
        ntpRetries--;
        delay(2000); 
    }
    Serial.println("Gagal sinkronisasi NTP setelah 5 kali percobaan.");
    return false;
}

float readTemperature() {
    return dht.readTemperature();
}

float readHumidity() {
    return dht.readHumidity();
}

float readBrightness() {
    return analogRead(34);
}

bool getSocketStatus() {
    return digitalRead(33) == HIGH;
}
void schedule() {
    int currentHour = timeClient.getHours();
    int currentMinute = timeClient.getMinutes();
    int currentDay = timeClient.getDay();
    if (currentDay != previousDay) {
        Serial.println("New day detected, resetting schedule trigger.");
        scheduleTriggered = false;  
        previousDay = currentDay;  
    }

    if (targetdaily) {
        if (currentHour == targethour && currentMinute == targetminute) {
            if (!scheduleTriggered) {
                Serial.println("Schedule triggered!");
                scheduleTriggered = true;  
                float currentTemp = readTemperature();
                // filterTemperatureData();  
                Serial.println("fetching");
                // fetchTemperatureData();
                fetchAllTemperatureData();
                delay(100);
            }
        } else {
            if (scheduleTriggered) {
                Serial.println("Schedule no longer triggered.");
                scheduleTriggered = false;
            }
        }
    }
}
void getMsg(Messages::Message &msg){
    // msg.token(fcmToken); 
    msg.topic(deviceConfig.topic);
    // msg.topic("tt");

    Messages::Notification notification;
    String titled = "Dari " + String(deviceConfig.deviceName);
    notification.body("HELLLLOOOOOO 🎉").title(titled);
    Serial.println(deviceConfig.topic);

    msg.notification(notification);

    object_t data, obj1, obj2;
    JsonWriter writer;
    writer.create(obj1, "key1", string_t("value1"));
    writer.create(obj2, "key2", string_t("value2"));
    writer.join(data, 2, obj1, obj2);
    msg.data(data);

    Messages::AndroidConfig androidConfig;
    androidConfig.priority(Messages::AndroidMessagePriority::_HIGH);

    Messages::AndroidNotification androidNotification;
    androidNotification.notification_priority(Messages::NotificationPriority::PRIORITY_HIGH);
    androidConfig.notification(androidNotification);

    msg.android(androidConfig);
}
void setData(){
    String devicePath = "devices/" + String(deviceConfig.deviceId) + "/schedule";

    Messages::Message msg;
    getMsg(msg);
    Serial.println("Sending Message. . .");
    messaging.send(aClient,Messages::Parent(FIREBASE_PROJECT_ID), msg, asyncCB, "fcmSendTask");
    Database.get(aClient, devicePath, asyncCB, true /* SSE mode (HTTP Streaming) */, "streamTask");
}
void updateData() {
    if (WiFi.status() == WL_CONNECTED) {
        String path = "/devices/" + String(deviceConfig.deviceId) + "/";
        if (String(deviceConfig.deviceType) == "Sensor") {
            float temperature = readTemperature();
            float humidity = readHumidity();
            timeClient.update();
            time_t epochTime = timeClient.getEpochTime();
            struct tm* timeInfo = gmtime(&epochTime);
            char formattedTime[20];
            strftime(formattedTime, sizeof(formattedTime), "%Y-%m-%dT%H:%M:%SZ", timeInfo);
            String timestamp = String(formattedTime);

            String temperaturePath = path + "temperatureData/" + timestamp;
            
            Database.set<float>(aClient, temperaturePath + "/temperature", temperature, asyncCB, "setTemperatureTask");
            Database.set<float>(aClient, temperaturePath + "/humidity", humidity, asyncCB, "setHumidityTask");
            if (temperature > tempThresholdHigh || temperature < tempThresholdLow) {
                // Membuat objek notifikasi
                Messages::Notification notification;
                String title = "Peringatan Suhu dari " + String(deviceConfig.deviceName);
                String body = (temperature > tempThresholdHigh) 
                              ? "Suhu di atas " + String(tempThresholdHigh, 1) + "°C: " + String(temperature, 1) + "°C"
                              : "Suhu di bawah " + String(tempThresholdLow, 1) + "°C: " + String(temperature, 1) + "°C";

                notification.body(body).title(title);

                // Menyiapkan pesan
                Messages::Message msg;
                msg.notification(notification);

                msg.topic(deviceConfig.topic);

                // Kirim pesan melalui FCM
                Serial.println("Sending temperature notification...");
                messaging.send(aClient, Messages::Parent(FIREBASE_PROJECT_ID), msg, asyncCB, "fcmsendTask");
            }
        } else if (String(deviceConfig.deviceType) == "Light") {
            float brightness = readBrightness();
            Database.set<float>(aClient, path + "brightness", brightness, asyncCB, "setBrightnessTask");
        } else if (String(deviceConfig.deviceType) == "Socket") {
            bool isOn = getSocketStatus();
            Database.set<bool>(aClient, path + "isOn", isOn, asyncCB, "setSocketStatusTask");
        }
    }
}