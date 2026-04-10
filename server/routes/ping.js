import { Router } from 'express';

const router = Router();

// GET /api/ping - Health check
router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: Math.floor(Date.now() / 1000)
  });
});

export default router;
