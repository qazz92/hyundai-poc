const express = require('express');
const router = express.Router();
const { getWriterPool, getReaderPool } = require('../db/connection');

/**
 * POST /test-write
 * Writes a test record to the primary database and measures replication lag
 * This endpoint demonstrates Aurora Global Database replication
 */
router.post('/', async (req, res, next) => {
  try {
    const region = process.env.AWS_REGION || 'unknown';
    const testData = req.body.test_data || 'sample';

    const writerPool = getWriterPool();
    const readerPool = getReaderPool();

    // Step 1: Write to primary database
    const writeTimestamp = new Date();
    const [writeResult] = await writerPool.query(
      'INSERT INTO health_checks (region, timestamp) VALUES (?, ?)',
      [region, writeTimestamp]
    );

    const insertedId = writeResult.insertId;

    // Step 2: Attempt to read from replica with retry logic
    let replicationLagMs = null;
    let found = false;
    const maxRetries = 10;
    const retryDelayMs = 100;

    for (let i = 0; i < maxRetries; i++) {
      // Wait before checking
      if (i > 0) {
        await sleep(retryDelayMs);
      }

      // Try to read from replica
      const [rows] = await readerPool.query(
        'SELECT * FROM health_checks WHERE id = ?',
        [insertedId]
      );

      if (rows && rows.length > 0) {
        // Record found in replica
        const readTimestamp = new Date();
        replicationLagMs = readTimestamp - writeTimestamp;
        found = true;
        break;
      }
    }

    // Step 3: Return results
    const response = {
      id: insertedId,
      timestamp: writeTimestamp.toISOString(),
      message: 'Write successful to primary database',
      replication: {
        found_in_replica: found,
        lag_ms: replicationLagMs,
        max_wait_ms: maxRetries * retryDelayMs,
      },
      test_data: testData,
    };

    res.status(201).json(response);
  } catch (error) {
    console.error('Error in test-write:', error);
    next(error);
  }
});

/**
 * Helper function to sleep for specified milliseconds
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = router;
