import "dart:io";

import "package:legion/tool.dart";

main(List<String> args) async {
  await setupLegionTool();

  var targets = args.takeWhile((arg) => arg != "--").toList();
  var extraArguments = args.skip(targets.length).toList();

  if (extraArguments.length >= 1 && extraArguments.first == "--") {
    extraArguments = extraArguments.skip(1).toList();
  }

  var executions = [
    new BuildStageExecution(
      BuildStage.build,
      targets,
      extraArguments
    )
  ];

  await executeBuildStages(
    Directory.current,
    executions,
    onProjectLoaded: (Project project) async {
      if (targets.isEmpty) {
        targets.addAll(await project.getStringListSetting("defaultTargets"));
      }
    }
  );
}
