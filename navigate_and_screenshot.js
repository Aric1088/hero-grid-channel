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
    console.log("Launching the SpamFilms3 channel...");
    const reqLaunch = http.request({
      hostname: ROKU_IP,
      port: 8060,
      path: '/launch/dev',
      method: 'POST'
    }, (res) => {});
    reqLaunch.end();
    
    console.log("Waiting 5 seconds for channel launch and splash screen to clear...");
    await sleep(5000);
    
    console.log("Selecting profile...");
    await sendKeypress('Select');
    await sleep(2000);
    
    console.log("Focusing top menu...");
    await sendKeypress('Up');
    await sleep(500);
    
    console.log("Navigating to Search tab...");
    await sendKeypress('Right');
    await sleep(500);
    await sendKeypress('Right');
    await sleep(500);
    await sendKeypress('Right');
    await sleep(500);
    
    console.log("Entering Search screen...");
    await sendKeypress('Select');
    await sleep(2500);
    
    console.log("Capturing screenshot...");
    const resultPath = await rokuDeploy.takeScreenshot({
      host: ROKU_IP,
      password: '1088',
      outDir: __dirname,
      outFile: 'search_screen'
    });
    console.log("Screenshot captured successfully:", resultPath);
  } catch (error) {
    console.error("Navigation/screenshot failed:", error);
  }
}

main();
