/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:path/path.dart' as path;

import 'artifacts_provider.dart';
import 'builder.dart';
import 'environment.dart';
import 'options.dart';
import 'target.dart';

class BuildCMake {
  final CargokitUserOptions userOptions;

  BuildCMake({required this.userOptions});

  Future<void> build() async {
    final targetPlatform = Environment.targetPlatform;
    final target = Target.forFlutterName(Environment.targetPlatform);
    if (target == null) {
      throw Exception("Unknown target platform: $targetPlatform");
    }

    final environment = BuildEnvironment.fromEnvironment(isAndroid: false);
    final provider =
        ArtifactProvider(environment: environment, userOptions: userOptions);
    final artifacts = await provider.getArtifacts([target]);

    final libs = artifacts[target]!;
    final copiedLibraries = <String>[];

    for (final lib in libs) {
      if (lib.type == AritifactType.dylib) {
        File(lib.path)
            .copySync(path.join(Environment.outputDir, lib.finalFileName));
        copiedLibraries.add(lib.finalFileName);
      }
    }

    if (copiedLibraries.isNotEmpty) {
      return;
    }

    final outputDir = Directory(Environment.outputDir);
    final outputListing = <String>[];
    if (outputDir.existsSync()) {
      outputListing.addAll(
        outputDir.listSync().map((entry) => path.basename(entry.path)),
      );
      outputListing.sort();
    }
    final builtArtifactNames = libs.map((lib) => lib.finalFileName).toList()
      ..sort();
    final rustBuildDirName =
        environment.configuration == BuildConfiguration.debug
            ? 'debug'
            : 'release';
    final targetDir = path.join(
      Environment.targetTempDir,
      target.rust,
      rustBuildDirName,
    );
    final targetListing = <String>[];
    final targetDirectory = Directory(targetDir);
    if (targetDirectory.existsSync()) {
      targetListing.addAll(
        targetDirectory
            .listSync()
            .map((entry) => path.basename(entry.path))
            .where((name) => name.contains(environment.crateInfo.packageName)),
      );
      targetListing.sort();
    }

    throw Exception(
      'Cargokit built no dynamic library for ${environment.crateInfo.packageName}.\n'
      'Expected a file like lib${environment.crateInfo.packageName}.so in $targetDir.\n'
      'Detected build artifacts: ${builtArtifactNames.isEmpty ? '(none)' : builtArtifactNames.join(', ')}\n'
      'Target directory contents: ${targetListing.isEmpty ? '(none)' : targetListing.join(', ')}\n'
      'Current CMake output directory contents: ${outputListing.isEmpty ? '(none)' : outputListing.join(', ')}',
    );
  }
}
