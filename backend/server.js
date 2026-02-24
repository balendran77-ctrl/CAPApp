const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const DB_RETRY_DELAY_MS = 10000;
let dbReconnectTimer = null;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ limit: '50mb', extended: true }));

const connectToDatabase = async () => {
  if (!process.env.MONGODB_URI) {
    throw new Error('MONGODB_URI is missing in backend/.env');
  }

  if (mongoose.connection.readyState === 1 || mongoose.connection.readyState === 2) {
    return;
  }

  mongoose.set('bufferCommands', false);

  await mongoose.connect(process.env.MONGODB_URI, {
    serverSelectionTimeoutMS: 10000,
    socketTimeoutMS: 45000,
    family: 4,
  });

  console.log('✓ MongoDB connected');
};

const scheduleReconnect = () => {
  if (dbReconnectTimer) {
    return;
  }

  dbReconnectTimer = setTimeout(async () => {
    dbReconnectTimer = null;
    try {
      await connectToDatabase();
    } catch (err) {
      console.error('MongoDB reconnect failed:', err.message);
      scheduleReconnect();
    }
  }, DB_RETRY_DELAY_MS);
};

mongoose.connection.on('error', (err) => {
  console.error('MongoDB runtime error:', err.message);
});

mongoose.connection.on('disconnected', () => {
  console.warn('MongoDB disconnected');
  scheduleReconnect();
});

const getDatabaseStatus = () => {
  const readyStates = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };

  return readyStates[mongoose.connection.readyState] || 'unknown';
};

// Health check endpoint
app.get('/api/health', (req, res) => {
  const dbStatus = getDatabaseStatus();
  const statusCode = dbStatus === 'connected' ? 200 : 503;

  res.status(statusCode).json({
    status: 'Server is running',
    database: dbStatus,
    timestamp: new Date(),
  });
});

// Reject API calls when DB is unavailable
app.use('/api', (req, res, next) => {
  if (req.path === '/health') {
    return next();
  }

  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      error: 'Database is not connected. Please try again shortly.',
    });
  }

  return next();
});

// Routes
app.use('/api/users', require('./routes/userRoutes'));
app.use('/api/items', require('./routes/itemRoutes'));

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
  });
});

// Start server and keep trying DB until available
const startServer = async () => {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });

  try {
    await connectToDatabase();
  } catch (err) {
    console.error('Initial MongoDB connection failed:', err.message);
    scheduleReconnect();
  }
};

startServer();
