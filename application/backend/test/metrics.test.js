const request = require('supertest');
const app = require('../server');

describe('Metrics Endpoints', () => {
  /**
   * Test: GET /metrics returns replication lag data
   */
  test('GET /metrics should return Aurora metrics structure', async () => {
    const response = await request(app).get('/metrics');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('region');
    expect(response.body).toHaveProperty('aurora');
    expect(response.body.aurora).toHaveProperty('replication_lag_ms');
    expect(response.body.aurora).toHaveProperty('connections');
    expect(response.body).toHaveProperty('timestamp');
  });

  /**
   * Test: GET /metrics/latency returns cross-region latency
   */
  test('GET /metrics/latency should return latency measurements', async () => {
    const response = await request(app).get('/metrics/latency');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('current_region');
    expect(response.body).toHaveProperty('endpoints');
    expect(Array.isArray(response.body.endpoints)).toBe(true);
    expect(response.body.endpoints.length).toBe(3);
  });

  /**
   * Test: GET /metrics/latency includes all three regions
   */
  test('GET /metrics/latency should include Seoul, US-East, US-West', async () => {
    const response = await request(app).get('/metrics/latency');

    expect(response.status).toBe(200);

    const regions = response.body.endpoints.map((e) => e.region);
    expect(regions).toContain('ap-northeast-2');
    expect(regions).toContain('us-east-1');
    expect(regions).toContain('us-west-2');
  });

  /**
   * Test: GET /metrics/latency includes URL for each endpoint
   */
  test('GET /metrics/latency should include URL for each endpoint', async () => {
    const response = await request(app).get('/metrics/latency');

    expect(response.status).toBe(200);

    response.body.endpoints.forEach((endpoint) => {
      expect(endpoint).toHaveProperty('region');
      expect(endpoint).toHaveProperty('url');
      expect(endpoint).toHaveProperty('latency_ms');
    });
  });
});
