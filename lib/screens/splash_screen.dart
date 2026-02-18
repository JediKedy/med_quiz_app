import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import 'main_menu.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String statusText = "Məlumatlar yoxlanılır...";
  SyncService syncService = SyncService();

  @override
  void initState() {
    super.initState();
    startSync();
  }

  Future<void> startSync() async {
    await syncService.syncEverything((status) {
      setState(() {
        statusText = status;
      });
    });

    // Sinxronizasiya bitdikdən sonra Ana Menyuya keçid
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => MainMenu())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}