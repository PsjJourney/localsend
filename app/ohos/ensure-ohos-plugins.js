const fs = require('fs');
const path = require('path');
const { fileURLToPath } = require('url');

function ensureTrailingSeparator(dirPath) {
  return dirPath.endsWith(path.sep) ? dirPath : `${dirPath}${path.sep}`;
}

function resolvePackageRoot(baseDir, rootUri) {
  if (rootUri.startsWith('file://')) {
    return fileURLToPath(rootUri);
  }
  if (rootUri.startsWith('file:')) {
    return rootUri.slice('file:'.length);
  }
  return path.resolve(baseDir, rootUri);
}

function hasOhosPlugin(pubspecContent) {
  let flutterIndent = null;
  let pluginIndent = null;
  let platformsIndent = null;

  for (const rawLine of pubspecContent.split(/\r?\n/)) {
    const line = rawLine.replace(/\s+#.*$/, '');
    const match = /^(\s*)([A-Za-z0-9_]+)\s*:(.*)$/.exec(line);
    if (!match) {
      continue;
    }

    const indent = match[1].length;
    const key = match[2];

    if (platformsIndent !== null && indent <= platformsIndent) {
      platformsIndent = null;
    }
    if (pluginIndent !== null && indent <= pluginIndent) {
      pluginIndent = null;
      platformsIndent = null;
    }
    if (flutterIndent !== null && indent <= flutterIndent) {
      flutterIndent = null;
      pluginIndent = null;
      platformsIndent = null;
    }

    if (key === 'flutter') {
      flutterIndent = indent;
      continue;
    }

    if (flutterIndent !== null && indent > flutterIndent && key === 'plugin') {
      pluginIndent = indent;
      continue;
    }

    if (pluginIndent !== null && indent > pluginIndent && key === 'platforms') {
      platformsIndent = indent;
      continue;
    }

    if (platformsIndent !== null && indent > platformsIndent && key === 'ohos') {
      return true;
    }
  }

  return false;
}

function findExistingPluginEntry(pluginsByPlatform, pluginName) {
  for (const platformEntries of Object.values(pluginsByPlatform || {})) {
    if (!Array.isArray(platformEntries)) {
      continue;
    }
    const match = platformEntries.find((entry) => entry && entry.name === pluginName);
    if (match) {
      return match;
    }
  }
  return null;
}

function createOhosPluginEntry(pluginName, rootPath, existingEntry) {
  const baseEntry = existingEntry && typeof existingEntry === 'object' ? existingEntry : {};
  return {
    ...baseEntry,
    name: pluginName,
    path: ensureTrailingSeparator(rootPath),
    native_build: baseEntry.native_build !== false,
    dependencies: Array.isArray(baseEntry.dependencies) ? baseEntry.dependencies : [],
    dev_dependency: baseEntry.dev_dependency === true,
  };
}

function ensureOhosPluginDependencies(flutterProjectPath) {
  const flutterPluginsPath = path.join(flutterProjectPath, '.flutter-plugins-dependencies');
  const packageConfigPath = path.join(flutterProjectPath, '.dart_tool', 'package_config.json');

  if (!fs.existsSync(flutterPluginsPath) || !fs.existsSync(packageConfigPath)) {
    return false;
  }

  const pluginData = JSON.parse(fs.readFileSync(flutterPluginsPath, 'utf8'));
  pluginData.plugins = pluginData.plugins || {};

  const originalOhosPlugins = Array.isArray(pluginData.plugins.ohos)
    ? pluginData.plugins.ohos.filter((entry) => entry && typeof entry.name === 'string')
    : [];
  const nextOhosPlugins = [...originalOhosPlugins];
  const knownPluginNames = new Set(nextOhosPlugins.map((entry) => entry.name));

  const packageConfig = JSON.parse(fs.readFileSync(packageConfigPath, 'utf8'));
  const packageConfigDir = path.dirname(packageConfigPath);

  for (const pkg of packageConfig.packages || []) {
    if (!pkg || typeof pkg.name !== 'string' || typeof pkg.rootUri !== 'string') {
      continue;
    }

    const rootPath = resolvePackageRoot(packageConfigDir, pkg.rootUri);
    const pubspecPath = path.join(rootPath, 'pubspec.yaml');
    const ohosModulePath = path.join(rootPath, 'ohos', 'src', 'main', 'module.json5');

    if (!fs.existsSync(pubspecPath) || !fs.existsSync(ohosModulePath)) {
      continue;
    }

    const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
    if (!hasOhosPlugin(pubspecContent) || knownPluginNames.has(pkg.name)) {
      continue;
    }

    const existingEntry = findExistingPluginEntry(pluginData.plugins, pkg.name);
    nextOhosPlugins.push(createOhosPluginEntry(pkg.name, rootPath, existingEntry));
    knownPluginNames.add(pkg.name);
  }

  nextOhosPlugins.sort((left, right) => left.name.localeCompare(right.name));

  const changed =
    !Array.isArray(pluginData.plugins.ohos) ||
    JSON.stringify(originalOhosPlugins) !== JSON.stringify(nextOhosPlugins);

  if (!changed) {
    return false;
  }

  pluginData.plugins.ohos = nextOhosPlugins;
  fs.writeFileSync(flutterPluginsPath, `${JSON.stringify(pluginData, null, 2)}\n`);

  const pluginNames = nextOhosPlugins.map((entry) => entry.name).join(', ');
  console.info(`[localsend] synced OHOS plugins: ${pluginNames || '(none)'}`);
  return true;
}

if (require.main === module) {
  const flutterProjectPath = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.resolve(__dirname, '..');
  ensureOhosPluginDependencies(flutterProjectPath);
}

module.exports = {
  ensureOhosPluginDependencies,
};
