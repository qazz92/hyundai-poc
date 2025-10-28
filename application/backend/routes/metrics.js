const express = require('express');
const router = express.Router();
const AWS = require('aws-sdk');
const { getReaderPool } = require('../db/connection');
const https = require('https');
const http = require('http');

// Initialize CloudWatch client
const cloudwatch = new AWS.CloudWatch({
  region: process.env.AWS_REGION || 'us-east-1',
});

/**
 * GET /metrics
 * Returns Aurora replication lag and ECS metrics from CloudWatch
 */
router.get('/', async (req, res, next) => {
  try {
    const region = process.env.AWS_REGION || 'us-east-1';

    // Fetch Aurora replication lag from CloudWatch
    const auroraLag = await getAuroraReplicationLag();

    // Get database connection count
    const connectionCount = await getDatabaseConnections();

    const response = {
      region,
      aurora: {
        replication_lag_ms: auroraLag,
        connections: connectionCount,
      },
      ecs: {
        task_count: 2, // Static for POC (2 tasks per service)
        cpu_utilization: null, // Could be fetched from CloudWatch if needed
        memory_utilization: null, // Could be fetched from CloudWatch if needed
      },
      timestamp: new Date().toISOString(),
    };

    res.status(200).json(response);
  } catch (error) {
    console.error('Error fetching metrics:', error);
    next(error);
  }
});

/**
 * GET /metrics/latency
 * Measures HTTP latency to peer regional endpoints
 */
router.get('/latency', async (req, res, next) => {
  try {
    const currentRegion = process.env.AWS_REGION || 'us-east-1';

    // Regional endpoint URLs from environment
    const endpoints = [
      {
        region: 'ap-northeast-2',
        url: process.env.ALB_SEOUL_URL || 'http://seoul-alb.example.com/health',
      },
      {
        region: 'us-east-1',
        url: process.env.ALB_US_EAST_URL || 'http://us-east-alb.example.com/health',
      },
      {
        region: 'us-west-2',
        url: process.env.ALB_US_WEST_URL || 'http://us-west-alb.example.com/health',
      },
    ];

    // Measure latency to each endpoint
    const latencyResults = await Promise.all(
      endpoints.map(async (endpoint) => {
        const latency = await measureHttpLatency(endpoint.url);
        return {
          region: endpoint.region,
          url: endpoint.url,
          latency_ms: latency,
        };
      })
    );

    res.status(200).json({
      current_region: currentRegion,
      endpoints: latencyResults,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error measuring latency:', error);
    next(error);
  }
});

/**
 * Fetch Aurora replication lag from CloudWatch
 * @returns {Promise<number|null>} Replication lag in milliseconds
 */
async function getAuroraReplicationLag() {
  try {
    // Extract cluster identifier from DB_READER_HOST
    const dbReaderHost = process.env.DB_READER_HOST || '';
    const clusterMatch = dbReaderHost.match(/^([\w-]+)\.cluster/);

    if (!clusterMatch) {
      console.error('Could not extract cluster identifier from DB_READER_HOST:', dbReaderHost);
      return null;
    }

    const clusterIdentifier = clusterMatch[1];

    const params = {
      MetricName: 'AuroraGlobalDBReplicationLag',
      Namespace: 'AWS/RDS',
      Dimensions: [
        {
          Name: 'DBClusterIdentifier',
          Value: clusterIdentifier,
        },
      ],
      StartTime: new Date(Date.now() - 5 * 60 * 1000), // 5 minutes ago
      EndTime: new Date(),
      Period: 60,
      Statistics: ['Average'],
    };

    const result = await cloudwatch.getMetricStatistics(params).promise();

    if (result.Datapoints && result.Datapoints.length > 0) {
      // Sort by timestamp and get most recent
      const sortedDatapoints = result.Datapoints.sort(
        (a, b) => b.Timestamp - a.Timestamp
      );
      return Math.round(sortedDatapoints[0].Average);
    }

    return null;
  } catch (error) {
    console.error('Error fetching Aurora replication lag:', error);
    return null;
  }
}

/**
 * Get current database connection count
 * @returns {Promise<number>} Number of active connections
 */
async function getDatabaseConnections() {
  try {
    const pool = getReaderPool();
    const [rows] = await pool.query('SHOW STATUS LIKE "Threads_connected"');

    if (rows && rows.length > 0) {
      return parseInt(rows[0].Value, 10);
    }

    return 0;
  } catch (error) {
    console.error('Error fetching database connections:', error);
    return 0;
  }
}

/**
 * Measure HTTP latency to a given URL
 * @param {string} url - URL to measure latency
 * @returns {Promise<number|null>} Latency in milliseconds
 */
function measureHttpLatency(url) {
  return new Promise((resolve) => {
    const startTime = process.hrtime.bigint();
    const protocol = url.startsWith('https') ? https : http;

    const req = protocol.get(url, { timeout: 5000 }, (res) => {
      // Consume response data to complete request
      res.on('data', () => {});
      res.on('end', () => {
        const endTime = process.hrtime.bigint();
        const latencyMs = Number(endTime - startTime) / 1_000_000;
        resolve(Math.round(latencyMs));
      });
    });

    req.on('error', (error) => {
      console.error(`Error measuring latency to ${url}:`, error.message);
      resolve(null);
    });

    req.on('timeout', () => {
      console.error(`Timeout measuring latency to ${url}`);
      req.destroy();
      resolve(null);
    });
  });
}

module.exports = router;
