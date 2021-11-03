const http = require('http');

const hostname = '127.0.0.1';
const port = process.env.PORT || 3000;

const APPLICATION_JSON = 'application/json';

const listener = async (req, res) => {
    const buffer = [];
    for await (const chunk of req) {
        buffer.push(chunk);
    }

    const data = Buffer.concat(buffer).toString();
    const body = req.headers['content-type'] !== undefined && req.headers['content-type'].startsWith(APPLICATION_JSON) ?
        JSON.parse(data) : data;
    const result = {
        request: {
            httpVersion: req.httpVersion,
            path: req.url,
            method: req.method,
            host: req.headers.host,
            headers: req.headers,
            body: body,
        }
    };

    console.info(result, '\n-----');

    res.writeHead(200, { 'Content-Type': APPLICATION_JSON });
    res.write(JSON.stringify(result));
    res.end();
};

const server = http.createServer(listener);

server.listen(port, hostname);

console.info(`Server listening at http://${hostname}:${port}`);
