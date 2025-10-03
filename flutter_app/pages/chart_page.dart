import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChartPage extends StatefulWidget {
  final User user;
  ChartPage({required this.user});

  @override
  _ChartPageState createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  Map<String, List<FlSpot>> temperatureData = {};
  Map<String, List<FlSpot>> humidityData = {};

  @override
  void initState() {
    super.initState();
    _setupRealTimeChartData();
  }

  void _setupRealTimeChartData() {
    String uid = widget.user.uid;

    // Listen perubahan di user data untuk role/organization
    FirebaseDatabase.instance.ref("users/$uid").onValue.listen((userSnapshot) {
      if (!mounted || !userSnapshot.snapshot.exists) return;

      Map<dynamic, dynamic>? userData =
          userSnapshot.snapshot.value as Map<dynamic, dynamic>?;
      String userRole = userData?["role"] ?? "user";
      String organizationId = userData?["organizationId"] ?? "";

      // Setup listener berdasarkan role
      if (userRole == "admin") {
        _setupAdminChartListener();
      } else if (organizationId.isNotEmpty) {
        _setupOrganizationChartListener(organizationId);
      } else {
        _setupPersonalChartListener(uid);
      }
    });
  }

  void _setupAdminChartListener() {
    // 🔥 LISTEN REAL-TIME UNTUK SEMUA DEVICES
    FirebaseDatabase.instance.ref("devices").onValue.listen((event) {
      if (!mounted) return;

      _processChartData(event.snapshot);
    });
  }

  void _setupOrganizationChartListener(String organizationId) {
    // 🔥 LISTEN REAL-TIME UNTUK DEVICES ORGANISASI
    FirebaseDatabase.instance
        .ref("organizations/$organizationId/devices")
        .onValue
        .listen((orgEvent) {
          if (!mounted || !orgEvent.snapshot.exists) return;

          Map<dynamic, dynamic> orgDevices =
              orgEvent.snapshot.value as Map<dynamic, dynamic>;

          // Listen untuk setiap device dalam organisasi
          for (String deviceId in orgDevices.keys) {
            FirebaseDatabase.instance.ref("devices/$deviceId").onValue.listen((
              deviceEvent,
            ) {
              if (!mounted || !deviceEvent.snapshot.exists) return;

              _processSingleDeviceChartData(deviceId, deviceEvent.snapshot);
            });
          }
        });
  }

  void _setupPersonalChartListener(String uid) {
    // 🔥 LISTEN REAL-TIME UNTUK DEVICES PERSONAL
    FirebaseDatabase.instance
        .ref("devices")
        .orderByChild("createdBy")
        .equalTo(uid)
        .onValue
        .listen((event) {
          if (!mounted) return;

          _processChartData(event.snapshot);
        });
  }

  void _processChartData(DataSnapshot snapshot) {
    if (!snapshot.exists) return;

    Map<String, List<FlSpot>> tempData = {};
    Map<String, List<FlSpot>> humData = {};

    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);

    Map<dynamic, dynamic> allDevices = snapshot.value as Map<dynamic, dynamic>;

    allDevices.forEach((deviceId, deviceData) {
      _parseChartData(
        deviceId.toString(),
        deviceData as Map<dynamic, dynamic>,
        tempData,
        humData,
        startOfDay,
      );
    });

    if (mounted) {
      setState(() {
        temperatureData = tempData;
        humidityData = humData;
      });
    }
  }

  void _processSingleDeviceChartData(String deviceId, DataSnapshot snapshot) {
    if (!snapshot.exists) return;

    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);

    Map<String, List<FlSpot>> tempData = Map.from(temperatureData);
    Map<String, List<FlSpot>> humData = Map.from(humidityData);

    _parseChartData(
      deviceId,
      snapshot.value as Map<dynamic, dynamic>,
      tempData,
      humData,
      startOfDay,
    );

    if (mounted) {
      setState(() {
        temperatureData = tempData;
        humidityData = humData;
      });
    }
  }

  // Helper function untuk parsing data perangkat ke chart
  void _parseChartData(
    String deviceId,
    Map<dynamic, dynamic> data,
    Map<String, List<FlSpot>> tempData,
    Map<String, List<FlSpot>> humData,
    DateTime startOfDay,
  ) {
    if (data["temperatureData"] == null || data["name"] == null) {
      return;
    }

    Map<dynamic, dynamic> tempRecords = data["temperatureData"];
    String deviceName = data["name"]?.toString() ?? deviceId;

    List<FlSpot> tempSpots = [];
    List<FlSpot> humSpots = [];

    // 🔥 AMBIL 20 DATA TERBARU SAJA UNTUK PERFORMANCE
    List<MapEntry<dynamic, dynamic>> sortedTempRecords =
        tempRecords.entries.toList()
          ..sort((a, b) => b.key.toString().compareTo(a.key.toString()))
          ..take(20); // Batasi jumlah data

    for (var entry in sortedTempRecords) {
      try {
        String timestamp = entry.key as String;
        Map<dynamic, dynamic> readings = entry.value;

        DateTime recordTime = DateTime.parse(timestamp);

        if (recordTime.isAfter(startOfDay)) {
          double temp = (readings["temperature"] ?? 0).toDouble();
          double hum = (readings["humidity"] ?? 0).toDouble();

          double minutesSinceMidnight =
              recordTime.hour * 60.0 +
              recordTime.minute +
              recordTime.second / 60.0;

          tempSpots.add(FlSpot(minutesSinceMidnight, temp));
          humSpots.add(FlSpot(minutesSinceMidnight, hum));
        }
      } catch (e) {
        print("❌ Error parsing chart data: $e");
      }
    }

    // 🔥 REVERSE UNTUK URUTAN LAMA -> BARU
    tempSpots = tempSpots.reversed.toList();
    humSpots = humSpots.reversed.toList();

    if (tempSpots.isNotEmpty) {
      tempData[deviceName] = tempSpots;
      humData[deviceName] = humSpots;
    } else {
      // 🔥 JIKA TIDAK ADA DATA, HAPUS DARI CHART
      tempData.remove(deviceName);
      humData.remove(deviceName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Grafik Perangkat'), centerTitle: true),
      body:
          temperatureData.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "Tidak ada data grafik",
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Data akan muncul setelah device mengirim sensor data",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children:
                      temperatureData.keys.map((deviceName) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Device: $deviceName",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  _buildChart(
                                    temperatureData[deviceName]!,
                                    humidityData[deviceName]!,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
    );
  }

  Widget _buildChart(List<FlSpot> tempData, List<FlSpot> humData) {
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        // 🔥 FORMAT JAM:MENIT
                        int hours = (value ~/ 60).toInt();
                        int minutes = (value % 60).toInt();
                        String timeLabel =
                            "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
                        return Text(timeLabel, style: TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: tempData,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: humData,
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend("Temperature", Colors.orange, Icons.thermostat),
              SizedBox(width: 10),
              _buildLegend("Humidity", Colors.greenAccent, Icons.water_drop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
