import { Router } from 'express';
import db from '../db/database.js';
import { cleanupExpiredSessions } from '../db/database.js';

const router = Router();

// GET /api/schedules - Get schedules (with optional date filter)
router.get('/', (req, res) => {
  cleanupExpiredSessions();

  const { from, to } = req.query;
  const deviceId = req.deviceId;

  let sql = 'SELECT * FROM schedules WHERE device_id = ?';
  const params = [deviceId];

  if (from) {
    sql += ' AND start_time >= ?';
    params.push(parseInt(from));
  }
  if (to) {
    sql += ' AND start_time <= ?';
    params.push(parseInt(to));
  }

  sql += ' ORDER BY start_time ASC';

  const schedules = db.prepare(sql).all(...params);

  // Return in snake_case JSON format
  const result = schedules.map(s => ({
    id: s.id,
    title: s.title,
    location: s.location,
    notes: s.notes,
    start_time: s.start_time,
    end_time: s.end_time,
    reminder_time: s.reminder_time,
    timezone: s.timezone,
    repeat_rule: s.repeat_rule,
    is_completed: s.is_completed === 1,
    created_at: s.created_at,
    updated_at: s.updated_at
  }));

  res.json({ schedules: result });
});

// GET /api/schedules/:id - Get single schedule
router.get('/:id', (req, res) => {
  const schedule = db.prepare('SELECT * FROM schedules WHERE id = ? AND device_id = ?')
    .get(req.params.id, req.deviceId);

  if (!schedule) {
    return res.status(404).json({ error: 'Schedule not found' });
  }

  res.json({
    id: schedule.id,
    title: schedule.title,
    location: schedule.location,
    notes: schedule.notes,
    start_time: schedule.start_time,
    end_time: schedule.end_time,
    reminder_time: schedule.reminder_time,
    timezone: schedule.timezone,
    repeat_rule: schedule.repeat_rule,
    is_completed: schedule.is_completed === 1,
    created_at: schedule.created_at,
    updated_at: schedule.updated_at
  });
});

// POST /api/schedules - Create schedule
router.post('/', (req, res) => {
  const { id, title, location, notes, start_time, end_time, reminder_time, timezone, repeat_rule, is_completed } = req.body;

  if (!id || !title || !start_time) {
    return res.status(400).json({ error: 'Missing required fields: id, title, start_time' });
  }

  const now = Math.floor(Date.now() / 1000);

  try {
    db.prepare(`
      INSERT INTO schedules (id, device_id, title, location, notes, start_time, end_time, reminder_time, timezone, repeat_rule, is_completed, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      req.deviceId,
      title,
      location || null,
      notes || null,
      start_time,
      end_time || null,
      reminder_time || null,
      timezone || 'Asia/Shanghai',
      repeat_rule || null,
      is_completed ? 1 : 0,
      now,
      now
    );

    res.status(201).json({
      success: true,
      schedule: { id, title, start_time, end_time, reminder_time, is_completed }
    });
  } catch (err) {
    if (err.message.includes('UNIQUE constraint')) {
      return res.status(409).json({ error: 'Schedule with this id already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/schedules/:id - Update schedule
router.put('/:id', (req, res) => {
  const { title, location, notes, start_time, end_time, reminder_time, timezone, repeat_rule, is_completed } = req.body;

  const existing = db.prepare('SELECT * FROM schedules WHERE id = ? AND device_id = ?')
    .get(req.params.id, req.deviceId);

  if (!existing) {
    return res.status(404).json({ error: 'Schedule not found' });
  }

  const now = Math.floor(Date.now() / 1000);

  db.prepare(`
    UPDATE schedules SET
      title = ?, location = ?, notes = ?, start_time = ?, end_time = ?,
      reminder_time = ?, timezone = ?, repeat_rule = ?, is_completed = ?, updated_at = ?
    WHERE id = ? AND device_id = ?
  `).run(
    title ?? existing.title,
    location ?? existing.location,
    notes ?? existing.notes,
    start_time ?? existing.start_time,
    end_time ?? existing.end_time,
    reminder_time ?? existing.reminder_time,
    timezone ?? existing.timezone,
    repeat_rule ?? existing.repeat_rule,
    is_completed !== undefined ? (is_completed ? 1 : 0) : existing.is_completed,
    now,
    req.params.id,
    req.deviceId
  );

  const updated = db.prepare('SELECT * FROM schedules WHERE id = ?').get(req.params.id);

  res.json({
    success: true,
    schedule: {
      id: updated.id,
      title: updated.title,
      location: updated.location,
      notes: updated.notes,
      start_time: updated.start_time,
      end_time: updated.end_time,
      reminder_time: updated.reminder_time,
      timezone: updated.timezone,
      repeat_rule: updated.repeat_rule,
      is_completed: updated.is_completed === 1,
      created_at: updated.created_at,
      updated_at: updated.updated_at
    }
  });
});

// DELETE /api/schedules/:id - Delete schedule
router.delete('/:id', (req, res) => {
  const result = db.prepare('DELETE FROM schedules WHERE id = ? AND device_id = ?')
    .run(req.params.id, req.deviceId);

  if (result.changes === 0) {
    return res.status(404).json({ error: 'Schedule not found' });
  }

  res.json({ success: true });
});

// POST /api/schedules/:id/complete - Mark as complete
router.post('/:id/complete', (req, res) => {
  const existing = db.prepare('SELECT * FROM schedules WHERE id = ? AND device_id = ?')
    .get(req.params.id, req.deviceId);

  if (!existing) {
    return res.status(404).json({ error: 'Schedule not found' });
  }

  const now = Math.floor(Date.now() / 1000);
  db.prepare('UPDATE schedules SET is_completed = 1, updated_at = ? WHERE id = ?')
    .run(now, req.params.id);

  res.json({ success: true, is_completed: true });
});

export default router;
