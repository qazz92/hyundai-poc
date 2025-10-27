/**
 * Request logging middleware
 * Logs incoming requests with timestamp and duration
 */
function requestLogger(req, res, next) {
  const startTime = Date.now();

  // Log request details
  const logLevel = process.env.LOG_LEVEL || 'info';

  if (logLevel === 'info' || logLevel === 'debug') {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  }

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    if (logLevel === 'info' || logLevel === 'debug') {
      console.log(
        `[${new Date().toISOString()}] ${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`
      );
    }
  });

  next();
}

module.exports = { requestLogger };
