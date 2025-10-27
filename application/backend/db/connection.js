const mysql = require('mysql2/promise');

// Connection pools for writer and reader endpoints
let writerPool = null;
let readerPool = null;

/**
 * Initialize database connection pools
 */
function initializePools() {
  const commonConfig = {
    host: process.env.DB_WRITER_HOST,
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
  };

  // Writer pool (primary database)
  writerPool = mysql.createPool({
    ...commonConfig,
    host: process.env.DB_WRITER_HOST,
  });

  // Reader pool (read replica or same as writer if not configured)
  readerPool = mysql.createPool({
    ...commonConfig,
    host: process.env.DB_READER_HOST || process.env.DB_WRITER_HOST,
  });

  console.log('Database connection pools initialized');
}

/**
 * Get writer connection pool
 */
function getWriterPool() {
  if (!writerPool) {
    initializePools();
  }
  return writerPool;
}

/**
 * Get reader connection pool
 */
function getReaderPool() {
  if (!readerPool) {
    initializePools();
  }
  return readerPool;
}

/**
 * Test database connection and measure latency
 * @param {Object} pool - MySQL connection pool
 * @returns {Promise<Object>} Connection status and latency
 */
async function testConnection(pool) {
  const startTime = process.hrtime.bigint();

  try {
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();

    const endTime = process.hrtime.bigint();
    const latencyMs = Number(endTime - startTime) / 1_000_000; // Convert nanoseconds to milliseconds

    return {
      status: 'connected',
      latency_ms: Math.round(latencyMs * 100) / 100, // Round to 2 decimal places
    };
  } catch (error) {
    console.error('Database connection test failed:', error.message);
    return {
      status: 'error',
      error: error.message,
      latency_ms: null,
    };
  }
}

/**
 * Close all database connections
 */
async function closeConnections() {
  try {
    if (writerPool) {
      await writerPool.end();
      console.log('Writer pool closed');
    }
    if (readerPool) {
      await readerPool.end();
      console.log('Reader pool closed');
    }
  } catch (error) {
    console.error('Error closing database connections:', error);
  }
}

// Handle process termination
process.on('SIGTERM', closeConnections);
process.on('SIGINT', closeConnections);

module.exports = {
  getWriterPool,
  getReaderPool,
  testConnection,
  closeConnections,
};
