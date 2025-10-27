-- Hyundai Motors POC - Database Initialization Script
-- Creates health_checks table and seed data

-- Create health_checks table
CREATE TABLE IF NOT EXISTS health_checks (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  region VARCHAR(20) NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  replication_lag_ms INT,
  INDEX idx_timestamp (timestamp),
  INDEX idx_region (region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert seed data for each region
INSERT INTO health_checks (region, replication_lag_ms) VALUES
  ('ap-northeast-2', 0),
  ('us-east-1', 0),
  ('us-west-2', 0);

-- Verify table creation
SELECT COUNT(*) as total_records FROM health_checks;

-- Show table structure
DESCRIBE health_checks;
