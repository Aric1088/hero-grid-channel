const { rokuDeploy } = require('roku-deploy');
const path = require('path');
const http = require('http');

const ROKU_IP = '192.168.1.155';

function sendKeypress(key) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: ROKU_IP,
      port: 8060,
      path: `/keypress/${key}`,
      method: 'POST'
    }, (res) => {
      resolve();
    });
    req.on('error', reject);
    req.end();
  });
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  try {
    console.log("Exiting the app by pressing Home...");
    await sendKeypress('Home');
    await sleep(3000);

    console.log("Launching the SpamFilms3 channel...");
    const reqLaunch = http.request({
      hostname: ROKU_IP,
      port: 8060,
      path: '/launch/dev',
      method: 'POST'
    }, (res) => {});
    reqLaunch.end();
    
    console.log("Waiting 6 seconds for channel launch...");
    await sleep(6000);
    
    console.log("Selecting profile...");
    await sendKeypress('Select');
    await sleep(4000);
    
    console.log("Pressing Up to focus TopMenu...");
    await sendKeypress('Up');
    await sleep(1000);
    
    console.log("Pressing Right to select Movies...");
    await sendKeypress('Right');
    await sleep(1000);
    
    console.log("Pressing Select to load Movies category...");
    await sendKeypress('Select');
    await sleep(4000);
    
    console.log("Now on Movies grid. Pressing Up to return to TopMenu...");
    await sendKeypress('Up');
    await sleep(2000);
    
    console.log("Capturing screenshot...");
    const resultPath = await rokuDeploy.takeScreenshot({
      host: ROKU_IP,
      password: '1088',
      outDir: __dirname,
      outFile: 'up_key_test'
    });
    console.log("Screenshot captured successfully:", resultPath);
  } catch (error) {
    console.error("Failed:", error);
  }
}

main();
