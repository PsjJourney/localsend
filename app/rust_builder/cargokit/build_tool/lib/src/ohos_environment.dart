import 'dart:io';

import 'package:path/path.dart' as path;

import 'target.dart';

class OhosEnvironment {
  OhosEnvironment({
    required this.sdkNativeDir,
    required this.targetTempDir,
    required this.target,
  });

  final String sdkNativeDir;
  final String targetTempDir;
  final Target target;

  static const _directEnvKeys = [
    'OHOS_SDK_NATIVE_DIR',
  ];

  static const _rootEnvKeys = [
    'OHOS_BASE_SDK_HOME',
    'OHOS_SDK_HOME',
    'DEVECO_SDK_HOME',
    'HOS_SDK_HOME',
    'OHOS_HOME',
  ];

  static String? locateNativeDir() {
    final seen = <String>{};

    bool isValidNativeDir(String candidate) {
      final exe = Platform.isWindows ? '.exe' : '';
      return File(path.join(candidate, 'llvm', 'bin', 'clang$exe'))
              .existsSync() &&
          Directory(path.join(candidate, 'sysroot')).existsSync();
    }

    void addCandidate(
      List<String> queue,
      String? candidate,
    ) {
      if (candidate == null || candidate.isEmpty) {
        return;
      }
      final normalized = path.normalize(candidate);
      if (seen.add(normalized)) {
        queue.add(normalized);
      }
    }

    final queue = <String>[];

    for (final key in _directEnvKeys) {
      addCandidate(queue, Platform.environment[key]);
    }

    final hostDir = switch (Platform.operatingSystem) {
      'linux' => 'linux',
      'macos' => 'mac',
      'windows' => 'windows',
      _ => null,
    };

    Iterable<String> nativeCandidatesForRoot(String root) sync* {
      yield root;
      yield path.join(root, 'native');
      yield path.join(root, 'default', 'openharmony', 'native');
      yield path.join(root, 'sdk', 'native');
      yield path.join(root, 'sdk', 'default', 'openharmony', 'native');
      if (hostDir != null) {
        yield path.join(root, hostDir, 'native');
        yield path.join(root, 'sdk', hostDir, 'native');
      }

      final directory = Directory(root);
      if (!directory.existsSync()) {
        return;
      }

      for (final entry in directory.listSync()) {
        if (entry is! Directory) {
          continue;
        }
        yield path.join(entry.path, 'native');
        yield path.join(entry.path, 'openharmony', 'native');
        yield path.join(entry.path, 'default', 'openharmony', 'native');
        if (hostDir != null) {
          yield path.join(entry.path, hostDir, 'native');
        }
      }
    }

    for (final key in _rootEnvKeys) {
      final root = Platform.environment[key];
      if (root == null || root.isEmpty) {
        continue;
      }
      for (final candidate in nativeCandidatesForRoot(root)) {
        addCandidate(queue, candidate);
      }
    }

    for (final candidate in queue) {
      if (isValidNativeDir(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<Map<String, String>> buildEnvironment() async {
    final exe = Platform.isWindows ? '.exe' : '';
    final clang = path.join(sdkNativeDir, 'llvm', 'bin', 'clang$exe');
    final clangxx = path.join(sdkNativeDir, 'llvm', 'bin', 'clang++$exe');
    final ar = path.join(sdkNativeDir, 'llvm', 'bin', 'llvm-ar$exe');
    final ranlib = path.join(sdkNativeDir, 'llvm', 'bin', 'llvm-ranlib$exe');
    final sysroot = path.join(sdkNativeDir, 'sysroot');

    for (final tool in [clang, clangxx, ar, ranlib]) {
      if (!File(tool).existsSync()) {
        throw Exception('Missing OpenHarmony toolchain binary: $tool');
      }
    }
    if (!Directory(sysroot).existsSync()) {
      throw Exception('Missing OpenHarmony sysroot: $sysroot');
    }

    final toolDir =
        Directory(path.join(targetTempDir, 'cargokit', 'ohos_toolchain'));
    toolDir.createSync(recursive: true);

    final linker = _createWrapper(
      toolDir.path,
      fileNamePrefix: 'clang',
      executablePath: clang,
      targetTriple: _clangTarget,
      sysroot: sysroot,
      extraFlags: _extraClangFlags,
    );
    final cxxLinker = _createWrapper(
      toolDir.path,
      fileNamePrefix: 'clangxx',
      executablePath: clangxx,
      targetTriple: _clangTarget,
      sysroot: sysroot,
      extraFlags: _extraClangFlags,
    );

    final env = <String, String>{
      ..._toolEnvAliases('AR', ar),
      ..._toolEnvAliases('CC', linker),
      ..._toolEnvAliases('CXX', cxxLinker),
      ..._toolEnvAliases('RANLIB', ranlib),
      'CARGO_TARGET_${target.rust.replaceAll('-', '_').toUpperCase()}_LINKER':
          linker,
    };

    return env;
  }

  Map<String, String> _toolEnvAliases(String prefix, String value) {
    final rustTripleUnderscored = target.rust.replaceAll('-', '_');
    return {
      '${prefix}_${target.rust}': value,
      '${prefix}_$rustTripleUnderscored': value,
    };
  }

  String _createWrapper(
    String toolDir, {
    required String fileNamePrefix,
    required String executablePath,
    required String targetTriple,
    required String sysroot,
    required List<String> extraFlags,
  }) {
    final scriptName = Platform.isWindows
        ? '$fileNamePrefix-${target.rust}.cmd'
        : '$fileNamePrefix-${target.rust}.sh';
    final scriptPath = path.join(toolDir, scriptName);
    final file = File(scriptPath);

    if (Platform.isWindows) {
      file.writeAsStringSync(_buildWindowsWrapper(
        executablePath: executablePath,
        targetTriple: targetTriple,
        sysroot: sysroot,
        extraFlags: extraFlags,
      ));
    } else {
      file.writeAsStringSync(_buildShellWrapper(
        executablePath: executablePath,
        targetTriple: targetTriple,
        sysroot: sysroot,
        extraFlags: extraFlags,
      ));
      Process.runSync('chmod', ['+x', scriptPath]);
    }

    return scriptPath;
  }

  String _buildShellWrapper({
    required String executablePath,
    required String targetTriple,
    required String sysroot,
    required List<String> extraFlags,
  }) {
    final args = [
      '-target',
      targetTriple,
      '--sysroot=$sysroot',
      '-D__MUSL__',
      ...extraFlags,
    ].map(_shellQuote).join(' ');

    return '''#!/bin/sh
exec ${_shellQuote(executablePath)} $args "\$@"
''';
  }

  String _buildWindowsWrapper({
    required String executablePath,
    required String targetTriple,
    required String sysroot,
    required List<String> extraFlags,
  }) {
    final args = [
      '-target',
      targetTriple,
      '--sysroot=$sysroot',
      '-D__MUSL__',
      ...extraFlags,
    ].join(' ');

    return '''@echo off
"$executablePath" $args %*
''';
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  String get _clangTarget => switch (target.rust) {
        'aarch64-unknown-linux-ohos' => 'aarch64-linux-ohos',
        'armv7-unknown-linux-ohos' => 'arm-linux-ohos',
        'x86_64-unknown-linux-ohos' => 'x86_64-linux-ohos',
        _ => throw Exception('Unsupported OpenHarmony Rust target: ${target.rust}'),
      };

  List<String> get _extraClangFlags => switch (target.rust) {
        'armv7-unknown-linux-ohos' => const [
            '-march=armv7-a',
            '-mfloat-abi=softfp',
            '-mtune=generic-armv7-a',
            '-mthumb',
          ],
        _ => const [],
      };
}
