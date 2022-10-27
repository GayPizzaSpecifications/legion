# Legion

Legion is a tool that makes it simple to cross-compile C/C++ projects.

## Installation

Ensure you have the [Dart SDK](https://dart.dev/get-dart) installed.

```bash
pub global activate -sgit https://github.com/mysticlgbt/legion.git
```

## Usage

```bash
cd path/to/cmake/project
legion quick linux-x64 linux-arm
```

For each target, a CMake build directory is created in `legion/${target}`.
