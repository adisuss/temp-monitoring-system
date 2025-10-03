import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:zephlyr/main.dart';

class ScheduleDataSendingScreen extends StatefulWidget {
  final Map<String, dynamic> availableDevices;
  final String userId;

  ScheduleDataSendingScreen({
    required this.availableDevices,
    required this.userId,
  });

  @override
  _ScheduleDataSendingScreenState createState() =>
      _ScheduleDataSendingScreenState();
}

class _ScheduleDataSendingScreenState extends State<ScheduleDataSendingScreen> {
  TimeOfDay? selectedTime;
  String? _selectedDeviceId;
  final TextEditingController _highController = TextEditingController();
  final TextEditingController _lowController = TextEditingController();

  String _getDeviceDisplayName(String deviceId) {
    final deviceData = widget.availableDevices[deviceId];
    final deviceName = deviceData?['deviceName'] ?? 'Unknown Device';
    final deviceLocation = deviceData?['deviceLocation'] ?? 'Unknown Location';
    return '$deviceName ($deviceLocation)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.availableDevices.isNotEmpty) {
      _selectedDeviceId = widget.availableDevices.keys.first;
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceData =
        _selectedDeviceId != null
            ? widget.availableDevices[_selectedDeviceId]
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Atur Jadwal Perangkat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 3,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pilih Perangkat",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              _buildDeviceSelector(),
              SizedBox(height: 12),
              if (deviceData != null) _buildDeviceInfo(deviceData),
              SizedBox(height: 16),
              _buildTimePicker(),
              SizedBox(height: 20),
              Text(
                "Threshold Suhu (°C)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lowController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Low',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _highController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'High',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: AppColors.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.memory, color: Theme.of(context).primaryColor),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedDeviceId,
                dropdownColor: AppColors.darkBackground,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDeviceId = newValue;
                  });
                },
                hint: Text(
                  "Pilih Perangkat",
                  style: TextStyle(fontSize: 16, color: AppColors.darkText),
                ),
                items:
                    widget.availableDevices.keys.map<DropdownMenuItem<String>>((
                      String deviceId,
                    ) {
                      return DropdownMenuItem<String>(
                        value: deviceId,
                        child: Text(
                          _getDeviceDisplayName(
                            deviceId,
                          ), // 🔥 PAKAI DISPLAY NAME
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.darkText,
                          ),
                        ),
                      );
                    }).toList(),
                isExpanded: true,
                underline: SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo(Map<String, dynamic> deviceData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: Icon(Icons.location_on, color: Colors.green),
        title: Text(
          'Lokasi: ${deviceData['deviceLocation'] ?? 'Unknown'}',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: Icon(Icons.access_time, color: Theme.of(context).primaryColor),
        title: Text(
          selectedTime != null
              ? 'Waktu: ${selectedTime!.format(context)}'
              : 'Pilih Waktu',
          style: TextStyle(fontSize: 16),
        ),
        trailing: ElevatedButton(
          onPressed: () => _pickTime(context),
          child: Text('Atur'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _saveSchedule,
        icon: Icon(Icons.save),
        label: Text('Simpan Jadwal'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          backgroundColor: AppColors.darkCard,
          foregroundColor: AppColors.darkText,
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _saveSchedule() async {
    if (_selectedDeviceId == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silakan pilih perangkat dan waktu')),
      );
      return;
    }

    final double? high = double.tryParse(_highController.text);
    final double? low = double.tryParse(_lowController.text);

    if (high == null || low == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Masukkan nilai suhu yang valid')));
      return;
    }

    try {
      final scheduleData = {
        'daily': true,
        'hour': selectedTime!.hour,
        'minute': selectedTime!.minute,
        'high': high,
        'low': low,
      };

      await FirebaseDatabase.instance
          .ref('devices/$_selectedDeviceId/schedule')
          .set(scheduleData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jadwal berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan jadwal: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
