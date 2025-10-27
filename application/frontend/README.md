# Frontend Dashboard - Hyundai Motors POC

Next.js 14+ dashboard for Hyundai Motors Infrastructure POC. Displays real-time metrics including regional health status, cross-region latency measurements, and Aurora replication lag.

## Features

- **Region Indicator**: Shows current AWS region serving the request
- **Health Status**: Real-time health checks for all 3 regional endpoints
- **Latency Table**: Client-side latency measurement to Seoul, US-East, and US-West
- **Replication Lag Gauge**: Visual gauge showing Aurora Global Database replication lag
- **Auto-Refresh**: All metrics refresh automatically every 5 seconds
- **Responsive Design**: Works on desktop and mobile devices
- **Hyundai Branding**: Uses Hyundai blue color scheme (#002C5F)

## Components

### RegionIndicator
Displays the current serving region with flag icon and region name.

**Props:**
- `region: string` - AWS region code (e.g., 'ap-northeast-2')

### LatencyTable
Measures and displays HTTP latency to all 3 regional health endpoints using the browser's Performance API.

**Features:**
- Color-coded latency (green < 100ms, yellow 100-200ms, red > 200ms)
- Auto-refresh every 5 seconds
- Shows online/offline status for each region

### ReplicationLagGauge
Fetches Aurora replication lag from the `/metrics` endpoint and displays it as a circular gauge.

**Color Coding:**
- Green: < 500ms (Excellent)
- Yellow: 500-1000ms (Good)
- Red: > 1000ms (High)

**Additional Info:**
- Database connection count
- Last updated timestamp
- Status thresholds legend

### HealthStatus
Polls the `/health` endpoint for each region and displays green/red status indicators.

**Features:**
- Real-time health check
- Auto-refresh every 5 seconds
- Visual status indicators (green = healthy, red = unhealthy)

## Environment Variables

Create a `.env.local` file based on `.env.example`:

```bash
# Backend API URL
NEXT_PUBLIC_API_URL=http://localhost:3001

# Regional ALB URLs for latency measurement
NEXT_PUBLIC_ALB_SEOUL_URL=http://seoul-alb.example.com/health
NEXT_PUBLIC_ALB_US_EAST_URL=http://us-east-alb.example.com/health
NEXT_PUBLIC_ALB_US_WEST_URL=http://us-west-alb.example.com/health
```

## Development

### Install Dependencies
```bash
npm install
```

### Run Development Server
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the dashboard.

### Build for Production
```bash
npm run build
```

### Start Production Server
```bash
npm start
```

### Run Tests
```bash
npm test
```

## Docker

### Build Image
```bash
docker build -t hyundai-poc-frontend:latest .
```

### Run Container
```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://backend-api:3001 \
  hyundai-poc-frontend:latest
```

## Technology Stack

- **Next.js 14+** - React framework with App Router
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS** - Utility-first CSS framework
- **React 18** - UI library
- **Jest** - Testing framework
- **Testing Library** - React component testing

## Styling

The dashboard uses Tailwind CSS with custom Hyundai brand colors:

- **Primary Blue**: #002C5F (`bg-hyundai-blue`)
- **Light Blue**: #00AAD2 (`bg-hyundai-lightblue`)
- **Gray**: #58595B (`text-hyundai-gray`)

## Performance

- **Server-Side Rendering (SSR)**: Initial page load with region detection
- **Client-Side Polling**: Metrics update every 5 seconds using React hooks
- **Performance API**: Accurate latency measurement using browser's native API
- **Optimized Build**: Multi-stage Docker build for minimal image size

## Browser Compatibility

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Latency Measurement

The LatencyTable component uses the browser's Performance API to measure round-trip time:

```typescript
const startTime = performance.now()
await fetch(url)
const endTime = performance.now()
const latencyMs = Math.round(endTime - startTime)
```

This provides accurate client-side latency measurements from the user's location to each regional endpoint.

## Auto-Refresh

All components use React's `useEffect` hook with `setInterval` to automatically refresh data:

```typescript
useEffect(() => {
  fetchData()
  const interval = setInterval(fetchData, 5000)
  return () => clearInterval(interval)
}, [])
```

Cleanup is handled automatically when components unmount.
