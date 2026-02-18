import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../services/sync_service.dart';
import '../theme_controller.dart';
import 'quiz_page.dart';

class MainMenu extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String title;

  const MainMenu({super.key, this.data, this.title = 'Ana Menyu'});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController searchController = TextEditingController();

  Map<String, dynamic> menuData = {};
  String searchQuery = '';
  bool isSearching = false;
  bool _isSyncing = false;
  List<String> allWrongs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (widget.data == null) {
      await loadBanksJson();
      _fetchAndStoreNotifications();
    } else {
      menuData = widget.data!;
    }
    await _loadWrongCount();
  }

  Future<void> loadBanksJson() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/banks.json');
    if (!await file.exists()) return;

    final content = await file.readAsString();
    if (!mounted) return;
    setState(() => menuData = json.decode(content));
  }

  Future<void> _syncAllData() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final messenger = ScaffoldMessenger.of(context);

    await SyncService().syncEverything((message) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(milliseconds: 700)),
      );
    });

    await loadBanksJson();
    if (!mounted) return;
    setState(() => _isSyncing = false);
  }

  Future<void> _loadWrongCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => allWrongs = prefs.getStringList('wrong_questions') ?? []);
  }

  Future<void> _resetWrongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wrong_questions');
    if (!mounted) return;
    setState(() => allWrongs = []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Səhv suallar təmizləndi')),
    );
  }

  Future<void> _fetchAndStoreNotifications() async {
    try {
      final url = Uri.parse(
        'https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/refs/heads/main/notifications.json',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final remoteNotifs = json.decode(response.body) as List<dynamic>;
        final prefs = await SharedPreferences.getInstance();

        final lastSeenId = prefs.getInt('last_remote_notif_id') ?? 0;
        final history = prefs.getStringList('notif_history') ?? [];
        var foundNew = false;
        var maxId = lastSeenId;

        for (final notif in remoteNotifs) {
          final id = notif['id'] ?? 0;
          final isActive = notif['is_active'] ?? false;

          if (isActive && id > lastSeenId) {
            final now = DateTime.now();
            final time = '${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

            history.insert(
              0,
              json.encode({'msg': notif['message'], 'time': time}),
            );

            if (id > maxId) maxId = id;
            foundNew = true;
          }
        }

        if (foundNew) {
          await prefs.setStringList('notif_history', history);
          await prefs.setInt('last_remote_notif_id', maxId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Yeni bir elanınız var!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Bildiriş xətası: $e');
    }
  }

  void _showNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('notif_history') ?? [];

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bildirişlər', style: Theme.of(context).textTheme.titleLarge),
                if (history.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    onPressed: () async {
                      await prefs.remove('notif_history');
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('Heç bir bildiriş yoxdur.'))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (c, i) {
                        final item = json.decode(history[i]);
                        return ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(item['msg']),
                          subtitle: Text(item['time'], style: const TextStyle(fontSize: 11)),
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
    final filteredData = Map<String, dynamic>.from(menuData)
      ..removeWhere((key, value) =>
          searchQuery.isNotEmpty && !key.toLowerCase().contains(searchQuery.toLowerCase()));

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(widget.title)
            : TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Axtar...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
        actions: [
          IconButton(
            tooltip: 'Tema',
            icon: Icon(isDarkMode(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: toggleAppTheme,
          ),
          if (widget.data == null)
            IconButton(icon: const Icon(Icons.sync), onPressed: _isSyncing ? null : _syncAllData),
          if (widget.data == null)
            IconButton(icon: const Icon(Icons.notifications), onPressed: _showNotificationHistory),
          if (allWrongs.isNotEmpty && widget.data == null)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: scheme.error),
              onPressed: _showResetDialog,
            ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) {
                searchQuery = '';
                searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer.withOpacity(0.22), scheme.surface],
          ),
        ),
        child: Column(
          children: [
            if (_isSyncing) const LinearProgressIndicator(),
            if (widget.data == null && searchQuery.isEmpty) _buildWrongAnswersTile(),
            Expanded(
              child: filteredData.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          widget.data == null
                              ? 'Məlumat bazası boşdur. Sync düyməsi ilə yükləyin.'
                              : 'Heç bir nəticə tapılmadı',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: filteredData.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final key = filteredData.keys.elementAt(index);
                        final value = filteredData[key];
                        final isFolder = value is Map;
                        final bankWrongCount =
                            allWrongs.where((w) => w.contains(key)).length;

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isFolder
                                  ? scheme.tertiaryContainer
                                  : scheme.primaryContainer,
                              child: Icon(
                                isFolder ? Icons.folder_copy_rounded : Icons.quiz_rounded,
                                color: isFolder ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(key, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: (!isFolder && bankWrongCount > 0)
                                ? Text(
                                    '$bankWrongCount səhv cavab',
                                    style: TextStyle(
                                      color: scheme.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                            trailing: Icon(Icons.chevron_right_rounded, color: scheme.primary),
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Səhvləri sıfırla?'),
        content: const Text('Bütün səhv etdiyiniz suallar siyahıdan silinəcək.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xeyr')),
          TextButton(
            onPressed: () {
              _resetWrongs();
              Navigator.pop(ctx);
            },
            child: Text('Bəli, sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongAnswersTile() {
    if (allWrongs.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.history_edu_rounded, color: scheme.error, size: 28),
        title: Text(
          'Səhv etdiyim suallar',
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onErrorContainer),
        ),
        subtitle: Text('${allWrongs.length} sual təkrar gözləyir'),
        trailing: CircleAvatar(
          backgroundColor: scheme.error,
          radius: 15,
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
        ),
        onTap: () {
          final wrongQuestions = allWrongs
              .map((q) => Question.fromJson(json.decode(q) as Map<String, dynamic>))
              .toList();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizPage(
                bankName: 'Səhvlərim',
                bankData: {'questions': wrongQuestions},
              ),
            ),
          ).then((_) => _loadWrongCount());
        },
      ),
    );
  }
}
