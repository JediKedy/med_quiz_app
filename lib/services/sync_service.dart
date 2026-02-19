import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  // Baza fayllarını birbaşa raw URL-dən oxuyuruq.
  static const String baseUrl =
      'https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/main/';

  Future<void> syncEverything(Function(String) onProgress) async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();
    
    print("Yaddaş yolu: ${directory.path}");

    try {
      onProgress("metadata.json yüklənir...");
      final response = await http.get(Uri.parse('${baseUrl}metadata.json'));
      
      if (response.statusCode != 200) {
        onProgress("Xəta: Server cavab vermir (${response.statusCode})");
        return;
      }

      final Map<String, dynamic> metadata = json.decode(response.body);
      final Map<String, dynamic> remoteFiles = metadata['files'];

      for (String filePath in remoteFiles.keys) {
        File localFile = File("${directory.path}/$filePath");
        String remoteHash = remoteFiles[filePath];
        String? localHash = prefs.getString("hash_$filePath");

        if (!await localFile.exists() || localHash != remoteHash) {
          onProgress("Yenilənir: $filePath");
          
          await localFile.parent.create(recursive: true);
          final fileRes = await http.get(Uri.parse('$baseUrl$filePath'));
          
          if (fileRes.statusCode == 200) {
            await localFile.writeAsBytes(fileRes.bodyBytes);
            await prefs.setString("hash_$filePath", remoteHash);
          } else {
            print("Fayl yüklənmədi: $filePath - Status: ${fileRes.statusCode}");
          }
        }
      }
      onProgress("Hər şey hazırdır!");
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      onProgress("Bağlantı xətası: $e");
    }
  }
}
