library legion.builder;

import "dart:async";
import "dart:io";

import "api.dart";
import "utils.dart";

import "src/builders/cmake.dart" as CMake;
import "src/builders/autotools.dart" as Autotools;
import "src/builders/boost_build.dart" as BoostBuild;
import "src/builders/script.dart" as ScriptBuilder;

import "src/toolchains/crosstool.dart" as CrossTool;
import "src/toolchains/gcc.dart" as Gcc;
import "src/toolchains/clang.dart" as Clang;

import "src/assemblies/copy_executable.dart" as CopyExecutable;

part "src/builder/stage.dart";
part "src/builder/cycle.dart";
part "src/builder/toolchains.dart";

final List<BuilderProvider> builderProviders = <BuilderProvider>[
  new CMake.CMakeBuilderProvider(),
  new Autotools.AutotoolsBuilderProvider(),
  new BoostBuild.BootBuilderProvider(),
  new ScriptBuilder.ScriptBuilderProvider()
];

final List<ToolchainProvider> toolchainProviders = <ToolchainProvider>[
  new CrossTool.CrossToolToolchainProvider()
];

final List<AssemblyStepProvider> assemblyProviders = <AssemblyStepProvider>[
  new CopyExecutable.CopyExecutableAssemblyStepProvider()
];

class BuildStageExecution {
  final BuildStage stage;
  final List<String> extraArguments;
  final List<String> targets;

  BuildStageExecution(this.stage, this.targets, this.extraArguments);
}

executeBuildStages(
  Directory directory,
  List<BuildStageExecution> executions,
  {
    onProjectLoaded(Project project)
  }) async {
  var project = new Project(directory);
  await project.init();

  if (onProjectLoaded != null) {
    await onProjectLoaded(project);
  }

  for (var execution in executions) {
    var cycle = new BuildCycle(
      project,
      execution.stage,
      execution.targets,
      execution.extraArguments
    );

    await cycle.run();
  }
}

Future<List<ToolchainProvider>> loadAllToolchains() async {
  var toolchainProviderList = <ToolchainProvider>[];

  toolchainProviderList.addAll(await loadCustomToolchains());
  // toolchainProviderList.addAll(await findGccToolchains());
  toolchainProviderList.addAll(await findClangToolchains());
  toolchainProviderList.addAll(toolchainProviders);

  return toolchainProviderList;
}

Future<ToolchainProvider> resolveToolchainProvider(String targetName, [Configuration config]) async {
  if (config == null) {
    config = new MockConfiguration();
  }

  var providers = await loadAllToolchains();

  for (var provider in providers) {
    var info = await provider.describe();

    var tname = targetName;
    if (targetName.startsWith("${info.id}:")) {
      tname = targetName.substring("${info.id}:".length);
    }

    if (targetName.startsWith("${info.id.replaceAll('/', '-')}:")) {
      tname = targetName.substring("${info.id.replaceAll('/', '-')}:".length);
    }

    if (targetName.startsWith("${info.id.replaceAll('/', '-').substring(1)}:")) {
      tname = targetName.substring("${info.id.replaceAll('/', '-').substring(1)}:".length);
    }

    if (await provider.isTargetSupported(tname, config)) {
      return provider;
    }
  }

  return null;
}

Future<Toolchain> resolveToolchain(String targetName, [Configuration config]) async {
  if (config == null) {
    config = new MockConfiguration();
  }

  var provider = await resolveToolchainProvider(targetName, config);

  if (provider != null) {
    return await provider.getToolchain(targetName, config);
  } else {
    return null;
  }
}
