library legion.toolchains.crosstool;

import "dart:async";
import "dart:io";

import "package:legion/api.dart";
import "package:legion/utils.dart";
import "package:legion/io.dart";
import "package:legion/legit.dart";

import "package:path/path.dart" as pathlib;

import "gcc.dart" as Gcc;

const String _gitUrl = "https://github.com/crosstool-ng/crosstool-ng.git";

const Map<String, String> crosstoolTargetMap = const {
  "linux-x86": "i686-ubuntu16.04-linux-gnu",
  "linux-x64": "x86_64-unknown-linux-gnu",
  "linux-x64-musl": "x86_64-multilib-linux-musl",
  "linux-arm": "arm-unknown-eabi",
  "linux-arm-rpi1": "armv6-unknown-linux-gnueabi",
  "linux-arm-rpi2": "armv7-rpi2-linux-gnueabihf",
  "linux-arm-rpi3": "armv8-rpi3-linux-gnueabihf",
  "linux-arm-rpi4": "armv8-rpi4-linux-gnueabihf",
  "linux-arm-uclibc": "arm-unknown-linux-uclibcgnueabi",
  "linux-mipsel": "mipsel-unknown-linux-gnu",
  "linux-powerpc": "powerpc-unknown-linux-gnu",
  "linux-powerpc-860": "powerpc-860-linux-gnu",
  "linux-mips": "mips-malta-linux-gnu",
  "linux-powerpc-e500v2": "powerpc-e500v2-linux-gnuspe",
  "linux-sparc": "sparc-unknown-linux-gnu",
  "windows-x86": "i686-w64-mingw32",
  "windows-x64": "x86_64-w64-mingw32"
};

class CrossTool {
  CrossTool();

  bootstrap({bool force: false}) async {
    if (!force) {
      if (await getLegionHomeFile(
        pathlib.join("crosstool-install", "bin", "ct-ng")
      ).exists()) {
        return;
      }
    }

    reportStatusMessage("Updating CrossTool Source");

    var dir = _getGitDir();

    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }

    var git = new GitClient.forDirectory(dir);

    if (!(await git.isRepository())) {
      await git.clone(_gitUrl);
    }

    reportStatusMessage("Bootstrapping CrossTool");

    var result = await executeCommand(
      "bash",
      args: ["bootstrap"],
      workingDirectory: dir.path,
      writeToBuffer: true
    );

    if (result.exitCode != 0) {
      throw new LegionError(
        "Failed to bootstrap CrossTool:\n${result.output}".trim()
      );
    }

    reportStatusMessage("Configuring CrossTool");

    result = await executeCommand(
      "bash",
      args: ["configure", "--prefix", _getInstallDir().path],
      workingDirectory: dir.path,
      writeToBuffer: true
    );

    if (result.exitCode != 0) {
      throw new LegionError("Failed to configure CrossTool:\n${result.output}");
    }

    reportStatusMessage("Making CrossTool");

    result = await executeCommand(
      "make",
      args: ["install"],
      workingDirectory: dir.path,
      writeToBuffer: true
    );

    if (result.exitCode != 0) {
      throw new LegionError("Failed to make CrossTool:\n${result.output}");
    }
  }

  Directory _getGitDir() {
    if (_gitDir == null) {
      _gitDir = getLegionHomeSubDir("crosstool-git").absolute;
    }
    return _gitDir;
  }

  Directory _getInstallDir() {
    if (_installDir == null) {
      _installDir = getLegionHomeSubDir("crosstool-install").absolute;
      if (!_installDir.existsSync()) {
        _installDir.createSync(recursive: true);
      }
    }

    return _installDir;
  }

  Directory _getWorkingDir() {
    if (_workingDir == null) {
      _workingDir = getLegionHomeSubDir("crosstool-work").absolute;
      if (!_workingDir.existsSync()) {
        _workingDir.createSync(recursive: true);
      }

      var workingDirSrc = Directory(pathlib.join(_workingDir.path, "src"));
      if (!workingDirSrc.existsSync()) {
        workingDirSrc.createSync(recursive: true);
      }
    }

    return _workingDir;
  }

  Directory _gitDir;
  Directory _installDir;
  Directory _workingDir;

  Future<ExecutionResult> _run(List<String> args, {
    bool inherit: false,
    Map<String, String> env: const {}
  }) async {
    return await executeCommand(
      pathlib.join(_getInstallDir().path, "bin", "ct-ng"),
      args: args,
      writeToBuffer: true,
      workingDirectory: _getWorkingDir().path,
      environment: env,
      outputHandler: (String out) {
        if (inherit && out.trim().isNotEmpty) {
          stdout.writeln(out);
        }
      }
    );
  }

  Future<List<String>> listSamples() async {
    var result = await _run(["list-samples"]);
    var lines = result.output.split("\n");

    var out = <String>[];

    for (String line in lines) {
      if (!line.startsWith("[")) {
        continue;
      }

      var status = line.substring(1, line.indexOf("]"));
      if (status.contains("B")) {
        continue;
      }

      var name = line.substring(line.indexOf("]") + 2).trim();

      out.add(name);
    }

    return out;
  }

  Future chooseSample(String name) async {
    var result = await _run([name]);

    if (result.exitCode != 0) {
      throw new LegionError(
        "Failed to choose sample: ${name}\n${result.output}"
      );
    }

    _lastToolchainSwitch = name;
  }

  Future build({bool inherit: true}) async {
    await changeConfigFile({
      "LOG_PROGRESS_BAR": "n",
      "CT_PREFIX_DIR": pathlib.join(getToolchainHome(), _lastToolchainSwitch),
      "CT_LOCAL_TARBALLS_DIR": pathlib.join(_getWorkingDir().path, "src")
    });

    reportStatusMessage("Building toolchain ${_lastToolchainSwitch}");

    var result = await _run([
      "build"
    ], inherit: inherit);

    if (result.exitCode != 0) {
      throw new LegionError(
        "Failed to build toolchain ${_lastToolchainSwitch}" +
          (inherit ? "" : ".\n${result.output}")
      );
    }
  }

  String _lastToolchainSwitch = "unknown";

  Future<String> getToolchain(String name, {bool install: false}) async {
    var prefix = pathlib.join(getToolchainHome(), name, "bin", "${name}-");
    var gcc = new File("${prefix}gcc");
    var gpp = new File("${prefix}g++");

    if (await gcc.exists() && await gpp.exists()) {
      return prefix.substring(0, prefix.length - 1);
    } else {
      if (install) {
        await bootstrap();
        await chooseSample(name);
        await build();
        return prefix;
      } else {
        throw new LegionError("Toolchain ${name} not found");
      }
    }
  }

  Future changeConfigFile(Map<String, dynamic> custom) async {
    var file = new File(pathlib.join(_getWorkingDir().path, ".config"));
    var lines = await file.readAsLines();
    var out = {};
    for (String line in lines) {
      if (line.startsWith("#")) {
        continue;
      }

      if (!line.contains("=")) {
        continue;
      }

      var parts = line.split("=");
      var key = parts[0];
      var value = parts.skip(1).join("=");
      out[key] = value;
    }

    for (var key in custom.keys) {
      var mkey = key;
      if (!key.startsWith("CT_")) {
        key = "CT_${key}";
      }

      out[key] = custom[mkey];
    }

    var wlines = [];
    for (var key in out.keys) {
      wlines.add("${key}=${out[key]}");
    }
    await file.writeAsString(wlines.join("\n"));
  }
}

class CrossToolToolchainProvider extends ToolchainProvider {
  final CrossTool crosstool = new CrossTool();

  @override
  Future<ProviderDescription> describe() async => new ProviderDescription.generic(
    "crosstool",
    "CrossTool"
  );

  @override
  Future<bool> isTargetSupported(String target, Configuration config) async {
    await crosstool.bootstrap();

    if (crosstoolTargetMap[target] is String) {
      target = crosstoolTargetMap[target];
    }

    var samples = await crosstool.listSamples();
    print(samples.join("\n"));
    return samples.contains(target);
  }

  @override
  Future<Toolchain> getToolchain(String target, Configuration config) async {
    await crosstool.bootstrap();

    var original = target;
    if (crosstoolTargetMap[target] is String) {
      target = crosstoolTargetMap[target];
    }

    var path = await crosstool.getToolchain(target, install: true);
    var gcc = new Gcc.GccTool("${path}-gcc");

    var toolchain = new Gcc.GccToolchain(
      original,
      gcc
    );

    return toolchain;
  }

  @override
  Future<List<String>> listFriendlyTargets() async {
    return crosstoolTargetMap.keys.toList();
  }

  @override
  Future<List<String>> listSupportedTargets() async {
    return await listFriendlyTargets();
  }
}
