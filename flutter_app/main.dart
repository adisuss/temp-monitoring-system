import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:zephlyr/firebase_options.dart';
import 'package:zephlyr/pages/home_page.dart';
import 'package:zephlyr/services/storage_service.dart';
import 'pages/login_page.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background Message: ${message.notification?.title}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔹 Mengaktifkan edge-to-edge UI...");

  try {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {}

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await setupFCM();
  runApp(MyApp());
  setupFCM();
}

/// **Konfigurasi Firebase Cloud Messaging (FCM)**
Future<void> setupFCM() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("⚠️ User belum login, hentikan proses saveFCMToken.");
    return;
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1️⃣ Minta izin notifikasi
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ User memberikan izin notifikasi");
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        "📩 Notifikasi diterima saat aplikasi aktif: ${message.notification?.title}",
      );

      if (message.notification != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) {
            return AlertDialog(
              title: Text(message.notification?.title ?? "No Title"),
              content: Text(message.notification?.body ?? "No Body"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
      }
    });

    // 4️⃣ Tangani notifikasi saat aplikasi dibuka dari tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Notifikasi dibuka dari tray: ${message.notification?.title}");
      // Tambahkan logika navigasi di sini jika diperlukan
    });
  } else {
    print("🚫 User tidak memberikan izin notifikasi");
  }
}

/// **Menyimpan FCM Token ke SharedPreferences**
Future<void> saveFCMToken(String token) async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    await StorageService.saveUserData(
      uid: user.uid,
      email: user.email!,
      fcmToken: token,
      apiKey: "gdjgjghfhgfhgfhkghgkjghg", // Sesuaikan dengan API key
    );
    print("✅ Data pengguna tersimpan!");
    print(user.uid);
  } else {
    print("⚠️ Tidak ada user yang sedang login!");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: lightTheme, // Tema terang
      darkTheme: darkTheme, // Tema gelap
      themeMode: ThemeMode.system, // Mengikuti tema sistem
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/homepage':
            (context) => HomePage(user: FirebaseAuth.instance.currentUser!),
      },
    );
  }
}

class AppColors {
  // Light Theme Colors
  static const Color lightPrimary = Colors.teal;
  static const Color lightBackground = Color.fromARGB(255, 2, 40, 67);
  static const Color lightCard = Color.fromARGB(255, 21, 107, 169);
  static const Color lightText = Colors.white;

  // Dark Theme Colors
  static const Color darkPrimary = Colors.teal;
  static const Color darkBackground = Color.fromARGB(255, 2, 40, 67);
  static const Color darkCard = Color.fromARGB(255, 21, 107, 169);
  static const Color darkText = Colors.white;
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.darkPrimary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  cardTheme: CardTheme(color: AppColors.darkCard, elevation: 3),
  textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.darkText)),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBackground, // Warna AppBar di tema gelap
    foregroundColor: Colors.white, // Warna ikon dan teks
    elevation: 2,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor:
        AppColors.darkCard, // Warna abu lebih soft dari hitam pekat
    selectedItemColor: AppColors.darkPrimary,
    unselectedItemColor: Colors.grey,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.darkPrimary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  cardTheme: CardTheme(color: AppColors.darkCard, elevation: 3),
  textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.darkText)),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBackground, // Warna AppBar di tema gelap
    foregroundColor: Colors.white, // Warna ikon dan teks
    elevation: 2,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor:
        AppColors.darkCard, // Warna abu lebih soft dari hitam pekat
    selectedItemColor: AppColors.darkPrimary,
    unselectedItemColor: Colors.grey,
  ),
);
