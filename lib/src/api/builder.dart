part of legion.api;

abstract class BuilderProvider implements Provider {
  Future<bool> isProjectSupported(Project project);
  Future<Builder> create(Target target);
}

abstract class Builder {
  final Target target;

  Builder(this.target);

  Future generate();
  Future build();
}
