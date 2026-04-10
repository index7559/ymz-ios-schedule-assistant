import { Router } from 'express';
import db from '../db/database.js';

const router = Router();

// POST /api/sync - Bulk sync schedules from iPhone
router.post('/', (req, res) => {
  const { schedules } = req.body;

  if (!Array.isArray(schedules)) {
    return res.status(400).json({ error: 'schedules must be an array' });
  }

  const now = Math.floor(Date.now() / 1000);
  let syncedCount = 0;

  const upsert = db.prepare(`
    INSERT INTO schedules (id, device_id, title, location, notes, start_time, end_time, reminder_time, timezone, repeat_rule, is_completed, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      title = excluded.title,
      location = excluded.location,
      notes = excluded.notes,
      start_time = excluded.start_time,
      end_time = excluded.end_time,
      reminder_time = excluded.reminder_time,
      timezone = excluded.timezone,
      repeat_rule = excluded.repeat_rule,
      is_completed = excluded.is_completed,
      updated_at = excluded.updated_at
    WHERE excluded.updated_at > schedules.updated_at
  `);

  const insertMany = db.transaction((items) => {
    for (const s of items) {
      upsert.run(
        s.id,
        req.deviceId,
        s.title,
        s.location || null,
        s.notes || null,
        s.start_time,
        s.end_time || null,
        s.reminder_time || null,
        s.timezone || 'Asia/Shanghai',
        s.repeat_rule || null,
        s.is_completed ? 1 : 0,
        s.created_at || now,
        s.updated_at || now
      );
      syncedCount++;
    }
  });

  try {
    insertMany(schedules);
    res.json({ success: true, syncedCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
