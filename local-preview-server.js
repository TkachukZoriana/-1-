const http = require('http');
const fs = require('fs');
const path = require('path');
const {
  initializeDatabase,
  listBookings,
  saveBooking
} = require('./booking-database');

const PORT = Number(process.env.PORT) || 8000;
const ROOT = __dirname;

const MIME_TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.js': 'application/javascript; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8'
  });
  response.end(JSON.stringify(payload));
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;

    request.on('data', chunk => {
      size += chunk.length;

      if (size > 1024 * 1024) {
        reject(new Error('Request body is too large.'));
        request.destroy();
        return;
      }

      chunks.push(chunk);
    });

    request.on('end', () => {
      try {
        const rawBody = Buffer.concat(chunks).toString('utf8');
        resolve(rawBody ? JSON.parse(rawBody) : {});
      } catch (error) {
        reject(new Error('Request body must be valid JSON.'));
      }
    });

    request.on('error', reject);
  });
}

const server = http.createServer((request, response) => {
  const pathname = decodeURIComponent(request.url.split('?')[0]);

  if (pathname === '/api/bookings' && request.method === 'POST') {
    readJsonBody(request)
      .then(payload => saveBooking(payload))
      .then(result => sendJson(response, 200, result))
      .catch(error => {
        console.error('Failed to save booking', error);
        sendJson(response, 500, {
          success: false,
          error: error.message
        });
      });

    return;
  }

  if (pathname === '/api/bookings' && request.method === 'GET') {
    listBookings()
      .then(result => sendJson(response, 200, result))
      .catch(error => {
        console.error('Failed to read bookings', error);
        sendJson(response, 500, {
          success: false,
          error: error.message
        });
      });

    return;
  }

  if (pathname === '/api/health' && request.method === 'GET') {
    sendJson(response, 200, {
      success: true
    });
    return;
  }

  const relativePath = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  const filePath = path.resolve(ROOT, relativePath);

  if (!filePath.startsWith(ROOT)) {
    response.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (error, fileBuffer) => {
    if (error) {
      response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      response.end('Not found');
      return;
    }

    const extension = path.extname(filePath).toLowerCase();
    response.writeHead(200, {
      'Content-Type': MIME_TYPES[extension] || 'application/octet-stream'
    });
    response.end(fileBuffer);
  });
});

server.on('error', error => {
  if (error && error.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Close the previous server window and start this file again.`);
    return;
  }

  console.error('Local preview server failed to start', error);
});

server.listen(PORT, () => {
  console.log(`Local preview server is running at http://localhost:${PORT}`);

  initializeDatabase()
    .then(() => {
      console.log('Access database is ready.');
    })
    .catch(error => {
      console.error('Database initialization failed', error);
    });
});
