library legion.io;

import "dart:async";
import "dart:convert";
import "dart:io";

import "utils.dart";

typedef ProcessResultHandler(ExecutionResult result);
typedef ProcessHandler(Process process);
typedef OutputHandler(String string);
typedef ProcessAdapterHandler(ProcessAdapterReferences adapter);
typedef LogHandler(String message);

Stdin get _stdin => stdin;

class ExecutionResult extends ProcessResult {
  final String output;

  ExecutionResult(int pid, int exitCode, stdout, stderr, this.output)
    : super(pid, exitCode, stdout, stderr);
}

class ProcessAdapterFlags {
  bool inherit = false;
  File logFile;
  LogHandler logHandler;
}

class ProcessAdapterReferences {
  ExecutionResult result;
  Process process;
  ProcessAdapterFlags flags = new ProcessAdapterFlags();

  Future<ExecutionResult> get onResultReady {
    if (result != null) {
      return new Future.value(result);
    } else {
      var c = new Completer<ExecutionResult>();
      _onResultReady.add(c.complete);
      return c.future;
    }
  }

  Future<Process> get onProcessReady {
    if (process != null) {
      return new Future.value(process);
    } else {
      var c = new Completer<Process>();
      _onProcessReady.add(c.complete);
      return c.future;
    }
  }

  List<ProcessResultHandler> _onResultReady = [];
  List<ProcessHandler> _onProcessReady = [];

  void pushProcess(Process process) {
    this.process = process;
    while (_onProcessReady.isNotEmpty) {
      _onProcessReady.removeAt(0)(process);
    }
  }

  void pushResult(ExecutionResult result) {
    this.result = result;
    while (_onResultReady.isNotEmpty) {
      _onResultReady.removeAt(0)(result);
    }
  }
}

Future<ExecutionResult> executeCommand(String executable,
  {
    List<String> args: const [],
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    stdin,
    ProcessHandler handler,
    OutputHandler stdoutHandler,
    OutputHandler stderrHandler,
    OutputHandler outputHandler,
    File outputFile,
    bool inherit: false,
    bool writeToBuffer: false,
    bool binary: false,
    ProcessResultHandler resultHandler,
    bool inheritStdin: false,
    LogHandler logHandler,
    bool pty: false
  }) async {
  if (pty && !Platform.isWindows) {
    var rcmd = executable;
    var rargs = args;

    executable = "script";

    args = <String>[];

    if (Platform.isMacOS) {
      args.addAll(<String>[
        "-q",
        "/dev/null",
        rcmd
      ]);

      args.addAll(rargs);
    } else {
      args.addAll(<String>[
        "-qefc",
        escapeShellArguments(rcmd, rargs),
        "/dev/null"
      ]);
    }

    if (environment != null) {
      environment = new Map<String, String>.from(environment);
    } else {
      environment = {};
    }

    if (environment["TERM"] is! String) {
      environment["TERM"] = "xterm";
    }
  }

  ProcessAdapterReferences refs = Zone.current["legion.io.process.ref"];

  if (refs != null) {
    outputFile = outputFile != null ? outputFile : refs.flags.logFile;
    logHandler = logHandler != null ? logHandler : refs.flags.logHandler;
  }

  IOSink raf;
  StreamSubscription stdinSub;

  if (outputFile != null) {
    if (!(await outputFile.exists())) {
      await outputFile.create(recursive: true);
    }

    raf = await outputFile.openWrite(mode: FileMode.append);
  }

  try {
    Process process = await Process.start(executable, args,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell
    );

    var id = process.pid.toString();

    if (refs != null) {
      refs.pushProcess(process);
      inherit = inherit || refs.flags.inherit;
    }

    if (raf != null) {
      await raf.writeln(
        "[${_currentTimestamp}][${id}] == Executing ${executable}"
          " with arguments ${args} (pid: ${process.pid}) =="
      );
    }

    if (logHandler != null) {
      logHandler(
        "[${_currentTimestamp}][${id}] == Executing ${executable}"
          " with arguments ${args} (pid: ${process.pid}) =="
      );
    }

    var buff = new StringBuffer();
    var ob = new StringBuffer();
    var eb = new StringBuffer();

    var obytes = <int>[];
    var ebytes = <int>[];
    var sbytes = <int>[];

    if (!binary) {
      process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((str) async {
        if (writeToBuffer) {
          ob.writeln(str);
          buff.writeln(str);
        }

        if (stdoutHandler != null) {
          stdoutHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stdout.writeln(str);
        }

        if (raf != null) {
          await raf.writeln("[${_currentTimestamp}][${id}] ${str}");
        }

        if (logHandler != null) {
          logHandler("[${_currentTimestamp}][${id}] ${str}");
        }
      });

      process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((str) async {
        if (writeToBuffer) {
          eb.writeln(str);
          buff.writeln(str);
        }

        if (stderrHandler != null) {
          stderrHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stderr.writeln(str);
        }

        if (raf != null) {
          await raf.writeln("[${_currentTimestamp}][${id}] ${str}");
        }

        if (logHandler != null) {
          logHandler("[${_currentTimestamp}][${id}] ${str}");
        }
      });
    } else {
      process.stdout.listen((bytes) {
        obytes.addAll(bytes);
        sbytes.addAll(bytes);
      });

      process.stderr.listen((bytes) {
        obytes.addAll(bytes);
        ebytes.addAll(bytes);
      });
    }

    if (handler != null) {
      handler(process);
    }

    if (stdin != null) {
      if (stdin is Stream) {
        stdin.listen(process.stdin.add, onDone: process.stdin.close);
      } else if (stdin is List) {
        process.stdin.add(stdin);
      } else {
        process.stdin.write(stdin);
        await process.stdin.close();
      }
    } else if (inheritStdin) {
      stdinSub = _stdin.listen(process.stdin.add, onDone: process.stdin.close);
    }

    var code = await process.exitCode;
    await new Future.delayed(const Duration(milliseconds: 1));
    var pid = process.pid;

    if (raf != null) {
      await raf.writeln(
        "[${_currentTimestamp}][${id}] == Exited with status ${code} =="
      );
      await raf.flush();
      await raf.close();
    }

    if (logHandler != null) {
      logHandler("[${_currentTimestamp}][${id}] == Exited with status ${code} ==");
    }

    var result = new ExecutionResult(
      pid,
      code,
      binary ? sbytes : ob.toString(),
      binary ? ebytes : eb.toString(),
      binary ? obytes : buff.toString()
    );

    if (resultHandler != null) {
      resultHandler(result);
    }

    if (refs != null) {
      refs.pushResult(result);
    }

    return result;
  } finally {
    if (stdinSub != null) {
      stdinSub.cancel();
    }

    if (raf != null) {
      await raf.flush();
      await raf.close();
    }
  }
}

String get _currentTimestamp {
  return new DateTime.now().toString();
}
