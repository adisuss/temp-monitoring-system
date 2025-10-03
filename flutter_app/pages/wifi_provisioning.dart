import 'package:zephlyr/main.dart';
import 'package:zephlyr/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class WifiProvisioningScreen extends StatefulWidget {
  final String deviceName;
  final String deviceType;
  final String deviceLocation;
  final String topic;
  final String organizationName;
  final String deviceId;

  WifiProvisioningScreen({
    required this.deviceName,
    required this.deviceType,
    required this.deviceLocation,
    required this.topic,
    required this.organizationName,
    required this.deviceId,
  });

  @override
  _WifiProvisioningScreenState createState() => _WifiProvisioningScreenState();
}

class _WifiProvisioningScreenState extends State<WifiProvisioningScreen> {
  TextEditingController ssidController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  String deviceSSID = "ESP32_Config";
  String deviceIP = "192.168.4.1";
  bool isConnecting = false;
  bool isConnectedToDevice = false;
  bool _obscurePassword = true;

  Future<void> connectToDeviceAP() async {
    setState(() {
      isConnecting = true;
    });

    try {
      bool success = await WiFiForIoTPlugin.connect(
        deviceSSID,
        security: NetworkSecurity.NONE,
        joinOnce: true,
      );

      if (success) {
        WiFiForIoTPlugin.forceWifiUsage(true);
        setState(() {
          isConnectedToDevice = true;
        });
      } else {
        setState(() {
          isConnectedToDevice = false;
        });
      }
    } catch (e) {
      setState(() {
        isConnectedToDevice = false;
      });
    }

    setState(() {
      isConnecting = false;
    });
  }

  Future<void> sendWifiCredentials() async {
    if (!isConnectedToDevice) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hubungkan ke Perangkat dulu!")));
      return;
    }

    String ssid = ssidController.text.trim();
    String password = passwordController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("SSID tidak boleh kosong!")));
      return;
    }

    // Load data dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? email = prefs.getString('email');
    String? authToken = prefs.getString('authToken');
    // String? fcmToken = prefs.getString('fcmToken');

    // Data yang dikirim ke ESP32
    Map<String, String> data = {
      'ssid': ssid,
      'wifi_password': password,
      'deviceName': widget.deviceName,
      'deviceType': widget.deviceType,
      'deviceLocation': widget.deviceLocation,
      'userId': userId ?? '',
      'authToken': authToken ?? '',
      'email': email ?? '',
      'orgName': widget.organizationName,
      'topic': widget.topic,
      'deviceId': widget.deviceId,
      // 'fcmToken': fcmToken ?? '',
    };

    try {
      var url = Uri.parse("http://$deviceIP/connect");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("WiFi berhasil dikonfigurasi!")));
        WiFiForIoTPlugin.forceWifiUsage(false);
        WiFiForIoTPlugin.disconnect();
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomePage(user: FirebaseAuth.instance.currentUser!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim data ke perangkat.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "WiFi Provisioning",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkBackground,
        elevation: 3,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Masukkan Detail WiFi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildCardForm(),
              SizedBox(height: 20),
              _buildConnectButton(),
              SizedBox(height: 16),
              _buildSendCredentialsButton(),
              if (!isConnectedToDevice)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "⚠ Belum terhubung ke perangkat!",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(ssidController, "WiFi SSID", Icons.wifi),
            SizedBox(height: 15),
            _buildTextField(
              passwordController,
              "WiFi Password",
              Icons.lock,
              isPassword: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.darkText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: AppColors.darkBackground,
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
                : null,
      ),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity, // Lebarkan tombol ke ukuran penuh
      child: ElevatedButton.icon(
        onPressed: isConnecting ? null : connectToDeviceAP,
        icon: Icon(Icons.wifi_find),
        label:
            isConnecting
                ? CircularProgressIndicator(color: Colors.white)
                : Text("Pindai Perangkat"),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16), // Ukuran tinggi seragam
          backgroundColor: AppColors.darkCard,
          foregroundColor: AppColors.darkText,
        ),
      ),
    );
  }

  Widget _buildSendCredentialsButton() {
    return SizedBox(
      width: double.infinity, // Lebarkan tombol ke ukuran penuh
      child: ElevatedButton.icon(
        onPressed: sendWifiCredentials,
        icon: Icon(Icons.send),
        label: Text("Hubungkan ke WiFi"),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16), // Ukuran tinggi seragam
          backgroundColor: AppColors.darkCard,
          foregroundColor: AppColors.darkText,
        ),
      ),
    );
  }
}
