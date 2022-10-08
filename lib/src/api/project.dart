part of legion.api;

class Project implements Configuration {
  final Directory directory;

  Storage _config;
  Storage _state;

  Storage get config => _config;
  Storage get state => _state;

  Project(this.directory);

  Future init() async {
    _config = new Storage(resolveWorkingPath(
      "legion.json",
      from: directory.absolute.path
    ), saveOnChange: false);

    _state = new Storage(resolveWorkingPath(
      "legion/.state",
      from: directory.absolute.path
    ), saveOnChange: true);

    _config.load();
    _state.load();
  }

  Future<Target> getTarget(
    String name,
    Toolchain toolchain,
    List<String> extraArguments) async {
    return new Target(this, name, toolchain, extraArguments);
  }

  @override
  Future<dynamic> getSetting(String key) async {
    return resolveConfigValue(config.entries, key);
  }

  @override
  Future<List<String>> getStringListSetting(String key) async {
    var value = resolveConfigValue(config.entries, key);
    if (value is List) {
      return value.where((x) => x is String).toList();
    }
    return const <String>[];
  }

  @override
  Future<Map<String, dynamic>> getMapSetting(String key) async {
    var value = resolveConfigValue(config.entries, key);
    if (value is Map) {
      return value;
    }
    return const <String, dynamic>{};
  }

  @override
  Future<bool> getBooleanSetting(String key) async {
    return resolveConfigValue(config.entries, key) == true;
  }

  @override
  Future<String> getStringSetting(String key, [String defaultValue = ""]) async {
    var str = resolveConfigValue(config.entries, key);

    if (str is! String) {
      str = defaultValue;
    }

    return str;
  }

  File getFile(String path) {
    var filePath = resolveWorkingPath(path, from: directory.path);
    return new File(filePath);
  }

  Future<File> getFileFromPossibilities(List<String> names) async {
    for (var file in names.map(getFile)) {
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Future<bool> hasFile(String path) async {
    return await getFile(path).exists();
  }

  @override
  Future<Configuration> getSubConfiguration(String key) async {
    return new MapConfiguration(await getMapSetting(key));
  }

  @override
  Future<List<Configuration>> getSubConfigurations(String key) async {
    var list = await getSetting(key);

    if (list is! List) {
      return const <Configuration>[];
    }

    var maps = list.where((x) => x is Map);

    return maps.map((x) {
      return new MapConfiguration(x);
    }).cast<Configuration>().toList();
  }

  @override
  Future<bool> hasStringSetting(String key) async {
    var str = await getStringSetting(key, null);

    return str != null;
  }
}
