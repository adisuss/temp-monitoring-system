import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:zephlyr/main.dart';
import 'package:zephlyr/pages/chart_page.dart';
import 'package:zephlyr/pages/device_name_page.dart';
import 'package:zephlyr/pages/login_page.dart';
import 'package:zephlyr/pages/schedule_screen.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  final User user;
  HomePage({required this.user});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  List<Map<String, dynamic>> devices = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
    _setupRealTimeListeners(); // 🔥 TAMBAH INI
    _debugCheckOrganization(); // 🔥 TAMBAH INI
    _fetchUserOrganizationStatus();
  }

  Future<void> _fetchUserOrganizationStatus() async {
    try {
      final userId = widget.user.uid;
      final userSnapshot =
          await FirebaseDatabase.instance.ref('users/$userId').get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final organizationId = userData['organizationId']?.toString();

        print('🔍 HOME - Organization ID: $organizationId');

        if (organizationId != null && organizationId.isNotEmpty) {
          // User sudah punya organisasi
          print('✅ User sudah join organisasi: $organizationId');

          // Auto-subscribe ke topic organisasi
          final topic = 'organization_$organizationId';
          await FirebaseMessaging.instance.subscribeToTopic(topic);
          print('✅ Subscribed to topic: $topic');
        } else {
          print('ℹ️ User belum join organisasi');
        }
      }
    } catch (e) {
      print('❌ Error fetching organization status: $e');
    }
  }

  void _debugCheckOrganization() async {
    final orgSnapshot =
        await FirebaseDatabase.instance
            .ref("users/${widget.user.uid}/organizationId")
            .get();

    print('🔍 DEBUG - Organization ID: ${orgSnapshot.value}');
    print(
      '🔍 DEBUG - Has organization: ${orgSnapshot.exists && orgSnapshot.value != null && orgSnapshot.value.toString().isNotEmpty}',
    );
  }

  void _setupRealTimeListeners() {
    // Listen untuk perubahan di node devices
    FirebaseDatabase.instance.ref("devices").onValue.listen((event) {
      if (!mounted) return;

      // Refresh devices list ketika ada perubahan
      _fetchDevices();
    });
  }

  Future<void> _joinOrganization(String orgName) async {
    try {
      final userId = widget.user.uid;
      final dbRef = FirebaseDatabase.instance.ref();

      // 1. CARI ORGANISASI BERDASARKAN NAMA
      final organizationsSnapshot = await dbRef.child('organizations').get();
      if (!organizationsSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tidak ada organisasi tersedia")),
        );
        return;
      }

      String? foundOrgId;
      Map<dynamic, dynamic> organizations =
          organizationsSnapshot.value as Map<dynamic, dynamic>;

      // Cari organizationId berdasarkan nama
      organizations.forEach((orgId, orgData) {
        if (orgData is Map &&
            orgData['name']?.toString().toLowerCase() ==
                orgName.toLowerCase()) {
          foundOrgId = orgId;
        }
      });

      if (foundOrgId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Organisasi '$orgName' tidak ditemukan")),
        );
        return;
      }

      final orgCode = foundOrgId!;

      // 2. Cek apakah user sudah jadi member
      final memberSnapshot =
          await dbRef.child('organizations/$orgCode/members/$userId').get();
      if (memberSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Anda sudah menjadi member organisasi ini")),
        );
        return;
      }

      // 3. Update user data dengan organizationId
      await dbRef.child('users/$userId').update({
        'organizationId': orgCode,
        'role': 'technician', // Role default untuk yang join
      });

      // 4. Add user ke members organization
      await dbRef.child('organizations/$orgCode/members/$userId').set({
        'joinedAt': ServerValue.timestamp,
        'role': 'technician',
      });

      // 5. Subscribe ke FCM topic organisasi
      final topic = 'organization_$orgCode';
      await FirebaseMessaging.instance.subscribeToTopic(topic);

      // 6. Refresh devices list untuk menampilkan devices organisasi
      _fetchDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil join organisasi $orgName"),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ User $userId joined organization: $orgCode ($orgName)');
    } catch (e) {
      print('❌ Error joining organization: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal join organisasi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showJoinOrganizationDialog() {
    final TextEditingController orgNameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Join Organisasi"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Masukkan nama organisasi"),
                SizedBox(height: 10),
                TextField(
                  controller: orgNameController,
                  decoration: InputDecoration(
                    labelText: "Nama Organisasi",
                    hintText: "contoh: Maintenance Team",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Contoh: Maintenance Team, Plant Jakarta, dll",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final orgName = orgNameController.text.trim();
                  if (orgName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Harap masukkan nama organisasi")),
                    );
                    return;
                  }

                  await _joinOrganization(orgName); // SEKARANG PAKAI NAMA
                  Navigator.pop(context);
                },
                child: Text("Join"),
              ),
            ],
          ),
    );
  }

  void _fetchDevices() async {
    String uid = widget.user.uid;
    DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");

    DataSnapshot userSnapshot = await userRef.get();
    if (!userSnapshot.exists || userSnapshot.value == null) return;

    Map<dynamic, dynamic>? userData =
        userSnapshot.value as Map<dynamic, dynamic>?;
    String userRole = userData?["role"] ?? "user";
    String organizationId = userData?["organizationId"] ?? "";

    List<Map<String, dynamic>> tempDevices = [];

    try {
      if (userRole == "admin") {
        // Admin: Ambil semua devices
        final allDevicesSnapshot =
            await FirebaseDatabase.instance.ref("devices").get();
        if (allDevicesSnapshot.exists) {
          Map<dynamic, dynamic> allDevices =
              allDevicesSnapshot.value as Map<dynamic, dynamic>;

          // 🔥 PARSE SEMUA DEVICES SECARA ASYNC
          for (var entry in allDevices.entries) {
            final device = await _parseDevice(
              entry.key.toString(),
              entry.value as Map<dynamic, dynamic>,
            );
            tempDevices.add(device);
          }
        }
      } else if (organizationId.isNotEmpty) {
        // User dengan organisasi
        final orgDevicesSnapshot =
            await FirebaseDatabase.instance
                .ref("organizations/$organizationId/devices")
                .get();

        if (orgDevicesSnapshot.exists) {
          Map<dynamic, dynamic> orgDevices =
              orgDevicesSnapshot.value as Map<dynamic, dynamic>;

          // 🔥 PARSE DEVICES ORGANISASI SECARA ASYNC
          for (var deviceId in orgDevices.keys) {
            final deviceSnapshot =
                await FirebaseDatabase.instance.ref("devices/$deviceId").get();

            if (deviceSnapshot.exists) {
              final device = await _parseDevice(
                deviceId.toString(),
                deviceSnapshot.value as Map<dynamic, dynamic>,
              );
              tempDevices.add(device);
            }
          }
        }
      } else {
        // User tanpa organisasi
        final userDevicesSnapshot =
            await FirebaseDatabase.instance
                .ref("devices")
                .orderByChild("createdBy")
                .equalTo(uid)
                .get();

        if (userDevicesSnapshot.exists) {
          Map<dynamic, dynamic> userDevices =
              userDevicesSnapshot.value as Map<dynamic, dynamic>;

          // 🔥 PARSE DEVICES PERSONAL SECARA ASYNC
          for (var entry in userDevices.entries) {
            final device = await _parseDevice(
              entry.key.toString(),
              entry.value as Map<dynamic, dynamic>,
            );
            tempDevices.add(device);
          }
        }
      }

      if (mounted) {
        setState(() {
          devices = tempDevices;
        });
      }

      print('✅ Loaded ${devices.length} devices');
    } catch (e) {
      print('❌ Error in _fetchDevices: $e');
    }
  }

  // Helper function untuk parsing data perangkat
  Future<Map<String, dynamic>> _parseDevice(
    String deviceId,
    Map<dynamic, dynamic> data,
  ) async {
    String latestTemperature = "N/A";
    String latestHumidity = "N/A";
    String organizationName = "Unknown Organization";

    // Baca data sensor
    if (data["temperatureData"] != null && data["temperatureData"] is Map) {
      Map<dynamic, dynamic> temperatureData =
          data["temperatureData"] as Map<dynamic, dynamic>;

      if (temperatureData.isNotEmpty) {
        var latestTimestamp = temperatureData.keys.reduce(
          (a, b) => a.compareTo(b) > 0 ? a : b,
        );
        var latestData = temperatureData[latestTimestamp];

        if (latestData is Map) {
          latestTemperature = latestData["temperature"]?.toString() ?? "N/A";
          latestHumidity = latestData["humidity"]?.toString() ?? "N/A";
        }
      }
    }

    // 🔥 FETCH NAMA ORGANISASI DARI FIREBASE
    final organizationId = data["organizationId"]?.toString();
    if (organizationId != null && organizationId.isNotEmpty) {
      try {
        final orgSnapshot =
            await FirebaseDatabase.instance
                .ref("organizations/$organizationId/name")
                .get();

        if (orgSnapshot.exists && orgSnapshot.value != null) {
          organizationName = orgSnapshot.value.toString();
          print(
            '✅ Fetched organization: $organizationName for $organizationId',
          );
        } else {
          print('❌ Organization not found: $organizationId');
        }
      } catch (e) {
        print('❌ Error fetching organization: $e');
      }
    } else {
      print('❌ No organizationId for device: $deviceId');
    }

    return {
      "id": deviceId,
      "name": data["name"] ?? "Unknown Device",
      "location": data["location"] ?? "Unknown Location",
      "type": data["type"] ?? "Unknown Type",
      "code": data["code"] ?? "N/A",
      "organizationId": organizationId ?? "",
      "organizationName": organizationName,
      "temperature": latestTemperature,
      "humidity": latestHumidity,
    };
  }

  void _handleSignOut() async {
    // Hapus token FCM agar tidak ada notifikasi yang dikirim ke device lama
    await FirebaseMessaging.instance.deleteToken();

    // Lakukan sign-out
    await _authService.signOut();

    // Navigasi ke halaman login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update index saat tab dipilih
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CircleAvatar(
          backgroundImage: NetworkImage(widget.user.photoURL ?? ""),
          radius: 20,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add),
            onPressed: _showJoinOrganizationDialog,
          ),
          IconButton(icon: Icon(Icons.logout), onPressed: _handleSignOut),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: IndexedStack(
          index:
              _selectedIndex, // Mengatur halaman yang aktif berdasarkan tab yang dipilih
          children: [
            _buildDeviceList(),
            DeviceNameScreen(
              onNext: () {
                _pageController.animateToPage(
                  1,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            // Di HomePage, di bagian Navigator ke ScheduleScreen:
            ScheduleDataSendingScreen(
              availableDevices: {
                for (var device in devices)
                  device["id"]: {
                    "deviceName": device["name"],
                    "deviceLocation": device["location"],
                    "deviceType": device["type"],
                  },
              },
              userId: widget.user.uid,
            ),

            _buildChart(), // Chart Page ditampilkan di tab Chart
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor, // Mengikuti tema
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.add),
                label: 'Add Device',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule),
                label: 'Automation',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.show_chart),
                label: 'Chart',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor:
                Theme.of(
                  context,
                ).scaffoldBackgroundColor, // Warna ikon aktif sesuai tema
            unselectedItemColor: Theme.of(context).textTheme.bodyLarge?.color
                ?.withOpacity(0.6), // Warna ikon tidak aktif
            backgroundColor:
                Theme.of(context)
                    .bottomNavigationBarTheme
                    .backgroundColor, // Warna latar belakang navbar mengikuti tema
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Center(
      child: ChartPage(user: widget.user), // Berikan parameter user
    );
  }

  Widget _buildDeviceList() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: 10),

          // 🔥 TAMBAH STATUS ORGANISASI
          _buildOrganizationStatus(),
          SizedBox(height: 10),

          Expanded(
            child:
                devices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text(
                            "Tidak ada devices",
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 5),
                          Text(
                            devices.isEmpty && _getOrganizationId().isEmpty
                                ? "Join organisasi atau tambah device"
                                : "Tidak ada devices di organisasi ini",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).cardTheme.color ??
                                    Colors.white,
                                Theme.of(
                                      context,
                                    ).cardTheme.color?.withOpacity(0.8) ??
                                    Colors.grey,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            color: Colors.transparent,
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Ikon Device berdasarkan type
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _getDeviceIcon(device["type"]),
                                      color: AppColors.darkPrimary,
                                      size: 40,
                                    ),
                                  ),
                                  SizedBox(width: 15),

                                  // Informasi Device
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device["name"] ?? "Unknown Device",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Lokasi: ${device["location"] ?? "Unknown"}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        Text(
                                          "Tipe: ${device["type"] ?? "Unknown"}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        // 🔥 TAMBAH NAMA ORGANISASI
                                        if (device["organizationName"] !=
                                                null &&
                                            device["organizationName"] !=
                                                "Unknown Organization")
                                          Text(
                                            "Organisasi: ${device["organizationName"]}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.darkText,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Informasi Suhu & Kelembapan
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.thermostat,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.color,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "${device["temperature"] ?? "N/A"}°C",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _getTemperatureColor(
                                                device["temperature"],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.water_drop,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.color,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "${device["humidity"] ?? "N/A"}%",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _getHumidityColor(
                                                device["humidity"],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // 🔥 METHOD BARU: Status Organisasi
  Widget _buildOrganizationStatus() {
    return FutureBuilder(
      future:
          FirebaseDatabase.instance
              .ref("users/${widget.user.uid}/organizationId")
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox();
        }

        final orgId = snapshot.data?.value;

        // 🔥 CEK: null, empty string, atau tidak exists
        if (orgId == null || orgId.toString().isEmpty) {
          return Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Anda belum join organisasi. Tap + untuk join",
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          );
        }

        // 🔥 JIKA SUDAH PUNYA ORGANIZATION ID, TIDAK TAMPILKAN APA-APA
        return SizedBox();
      },
    );
  }

  // 🔥 METHOD BARU: Get Organization ID
  String _getOrganizationId() {
    // Ini sederhana, bisa diperbaiki dengan FutureBuilder jika perlu real-time
    return ""; // Akan di-update secara manual
  }

  // 🔥 METHOD BARU: Icon berdasarkan device type
  IconData _getDeviceIcon(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'sensor':
        return Icons.sensors;
      case 'controller':
        return Icons.control_camera;
      case 'boiler':
        return Icons.heat_pump;
      case 'chiller':
        return Icons.ac_unit;
      case 'compressor':
        return Icons.compress;
      default:
        return Icons.memory;
    }
  }

  // 🔥 METHOD BARU: Warna temperature berdasarkan nilai
  Color _getTemperatureColor(String? temperature) {
    if (temperature == "N/A") return AppColors.darkText;

    try {
      double temp = double.tryParse(temperature!) ?? 0;
      if (temp > 35) return Colors.red;
      if (temp > 25) return Colors.orange;
      return Colors.green;
    } catch (e) {
      return AppColors.darkText;
    }
  }

  // 🔥 METHOD BARU: Warna humidity berdasarkan nilai
  Color _getHumidityColor(String? humidity) {
    if (humidity == "N/A") return AppColors.darkText;

    try {
      double hum = double.tryParse(humidity!) ?? 0;
      if (hum > 80) return Colors.blue;
      if (hum > 50) return Colors.green;
      return Colors.orange;
    } catch (e) {
      return AppColors.darkText;
    }
  }
}
