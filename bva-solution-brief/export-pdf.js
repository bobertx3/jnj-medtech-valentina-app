const puppeteer = require('puppeteer');
const { PDFDocument } = require('pdf-lib');
const fs = require('fs');
const path = require('path');

const INPUT = path.resolve(process.argv[2] || 'jnj-medtech-business-value-analysis.html');
const OUTPUT_NAME = process.argv[3] || INPUT.replace(/\.html$/, '.pdf');
const OUTPUT = path.resolve(OUTPUT_NAME);
const WIDTH = 1920;
const HEIGHT = 1080;
const SCALE = 2;

(async () => {
  console.log(`Opening: ${INPUT}`);
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: SCALE });
  await page.goto(`file://${INPUT}`, { waitUntil: 'networkidle0', timeout: 30000 });

  await page.evaluate(() => document.fonts.ready);
  await new Promise(r => setTimeout(r, 1500));

  // Force all counters to their final values
  await page.evaluate(() => {
    document.querySelectorAll('.counter').forEach(c => {
      c.textContent = c.dataset.target;
      c.dataset.animated = 'true';
    });
  });

  const slideCount = await page.evaluate(() => document.querySelectorAll('.slide').length);
  console.log(`Found ${slideCount} slides`);

  const screenshots = [];

  for (let i = 0; i < slideCount; i++) {
    // Screenshot the slide element directly — this captures IT, not the viewport
    const slideHandle = await page.evaluateHandle((idx) => document.querySelectorAll('.slide')[idx], i);
    const screenshotBuffer = await slideHandle.asElement().screenshot({ type: 'png' });
    await slideHandle.dispose();

    screenshots.push(screenshotBuffer);
    console.log(`  Captured slide ${i + 1}/${slideCount}`);
  }

  await browser.close();

  // Assemble PDF — 16:9 landscape
  const pdfDoc = await PDFDocument.create();
  const pageWidth = 960;
  const pageHeight = 540;

  for (const buf of screenshots) {
    const img = await pdfDoc.embedPng(buf);
    const pdfPage = pdfDoc.addPage([pageWidth, pageHeight]);
    pdfPage.drawImage(img, { x: 0, y: 0, width: pageWidth, height: pageHeight });
  }

  const pdfBytes = await pdfDoc.save();
  fs.writeFileSync(OUTPUT, pdfBytes);
  console.log(`\nPDF saved: ${OUTPUT} (${(pdfBytes.length / 1024 / 1024).toFixed(1)} MB)`);
})();
