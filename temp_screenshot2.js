
const { rokuDeploy } = require('roku-deploy');
async function main() {
  try {
    await rokuDeploy.takeScreenshot({
      host: '192.168.1.155',
      password: '1088',
      outDir: 'C:/Users/aricz/Documents/GitHub/spamfilms3_ui/spamfilms-roku/hero-grid-channel',
      outFile: 'details_screen_focus'
    });
  } catch (e) {
    console.error(e);
  }
}
main();
