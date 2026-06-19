const { rokuDeploy } = require('roku-deploy');
const path = require('path');

async function main() {
  try {
    console.log("Taking screenshot of Roku TV...");
    const resultPath = await rokuDeploy.takeScreenshot({
      host: '192.168.1.155',
      password: '1088',
      outDir: __dirname,
      outFile: 'roku_screenshot'
    });
    console.log("Screenshot saved successfully to:", resultPath);
  } catch (error) {
    console.error("Error taking screenshot:", error);
  }
}

main();
