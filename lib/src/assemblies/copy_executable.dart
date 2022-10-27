library legion.assemblies.copy_executable;

import "dart:async";
import "dart:io";

import "package:path/path.dart" as pathlib;
import "package:legion/format.dart" as formatlib;

import "package:legion/utils.dart";
import "package:legion/api.dart";

class CopyExecutableAssemblyStep extends AssemblyStep {
  final Configuration config;

  CopyExecutableAssemblyStep(this.config);

  @override
  Future perform(Target target) async {
    var src = await config.getSetting("copy-executable");
    var dest = await config.getSetting("to");

    var variables = <String, String>{
      "project.directory": target.project.directory.path,
      "target.name": target.id.name,
      "target.actual": target.id.actual,
      "target.directory": target.buildDirectory.path
    };

    src = formatlib.format(src, replace: variables);
    dest = formatlib.format(dest, replace: variables);

    var file = await getFileFromPossibleExtensions(src, [
      "exe",
      "sh",
      "bash"
    ]);

    var srcName = pathlib.basename(src);
    var destName = pathlib.basename(dest);
    var realFileName = pathlib.basename(file.path);

    if (realFileName.contains(".") && !srcName.contains(".") && !destName.contains(".")) {
      destName += ".${pathlib.extension(realFileName)}";
      dest = pathlib.join(pathlib.dirname(dest), destName);
    }

    var destFile = new File(dest);

    if (!(await destFile.parent.exists())) {
      await destFile.parent.create(recursive: true);
    }

    await file.copy(dest);
  }
}

class CopyExecutableAssemblyStepProvider extends AssemblyStepProvider {
  @override
  Future<bool> claims(Configuration config) async {
    return await config.hasStringSetting("copy-executable") &&
      await config.hasStringSetting("to");
  }

  @override
  Future<AssemblyStep> create(Configuration config) async =>
    new CopyExecutableAssemblyStep(config);
}
