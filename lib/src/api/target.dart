part of legion.api;

class Target {
  final Project project;
  final String name;
  final Toolchain toolchain;
  final List<String> extraArguments;

  Target(this.project, this.name, this.toolchain, this.extraArguments);

  Future<bool> getBooleanSetting(String name) async {
    return await project.getBooleanSetting(name) || await project.getBooleanSetting(
      "targets.${this.name}.${name}"
    );
  }

  Directory get buildDirectory {
    if (_buildDirectory == null) {
      _buildDirectory = new Directory(
        resolveWorkingPath(
          "legion/${name}",
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
