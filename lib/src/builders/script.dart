library legion.builders.script;

import "dart:async";

import "package:legion/api.dart";
import "package:legion/io.dart";
import "package:legion/utils.dart";

const List<String> buildScriptPossibilities = const <String>[
  "build.sh",
  "tool/build.sh",
  "tool/build",
  "tools/build.sh",
  "tools/build",
  "script/build.sh",
  "script/build",
  "scripts/build.sh",
  "scripts/build",
  "build"
];

const List<String> configureScriptPossibilities = const <String>[
  "configure.sh",
  "tool/configure.sh",
  "tool/configure",
  "tools/configure.sh",
  "tools/configure",
  "script/configure.sh",
  "script/configure",
  "scripts/configure.sh",
  "scripts/configure",
  "configure"
];

class ScriptBuilder extends Builder {
  ScriptBuilder(Target target) : super(target);

  @override
  Future generate() async {
    await target.ensureCleanBuildDirectory();

    var configureScriptFile = await target.project.getFileFromPossibilities(
      configureScriptPossibilities
    );

    if (configureScriptFile == null || !(await configureScriptFile.exists())) {
      return;
    }

    var args = <String>[];

    args.addAll(target.extraArguments);

    var system = await target.toolchain.getSystemName();
    var cc = await target.toolchain.getToolPath("cc");
    var cxx = await target.toolchain.getToolPath("c++");
    var env = await target.toolchain.getEnvironmentVariables();

    args.add("CC=${cc}");
    args.add("CXX=${cxx}");
    args.add("SYSTEM=${system}");

    for (var key in env.keys) {
      args.add("${key}=${escapeShellArgumentList(env[key])}");
    }

    var result = await executeCommand(
      configureScriptFile.path,
      args: args,
      inherit: true,
      workingDirectory: target.buildDirectory.path
    );

    if (result.exitCode != 0) {
      throw new LegionError("Configure failed for target ${target.name}");
    }
  }

  @override
  Future build() async {
    var buildScriptFile = await target.project.getFileFromPossibilities(
      buildScriptPossibilities
    );

    if (buildScriptFile == null || !(await buildScriptFile.exists())) {
      reportWarningMessage("Build script file not found");
      return;
    }

    var args = <String>[];

    args.addAll(target.extraArguments);

    var system = await target.toolchain.getSystemName();
    var cc = await target.toolchain.getToolPath("cc");
    var cxx = await target.toolchain.getToolPath("c++");
    var env = await target.toolchain.getEnvironmentVariables();

    args.add("CC=${cc}");
    args.add("CXX=${cxx}");
    args.add("SYSTEM=${system}");
    args.add("PROJECT=${target.project.directory.path}");

    for (var key in env.keys) {
      args.add("${key}=${escapeShellArgumentList(env[key])}");
    }

    var result = await executeCommand(
      buildScriptFile.path,
      args: args,
      inherit: true,
      workingDirectory: target.buildDirectory.path
    );

    if (result.exitCode != 0) {
      throw new LegionError("Build failed for target ${target.name}");
    }
  }
}

class ScriptBuilderProvider extends BuilderProvider {
  @override
  Future<ProviderDescription> describe() async => new ProviderDescription.generic(
    "script",
    "Custom Scripts"
  );

  @override
  Future<Builder> create(Target target) async {
    return new ScriptBuilder(target);
  }

  @override
  Future<bool> isProjectSupported(Project project) async {
    var buildScriptFile = await project.getFileFromPossibilities(
      buildScriptPossibilities
    );

    return buildScriptFile != null && await buildScriptFile.exists();
  }
}
