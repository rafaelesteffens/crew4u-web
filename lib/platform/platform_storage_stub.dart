class PlatformStorage {
  const PlatformStorage();

  static final Map<String, String> _memory = {};

  Future<String?> read(String key) async => _memory[key];

  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
  }
}
