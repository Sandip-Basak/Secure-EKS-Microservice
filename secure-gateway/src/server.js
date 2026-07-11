const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const pino = require('pino-http')();
const bcrypt = require('bcrypt'); // Added for secure password hashing

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET && process.env.NODE_ENV === 'production') {
  console.error("FATAL: JWT_SECRET environment variable is missing.");
  process.exit(1);
}

app.use(pino);
app.use(helmet());
app.use(express.json());

// In-memory data store acting as our temporary DB pool before Phase 3
const usersDb = [];

app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Strict Rate Limiting for both Login and Registration to prevent brute-forcing
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 50, // Dropped to 50 to protect registration endpoints from automated spam
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts, please try again later.' }
});

// ==========================================
// SECURE USER REGISTRATION ENDPOINT
// ==========================================
app.post('/api/auth/register', authLimiter, async (req, res, next) => {
  try {
    const { username, password, tenantId } = req.body;

    if (!username || !password || !tenantId) {
      return res.status(400).json({ error: 'Username, password, and Tenant ID are mandatory.' });
    }

    // Check if user already exists within THIS specific tenant scope
    const userExists = usersDb.find(u => u.username === username && u.tenantId === tenantId);
    if (userExists) {
      // Security Take: Return a generic 400 error to complicate user enumeration profiling
      return res.status(400).json({ error: 'Registration could not be completed.' });
    }

    // High-work-factor hashing (Salt rounds = 12) to defend against GPU cracking arrays
    const hashedPassword = await bcrypt.hash(password, 12);

    const newUser = {
      id: Date.now().toString(), // Temporary mock ID assignment
      username,
      password: hashedPassword,
      tenantId,
      role: 'user'
    };

    usersDb.push(newUser);

    // SECURITY DEFENSE (CWE-532): Log the event but NEVER the raw password or hash payload
    req.log.info({ tenantId, username }, 'New user registration successful');

    return res.status(201).json({ message: 'User registration verified successfully.' });
  } catch (err) {
    next(err);
  }
});

// ==========================================
// UPDATED AUTHENTICATION ENDPOINT
// ==========================================
app.post('/api/auth/login', authLimiter, async (req, res, next) => {
  try {
    const { username, password, tenantId } = req.body;

    if (!tenantId || !username || !password) {
      return res.status(400).json({ error: 'Missing mandatory validation fields.' });
    }

    // Query user constrained strictly inside their declared tenant boundary
    const user = usersDb.find(u => u.username === username && u.tenantId === tenantId);
    if (!user) {
      return res.status(401).json({ error: 'Invalid security credentials.' });
    }

    // Verify password match using timing-attack safe comparison
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid security credentials.' });
    }

    const token = jwt.sign(
      { sub: user.username, tenant_id: user.tenantId, role: user.role },
      JWT_SECRET,
      { expiresIn: '1h', algorithm: 'HS256' }
    );

    req.log.info({ tenantId, username }, 'User login authenticated');
    return res.json({ token });
  } catch (err) {
    next(err);
  }
});

app.use((err, req, res, next) => {
  req.log.error(err);
  res.status(500).json({ error: 'Internal Server Error' });
});

app.listen(PORT, () => {
  console.log(`Gateway executing on port ${PORT}`);
});