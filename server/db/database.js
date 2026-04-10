import Database from 'better-sqlite3';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const db = new Database(join(__dirname, 'schedule.db'));
db.pragma('journal_mode = WAL');

// Initialize schema
const initSQL = readFileSync(join(__dirname, 'init.sql'), 'utf-8');
db.exec(initSQL);

export default db;

// Helper: Clean up expired sessions (>72 hours inactive)
export function cleanupExpiredSessions() {
  const cutoff = Math.floor(Date.now() / 1000) - (72 * 60 * 60);
  const result = db.prepare('DELETE FROM sessions WHERE last_active_at < ?').run(cutoff);
  return result.changes;
}

// Helper: Update session last_active_at
export function touchSession(sessionId) {
  const now = Math.floor(Date.now() / 1000);
  db.prepare('UPDATE sessions SET last_active_at = ? WHERE id = ?').run(now, sessionId);
}

// Helper: Get or create session
export function getOrCreateSession(id, deviceId) {
  const now = Math.floor(Date.now() / 1000);
  const existing = db.prepare('SELECT * FROM sessions WHERE id = ?').get(id);
  if (existing) {
    db.prepare('UPDATE sessions SET last_active_at = ? WHERE id = ?').run(now, id);
    return existing;
  }
  db.prepare('INSERT INTO sessions (id, device_id, created_at, last_active_at) VALUES (?, ?, ?, ?)')
    .run(id, deviceId, now, now);
  return { id, device_id: deviceId, created_at: now, last_active_at: now };
}
