library legion.builders.cmake;

import "dart:async";

import "package:legion/api.dart";
import "package:legion/io.dart";
import "package:legion/utils.dart";

String getCMakeSystemName(String target) {
  if (target.contains("linux")) {
    return "Linux";
  } else if (target.contains("win32") || target.contains("mingw32")) {
    return "Windows";
  } else if (target.contains("darwin") || target.contains("mac")) {
    return "Darwin";
  } else {
    return "Unknown";
  }
}

Map<String, String> generateNormalCMakeToolchain(
  String system,
  String target,
  String cc,
  String cpp,
  String machine) {
  if (system == null) {
    system = getCMakeSystemName(target);
  }

  var map = <String, String>{
    "CMAKE_SYSTEM_NAME": system,
    "CMAKE_C_COMPILER": cc,
    "CMAKE_CXX_COMPILER": cpp
  };

  if (machine != null) {
    map.addAll(<String, String>{
      "CMAKE_C_COMPILER_TARGET": machine,
      "CMAKE_CXX_COMPILER_TARGET": machine
    });
  }

  var cflags = <String>[];
  var cxxflags = <String>[];

  map["CMAKE_C_FLAGS"] = cflags.join(" ");
  map["CMAKE_CXX_FLAGS"] = cxxflags.join(" ");

  return map;
}

class CMakeTargetGenerator {
  final Target target;

  String toolchainFilePath;
  Map<String, dynamic> defs = <String, dynamic>{};
  Map<String, List<String>> toolchainDefs = <String, List<String>>{};

  CMakeTargetGenerator(this.target);

  Future configureCMakeTarget() async {
    var file = target.project.getFile(
      "legion/.toolchains/${target.id.name}.cmake"
    );

    var out = new StringBuffer();
    for (var key in toolchainDefs.keys) {
      String mval = '"' + toolchainDefs[key].join(" ") + '"';
      out.writeln("set(${key} ${mval})");
    }

    if (await file.exists()) {
      await file.delete();
    }

    await file.create(recursive: true);
    await file.writeAsString(out.toString());

    toolchainFilePath = file.absolute.path;
  }

  void define(String key, value) {
    defs[key] = value;
  }

  void defineOrAppend(String key, value) {
    var tmp = defs[key];
    if (tmp is String && tmp.trim().isNotEmpty) {
      tmp += (tmp.endsWith(" ") ? "" : " ") + value;
    } else {
      tmp = value;
    }
    defs[key] = tmp;
  }

  Future configure() async {
    await configureCMakeTarget();

    if (toolchainFilePath != null) {
      defs["CMAKE_TOOLCHAIN_FILE"] = toolchainFilePath;
    }
  }

  void addToolchainDefs(Map<String, String> map) {
    for (String key in map.keys) {
      var nval = map[key];
      var val = toolchainDefs[key];

      if (val == null) {
        val = toolchainDefs[key] = [];
      }

      val.add(nval);
    }
  }

  List<String> generateArguments([List<String> post]) {
    if (post == null) {
      post = <String>[];
    }

    var args = <String>[];

    for (String key in defs.keys) {
      args.add("-D${key}=${defs[key]}");
    }

    args.addAll(post);

    return args;
  }
}

class CMakeBuilder extends Builder {
  CMakeBuilder(Target target) : super(target);

  @override
  Future generate() async {
    var system = await target.toolchain.getSystemName();
    var cc = await target.toolchain.getToolPath("cc");
    var cxx = await target.toolchain.getToolPath("c++");
    var env = await target.toolchain.getEnvironmentVariables();

    var cflags = env["CFLAGS"] is List ? env["CFLAGS"] : [];
    var cxxflags = env["CCFLAGS"] is List ? env["CCFLAGS"] : [];

    var generator = new CMakeTargetGenerator(target);

    String targetMachine;
    if (await target.toolchain.needsTargetSpecified()) {
      targetMachine = await target.toolchain.getTargetMachine();
    }

    generator.addToolchainDefs(generateNormalCMakeToolchain(
      system,
      target.id.name,
      cc,
      cxx,
      targetMachine
    ));

    await generator.configure();

    for (var flag in cflags) {
      generator.defineOrAppend("CMAKE_C_FLAGS", flag);
    }

    for (var flag in cxxflags) {
      generator.defineOrAppend("CMAKE_CXX_FLAGS", flag);
    }

    var userDefs = new Map<String, dynamic>.from(
      await target.project.getMapSetting("cmake.defs")
    );

    userDefs.addAll(
      await target.project.getMapSetting("cmake.targets.${target}.defs")
    );

    for (var key in userDefs.keys) {
      generator.defineOrAppend(key, userDefs[key]);
    }

    var dir = await target.ensureCleanBuildDirectory();

    var extraArguments = new List<String>.from(target.extraArguments);

    extraArguments.add("-G");
    extraArguments.add(await target.getStringSetting(
      "cmake.generator",
      "Unix Makefiles"
    ));

    extraArguments.add("../..");

    var args = generator.generateArguments(extraArguments);
    var inherit = await target.getBooleanSetting("cmake.verbose");
    var result = await executeCommand(
      "cmake",
      args: args,
      workingDirectory: dir.path,
      writeToBuffer: true,
      inherit: inherit,
      pty: true
    );

    if (result.exitCode != 0) {
      var msg = "CMake failed for target ${target.id.name}";

      if (!inherit) {
        msg += "\n${result.output}";
      }
      throw new LegionError(msg);
    }
  }

  @override
  Future build() async {
    var dir = target.buildDirectory;

    var cmd = await makeChoiceByFileExistence({
      "Makefile": "make",
      "build.ninja": "ninja",
      "_": "make"
    }, from: dir.path);

    var result = await executeCommand(
      cmd,
      args: target.extraArguments,
      inherit: true,
      workingDirectory: dir.path,
      pty: true
    );

    if (result.exitCode != 0) {
      throw new LegionError("Build failed for target ${target.id.name}");
    }
  }
}

class CMakeBuilderProvider extends BuilderProvider {
  @override
  Future<ProviderDescription> describe() async => new ProviderDescription.generic(
    "cmake",
    "CMake"
  );

  @override
  Future<bool> isProjectSupported(Project project) async {
    return await project.hasFile("CMakeLists.txt");
  }

  @override
  Future<Builder> create(Target target) async => new CMakeBuilder(target);
}
