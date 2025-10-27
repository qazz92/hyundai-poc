const express = require('express');
const router = express.Router();
const { getWriterPool, getReaderPool, testConnection } = require('../db/connection');

/**
 * GET /health
 * Basic health check endpoint
 * Returns application status, region, and timestamp
 */
router.get('/', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    region: process.env.AWS_REGION || 'unknown',
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /db-health
 * Database connectivity health check
 * Tests both writer and reader connections and measures latency
 */
router.get('/', async (req, res, next) => {
  try {
    const writerPool = getWriterPool();
    const readerPool = getReaderPool();

    // Test both connections in parallel
    const [writerStatus, readerStatus] = await Promise.all([
      testConnection(writerPool),
      testConnection(readerPool),
    ]);

    // Determine overall status
    const isHealthy = writerStatus.status === 'connected' && readerStatus.status === 'connected';

    const response = {
      writer: {
        endpoint: process.env.DB_WRITER_HOST,
        status: writerStatus.status,
        latency_ms: writerStatus.latency_ms,
      },
      reader: {
        endpoint: process.env.DB_READER_HOST || process.env.DB_WRITER_HOST,
        status: readerStatus.status,
        latency_ms: readerStatus.latency_ms,
      },
    };

    // Return 200 if both are connected, 503 if either fails
    res.status(isHealthy ? 200 : 503).json(response);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
