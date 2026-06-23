import path from 'path';
import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { flutterHvigorPlugin } from 'flutter-hvigor-plugin';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { ensureOhosPluginDependencies } = require('./ensure-ohos-plugins');

const flutterProjectPath = path.dirname(__dirname);
ensureOhosPluginDependencies(flutterProjectPath);

export default {
  system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [flutterHvigorPlugin(flutterProjectPath)],
};
