import { spawn, ChildProcess } from 'child_process';
import path from 'path';
import fs from 'fs';
import mongoose from 'mongoose';

const TEST_PORT = 27018;
const TEST_REPL_SET = 'rs0';
const DEFAULT_MONGOD_PATH = 'C:\\Program Files\\MongoDB\\Server\\8.3\\bin\\mongod.exe';
const PID_FILE = path.join(__dirname, '.test-rs-mongod.pid');

export async function startTestReplicaSet(): Promise<void> {
  const mongodPath = process.env.MONGOD_PATH || DEFAULT_MONGOD_PATH;
  if (!fs.existsSync(mongodPath)) {
    console.warn(`[test-rs] mongod binary not found at ${mongodPath}. Skipping test replica set startup.`);
    return;
  }

  // Check if port 27018 is already up and running rs0
  try {
    const conn = await mongoose.createConnection(`mongodb://127.0.0.1:${TEST_PORT}/admin?directConnection=true`, {
      serverSelectionTimeoutMS: 1500,
      connectTimeoutMS: 2000,
    }).asPromise();
    if (conn.db) {
      const admin = conn.db.admin();
      const hello = await admin.command({ hello: 1 });
      await conn.close();
      if (hello.setName === TEST_REPL_SET && hello.isWritablePrimary) {
        // Replica set already running and healthy
        return;
      }
    } else {
      await conn.close();
    }
  } catch {
    // Port 27018 not running yet, proceed with startup
  }

  // Create isolated temp database directory
  const dbPath = path.join(__dirname, '..', '.test-rs-data');
  if (!fs.existsSync(dbPath)) {
    fs.mkdirSync(dbPath, { recursive: true });
  }

  const proc: ChildProcess = spawn(mongodPath, [
    '--port', String(TEST_PORT),
    '--dbpath', dbPath,
    '--replSet', TEST_REPL_SET,
    '--bind_ip', '127.0.0.1',
    '--oplogSize', '128',
  ], {
    detached: true,
    stdio: 'ignore',
  });

  proc.unref();

  if (proc.pid) {
    fs.writeFileSync(PID_FILE, String(proc.pid), 'utf8');
  }

  // Connect and initialize replica set
  let connected = false;
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 500));
    try {
      const conn = await mongoose.createConnection(`mongodb://127.0.0.1:${TEST_PORT}/admin?directConnection=true`, {
        serverSelectionTimeoutMS: 1500,
        connectTimeoutMS: 2000,
      }).asPromise();
      connected = true;

      if (conn.db) {
        const admin = conn.db.admin();
        try {
          await admin.command({
            replSetInitiate: {
              _id: TEST_REPL_SET,
              members: [{ _id: 0, host: `127.0.0.1:${TEST_PORT}` }],
            },
          });
        } catch (e: any) {
          // If already initiated or concurrently initialized, continue
        }

        // Wait for node to step up as writable primary
        for (let j = 0; j < 30; j++) {
          await new Promise((res) => setTimeout(res, 500));
          try {
            const hello = await admin.command({ hello: 1 });
            if (hello.isWritablePrimary) {
              break;
            }
          } catch {}
        }
      }

      await conn.close();
      break;
    } catch {
      // Wait and retry connection
    }
  }

  if (!connected) {
    console.warn(`[test-rs] Failed to connect to test replica set on port ${TEST_PORT} after startup.`);
  }
}

export async function stopTestReplicaSet(): Promise<void> {
  if (fs.existsSync(PID_FILE)) {
    try {
      const pidStr = fs.readFileSync(PID_FILE, 'utf8').trim();
      const pid = parseInt(pidStr, 10);
      if (!isNaN(pid)) {
        process.kill(pid);
      }
    } catch {
      // Ignore if process already exited
    } finally {
      try {
        fs.unlinkSync(PID_FILE);
      } catch {}
    }
  }
}
