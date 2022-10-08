part of legion.api;

abstract class AssemblyStepProvider {
  Future<bool> claims(Configuration config);
  Future<AssemblyStep> create(Configuration config);
}

abstract class AssemblyStep {
  Future perform(Target target);
}
