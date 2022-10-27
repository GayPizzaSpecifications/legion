library legion.builders.autotools;

import "dart:async";

import "package:legion/api.dart";
import "package:legion/io.dart";
import "package:legion/utils.dart";

class AutotoolsBuilder extends Builder {
  AutotoolsBuilder(Target target) : super(target);

  @override
  Future generate() async {
    await target.ensureCleanBuildDirectory();

    var configureScriptFile = target.project.getFile("configure");
    var shouldRunBootstrap = !(await target.project.getBooleanSetting(
      "autotools.bootstrap.disable"
    ));

    if (shouldRunBootstrap) {
      var exe = "bash";
      var args = <String>[];

      var bootstrapFile = target.project.getFile("bootstrap");

      if (!(await bootstrapFile.exists())) {
        bootstrapFile = target.project.getFile("autogen.sh");
      }

      if (!(await bootstrapFile.exists())) {
        exe = "autoconf";
      } else {
        args = <String>[bootstrapFile.path];
      }

      var result = await executeCommand(
        exe,
        args: args,
        writeToBuffer: true,
        inherit: true,
        workingDirectory: target.project.directory.path
      );

      if (result.exitCode != 0) {
        throw new LegionError("Bootstrap failed for target ${target.id.name}");
      }
    }

    var args = <String>[
      configureScriptFile.path
    ];

    args.addAll(target.extraArguments);

    var targetMachine = await target.toolchain.getTargetMachine();
    args.add("--host=${targetMachine}");

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
      "bash",
      args: args,
      inherit: true,
      workingDirectory: target.buildDirectory.path
    );

    if (result.exitCode != 0) {
      throw new LegionError("Configure failed for target ${target.id.name}");
    }
  }

  @override
  Future build() async {
    var args = <String>[];

    args.addAll(target.extraArguments);

    var result = await executeCommand(
      "make",
      args: args,
      inherit: true,
      workingDirectory: target.buildDirectory.path
    );

    if (result.exitCode != 0) {
      throw new LegionError("Make failed for target ${target.id.name}");
    }
  }
}

class AutotoolsBuilderProvider extends BuilderProvider {
  @override
  Future<ProviderDescription> describe() async => new ProviderDescription.generic(
    "autotools",
    "GNU Autotools"
  );

  @override
  Future<Builder> create(Target target) async {
    return new AutotoolsBuilder(target);
  }

  @override
  Future<bool> isProjectSupported(Project project) async {
    return await project.hasFile("configure") || (
      await project.hasFile("bootstrap") ||
      await project.hasFile("autogen.sh")
    ) || await project.hasFile("configure.ac");
  }
}
