part of legion.api;

abstract class ToolchainProvider implements Provider {
  Future<List<String>> listFriendlyTargets();
  Future<List<String>> listSupportedTargets();
  Future<bool> isTargetSupported(String target, Configuration config);
  Future<Toolchain> getToolchain(String target, Configuration config);
}

abstract class Toolchain {
  Future<String> getToolchainBase();
  Future<String> getSystemName();
  Future<Map<String, List<String>>> getEnvironmentVariables();

  Future<String> getTargetMachine();

  Future<String> getToolPath(String tool);
  Future<Tool> getTool(String tool);

  Future<CompilerTool> getCompilerTool(String toolName) async {
    var tool = await getTool(toolName);

    if (tool is CompilerTool) {
      return tool;
    }

    throw new Exception("Expected tool '${toolName}' to be a compiler.");
  }

  Future<bool> needsTargetSpecified();
}
