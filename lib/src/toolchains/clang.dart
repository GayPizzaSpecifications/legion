library legion.toolchains.clang;

import "dart:async";

import "package:legion/api.dart";
import "package:legion/utils.dart";

import "generic_compiler.dart";

const Map<String, String> clangTargetMap = const <String, String>{
  "linux-x64": "x86_64-linux-eabi",
  "linux-x86": "x86-linux-eabi",
  "linux-arm": "arm-linux-eabi",
  "linux-armv7a": "armv7a-linux-eabi",
  "linux-armv7m": "armv7m-linux-aebi",
  "mac-x86": "x86-apple-darwin-eabi",
  "mac-amd64": "x86_64-apple-darwin-eabi",
  "mac-arm64": "arm64-apple-darwin-eabi"
};

class ClangTool extends GenericCompilerTool {
  final String target;

  ClangTool(String path, {this.target = null}) : super(path);

  @override
  Future<String> getCompilerId() async {
    return "Clang";
  }

  @override
  Future<List<String>> getExtraArguments() async {
    if (target == null) {
      return const <String>[];
    }
    return <String>["-target", target];
  }
}

class ClangToolchain extends GenericToolchain {
  ClangToolchain(String target, ClangTool compiler) :
      super(target, compiler, "clang", "clang++");

  @override
  Future<GenericCompilerTool> getCompilerWrapper(String path) async =>
    new ClangTool(path, target: target);

  @override
  Future<bool> needsTargetSpecified() async => true;
}

class ClangToolchainProvider extends ToolchainProvider {
  static final String defaultClangPath = findExecutableSync("clang");

  final String id;
  final String path;

  ClangToolchainProvider(this.id, this.path);

  @override
  Future<ProviderDescription> describe() async => new ProviderDescription(
    id,
    "clang",
    "Clang (${path})"
  );

  @override
  Future<Toolchain> getToolchain(String target, Configuration config) async {
    var actualTarget = target;
    if (clangTargetMap[target] != null) {
      actualTarget = clangTargetMap[target];
    }
    var clang = new ClangTool(path, target: actualTarget);
    return new ClangToolchain(target, clang);
  }

  @override
  Future<bool> isTargetSupported(String target, Configuration config) async {
    if (path == null) {
      return false;
    }

    var clang = new ClangTool(path);
    var targets = await clang.getTargetNames();
    return targets.contains(target);
  }

  @override
  Future<List<String>> listFriendlyTargets() async {
    if (path == null) {
      return const <String>[];
    }

    var clang = new ClangTool(path);
    var targets = await clang.getTargetNames(basic: true);
    return targets;
  }

  @override
  Future<List<String>> listSupportedTargets() async {
    if (path == null) {
      return const <String>[];
    }

    var clang = new ClangTool(path);
    var targets = await clang.getTargetNames();
    return targets;
  }

  Future<bool> isValidCompiler() async {
    var clang = new ClangTool(path);

    try {
      await clang.getVersion();
      return true;
    } catch (e) {
      return false;
    }
  }
}
