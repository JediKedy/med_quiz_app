import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_quiz_app/screens/quiz_page.dart';

class MainMenu extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String title;

  MainMenu({this.data, this.title = "Ana Menyu"});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  Map<String, dynamic> menuData = {};

  @override
  void initState() {
    super.initState();
    if (widget.data == null) {
      loadBanksJson();
      checkBroadcast(); // Broadcast mesajını yoxla
    } else {
      menuData = widget.data!;
    }
  }

  // Yerli yaddaşdan banks.json faylını oxuyur
  Future<void> loadBanksJson() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/banks.json');
    
    if (await file.exists()) {
      String content = await file.readAsString();
      setState(() {
        menuData = json.decode(content);
      });
    }
  }

  // Admin mesajı (Broadcast) varmı deyə yoxlayır
  Future<void> checkBroadcast() async {
    final prefs = await SharedPreferences.getInstance();
    String? msg = prefs.getString('pending_broadcast');
    if (msg != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Yeni Elan!"),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                prefs.remove('pending_broadcast');
                Navigator.pop(ctx);
              },
              child: Text("Bağla"),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: menuData.isEmpty
          ? Center(child: Text("Məlumat tapılmadı. Zəhmət olmasa interneti yoxlayın."))
          : ListView.builder(
              itemCount: menuData.length,
              itemBuilder: (context, index) {
                String key = menuData.keys.elementAt(index);
                var value = menuData[key];

                return ListTile(
                  leading: Icon(value is Map ? Icons.folder : Icons.quiz),
                  title: Text(key),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    if (value is Map) {
                      // Əgər iç-içə Map-dirsə, yeni menyu səhifəsi aç (Rekursiya)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainMenu(
                            data: value as Map<String, dynamic>, // Buranı belə dəyiş
                            title: key,
                        ),
                        ),
                      );
                    } else {
                      // Əgər String-dirsə, deməli bu sual faylının yoludur (Quiz-i başlat)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizPage(bankName: key, bankData: value),
                        ),
                      );
                      // Növbəti addımda QuizPage-ə yönləndirəcəyik
                    }
                  },
                );
              },
            ),
    );
  }
}