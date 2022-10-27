library legion.tool;

import "dart:io";

export "package:legion/api.dart";
export "package:legion/builder.dart";
export "package:legion/utils.dart";

bool _legionToolSetup = false;

Future<void> setupLegionTool() async {
  if (_legionToolSetup) {
    return;
  }
  _legionToolSetup = true;

  var legionProjectCwd = Platform.environment["LEGION_PROJECT_CWD"];
  if (legionProjectCwd != null) {
    Directory.current = Directory(legionProjectCwd.toString());
  }
}