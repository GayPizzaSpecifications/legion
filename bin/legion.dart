import "brigade.dart" as Brigade;
import "platoon.dart" as Platoon;
import "assemble.dart" as Assemble;
import "intel.dart" as Intel;
import "foxhole.dart" as Foxhole;

import "dart:io";

import "package:legion/tool.dart";

main(List<String> args) async {
  await setupLegionTool();

  if (args.isEmpty) {
    print("Usage: legion <command> [args]");
    print("Commands:");
    print("  brigade: Generate Targets");
    print("  war: Generate and Build Targets");
    print("  intel: Show Builders and Toolchains");
    print("  foxhole: Generate Toolchain Environment");
    return null;
  }

  String cmd = args[0];
  List<String> argv = args.skip(1).toList();

  if (cmd == "brigade" || cmd == "generate") {
    return await Brigade.main(argv);
  } else if (cmd == "platoon" || cmd == "build" || cmd == "make") {
    return await Platoon.main(argv);
  } else if (cmd == "assemble" || cmd == "dist") {
    return await Assemble.main(argv);
  } else if (cmd == "quick" || cmd == "qbuild" || cmd == "war") {
    var sections = splitExtraArguments(argv);
    var brigadeArgs = <String>[];
    if (sections.length >= 1) {
      brigadeArgs.addAll(sections[0]);
    }

    if (sections.length >= 2) {
      brigadeArgs.addAll(sections[1]);
    }

    var buildArgs = <String>[];

    if (sections.length >= 3) {
      buildArgs.addAll(sections[2]);
    }

    await Brigade.main(brigadeArgs);

    if (GlobalState.hasError) {
      return null;
    }

    var platoonArgString = Platform.environment["LEGION_BUILD_ARGS"];
    var platoonArgs = <String>[];

    if (sections.length >= 1) {
      platoonArgs.addAll(sections[0]);
    }

    if (buildArgs.isNotEmpty) {
      platoonArgs.add("--");
      platoonArgs.addAll(buildArgs);
    }

    if (platoonArgString is String) {
      platoonArgs.addAll(platoonArgString.split(" "));
    }

    return await Platoon.main(platoonArgs);
  } else if (cmd == "commo" || cmd == "info" || cmd == "intel") {
    return await Intel.main(argv);
  } else if (cmd == "foxhole" || cmd == "env" || cmd == "toolchain") {
    return await Foxhole.main(argv);
  } else {
    print("Unknown Command: ${cmd}");
    exitCode = 1;
    return null;
  }
}
