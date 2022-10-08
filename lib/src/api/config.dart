part of legion.api;

abstract class Configuration {
  Future<dynamic> getSetting(String key);
  Future<List<String>> getStringListSetting(String key);
  Future<Map<String, dynamic>> getMapSetting(String key);
  Future<bool> getBooleanSetting(String key);
  Future<String> getStringSetting(String key, [String defaultValue = ""]);
  Future<Configuration> getSubConfiguration(String key);

  Future<List<Configuration>> getSubConfigurations(String key);

  Future<bool> hasStringSetting(String key);
}

class MockConfiguration extends Configuration {
  @override
  Future<bool> getBooleanSetting(String key) async => false;

  @override
  Future<Map<String, dynamic>> getMapSetting(String key) async =>
    const <String, dynamic>{};

  @override
  Future<dynamic> getSetting(String key) async => null;

  @override
  Future<List<String>> getStringListSetting(String key) async =>
    const <String>[];

  @override
  Future<String> getStringSetting(String key, [String defaultValue = ""]) async =>
    defaultValue;

  @override
  Future<Configuration> getSubConfiguration(String key) async {
    return this;
  }

  @override
  Future<bool> hasStringSetting(String key) async => false;

  @override
  Future<List<Configuration>> getSubConfigurations(String key) async => const [];
}

class MapConfiguration extends Configuration {
  final Map<String, dynamic> map;

  MapConfiguration(this.map);

  @override
  Future<bool> getBooleanSetting(String key) async {
    return (await getSetting(key)) == true;
  }

  @override
  Future<Map<String, dynamic>> getMapSetting(String key) async {
    var value = await getSetting(key);
    if (value is Map) {
      return value;
    }
    return const <String, dynamic>{};
  }

  @override
  Future<dynamic> getSetting(String key) async {
    return await resolveConfigValue(map, key);
  }

  @override
  Future<List<String>> getStringListSetting(String key) async {
    var value = await getSetting(key);
    if (value is List) {
      return value.map((x) => x.toString()).toList();
    }
    return const <String>[];
  }

  @override
  Future<String> getStringSetting(String key, [String defaultValue = ""]) async {
    var value = await getSetting(key);
    if (value is String) {
      return value;
    }
    return defaultValue;
  }

  @override
  Future<Configuration> getSubConfiguration(String key) async {
    return new MapConfiguration(await getMapSetting(key));
  }

  @override
  Future<bool> hasStringSetting(String key) async => (
    await getStringSetting(key, null)
  ) != null;

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
}
