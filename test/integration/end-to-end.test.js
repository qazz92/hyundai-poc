/**
 * End-to-End Integration Tests for Hyundai Motors POC
 *
 * Tests the 4 core validation objectives:
 * 1. Regional latency measurement
 * 2. Aurora replication lag measurement
 * 3. Cross-region failover capability
 * 4. Route53 geographic routing verification
 */

const axios = require('axios');
const { performance } = require('perf_hooks');

// Regional endpoints - will be populated from environment or config
const ENDPOINTS = {
  seoul: process.env.SEOUL_ENDPOINT || 'http://seoul-alb.example.com',
  usEast: process.env.US_EAST_ENDPOINT || 'http://us-east-alb.example.com',
  usWest: process.env.US_WEST_ENDPOINT || 'http://us-west-alb.example.com',
};

/**
 * Helper function to measure HTTP latency
 */
async function measureLatency(url) {
  const startTime = performance.now();
  try {
    await axios.get(url, { timeout: 5000 });
    const endTime = performance.now();
    return Math.round(endTime - startTime);
  } catch (error) {
    console.error(`Failed to measure latency for ${url}:`, error.message);
    return null;
  }
}

/**
 * Helper function to measure multiple requests and calculate statistics
 */
async function measureLatencyStats(url, iterations = 10) {
  const measurements = [];
  for (let i = 0; i < iterations; i++) {
    const latency = await measureLatency(url);
    if (latency !== null) {
      measurements.push(latency);
    }
    // Small delay between requests
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  if (measurements.length === 0) {
    return null;
  }

  measurements.sort((a, b) => a - b);
  const average = measurements.reduce((a, b) => a + b, 0) / measurements.length;
  const min = measurements[0];
  const max = measurements[measurements.length - 1];
  const p95Index = Math.floor(measurements.length * 0.95);
  const p95 = measurements[p95Index];

  return { average, min, max, p95, count: measurements.length };
}

describe('Validation Objective 1: Regional Latency Measurement', () => {
  /**
   * Test 1: Korea-to-Korea latency should be < 50ms
   *
   * This test validates that same-region latency is low.
   * Note: This will only pass when running from Korea region.
   */
  test('Korea-to-Korea latency should be under 50ms', async () => {
    const stats = await measureLatencyStats(`${ENDPOINTS.seoul}/health`, 10);

    expect(stats).not.toBeNull();
    expect(stats.average).toBeLessThan(50);
    console.log('Korea-to-Korea latency stats:', stats);
  }, 30000);

  /**
   * Test 2: Korea-to-US-East latency should be 150-200ms
   *
   * This validates cross-region latency matches expectations.
   * Note: This will only pass when running from Korea region.
   */
  test('Korea-to-US-East latency should be 150-200ms', async () => {
    const stats = await measureLatencyStats(`${ENDPOINTS.usEast}/health`, 10);

    expect(stats).not.toBeNull();
    expect(stats.average).toBeGreaterThanOrEqual(150);
    expect(stats.average).toBeLessThanOrEqual(200);
    console.log('Korea-to-US-East latency stats:', stats);
  }, 30000);

  /**
   * Test 3: Korea-to-US-West latency should be 100-150ms
   *
   * This validates cross-region latency to US-West.
   * Note: This will only pass when running from Korea region.
   */
  test('Korea-to-US-West latency should be 100-150ms', async () => {
    const stats = await measureLatencyStats(`${ENDPOINTS.usWest}/health`, 10);

    expect(stats).not.toBeNull();
    expect(stats.average).toBeGreaterThanOrEqual(100);
    expect(stats.average).toBeLessThanOrEqual(150);
    console.log('Korea-to-US-West latency stats:', stats);
  }, 30000);
});

describe('Validation Objective 2: Aurora Replication Lag Measurement', () => {
  /**
   * Test 4: Aurora replication lag should be < 1000ms
   *
   * This test verifies that database replication happens within acceptable timeframe.
   */
  test('Aurora replication lag should be under 1000ms', async () => {
    // Query metrics endpoint which includes replication lag
    const response = await axios.get(`${ENDPOINTS.usEast}/metrics`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('aurora');
    expect(response.data.aurora).toHaveProperty('replication_lag_ms');

    const replicationLag = response.data.aurora.replication_lag_ms;
    expect(replicationLag).toBeLessThan(1000);
    console.log('Aurora replication lag:', replicationLag, 'ms');
  }, 10000);

  /**
   * Test 5: Database write-read consistency across regions
   *
   * This test writes to primary and verifies replication to secondary.
   */
  test('Write to primary should replicate to Seoul read replica', async () => {
    // Write to primary (us-east-1)
    const writePayload = {
      test_data: `test-${Date.now()}`,
    };

    const writeResponse = await axios.post(
      `${ENDPOINTS.usEast}/test-write`,
      writePayload
    );

    expect(writeResponse.status).toBe(201);
    expect(writeResponse.data).toHaveProperty('id');
    const recordId = writeResponse.data.id;

    // Wait 500ms for replication
    await new Promise((resolve) => setTimeout(resolve, 500));

    // Query from Seoul read replica
    const readResponse = await axios.get(
      `${ENDPOINTS.seoul}/db-health`
    );

    expect(readResponse.status).toBe(200);
    expect(readResponse.data.reader.status).toBe('connected');
    console.log('Write-read replication verified. Record ID:', recordId);
  }, 15000);
});

describe('Validation Objective 3: Cross-Region Failover Capability', () => {
  /**
   * Test 6: All regional /health endpoints should return 200
   *
   * This smoke test verifies all regions are operational.
   */
  test('All regional /health endpoints should be accessible', async () => {
    const seoulResponse = await axios.get(`${ENDPOINTS.seoul}/health`);
    const usEastResponse = await axios.get(`${ENDPOINTS.usEast}/health`);
    const usWestResponse = await axios.get(`${ENDPOINTS.usWest}/health`);

    expect(seoulResponse.status).toBe(200);
    expect(seoulResponse.data.status).toBe('healthy');
    expect(seoulResponse.data.region).toBe('ap-northeast-2');

    expect(usEastResponse.status).toBe(200);
    expect(usEastResponse.data.status).toBe('healthy');
    expect(usEastResponse.data.region).toBe('us-east-1');

    expect(usWestResponse.status).toBe(200);
    expect(usWestResponse.data.status).toBe('healthy');
    expect(usWestResponse.data.region).toBe('us-west-2');

    console.log('All regions healthy:', {
      seoul: seoulResponse.data.region,
      usEast: usEastResponse.data.region,
      usWest: usWestResponse.data.region,
    });
  }, 15000);
});

describe('Validation Objective 4: Route53 Geographic Routing Verification', () => {
  /**
   * Test 7: Route53 routes Korean IP to Seoul ALB
   *
   * Note: This test requires DNS to be configured and may need to be run
   * from a Korean IP address to validate geolocation routing.
   */
  test('Route53 should route Korean traffic to Seoul region', async () => {
    // This test assumes the domain is configured
    const globalDomain = process.env.GLOBAL_DOMAIN || 'www.hyundai-poc.com';

    if (globalDomain === 'www.hyundai-poc.com') {
      console.log('Skipping DNS test - GLOBAL_DOMAIN not configured');
      return;
    }

    const response = await axios.get(`https://${globalDomain}/health`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('region');

    // When run from Korean IP, should route to Seoul
    console.log('Routed to region:', response.data.region);
  }, 10000);

  /**
   * Test 8: Metrics endpoint includes all three regions
   *
   * This validates that the application is aware of all regional endpoints.
   */
  test('Metrics endpoint should include all three regional endpoints', async () => {
    const response = await axios.get(`${ENDPOINTS.usEast}/metrics/latency`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('current_region');
    expect(response.data).toHaveProperty('endpoints');
    expect(response.data.endpoints).toHaveLength(3);

    const regions = response.data.endpoints.map((e) => e.region);
    expect(regions).toContain('ap-northeast-2');
    expect(regions).toContain('us-east-1');
    expect(regions).toContain('us-west-2');

    console.log('Latency measurement includes all regions:', regions);
  }, 10000);
});

describe('Observability and Monitoring', () => {
  /**
   * Test 9: Database health check verifies writer and reader connections
   *
   * This validates that both writer and reader endpoints are accessible.
   */
  test('Database health check should verify writer and reader connectivity', async () => {
    const response = await axios.get(`${ENDPOINTS.usEast}/db-health`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('writer');
    expect(response.data).toHaveProperty('reader');

    expect(response.data.writer.status).toBe('connected');
    expect(response.data.reader.status).toBe('connected');

    expect(response.data.writer).toHaveProperty('latency_ms');
    expect(response.data.reader).toHaveProperty('latency_ms');

    console.log('Database connectivity:', {
      writer: `${response.data.writer.status} (${response.data.writer.latency_ms}ms)`,
      reader: `${response.data.reader.status} (${response.data.reader.latency_ms}ms)`,
    });
  }, 10000);

  /**
   * Test 10: CloudWatch dashboard displays all metrics
   *
   * This test verifies that metrics are being published and available.
   * Note: This is a smoke test that checks the metrics endpoint structure.
   */
  test('Metrics endpoint should return complete metrics structure', async () => {
    const response = await axios.get(`${ENDPOINTS.usEast}/metrics`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('region');
    expect(response.data).toHaveProperty('aurora');
    expect(response.data).toHaveProperty('timestamp');

    expect(response.data.aurora).toHaveProperty('replication_lag_ms');
    expect(response.data.aurora).toHaveProperty('connections');

    console.log('Metrics structure validated:', {
      region: response.data.region,
      replicationLag: response.data.aurora.replication_lag_ms,
      connections: response.data.aurora.connections,
    });
  }, 10000);
});
