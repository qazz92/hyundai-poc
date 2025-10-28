# Multi-stage build for Next.js frontend

# Stage 1: Build the application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source files
COPY . .

# Build arguments for Next.js environment variables
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_ALB_SEOUL_URL
ARG NEXT_PUBLIC_ALB_US_EAST_URL
ARG NEXT_PUBLIC_ALB_US_WEST_URL
ARG NEXT_PUBLIC_DOMAIN
ARG NEXT_PUBLIC_API_DOMAIN

# Set as environment variables for Next.js build
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_ALB_SEOUL_URL=${NEXT_PUBLIC_ALB_SEOUL_URL}
ENV NEXT_PUBLIC_ALB_US_EAST_URL=${NEXT_PUBLIC_ALB_US_EAST_URL}
ENV NEXT_PUBLIC_ALB_US_WEST_URL=${NEXT_PUBLIC_ALB_US_WEST_URL}
ENV NEXT_PUBLIC_DOMAIN=${NEXT_PUBLIC_DOMAIN}
ENV NEXT_PUBLIC_API_DOMAIN=${NEXT_PUBLIC_API_DOMAIN}

# Build Next.js application
RUN npm run build

# Stage 2: Production runtime
FROM node:20-alpine AS runner

WORKDIR /app

# Set environment to production
ENV NODE_ENV production

# Copy necessary files from builder
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "server.js"]
