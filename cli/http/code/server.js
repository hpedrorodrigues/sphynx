const http = require('http');

const hostname = '127.0.0.1';
const port = process.env.PORT || 3000;

const APPLICATION_JSON = 'application/json';

const deserializeBody = (contentType, data) => {
  if (contentType === undefined || !contentType.startsWith(APPLICATION_JSON)) {
    return data;
  }

  try {
    return JSON.parse(data);
  } catch (e) {
    return data;
  }
};

const listener = async (req, res) => {
  const buffer = [];
  for await (const chunk of req) {
    buffer.push(chunk);
  }

  const data = Buffer.concat(buffer).toString();
  const body = deserializeBody(req.headers['content-type'], data);
  const result = {
    request: {
      httpVersion: req.httpVersion,
      path: req.url,
      method: req.method,
      host: req.headers.host,
      headers: req.headers,
      body: body,
    },
  };

  console.info(result, '\n-----');

  res.writeHead(200, { 'Content-Type': APPLICATION_JSON });
  res.write(JSON.stringify(result));
  res.end();
};

const server = http.createServer(listener);

server.listen(port, hostname);

console.info(`Server listening at http://${hostname}:${port}\n`);
