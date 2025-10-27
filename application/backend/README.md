# Backend API - Hyundai Motors POC

Node.js Express API for Hyundai Motors Infrastructure POC. Provides health checks, database connectivity monitoring, Aurora replication lag metrics, and cross-region latency measurement.

## Endpoints

### GET /health
Basic health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "region": "us-east-1",
  "timestamp": "2025-10-27T10:30:00Z"
}
```

### GET /db-health
Database connectivity health check. Tests both writer and reader connections.

**Response:**
```json
{
  "writer": {
    "endpoint": "marketing-cluster.cluster-xxx.us-east-1.rds.amazonaws.com",
    "status": "connected",
    "latency_ms": 12
  },
  "reader": {
    "endpoint": "marketing-cluster.cluster-ro-xxx.us-east-1.rds.amazonaws.com",
    "status": "connected",
    "latency_ms": 8
  }
}
```

### GET /metrics
Returns Aurora replication lag and database metrics.

**Response:**
```json
{
  "region": "us-east-1",
  "aurora": {
    "replication_lag_ms": 850,
    "connections": 12
  },
  "ecs": {
    "task_count": 2,
    "cpu_utilization": null,
    "memory_utilization": null
  },
  "timestamp": "2025-10-27T10:30:00Z"
}
```

### GET /metrics/latency
Measures HTTP latency to peer regional endpoints.

**Response:**
```json
{
  "current_region": "us-east-1",
  "endpoints": [
    {
      "region": "ap-northeast-2",
      "url": "https://seoul.hyundai-poc.com/health",
      "latency_ms": 180
    },
    {
      "region": "us-east-1",
      "url": "https://us-east.hyundai-poc.com/health",
      "latency_ms": 5
    },
    {
      "region": "us-west-2",
      "url": "https://us-west.hyundai-poc.com/health",
      "latency_ms": 75
    }
  ],
  "timestamp": "2025-10-27T10:30:00Z"
}
```

### POST /test-write
Writes a test record to primary database and measures replication lag.

**Request:**
```json
{
  "test_data": "sample"
}
```

**Response:**
```json
{
  "id": 12345,
  "timestamp": "2025-10-27T10:30:00Z",
  "message": "Write successful to primary database",
  "replication": {
    "found_in_replica": true,
    "lag_ms": 450,
    "max_wait_ms": 1000
  },
  "test_data": "sample"
}
```

## Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# AWS Configuration
AWS_REGION=us-east-1

# Database Configuration
DB_WRITER_HOST=your-writer-endpoint.rds.amazonaws.com
DB_READER_HOST=your-reader-endpoint.rds.amazonaws.com
DB_PORT=3306
DB_NAME=hyundai_poc
DB_USER=admin
DB_PASSWORD=your-password

# Application Configuration
PORT=3001
LOG_LEVEL=info

# Regional Endpoints
ALB_SEOUL_URL=http://seoul-alb.example.com/health
ALB_US_EAST_URL=http://us-east-alb.example.com/health
ALB_US_WEST_URL=http://us-west-alb.example.com/health
```

## Development

### Install Dependencies
```bash
npm install
```

### Run Locally
```bash
npm start
```

### Run with Watch Mode
```bash
npm run dev
```

### Run Tests
```bash
npm test
```

## Docker

### Build Image
```bash
docker build -t hyundai-poc-backend:latest .
```

### Run Container
```bash
docker run -p 3001:3001 --env-file .env hyundai-poc-backend:latest
```

## Architecture

- **Express.js** - Web framework
- **mysql2** - MySQL database driver with connection pooling
- **aws-sdk** - AWS CloudWatch metrics
- **cors** - Cross-origin resource sharing
- **dotenv** - Environment variable management

## Connection Pooling

The application maintains two connection pools:
- **Writer Pool** - Connected to primary Aurora cluster (us-east-1)
- **Reader Pool** - Connected to local read replica

Connection pool size: 5 connections per pool (adequate for POC load)

## Error Handling

Centralized error handling middleware catches all errors and returns consistent error responses:

```json
{
  "status": "error",
  "message": "Error description",
  "timestamp": "2025-10-27T10:30:00Z"
}
```

## Logging

Request logging middleware logs all incoming requests with:
- Timestamp
- HTTP method
- Path
- Status code
- Response time

Configure log level with `LOG_LEVEL` environment variable (info, debug, error).
