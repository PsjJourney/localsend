import 'dart:convert';
import 'dart:io';

const _desiredHvigorFile = '''
// Script for compiling build behavior. It is built in the build plug-in and cannot be modified currently.
import { harTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: harTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [],       /* Custom plugin to extend the functionality of Hvigor. */
};
''';

Future<void> main() async {
  final packageConfigFile = File('.dart_tool/package_config.json');
  if (!packageConfigFile.existsSync()) {
    stderr.writeln(
        'Missing .dart_tool/package_config.json. Run flutter pub get first.');
    exitCode = 1;
    return;
  }

  final packageConfig = jsonDecode(await packageConfigFile.readAsString())
      as Map<String, dynamic>;
  final packages =
      (packageConfig['packages'] as List).cast<Map<String, dynamic>>();

  var updatedCount = 0;

  for (final package in packages) {
    final rootUri = package['rootUri'] as String?;
    if (rootUri == null || !rootUri.startsWith('file://')) {
      continue;
    }

    final rootDir = Directory(Uri.parse(rootUri).toFilePath());
    final hvigorFile = File('${rootDir.path}/ohos/hvigorfile.ts');
    if (!hvigorFile.existsSync()) {
      continue;
    }

    final current = await hvigorFile.readAsString();
    if (!current
        .contains("export { harTasks } from '@ohos/hvigor-ohos-plugin';")) {
      continue;
    }

    await hvigorFile.writeAsString(_desiredHvigorFile);
    updatedCount++;
    stdout.writeln('Patched OHOS plugin hvigorfile: ${package['name']}');
  }

  if (updatedCount == 0) {
    stdout.writeln('No OHOS plugin hvigorfile patching needed.');
  } else {
    stdout.writeln('Patched $updatedCount OHOS plugin hvigorfile(s).');
  }
}
