import 'dotenv/config';

const SYNC_SECRET = process.env.SYNC_SECRET || 'default-secret-change-me';

export function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  const deviceId = req.headers['x-device-id'];

  if (!deviceId) {
    return res.status(401).json({ error: 'Missing X-Device-ID header' });
  }

  if (!authHeader || authHeader !== `Bearer ${SYNC_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  req.deviceId = deviceId;
  next();
}
