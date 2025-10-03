#ifndef SERVER_MANAGER_H
#define SERVER_MANAGER_H

#include <WebServer.h>
#include <ArduinoJson.h>
#include "WiFiManager.h"

extern WebServer server;

void setupServer();
void handleConnect();

#endif
