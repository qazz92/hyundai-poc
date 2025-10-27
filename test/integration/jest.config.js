/**
 * Jest configuration for integration tests
 */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/*.test.js'],
  testTimeout: 30000,
  verbose: true,
  collectCoverage: false,
  coveragePathIgnorePatterns: ['/node_modules/'],
};
