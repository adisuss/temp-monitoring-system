import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:zephlyr/main.dart';
import 'package:zephlyr/pages/wifi_provisioning.dart';

class DeviceType {
  final String name;
  DeviceType(this.name);
}

class DeviceNameScreen extends StatefulWidget {
  final VoidCallback onNext;

  DeviceNameScreen({required this.onNext});

  @override
  _DeviceNameScreenState createState() => _DeviceNameScreenState();
}

class _DeviceNameScreenState extends State<DeviceNameScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceLocationController =
      TextEditingController();
  final TextEditingController _organizationNameController =
      TextEditingController();

  String? _selectedDeviceType;
  String? _selectedOrganizationType;

  final List<DeviceType> deviceTypes = [
    DeviceType('Sensor'),
    DeviceType('Controller'),
  ];

  final List<String> organizationTypes = [
    // tambahan
    'Perorangan',
    'Organisasi',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Perangkat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 3,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Masukkan Informasi Perangkat",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildCardForm(),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _onNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardTheme.color,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Lanjutkan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
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
            _buildTextField(
              _deviceNameController,
              "Nama Perangkat",
              Icons.memory,
            ),
            SizedBox(height: 15),
            _buildDropdownField(),
            SizedBox(height: 15),
            _buildTextField(
              _deviceLocationController,
              "Lokasi Perangkat",
              Icons.location_on,
            ),
            SizedBox(height: 15),
            _buildOrganizationDropdown(), // Tipe organisasi
            if (_selectedOrganizationType == 'Organisasi') SizedBox(height: 15),
            if (_selectedOrganizationType == 'Organisasi')
              _buildTextField(
                _organizationNameController,
                "Nama Organisasi",
                Icons.business,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedOrganizationType,
      items:
          organizationTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type, style: TextStyle(color: AppColors.darkText)),
            );
          }).toList(),
      dropdownColor: AppColors.darkBackground,
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.account_tree,
          color: Theme.of(context).primaryColor,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: AppColors.darkBackground,
        contentPadding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ), // buat jarak lebih nyaman
      ),
      style: TextStyle(
        color: AppColors.darkText,
        fontSize: 16, // sesuaikan dengan dropdown perangkat
      ),
      hint: Text(
        'Pilih Tipe Organisasi',
        style: TextStyle(color: AppColors.darkText, fontSize: 16),
      ),
      onChanged: (String? newValue) {
        setState(() {
          _selectedOrganizationType = newValue;
        });
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.darkText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: AppColors.darkBackground,
      ),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedDeviceType,
      items:
          deviceTypes.map((DeviceType deviceType) {
            return DropdownMenuItem<String>(
              value: deviceType.name,
              child: Text(deviceType.name),
            );
          }).toList(),
      dropdownColor: AppColors.darkBackground,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.sensors, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: AppColors.darkBackground,
      ),
      style: TextStyle(color: AppColors.darkText), // Warna teks dropdown
      hint: Text(
        'Pilih Tipe Perangkat',
        style: TextStyle(color: AppColors.darkText), // Warna hint text
      ),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDeviceType = newValue;
        });
      },
    );
  }

  void _onNextPressed() async {
    if (_deviceNameController.text.isEmpty ||
        _selectedDeviceType == null ||
        _deviceLocationController.text.isEmpty ||
        _selectedOrganizationType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Harap lengkapi semua data')));
      return;
    }

    // Validasi Nama Organisasi jika tipe = Organisasi
    if (_selectedOrganizationType == 'Organisasi' &&
        _organizationNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Harap masukkan nama organisasi')));
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final deviceName = _deviceNameController.text;
      final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';

      String organizationId;
      String organizationName;
      String topic;

      // 🔥 CEK DULU APAKAH USER SUDAH PUNYA ORGANISASI
      final userSnapshot =
          await FirebaseDatabase.instance.ref("users/$userId").get();
      final existingOrgId =
          userSnapshot.child('organizationId').value as String?;

      if (_selectedOrganizationType == 'Organisasi') {
        if (existingOrgId != null &&
            existingOrgId.isNotEmpty &&
            existingOrgId.startsWith('org_')) {
          // 🔥 USER SUDAH PUNYA ORGANISASI - PAKAI YANG SUDAH ADA
          organizationId = existingOrgId;
          final orgSnapshot =
              await FirebaseDatabase.instance
                  .ref("organizations/$organizationId")
                  .get();
          organizationName =
              orgSnapshot.child('name').value as String? ??
              "Existing Organization";
          topic = 'organization_$organizationId';

          print('✅ Using existing organization: $organizationName');
        } else {
          // 🔥 BUAT ORGANISASI BARU
          organizationName = _organizationNameController.text;
          organizationId = 'org_${DateTime.now().millisecondsSinceEpoch}';
          topic = 'organization_$organizationId';

          // Buat organisasi baru
          final orgRef = FirebaseDatabase.instance.ref(
            "organizations/$organizationId",
          );
          await orgRef.set({
            "name": organizationName,
            "createdBy": userId,
            "createdAt": ServerValue.timestamp,
          });

          // Tambahkan user sebagai member
          await orgRef.child("members/$userId").set({
            "role": "supervisor",
            "joinedAt": ServerValue.timestamp,
          });

          // Update user data dengan organizationId
          await FirebaseDatabase.instance.ref("users/$userId").update({
            "organizationId": organizationId,
            "role": "supervisor",
          });

          print('✅ Created new organization: $organizationName');
        }
      } else {
        // PERORANGAN
        if (existingOrgId != null &&
            existingOrgId.isNotEmpty &&
            existingOrgId.startsWith('personal_')) {
          // 🔥 SUDAH PUNYA ORGANISASI PERSONAL - PAKAI YANG SUDAH ADA
          organizationId = existingOrgId;
          organizationName = "Perorangan";
          topic = 'personal_$userId';

          print('✅ Using existing personal organization');
        } else {
          // 🔥 BUAT ORGANISASI PERSONAL BARU
          organizationId = "personal_$userId";
          organizationName = "Perorangan";
          topic = 'personal_$userId';

          // Buat organisasi personal
          final orgRef = FirebaseDatabase.instance.ref(
            "organizations/$organizationId",
          );
          await orgRef.set({
            "name": organizationName,
            "createdBy": userId,
            "createdAt": ServerValue.timestamp,
          });

          // Tambahkan user sebagai member
          await orgRef.child("members/$userId").set({
            "role": "supervisor",
            "joinedAt": ServerValue.timestamp,
          });

          // Update user data
          await FirebaseDatabase.instance.ref("users/$userId").update({
            "organizationId": organizationId,
            "role": "supervisor",
          });

          print('✅ Created new personal organization');
        }
      }

      // BUAT DEVICE (SAMA SEPERTI SEBELUMNYA)
      final deviceRef = FirebaseDatabase.instance.ref("devices/$deviceId");
      await deviceRef.set({
        "name": deviceName,
        "code": _deviceNameController.text.toUpperCase().replaceAll(' ', '_'),
        "organizationId": organizationId,
        "type": _selectedDeviceType,
        "location": _deviceLocationController.text,
        "createdBy": userId,
        "createdAt": ServerValue.timestamp,
      });

      // Tambahkan device ke organisasi
      await FirebaseDatabase.instance
          .ref("organizations/$organizationId/devices/$deviceId")
          .set(true);

      // Simpan device reference di user
      await FirebaseDatabase.instance
          .ref("users/$userId/devices/$deviceId")
          .set({
            "deviceName": deviceName,
            "deviceType": _selectedDeviceType,
            "deviceLocation": _deviceLocationController.text,
            "organizationId": organizationId,
          });

      // Subscribe ke FCM topic organisasi (jika belum subscribe)
      await FirebaseMessaging.instance.subscribeToTopic(topic);

      print('✅ Device created: $deviceId');
      print('✅ Organization: $organizationId');
      print('✅ Topic: $topic');

      // Navigate ke halaman berikutnya
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => WifiProvisioningScreen(
                deviceName: deviceName,
                deviceType: _selectedDeviceType!,
                deviceLocation: _deviceLocationController.text,
                topic: topic,
                organizationName: organizationName,
                deviceId: deviceId,
              ),
        ),
      );
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: $e')));
    }
  }
}
