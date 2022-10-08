import "package:legion/src/toolchains/crosstool.dart";

main() async {
  var crosstool = new CrossTool();

  var toolchain = await crosstool.listSamples();
  print("Got Toolchain: ${toolchain}");
}
