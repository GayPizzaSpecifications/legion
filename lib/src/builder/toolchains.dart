part of legion.builder;

Future<List<ToolchainProvider>> loadCustomToolchains() async {
  Map<String, Map<String, dynamic>> json = (await readJsonFile<Map<String, dynamic>>(
    getLegionHomeFile("toolchains.json").path,
    defaultValue: <String, dynamic>{}
  )).cast<String, Map<String, dynamic>>();

  var providers = <ToolchainProvider>[];

  for (var toolchainName in json.keys) {
    var m = json[toolchainName];
    if (m is! Map) continue;

    var type = m["type"];
    var path = m["path"];

    ToolchainProvider provider;

    if (type == "gcc") {
      provider = new Gcc.GccToolchainProvider(toolchainName, path);
    } else if (type == "clang") {
      provider = new Clang.ClangToolchainProvider(toolchainName, path);
    } else {
      throw new LegionError(
        "Unknown custom toolchain type '${type}' for ${toolchainName}"
      );
    }

    providers.add(provider);
  }

  return providers;
}

final RegExp _gccExecutablePattern = new RegExp(r"(.+-gcc|gcc)$");
final RegExp _clangExecutablePattern = new RegExp(r"^clang$");

Future<List<ToolchainProvider>> findGccToolchains() async {
  var disabled =
    await readGlobalConfigSetting("toolchains.autodiscover.disabled") == true;

  var stopAtFirstCompiler =
    await readGlobalConfigSetting("toolchains.autodiscover.all") != true;

  var providers = <ToolchainProvider>[];

  if (disabled) {
    return providers;
  }

  await for (var exe in findExecutablesMatching(_gccExecutablePattern)) {
    var gcc = new Gcc.GccToolchainProvider(exe, exe);

    if (!(await gcc.isValidCompiler())) {
      continue;
    }

    providers.add(gcc);

    if (stopAtFirstCompiler) {
      return providers;
    }
  }

  return providers;
}

Future<List<ToolchainProvider>> findClangToolchains() async {
  var disabled =
    await readGlobalConfigSetting("toolchains.autodiscover.disabled") == true;

  var stopAtFirstCompiler =
    await readGlobalConfigSetting("toolchains.autodiscover.all") != true;

  var providers = <ToolchainProvider>[];

  if (disabled) {
    return providers;
  }

  await for (var exe in findExecutablesMatching(_clangExecutablePattern)) {
    var clang = new Clang.ClangToolchainProvider(exe, exe);

    if (!(await clang.isValidCompiler())) {
      continue;
    }

    providers.add(clang);

    if (stopAtFirstCompiler) {
      return providers;
    }
  }

  return providers;
}
