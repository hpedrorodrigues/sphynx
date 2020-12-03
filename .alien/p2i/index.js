const puppeteer = require('puppeteer');
const yargs = require('yargs');

const args = yargs
  .string(['url', 'filename', 'selector'])
  .demandOption(['url'])
  .describe('url', 'The URL to take the screenshot')
  .alias('u', 'url')
  .nargs('url', 1)
  .describe('filename', 'The file path to save the image to')
  .alias('f', 'filename')
  .nargs('filename', 1)
  .default('filename', 'screenshot.png')
  .describe('selector', 'A query selector to be used to screenshot an element')
  .alias('s', 'selector')
  .nargs('selector', 1)
  .number(['width', 'height'])
  .describe('width', 'The screenshot resolution width')
  .alias('w', 'width')
  .nargs('width', 1)
  .default('width', 1440)
  .describe('height', 'The screenshot resolution height')
  .alias('h', 'height')
  .nargs('height', 1)
  .default('height', 900).argv;

const main = async () => {
  console.info(`Processing page: "${args.url}".`);

  const browser = await puppeteer.launch({
    args: ['--disable-dev-shm-usage', '--lang=en-US'],
  });
  const page = await browser.newPage();

  await page.setExtraHTTPHeaders({ 'Accept-Language': 'en-US' });
  await page.setViewport({ width: args.width, height: args.height });
  await page.goto(args.url, { waitUntil: 'domcontentloaded' });

  if (args.selector) {
    try {
      await page.waitForSelector(args.selector, { visible: true });
      const element = await page.$(args.selector);
      await element.screenshot({ path: args.filename });
    } catch (e) {
      if (e instanceof puppeteer.errors.TimeoutError) {
        console.error(
          `The selector "${args.selector}" cannot be found in page "${args.url}".`
        );
      } else {
        console.error(e);
      }
    }
  } else {
    await page.screenshot({ path: args.filename });
  }

  await browser.close();
};

main();
