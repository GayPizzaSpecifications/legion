import "dart:async";
import "dart:io";

import "package:legion/tool.dart";

main(List<String> args) async {
  // Protect print statements from clobbering for evaluation
  return await Zone.current.fork(specification: new ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      if (line.startsWith("raw::")) {
        stdout.writeln(line.substring(5));
      } else if (!line.contains("=")) {
        stderr.writeln(line);
      } else {
        stdout.writeln(line);
      }
    }
  )).run(() async {
    return await _main(args);
  });
}

_main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: foxhole <target>");
    exitCode = 1;
    return;
  }

  var targetName = args[0];

  try {
    var toolchain = await resolveToolchain(targetName);
    if (toolchain != null) {
      await _printToolchainEnv(toolchain);
    } else {
      reportErrorMessage("Unknown target ${targetName}");
      return;
    }
  } on LegionError catch (e) {
    reportErrorMessage(e.toString());
    return;
  }
}

_printToolchainEnv(Toolchain toolchain) async {
  var cc = await toolchain.getToolPath("cc");
  var cxx = await toolchain.getToolPath("c++");
  var as = await toolchain.getToolPath("as");
  var ld = await toolchain.getToolPath("ld");
  var ar = await toolchain.getToolPath("ar");
  var sys = await toolchain.getSystemName();
  var base = await toolchain.getToolchainBase();

  print("AS=${escapeShellArgument(as)}");
  print("CC=${escapeShellArgument(cc)}");
  print("CXX=${escapeShellArgument(cxx)}");
  print("LD=${escapeShellArgument(ld)}");
  print("AR=${escapeShellArgument(ar)}");

  var env = await toolchain.getEnvironmentVariables();

  for (var key in env.keys) {
    if (env[key].isNotEmpty) {
      print("${key}=${escapeShellArgumentList(env[key])}");
    }
  }

  print("SYSNAME=${escapeShellArgument(sys)}");
  print("TOOLCHAIN_PREFIX=${escapeShellArgument(base)}");
}
