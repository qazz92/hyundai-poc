module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'routes/**/*.js',
    'db/**/*.js',
    'middleware/**/*.js',
  ],
  testMatch: ['**/test/**/*.test.js'],
  testTimeout: 10000,
};
