const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const SCRIPT_PATH = path.resolve(__dirname, 'access-db.ps1');

function resolveDatabasePath() {
  if (process.env.ACCESS_DB_PATH) {
    return process.env.ACCESS_DB_PATH;
  }

  const accessFiles = fs
    .readdirSync(PROJECT_ROOT, { withFileTypes: true })
    .filter(entry => entry.isFile() && entry.name.toLowerCase().endsWith('.accdb'))
    .map(entry => path.join(PROJECT_ROOT, entry.name));

  if (accessFiles.length === 1) {
    return accessFiles[0];
  }

  if (accessFiles.length === 0) {
    throw new Error('Access database file (*.accdb) was not found in the project root.');
  }

  throw new Error('Multiple Access database files were found. Set ACCESS_DB_PATH to choose one.');
}

function runDatabaseAction(action, payload) {
  return new Promise((resolve, reject) => {
    let databasePath;

    try {
      databasePath = resolveDatabasePath();
    } catch (error) {
      reject(error);
      return;
    }

    const args = [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      SCRIPT_PATH,
      '-Action',
      action,
      '-DatabasePath',
      databasePath
    ];

    if (payload !== undefined) {
      const payloadBase64 = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64');
      args.push('-PayloadBase64', payloadBase64);
    }

    execFile(
      'powershell.exe',
      args,
      {
        windowsHide: true,
        maxBuffer: 1024 * 1024
      },
      (error, stdout, stderr) => {
        if (error) {
          const details = stderr.trim() || stdout.trim() || error.message;
          reject(new Error(details));
          return;
        }

        const output = stdout.trim();
        if (!output) {
          resolve({});
          return;
        }

        try {
          resolve(JSON.parse(output));
        } catch (parseError) {
          reject(new Error(`Invalid database response: ${output}`));
        }
      }
    );
  });
}

function initializeDatabase() {
  return runDatabaseAction('init');
}

function saveBooking(payload) {
  return runDatabaseAction('save-booking', payload);
}

function listBookings() {
  return runDatabaseAction('list-bookings');
}

module.exports = {
  initializeDatabase,
  listBookings,
  saveBooking
};
