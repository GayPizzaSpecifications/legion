library legion.utils;

import "dart:async";
import "dart:io";
import "dart:convert";

import "package:path/path.dart" as pathlib;
import "package:ansicolor/ansicolor.dart" as ansicolor;
import "package:system_info2/system_info2.dart";

const Map<String, String> _architectures = const {
  "x86_64": "x64",
  "i386": "x86",
  "i686": "x86",
  "amd64": "x64"
};

class LegionError {
  final String message;

  LegionError(this.message);

  @override
  String toString() => message;
}

bool isArchX86_32Bit(String arch) =>
  [arch, _architectures[arch]].any((x) => const ["x86", "x32"].contains(x));

bool isTargetX86_32Bit(String target) =>
    isArchX86_32Bit(target.split("-").last);

class Icon {
  static const String NAV_ARROW = "\u27A4";
  static const String WARNING_SIGN = "\u26A0";
  static const String NIB = "\u2712";
  static const String RIGHTWARDS_ARROWHEAD = "\u27A4";
}

String getHomeDirectory() {
  if (Platform.isWindows) {
    return Platform.environment["USERPROFILE"];
  } else {
    return Platform.environment["HOME"];
  }
}

String getLegionHome() {
  if (Platform.environment["LEGION_HOME"] is String) {
    return Platform.environment["LEGION_HOME"];
  } else {
    return pathlib.join(getHomeDirectory(), ".legion");
  }
}

String getToolchainHome() {
  return pathlib.join(getLegionHome(), "toolchains");
}

Directory getLegionHomeSubDir(String path) {
  return new Directory(pathlib.join(getLegionHome(), path));
}

File getLegionHomeFile(String path) {
  return new File(pathlib.join(getLegionHome(), path));
}

void reportStatusMessage(String message) {
  var msg = "${'  ' * GlobalState.currentStatusLevel}"
            "${_blue(Icon.NAV_ARROW)} ${_magenta(message)}";

  print(msg);
}

void reportErrorMessage(String message) {
  GlobalState.hasError = true;
  exitCode = 1;

  var lines = message.trim().split("\n");
  var out = "${'  ' * GlobalState.currentStatusLevel}"
            "${_boldRed(Icon.NAV_ARROW)} ";

  int i = 0;
  for (String line in lines) {
    if (i == 0) {
      out += _magenta(line);
    } else {
      out += line;
    }
    out += "\n";
    i++;
  }

  print(out.trim());
}

Future executeWithStatusLevel(function()) async {
  GlobalState.currentStatusLevel++;

  try {
    await function();
  } finally {
    GlobalState.currentStatusLevel--;
  }
}

void reportWarningMessage(String message) {
  var lines = message.trim().split("\n");
  var out = "${'  ' * GlobalState.currentStatusLevel}"
            "${_gold(Icon.WARNING_SIGN)} ";

  int i = 0;
  for (String line in lines) {
    if (i == 0) {
      out += _magenta(line);
    } else {
      out += line;
    }
    out += "\n";
    i++;
  }

  print(out.trim());
}

class GlobalState {
  static int currentStatusLevel = 0;
  static bool hasError = false;
}

_magenta(String message) {
  return (new ansicolor.AnsiPen()..magenta())(message);
}

_gold(String message) {
  return (new ansicolor.AnsiPen()..yellow(bold: true))(message);
}

_boldCyan(String message) {
  return (new ansicolor.AnsiPen()..cyan(bold: true))(message);
}

_blue(String message) {
  return (new ansicolor.AnsiPen()..blue(bold: true))(message);
}

_boldRed(String message) {
  return (new ansicolor.AnsiPen()..red(bold: true))(message);
}

_red(String message) {
  return (new ansicolor.AnsiPen()..red())(message);
}

Future<Map<String, Map<String, dynamic>>> getTargetConfig() async {
  var file = getLegionHomeFile("targets.json");

  if (await file.exists()) {
    var content = await file.readAsString();

    return json.decode(content);
  } else {
    await file.create(recursive: true);
    await file.writeAsString("{}\n");
    return {};
  }
}

String resolveWorkingPath(String path, {from}) {
  if (from != null) {
    if (from is Directory) {
      from = from.path;
    } else if (from is! String) {
      from = from.toString();
    }
  } else {
    from = Directory.current.path;
  }

  return pathlib.join(from, path);
}

Future<T> readJsonFile<T>(String path, {inside, T defaultValue}) async {
  path = path.replaceAll("{LEGION}", getLegionHome());

  if (inside != null) {
    if (inside is Directory) {
      inside = inside.path;
    } else if (inside is! String) {
      inside = inside.toString();
    }

    path = pathlib.join(inside, path);
  }

  var file = new File(path);

  if (await file.exists()) {
    var result = json.decode(await file.readAsString());
    return result as T;
  } else {
    return defaultValue;
  }
}

Future writeJsonFile(String path, data) async {
  var file = new File(path);
  if (!(await file.exists())) {
    await file.create(recursive: true);
  }
  await file.writeAsString(const JsonEncoder.withIndent("  ").convert(
    data
  ) + "\n");
}

String getLocalArch() {
  var arch = SysInfo.kernelArchitecture;

  if (_architectures[arch] is String) {
    arch = _architectures[arch];
  }

  return arch;
}

String getLocalOperatingSystem() {
  var os = Platform.operatingSystem;

  if (os == "macos") {
    return "mac";
  }

  return os;
}

Future<String> findExecutable(String name) async {
  var paths = Platform.environment["PATH"].split(
    Platform.isWindows ? ";" : ":"
  );
  var tryFiles = [name];

  if (Platform.isWindows) {
    tryFiles.addAll(["${name}.exe", "${name}.bat"]);
  }

  for (var p in paths) {
    if (Platform.environment.containsKey("HOME")) {
      p = p.replaceAll("~/", Platform.environment["HOME"]);
    }

    var dir = new Directory(pathlib.normalize(p));

    if (!(await dir.exists())) {
      continue;
    }

    for (var t in tryFiles) {
      var file = new File("${dir.path}/${t}");

      if (await file.exists()) {
        return file.path;
      }
    }
  }

  return null;
}

Stream<String> findExecutablesMatching(Pattern pattern) async* {
  var paths = Platform.environment["PATH"].split(
    Platform.isWindows ? ";" : ":"
  );

  for (var p in paths) {
    if (Platform.environment.containsKey("HOME")) {
      p = p.replaceAll("~/", Platform.environment["HOME"]);
    }

    var dir = new Directory(p);
    if (!(await dir.exists())) {
      continue;
    }

    await for (var entity in dir.list()) {
      if (entity is! File) {
        continue;
      }

      var file = entity as File;
      var stat = await file.stat();

      file = file.absolute;

      if (!hasPermission(stat.mode, FilePermission.EXECUTE)) {
        continue;
      }

      var name = pathlib.basename(file.path);

      if (name.endsWith(".exe")) {
        name = name.substring(0, name.length - 4);
      }

      if (pattern.allMatches(name).isNotEmpty) {
        yield file.path;
      }
    }
  }
}

String findExecutableSync(String name) {
  var paths = Platform.environment["PATH"].split(
    Platform.isWindows ? ";" : ":"
  );
  var tryFiles = [name];

  if (Platform.isWindows) {
    tryFiles.addAll(["${name}.exe", "${name}.bat"]);
  }

  for (var p in paths) {
    if (Platform.environment.containsKey("HOME")) {
      p = p.replaceAll("~/", Platform.environment["HOME"] + "/");
    }

    var dir = new Directory(pathlib.normalize(p));

    if (!dir.existsSync()) {
      continue;
    }

    for (var t in tryFiles) {
      var file = new File("${dir.path}/${t}");

      if (file.existsSync()) {
        return file.path;
      }
    }
  }

  return null;
}

bool getBooleanEnvSetting(String name) {
  var env = "LEGION_" + name.replaceAll(".", "_").toUpperCase();

  if (const [
    "yes",
    "y",
    "1",
    "true",
    "ON",
    "on"
  ].contains(Platform.environment[env])) {
    return true;
  }

  return false;
}

List<List<String>> splitExtraArguments(List<String> args, [int split = 0]) {
  var out = <List<String>>[];

  var list = <String>[];
  for (var i = 0; i < args.length; i++) {
    var arg = args[i];

    if (split > 0 && out.length >= split) {
      if (out.isEmpty) {
        list.add(arg);
      } else {
        out.last.add(arg);
      }
    } else if (arg == "--") {
      out.add(list);
      list = <String>[];
      if (split > 0 && out.length >= split) {
        i--;
      }
    } else {
      list.add(arg);
    }
  }

  if (list.isNotEmpty) {
    out.add(list);
  }

  return out;
}

Future<dynamic> makeChoiceByFileExistence(Map<String, dynamic> files, {from}) async {
  for (var key in files.keys) {
    var p = resolveWorkingPath(key, from: from);
    var file = new File(p);

    if (await file.exists()) {
      return files[key];
    }
  }

  return files["_"];
}

Future<File> getFileFromPossibleExtensions(String basePath, List<String> extensions) async {
  var file = new File(basePath);

  if (await file.exists()) {
    return file;
  }

  for (var ext in extensions) {
    if (ext.startsWith(".")) {
      ext = ext.substring(1);
    }
    file = new File("${basePath}.${ext}");

    if (await file.exists()) {
      return file;
    }
  }

  return new File(basePath);
}

final RegExp _shellEscapeNeeded = new RegExp(r"[^A-Za-z0-9_\/:=-]");
final RegExp _shellEscapeDupSingle = new RegExp(r"^(?:'')+");
final RegExp _shellEscapeNonEscaped = new RegExp(r"\\'''");

String escapeShellArgument(String arg) {
  if (_shellEscapeNeeded.hasMatch(arg)) {
    arg = "'" + arg.replaceAll("'", "'\\''") + "'";
    arg = arg
      .replaceAll(_shellEscapeDupSingle, "")
      .replaceAll(_shellEscapeNonEscaped, "\\'");
  }
  return arg;
}

String escapeShellArgumentList(List<String> args) {
  return args.map(escapeShellArgument).join(" ");
}

String escapeShellArguments(String exe, List<String> args) {
  var out = <String>[];

  void escape(String arg) {
    out.add(escapeShellArgument(arg));
  }

  escape(exe);

  for (var arg in args) {
    escape(arg);
  }

  return out.join(" ");
}

class FilePermission {
  final int index;
  final String _name;

  const FilePermission._(this.index, this._name);

  static const EXECUTE = const FilePermission._(0, 'EXECUTE');
  static const WRITE = const FilePermission._(1, 'WRITE');
  static const READ = const FilePermission._(2, 'READ');
  static const SET_UID = const FilePermission._(3, 'SET_UID');
  static const SET_GID = const FilePermission._(4, 'SET_GID');
  static const STICKY = const FilePermission._(5, 'STICKY');

  static const List<FilePermission> values = const [EXECUTE, WRITE, READ, SET_UID, SET_GID, STICKY];

  String toString() => 'FilePermission.$_name';
}

class FilePermissionRole {
  final int index;
  final String _name;

  const FilePermissionRole._(this.index, this._name);

  static const WORLD = const FilePermissionRole._(0, 'WORLD');
  static const GROUP = const FilePermissionRole._(1, 'GROUP');
  static const OWNER = const FilePermissionRole._(2, 'OWNER');

  static const List<FilePermissionRole> values = const [WORLD, GROUP, OWNER];

  String toString() => 'FilePermissionRole.$_name';
}

bool hasPermission(int fileStatMode, FilePermission permission, {FilePermissionRole role: FilePermissionRole.WORLD}) {
  var bitIndex = _getPermissionBitIndex(permission, role);
  return (fileStatMode & (1 << bitIndex)) != 0;
}

int _getPermissionBitIndex(FilePermission permission, FilePermissionRole role) {
  switch (permission) {
    case FilePermission.SET_UID: return 11;
    case FilePermission.SET_GID: return 10;
    case FilePermission.STICKY: return 9;
    default: return (role.index * 3) + permission.index;
  }
}

dynamic resolveConfigValue(root, String key) {
  dynamic _resolve(sec, List<String> parts) {
    if (sec is Map) {
      if (parts.length == 1) {
        return sec[parts.first];
      }

      var fkey = parts.join(".");
      if (sec.containsKey(fkey)) {
        return sec[fkey];
      }

      var rkey = parts.first;

      if (sec.containsKey(rkey)) {
        return _resolve(sec[rkey], parts.sublist(1));
      }

      return null;
    } else {
      return null;
    }
  }

  return _resolve(root, key.split("."));
}

Map<String, dynamic> _globalConfiguration;

Future<dynamic> readGlobalConfigSetting(String key, [defaultValue]) async {
  if (_globalConfiguration == null) {
    var file = getLegionHomeFile("config.json");
    if (!(await file.exists())) {
      return defaultValue;
    }
    var content = await file.readAsString();
    _globalConfiguration = json.decode(content);
  }

  var value = resolveConfigValue(_globalConfiguration, key);

  if (value == null) {
    value = defaultValue;
  }
  return value;
}
