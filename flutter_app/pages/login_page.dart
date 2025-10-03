import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    // Efek animasi muncul perlahan
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;
      if (user != null) {
        final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
        // Simpan lokal (tanpa fcmToken)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.uid);
        await prefs.setString('email', user.email ?? '');

        final userSnapshot = await dbRef.child('users/${user.uid}').get();
        final userData = userSnapshot.value as Map<dynamic, dynamic>?;
        final organizationId = userData?['organizationId']?.toString();

        print('🔍 LOGIN - Organization ID: $organizationId');

        // Navigasi ke home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(user: user)),
        );
      }
    } catch (e) {
      print("❌ Error signing in with Google: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gambar
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("lib/assets/loginpage.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Overlay efek gelap
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          // Konten Login
          AnimatedOpacity(
            duration: Duration(seconds: 1),
            opacity: _opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Spacer(flex: 2),
                  Lottie.asset(
                    "lib/assets/Animation1740659687287.json",
                    height: 100,
                  ),
                  SizedBox(height: 40),
                  Text(
                    "Welcome to Zephlyr",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "\"When circuits etch the sigils of the ancients, and scripts weave spells that awaken relics of a lost era.\"",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  Spacer(flex: 3),

                  // Tombol Glassmorphism yang lebih panjang & ramping
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      10,
                    ), // Sudut lebih kecil untuk kesan sleek
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 8,
                        sigmaY: 8,
                      ), // Blur lebih soft
                      child: Container(
                        width:
                            MediaQuery.of(context).size.width *
                            0.75, // Lebar 75% layar
                        height: 42, // Tinggi tombol lebih kecil
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: 1,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: -2,
                              offset: Offset(-2, -2),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: -2,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Image.asset(
                            "lib/assets/7123025_logo_google_g_icon.png",
                            height: 18,
                            width: 18,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 18,
                              );
                            },
                          ),
                          label: Text(
                            "Masuk dengan Google",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  Text(
                    "By continuing, you agree to our Terms & Conditions",
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
