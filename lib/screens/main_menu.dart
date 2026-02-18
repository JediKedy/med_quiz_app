import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'quiz_page.dart';
import '../models/question_model.dart';

class MainMenu extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String title;

  MainMenu({this.data, this.title = "Ana Menyu"});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  Map<String, dynamic> menuData = {};
  String searchQuery = "";
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  List<String> allWrongs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (widget.data == null) {
      await loadBanksJson();
      _fetchAndStoreNotifications(); // GitHub-dan bildirişləri yoxla
    } else {
      menuData = widget.data!;
    }
    await _loadWrongCount();
  }

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

  Future<void> _loadWrongCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allWrongs = prefs.getStringList('wrong_questions') ?? [];
    });
  }

  Future<void> _resetWrongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wrong_questions');
    setState(() {
      allWrongs = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Səhv suallar təmizləndi")),
      );
    }
  }

  Future<void> _fetchAndStoreNotifications() async {
    try {
      final url = Uri.parse("https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/refs/heads/main/notifications.json");
      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        List<dynamic> remoteNotifs = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        int lastSeenId = prefs.getInt('last_remote_notif_id') ?? 0;
        List<String> history = prefs.getStringList('notif_history') ?? [];
        bool foundNew = false;
        int maxId = lastSeenId;

        for (var notif in remoteNotifs) {
          int id = notif['id'] ?? 0;
          bool isActive = notif['is_active'] ?? false;

          if (isActive && id > lastSeenId) {
            String time = "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute}";
            
            history.insert(0, json.encode({
              "msg": notif['message'],
              "time": time
            }));

            if (id > maxId) maxId = id;
            foundNew = true;
          }
        }

        if (foundNew) {
          await prefs.setStringList('notif_history', history);
          await prefs.setInt('last_remote_notif_id', maxId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Yeni bir elanınız var!"), backgroundColor: Colors.blue),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Bildiriş xətası: $e");
    }
  }

  void _showNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('notif_history') ?? [];

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Bildirişlər", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (history.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: () async {
                      await prefs.remove('notif_history');
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  )
              ],
            ),
            Divider(),
            Expanded(
              child: history.isEmpty
                  ? Center(child: Text("Heç bir bildiriş yoxdur."))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (c, i) {
                        var item = json.decode(history[i]);
                        return ListTile(
                          leading: Icon(Icons.info_outline, color: Colors.blue),
                          title: Text(item['msg']),
                          subtitle: Text(item['time'], style: TextStyle(fontSize: 10)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> filteredData = Map.from(menuData);
    if (searchQuery.isNotEmpty) {
      filteredData.removeWhere((key, value) => !key.toLowerCase().contains(searchQuery.toLowerCase()));
    }

    return Scaffold(
      appBar: AppBar(
        title: !isSearching 
          ? Text(widget.title) 
          : TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(color: Colors.white), // Rəng ağ olaraq düzəldildi
              decoration: InputDecoration(
                hintText: "Axtar...", 
                border: InputBorder.none, 
                hintStyle: TextStyle(color: Colors.white70)
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
        actions: [
          if (widget.data == null)
            IconButton(icon: Icon(Icons.notifications), onPressed: _showNotificationHistory),
          if (allWrongs.isNotEmpty && widget.data == null)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: Colors.red.shade200),
              onPressed: () => _showResetDialog(),
            ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) { searchQuery = ""; searchController.clear(); }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.data == null && searchQuery.isEmpty) _buildWrongAnswersTile(),
          Expanded(
            child: filteredData.isEmpty
              ? Center(child: Text("Heç bir nəticə tapılmadı"))
              : ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredData.length,
                  separatorBuilder: (c, i) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    String key = filteredData.keys.elementAt(index);
                    var value = filteredData[key];
                    bool isFolder = value is Map;
                    int bankWrongCount = allWrongs.where((w) => w.contains(key)).length;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isFolder ? Colors.orange.shade50 : Colors.blue.shade50,
                        child: Icon(isFolder ? Icons.folder : Icons.quiz, color: isFolder ? Colors.orange : Colors.blue),
                      ),
                      title: Text(key, style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: (!isFolder && bankWrongCount > 0) 
                        ? Text("$bankWrongCount səhv cavab", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)) 
                        : null,
                      trailing: Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => isFolder 
                              ? MainMenu(data: value as Map<String, dynamic>, title: key)
                              : QuizPage(bankName: key, bankData: value),
                          ),
                        ).then((_) => _loadWrongCount());
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Səhvləri sıfırla?"),
        content: Text("Bütün səhv etdiyiniz suallar siyahıdan silinəcək."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Xeyr")),
          TextButton(
            onPressed: () { _resetWrongs(); Navigator.pop(ctx); }, 
            child: Text("Bəli, sil", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildWrongAnswersTile() {
    if (allWrongs.isEmpty) return SizedBox();
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.history_edu, color: Colors.red, size: 30),
        title: Text("Səhv etdiyim suallar", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        subtitle: Text("${allWrongs.length} sual təkrar gözləyir"),
        trailing: CircleAvatar(
          backgroundColor: Colors.red,
          radius: 15,
          child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
        ),
        onTap: () {
          List<Question> wrqs = allWrongs.map((q) => Question.fromJson(json.decode(q))).toList();
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => QuizPage(bankName: "Səhvlərim", bankData: {"questions": wrqs}))
          ).then((_) => _loadWrongCount());
        },
      ),
    );
  }
}