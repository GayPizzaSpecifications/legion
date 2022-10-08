library legion.storage;

import "dart:convert";
import "dart:io";
import "dart:mirrors";

import "utils.dart";

typedef void StorageChecker(Map<String, dynamic> content);

class JsonStorageType extends StorageType {
  const JsonStorageType();

  @override
  Map<String, dynamic> decode(String input) =>
    json.decode(input, reviver: (key, value) {
      if (value is! String) return value;

      try {
        return DateTime.parse(value);
      } on FormatException {
        return value;
      }
    });

  @override
  String encode(Map<String, dynamic> input) =>
    new JsonEncoder.withIndent("  ", (value) {
      if (value is DateTime) {
        return value.toString();
      } else {
        return value;
      }
    }).convert(input);
}

abstract class StorageType {
  static const StorageType json = const JsonStorageType();

  const StorageType();

  String encode(Map<String, dynamic> input);

  Map<String, dynamic> decode(String input);
}

class Storage extends StorageContainer {
  final String path;
  final bool _saveOnChange;

  StorageType type = StorageType.json;
  List<StorageChecker> _checkers = [];
  Map<String, dynamic> _entries;

  Storage(this.path, { bool saveOnChange: true })
    : _saveOnChange = saveOnChange;

  void load() {
    var file = new File(path);

    if (!file.existsSync()) {
      _entries = {};
    } else {
      var content = file.readAsStringSync();
      var map = type.decode(content);

      if (map is! Map) {
        throw new Exception("JSON was not a map!");
      }

      for (var checker in _checkers) {
        checker(map);
      }

      _entries = map;
    }
  }

  void save() {
    var file = new File(path);

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    file.writeAsStringSync(type.encode(_entries) + "\n", flush: true);
  }

  void destroy() {
    save();
  }

  void addChecker(StorageChecker checker) {
    _checkers.add(checker);
  }

  Map<String, dynamic> asMap() => new Map.from(_entries);

  @override
  Map<String, dynamic> get entries => _entries;

  @override
  void onChange() {
    if (_saveOnChange) {
      save();
    }
  }

  void delete() {
    destroy();
    var file = new File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Map<String, dynamic> asPrimitiveMap() {
    return json.decode(StorageType.json.encode(entries));
  }

  String toJsonString() => StorageType.json.encode(entries);
}

class SubStorage extends StorageContainer {
  final StorageContainer parent;
  final String key;

  SubStorage(this.parent, this.key) {
    if (!parent.entries.containsKey(key)) {
      parent.entries[key] = {};
      parent.onChange();
    }
  }

  @override
  Map<String, dynamic> get entries => parent.entries[key];

  @override
  void onChange() {
    parent.onChange();
  }
}

abstract class StorageContainer {
  DateTime getTimestamp(String key, {DateTime defaultValue}) =>
    get(key, DateTime, defaultValue);

  String getString(String key, {String defaultValue}) =>
    get(key, String, defaultValue);

  int getInteger(String key, {int defaultValue}) => get(key, int, defaultValue);

  double getDouble(String key, {double defaultValue}) =>
    get(key, double, defaultValue);

  bool getBoolean(String key, {bool defaultValue: false}) =>
    get(key, bool, defaultValue);

  List<T> getList<T>(String key, {List<T> defaultValue}) =>
    get<List<dynamic>>(key, List, defaultValue).cast<T>();

  Map<String, dynamic> getMap(String key,
    {Map<String, dynamic> defaultValue}) => get(key, Map, defaultValue);

  dynamic getFromMap(String key, dynamic mapKey) => getMap(key)[mapKey];

  bool isInMap(String key, dynamic mapKey) => getMap(key).containsKey(mapKey);

  bool isInList(String key, dynamic value) =>
    getList(key, defaultValue: []).contains(value);

  int getListLength(String key) => getList(key, defaultValue: []).length;

  int incrementInteger(String key, {int defaultValue: 0}) =>
    addToInteger(key, 1);

  int decrementInteger(String key, {int defaultValue: 0}) =>
    subtractFromInteger(key, 1);

  int addToInteger(String key, int n, {int defaultValue: 0}) {
    var v = getInteger(key, defaultValue: defaultValue);
    v += n;
    setInteger(key, v);
    return v;
  }

  int subtractFromInteger(String key, int n, {int defaultValue: 0}) {
    var v = getInteger(key, defaultValue: defaultValue);
    v -= n;
    setInteger(key, v);
    return v;
  }

  double addToDouble(String key, num n, {double defaultValue: 0.0}) {
    var v = getDouble(key, defaultValue: defaultValue);
    v += n;
    setDouble(key, v);
    return v;
  }

  double subtractFromDouble(String key, double n, {double defaultValue: 0.0}) {
    var v = getDouble(key, defaultValue: defaultValue);
    v -= n;
    setDouble(key, v);
    return v;
  }

  dynamic remove(String key) {
    var value = entries[key];
    entries.remove(key);
    onChange();
    return value;
  }

  void setString(String key, String value) => set(key, String, value);

  void setInteger(String key, int value) => set(key, int, value);

  void setBoolean(String key, bool value) => set(key, bool, value);

  void setDouble(String key, double value) => set(key, double, value);

  void setList(String key, List<dynamic> value) => set(key, List, value);

  void setMap(String key, Map<dynamic, dynamic> value) => set(key, Map, value);

  void setTimestamp(String key, DateTime value) => set(key, DateTime, value);

  void addToList(String key, dynamic value) {
    var list = getList(key, defaultValue: []);
    list.add(value);
    setList(key, list);
  }

  void removeFromList(String key, dynamic value) =>
    setList(key, new List.from(getList(key, defaultValue: [])
      ..remove(value)));

  void putInMap(String key, dynamic mapKey, dynamic value) =>
    setMap(key, new Map.from(getMap(key, defaultValue: {}))..[mapKey] = value);

  void removeFromMap(String key, dynamic mapKey) =>
    setMap(key, new Map.from(getMap(key, defaultValue: {}))..remove(mapKey));

  void updateTimestamp(String key) => setTimestamp(key, new DateTime.now());

  void clearMap(String key) => setMap(key, {});

  void clearList(String key) => setList(key, []);

  List<String> getMapKeys(String key) => get(key, Map, {}).keys.toList();

  bool has(String key) => entries.containsKey(key);

  T get<T>(String key, Type type, T defaultValue) {
    var mirror = reflectType(type);

    dynamic value = defaultValue;

    if (entries.containsKey(key)) {
      value = entries[key];
    }

    var valueType = reflectType(value != null ? value.runtimeType : Null);

    if (!mirror.isAssignableTo(valueType)) {
      throw new LegionError("The value of '${key}' is not the correct type");
    }

    return value as T;
  }

  SubStorage getSubStorage(String key) {
    return new SubStorage(this, key);
  }

  void set(String key, Type type, value) {
    var mirror = reflectType(type);

    var valueType = reflectType(value != null ? value.runtimeType : Null);

    if (!mirror.isAssignableTo(valueType)) {
      throw new LegionError("The value of '${key}' is not the correct type");
    }

    entries[key] = value;
    onChange();
  }

  List<String> get keys => entries.keys.toList();

  void onChange();

  Map<String, dynamic> get entries;
}

class MockStorageContainer extends StorageContainer {
  @override
  Map<String, dynamic> get entries => <String, dynamic>{};

  @override
  void onChange() {}
}
