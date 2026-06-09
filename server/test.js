const puppeteer = require('puppeteer');

(async () => {
  console.log('Launching browser...');
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', err => console.log('PAGE ERROR:', err.message));
  
  console.log('Navigating...');
  await page.goto('http://localhost:3000', { waitUntil: 'networkidle0' });
  
  console.log('Clicking to register...');
  await page.click('#to-register');
  
  console.log('Typing credentials...');
  await page.type('#reg-name', 'Sumit');
  await page.type('#reg-email', 'sumit@test.com');
  await page.type('#reg-password', 'password123');
  
  console.log('Submitting form...');
  await page.click('#register-form button[type=\"submit\"]');
  
  await new Promise(r => setTimeout(r, 2000));
  
  const toastText = await page.evaluate(() => {
    const el = document.getElementById('toast');
    return el && el.classList.contains('show') ? el.innerText : 'No visible toast';
  });
  console.log('Toast output:', toastText);
  
  const isDashboard = await page.evaluate(() => {
    return document.getElementById('dashboard-page').classList.contains('active-page');
  });
  console.log('Is Dashboard Active:', isDashboard);
  
  await browser.close();
})();
