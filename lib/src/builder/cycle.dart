part of legion.builder;

class BuildCycle {
  final Project project;
  final BuildStage stage;
  final List<String> targetNames;
  final List<String> extraArguments;

  BuildCycle(this.project, this.stage, this.targetNames, this.extraArguments);

  Future run() async {
    try {
      if (stage == BuildStage.configure) {
        await _configure();
      } else if (stage == BuildStage.build) {
        await _build();
      } else if (stage == BuildStage.assemble) {
        await _assemble();
      } else {
        throw new LegionError("Unknown build stage ${stage}");
      }
    } on LegionError catch (e) {
      reportErrorMessage(e.toString());
    }
  }

  Stream<Target> getTargets() async* {
    var names = new List<String>.from(targetNames);

    if (names.isEmpty) {
      names.addAll(project.state.getList("targets", defaultValue: []));
    }

    for (var name in names) {
      var toolchainProvider = await getToolchainProvider(name);

      if (toolchainProvider == null) {
        reportErrorMessage("Unable to find toolchain for target ${name}");
        continue;
      }

      var toolchain = await toolchainProvider.getToolchain(name, project);

      if (toolchain == null) {
        reportErrorMessage("Unable to find toolchain for target ${name}");
        continue;
      }

      yield await project.getTarget(name, toolchain, extraArguments);
    }
  }

  Stream<Builder> getBuilders() async* {
    var builderProvider = await getBuilderProvider();

    if (builderProvider == null) {
      reportErrorMessage("Unable to find builder");
      return;
    }

    for (var target in await getTargets().toList()) {
      yield await builderProvider.create(target);
    }
  }

  Future _configure() async {
    for (var builder in await getBuilders().toList()) {
      reportStatusMessage("Generating target ${builder.target.name}");
      try {
        await builder.generate();

        if (!project.state.isInList("targets", builder.target.name)) {
          project.state.addToList("targets", builder.target.name);
        }

        reportStatusMessage("Generated target ${builder.target.name}");
      } catch (e, stack) {
        var msg = e.toString();

        if (e is! LegionError) {
          msg += "\n${stack}";
        }

        reportErrorMessage(msg);

        if (project.state.isInList("targets", builder.target.name)) {
          project.state.removeFromList("targets", builder.target.name);
        }
      }
    }
  }

  Future _build() async {
    for (var builder in await getBuilders().toList()) {
      reportStatusMessage("Building target ${builder.target.name}");
      try {
        await builder.build();
        reportStatusMessage("Built target ${builder.target.name}");
      } catch (e, stack) {
        var msg = e.toString();

        if (e is! LegionError) {
          msg += "\n${stack}";
        }

        reportErrorMessage(msg);
      }
    }
  }

  Future _assemble() async {
    var steps = await getAssemblySteps();

    for (var target in await getTargets().toList()) {
      reportStatusMessage("Assembling target ${target.name}");
      for (var step in steps) {
        await step.perform(target);
      }
      reportStatusMessage("Assembled target ${target.name}");
    }
  }

  Future<ToolchainProvider> getToolchainProvider(String targetName) async {
    return await resolveToolchainProvider(targetName, project);
  }

  Future<BuilderProvider> getBuilderProvider() async {
    for (var provider in builderProviders) {
      if (await provider.isProjectSupported(project)) {
        return provider;
      }
    }

    return null;
  }

  Future<List<AssemblyStep>> getAssemblySteps() async {
    var assemblies = await project.getSubConfigurations("assembly");
    var steps = <AssemblyStep>[];

    for (var assembly in assemblies) {
      AssemblyStep step;
      for (var provider in assemblyProviders) {
        if (await provider.claims(assembly)) {
          step = await provider.create(assembly);
        }
      }

      if (step == null) {
        reportWarningMessage("Assembly step was not claimed");
      } else {
        steps.add(step);
      }
    }

    return steps;
  }
}
