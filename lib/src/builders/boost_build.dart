library legion.builders.b2;

import "dart:async";
import "dart:io";

import "package:legion/api.dart";
import "package:legion/io.dart";
import "package:legion/utils.dart";

class BoostBuilder extends Builder {
  BoostBuilder(Target target) : super(target);

  @override
  Future generate() async {
    await target.ensureCleanBuildDirectory();

    var shouldRunBootstrap = !(await target.project.getBooleanSetting(
      "b2.bootstrap.disable"
    ));

    var shouldSpecifyToolset = !(await target.project.getBooleanSetting(
      "b2.bootstrap.toolset.disable"
    ));

    if (shouldRunBootstrap) {
      var exe = "bash";
      var args = <String>[];

      var projectConfigFile = await target.project.getFile(
        "project-config.jam"
      );

      if (await projectConfigFile.exists()) {
        await projectConfigFile.delete();
      }

      var bootstrapFile = await target.project.getFileFromPossibilities(const [
        "bootstrap",
        "bootstrap.sh"
      ]);

      if (bootstrapFile != null) {
        args.add(bootstrapFile.path);

        var ccTool = await target.toolchain.getCompilerTool("cc");
        var id = (await ccTool.getCompilerId()).toLowerCase();

        if (id == "unknown") {
          id = "cc";
        }

        if (shouldSpecifyToolset) {
          args.add("--with-toolset=${id}");
        }

        var result = await executeCommand(
          exe,
          args: args,
          writeToBuffer: true,
          inherit: true,
          pty: true,
          workingDirectory: target.project.directory.path,
          environment: await _calculateEnvironment()
        );

        if (result.exitCode != 0) {
          throw new LegionError("Bootstrap failed for target ${target.id.name}");
        }
      }
    }
  }

  @override
  Future build() async {
    var args = <String>[];
    args.add("--build-dir=${target.buildDirectory.path}");

    var ccTool = await target.toolchain.getCompilerTool("cc");
    var id = (await ccTool.getCompilerId()).toLowerCase();

    if (id == "unknown") {
      id = "cc";
    }

    args.add("--toolset=${id}");

    args.addAll(target.extraArguments);

    var exe = await target.project.getFile("b2");

    if (!(await exe.exists())) {
      var path = await findExecutable("b2");

      if (path != null) {
        exe = new File(path);
      }
    }

    if (exe == null || !(await exe.exists())) {
      throw new LegionError(
        "b2 command could not be found for target ${target.id.name}"
      );
    }

    var result = await executeCommand(
      exe.path,
      args: args,
      inherit: true,
      workingDirectory: target.project.directory.path,
      environment: await _calculateEnvironment()
    );

    if (result.exitCode != 0) {
      throw new LegionError("b2 failed for target ${target.id.name}");
    }
  }

  Future<Map<String, String>> _calculateEnvironment() async {
    var targetMachine = await target.toolchain.getTargetMachine();

    var system = await target.toolchain.getSystemName();
    var cc = await target.toolchain.getToolPath("cc");
    var cxx = await target.toolchain.getToolPath("c++");
    var env = await target.toolchain.getEnvironmentVariables();

    var environment = {
      "CC": cc,
      "CXX": cxx,
      "SYSTEM": system,
      "TARGET_MACHINE": targetMachine
    };

    for (var key in env.keys) {
      environment[key] = escapeShellArgumentList(env[key]);
    }

    return environment;
  }
}

class BootBuilderProvider extends BuilderProvider {
  @override
  Future<ProviderDescription> describe() async => new ProviderDescription.generic(
    "boost-build",
    "Boost.Build"
  );

  @override
  Future<Builder> create(Target target) async {
    return new BoostBuilder(target);
  }

  @override
  Future<bool> isProjectSupported(Project project) async {
    return await project.hasFile("boost-build.jam");
  }
}
