import { Router } from 'express';
import db, { getOrCreateSession, cleanupExpiredSessions } from '../db/database.js';

const router = Router();

// GET /api/sessions - Get session (and cleanup expired)
router.get('/', (req, res) => {
  cleanupExpiredSessions();

  const { session_id } = req.query;
  if (!session_id) {
    return res.status(400).json({ error: 'Missing session_id query parameter' });
  }

  const session = db.prepare('SELECT * FROM sessions WHERE id = ? AND device_id = ?')
    .get(session_id, req.deviceId);

  if (!session) {
    return res.status(404).json({ error: 'Session not found or expired' });
  }

  res.json({ id: session.id, last_active_at: session.last_active_at });
});

// POST /api/sessions - Create or get session
router.post('/', (req, res) => {
  const { session_id } = req.body;

  if (!session_id) {
    return res.status(400).json({ error: 'Missing session_id in body' });
  }

  const session = getOrCreateSession(session_id, req.deviceId);
  res.status(201).json({ id: session.id, created_at: session.created_at, last_active_at: session.last_active_at });
});

export default router;
