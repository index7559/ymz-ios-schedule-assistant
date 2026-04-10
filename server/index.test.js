import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import express from 'express';
import cors from 'cors';
import schedulesRouter from './routes/schedules.js';
import syncRouter from './routes/sync.js';
import sessionsRouter from './routes/sessions.js';
import pingRouter from './routes/ping.js';
import db from './db/database.js';

const app = express();
app.use(cors());
app.use(express.json());

// Mock auth - inject test device ID
app.use((req, res, next) => {
  req.deviceId = 'test-device';
  next();
});

app.use('/api/ping', pingRouter);
app.use('/api/schedules', schedulesRouter);
app.use('/api/sync', syncRouter);
app.use('/api/sessions', sessionsRouter);

describe('API Tests', () => {
  const testDeviceId = 'test-device';

  afterAll(() => {
    db.prepare('DELETE FROM schedules WHERE device_id = ?').run(testDeviceId);
    db.prepare('DELETE FROM sessions WHERE device_id = ?').run(testDeviceId);
  });

  describe('GET /api/ping', () => {
    it('should return status ok', async () => {
      const res = await request(app).get('/api/ping');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.timestamp).toBeDefined();
    });
  });

  describe('Schedules CRUD', () => {
    const scheduleId = 'test-schedule-' + Date.now();

    it('should create a schedule', async () => {
      const res = await request(app)
        .post('/api/schedules')
        .send({
          id: scheduleId,
          title: 'Test Meeting',
          start_time: 1744227600,
          reminder_time: 1744226700
        });
      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
    });

    it('should get schedules', async () => {
      const res = await request(app).get('/api/schedules');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.schedules)).toBe(true);
    });

    it('should update a schedule', async () => {
      const res = await request(app)
        .put(`/api/schedules/${scheduleId}`)
        .send({ title: 'Updated Meeting' });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.schedule.title).toBe('Updated Meeting');
    });

    it('should mark schedule as complete', async () => {
      const res = await request(app).post(`/api/schedules/${scheduleId}/complete`);
      expect(res.status).toBe(200);
      expect(res.body.is_completed).toBe(true);
    });

    it('should delete a schedule', async () => {
      const res = await request(app).delete(`/api/schedules/${scheduleId}`);
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('Sessions', () => {
    const sessionId = 'test-session-' + Date.now();

    it('should create a session', async () => {
      const res = await request(app)
        .post('/api/sessions')
        .send({ session_id: sessionId });
      expect(res.status).toBe(201);
      expect(res.body.id).toBe(sessionId);
    });

    it('should get session', async () => {
      const res = await request(app).get(`/api/sessions?session_id=${sessionId}`);
      expect(res.status).toBe(200);
      expect(res.body.id).toBe(sessionId);
    });
  });

  describe('Sync', () => {
    it('should bulk sync schedules', async () => {
      const res = await request(app)
        .post('/api/sync')
        .send({
          schedules: [{
            id: 'sync-test-' + Date.now(),
            title: 'Synced Event',
            start_time: 1744227600,
            is_completed: false
          }]
        });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
