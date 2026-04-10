import express from 'express';
import cors from 'cors';
import { authMiddleware } from './middleware/auth.js';
import schedulesRouter from './routes/schedules.js';
import syncRouter from './routes/sync.js';
import sessionsRouter from './routes/sessions.js';
import pingRouter from './routes/ping.js';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Public routes
app.use('/api/ping', pingRouter);

// Protected routes (require auth)
app.use('/api/schedules', authMiddleware, schedulesRouter);
app.use('/api/sync', authMiddleware, syncRouter);
app.use('/api/sessions', authMiddleware, sessionsRouter);

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Schedule server running on http://0.0.0.0:${PORT}`);
  console.log(`API endpoints:`);
  console.log(`  GET  /api/ping           - Health check`);
  console.log(`  GET  /api/schedules      - List schedules`);
  console.log(`  POST /api/schedules      - Create schedule`);
  console.log(`  PUT  /api/schedules/:id - Update schedule`);
  console.log(`  DELETE /api/schedules/:id - Delete schedule`);
  console.log(`  POST /api/schedules/:id/complete - Mark complete`);
  console.log(`  POST /api/sync           - Bulk sync schedules`);
  console.log(`  GET  /api/sessions       - Get session`);
  console.log(`  POST /api/sessions       - Create/get session`);
});
