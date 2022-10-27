import "dart:convert";

import "package:args/args.dart";

import "package:legion/tool.dart";

class ToolchainSummary {
  final ProviderDescription description;
  final List<String> friendlyTargets;
  final List<String> supportedTargets;

  ToolchainSummary(
    this.description,
    this.friendlyTargets,
    this.supportedTargets);
}

main(List<String> args) async {
  await setupLegionTool();

  var argp = new ArgParser();
  argp.addOption("format", abbr: "f", allowed: const <String>[
    "human",
    "json",
    "raw"
  ], defaultsTo: "human");

  var opts = argp.parse(args);

  try {
    var toolchains = await loadAllToolchains();
    var infos = <ToolchainSummary>[];

    for (var toolchain in toolchains) {
      var summary = new ToolchainSummary(
        await toolchain.describe(),
        await toolchain.listFriendlyTargets(),
        await toolchain.listSupportedTargets()
      );

      infos.add(summary);
    }

    var format = opts["format"];

    if (format == "human") {
      await printHumanOutput(infos);
    } else if (format == "json") {
      await printJsonOutput(infos);
    } else {
      await printRawOutput(infos);
    }
  } on LegionError catch (e) {
    reportErrorMessage(e.toString());
    return;
  }
}

printHumanOutput(List<ToolchainSummary> toolchains) async {
  reportStatusMessage("Supported Builders");
  for (var provider in builderProviders) {
    var info = await provider.describe();
    GlobalState.currentStatusLevel++;
    reportStatusMessage("${info.description}");
    GlobalState.currentStatusLevel--;
  }

  reportStatusMessage("Supported Toolchains");

  for (var toolchain in toolchains) {
    GlobalState.currentStatusLevel++;
    var info = toolchain.description;
    var targets = toolchain.friendlyTargets;
    if (targets.isEmpty) {
      reportStatusMessage("${info.description} (No Targets Available)");
    } else {
      reportStatusMessage("${info.description}");
      for (var target in targets) {
        GlobalState.currentStatusLevel++;
        reportStatusMessage("${target}");
        GlobalState.currentStatusLevel--;
      }
    }
    GlobalState.currentStatusLevel--;
  }
}

printJsonOutput(List<ToolchainSummary> toolchains) async {
  var json = {
    "builders": {},
    "toolchains": {}
  };

  for (var builder in builderProviders) {
    var info = await builder.describe();
    json["builders"][info.id] = info.encode();
  }

  for (var toolchain in toolchains) {
    var data = toolchain.description.encode();
    data["friendlyTargets"] = toolchain.friendlyTargets;
    data["supportedTargets"] = toolchain.supportedTargets;
    json["toolchains"][toolchain.description.id] = data;
  }

  print(jsonEncode(json));
}

printRawOutput(List<ToolchainSummary> toolchains) async {
  for (var builder in builderProviders) {
    var info = await builder.describe();
    print("builder::${info.id}::${info.type}::${info.description}");
  }

  for (var toolchain in toolchains) {
    var info = toolchain.description;
    print("toolchain::${info.id}::${info.type}::${info.description}");

    for (var target in toolchain.friendlyTargets) {
      print("target::${info.id}::${target}");
    }

    for (var target in toolchain.supportedTargets) {
      print("raw-target::${info.id}::${target}");
    }
  }
}
