const http = require('http');
const util = require('util');

const hostname = '127.0.0.1';
const port = process.env.PORT || 3000;
const statusCode = process.env.STATUS_CODE || 200;
const responseBody = process.env.RESPONSE_BODY;
const compactMode = process.env.COMPACT_MODE == 'true';

const APPLICATION_JSON = 'application/json';

const decodeUrl = (url) => {
  const decoded = decodeURIComponent(url);
  if (compactMode) {
    return decoded;
  }

  return { raw: url, decoded };
};

const deserializeBody = (contentType, data) => {
  if (data === '') {
    return '<No body>';
  }

  if (contentType === undefined || !contentType.startsWith(APPLICATION_JSON)) {
    return data;
  }

  try {
    const deserialized = JSON.parse(data);
    if (compactMode) {
      return deserialized;
    }

    return { raw: data, deserialized };
  } catch (e) {
    return data;
  }
};

const listener = async (req, res) => {
  console.info('-----\n');

  const buffer = [];
  for await (const chunk of req) {
    buffer.push(chunk);
  }

  const data = Buffer.concat(buffer).toString();
  const output = {
    httpVersion: req.httpVersion,
    path: decodeUrl(req.url),
    method: req.method,
    headers: req.headers,
    body: deserializeBody(req.headers['content-type'], data),
    clientAddress: `${req.socket.remoteAddress}:${req.socket.remotePort}`,
  };

  console.info(
    util.inspect(output, {
      depth: Infinity,
      colors: true,
      compact: false,
      sorted: true,
    }),
    '\n\n',
  );

  res.writeHead(statusCode, { 'Content-Type': APPLICATION_JSON });
  res.write(responseBody || JSON.stringify(output));
  res.end();
};

const server = http.createServer(listener);

server.listen(port, hostname);

console.info(`Server listening at http://${hostname}:${port}\n`);
