import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const run = (cmd) => { console.log(`\n> ${cmd}`); execSync(cmd, { stdio: 'inherit' }); };

if (!existsSync('node_modules')) run('npm install');
if (!existsSync('android')) run('npx cap add android');
if (!existsSync('ios')) run('npx cap add ios');
run('npx cap sync');

// Google Play requires API 36 for new apps from Aug 31, 2026.
const vars = 'android/variables.gradle';
if (existsSync(vars)) {
  let s = readFileSync(vars, 'utf8');
  s = s.replace(/compileSdkVersion\s*=\s*\d+/, 'compileSdkVersion = 36');
  s = s.replace(/targetSdkVersion\s*=\s*\d+/, 'targetSdkVersion = 36');
  writeFileSync(vars, s);
  console.log('Android compile/target SDK set to 36.');
}

console.log('\nPWT native platforms initialized. Next: configure Firebase/APNs credentials, then run npm run android or npm run ios.');
