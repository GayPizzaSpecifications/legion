part of legion.api;

class TargetIdentifier {
  final String name;
  final String actual;

  TargetIdentifier(this.name, this.actual);
}

class Target {
  final Project project;
  final TargetIdentifier id;
  final Toolchain toolchain;
  final List<String> extraArguments;

  Target(this.project, this.id, this.toolchain, this.extraArguments);

  Future<bool> getBooleanSetting(String name) async {
    return await project.getBooleanSetting(name) || await project.getBooleanSetting(
      "targets.${id.name}.${name}"
    );
  }

  Directory get buildDirectory {
    if (_buildDirectory == null) {
      _buildDirectory = new Directory(
        resolveWorkingPath(
          "legion/${id.name}",
          from: project.directory
        )
      );


      if (!(_buildDirectory.existsSync())) {
        _buildDirectory.createSync(recursive: true);
      }
    }
    return _buildDirectory;
  }

  Future<Directory> ensureCleanBuildDirectory() async {
    var items = await buildDirectory.list().toList();

    if (items.isEmpty) {
      return buildDirectory;
    }

    for (var item in items) {
      await item.delete(recursive: true);
    }

    return buildDirectory;
  }

  Directory _buildDirectory;

  Future<String> getStringSetting(String key, [String defaultValue]) async {
    return await project.getStringSetting(key, defaultValue);
  }
}
