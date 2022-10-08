part of legion.api;

abstract class Tool {
  Future<bool> exists();

  Future<ExecutionResult> run(List<String> args, {
    String workingDir,
    bool inherit: false,
    bool writeToBuffer: true,
    bool pty: false
  });
}

abstract class CompilerTool implements Tool {
  Future<String> getTargetMachine();
  Future<String> getCompilerId();
}
