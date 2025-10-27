const request = require('supertest');
const app = require('../server');

describe('Health Endpoints', () => {
  /**
   * Test: GET /health returns 200 with region info
   */
  test('GET /health should return 200 with status and region', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status', 'healthy');
    expect(response.body).toHaveProperty('region');
    expect(response.body).toHaveProperty('timestamp');
  });

  /**
   * Test: GET /health response includes valid timestamp
   */
  test('GET /health should return valid ISO timestamp', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);

    const timestamp = new Date(response.body.timestamp);
    expect(timestamp).toBeInstanceOf(Date);
    expect(isNaN(timestamp.getTime())).toBe(false);
  });

  /**
   * Test: GET /health includes region from environment
   */
  test('GET /health should include AWS region', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(typeof response.body.region).toBe('string');
    expect(response.body.region.length).toBeGreaterThan(0);
  });
});
