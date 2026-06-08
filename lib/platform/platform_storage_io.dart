import 'dart:convert';
import 'dart:io';

class PlatformStorage {
  const PlatformStorage();

  static final File _file = File(
    '${Directory.systemTemp.path}/crew4u_storage.json',
  );

  Future<String?> read(String key) async {
    final data = await _readAll();
    return data[key];
  }

  Future<void> write(String key, String value) async {
    final data = await _readAll();
    data[key] = value;
    await _writeAll(data);
  }

  Future<void> remove(String key) async {
    final data = await _readAll();
    data.remove(key);
    await _writeAll(data);
  }

  Future<Map<String, String>> _readAll() async {
    if (!await _file.exists()) return {};

    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) return {};

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, String> data) async {
    await _file.writeAsString(jsonEncode(data));
  }
}
