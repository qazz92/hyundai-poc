'use client'

import { useState, useEffect } from 'react'

interface HealthData {
  region: string
  status: 'healthy' | 'unhealthy' | 'unknown'
  timestamp: string
}

interface RegionConfig {
  name: string
  code: string
  healthUrl: string
}

const regions: RegionConfig[] = [
  {
    name: 'Seoul',
    code: 'ap-northeast-2',
    healthUrl: process.env.NEXT_PUBLIC_ALB_SEOUL_URL || 'http://localhost:3001/health',
  },
  {
    name: 'US East',
    code: 'us-east-1',
    healthUrl: process.env.NEXT_PUBLIC_ALB_US_EAST_URL || 'http://localhost:3001/health',
  },
  {
    name: 'US West',
    code: 'us-west-2',
    healthUrl: process.env.NEXT_PUBLIC_ALB_US_WEST_URL || 'http://localhost:3001/health',
  },
]

export default function HealthStatus() {
  const [healthData, setHealthData] = useState<Record<string, HealthData>>({})
  const [loading, setLoading] = useState(true)

  // Check health for a single region
  const checkHealth = async (region: RegionConfig): Promise<HealthData> => {
    try {
      const response = await fetch(region.healthUrl, {
        method: 'GET',
        cache: 'no-store',
      })

      if (response.ok) {
        const data = await response.json()
        return {
          region: region.code,
          status: 'healthy',
          timestamp: data.timestamp || new Date().toISOString(),
        }
      } else {
        return {
          region: region.code,
          status: 'unhealthy',
          timestamp: new Date().toISOString(),
        }
      }
    } catch (error) {
      console.error(`Error checking health for ${region.name}:`, error)
      return {
        region: region.code,
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
      }
    }
  }

  // Check health for all regions
  const checkAllHealth = async () => {
    setLoading(true)

    const results = await Promise.all(regions.map((region) => checkHealth(region)))

    const healthMap: Record<string, HealthData> = {}
    results.forEach((result) => {
      healthMap[result.region] = result
    })

    setHealthData(healthMap)
    setLoading(false)
  }

  // Initial check and auto-refresh every 5 seconds
  useEffect(() => {
    checkAllHealth()

    const interval = setInterval(() => {
      checkAllHealth()
    }, 5000)

    return () => clearInterval(interval)
  }, [])

  return (
    <div className="space-y-4">
      {loading && Object.keys(healthData).length === 0 ? (
        <p className="text-center text-gray-500 py-4">Checking health status...</p>
      ) : (
        regions.map((region) => {
          const health = healthData[region.code]
          const isHealthy = health?.status === 'healthy'

          return (
            <div
              key={region.code}
              className={`flex items-center justify-between p-4 rounded-lg border-2 ${
                isHealthy
                  ? 'bg-green-50 border-green-200'
                  : 'bg-red-50 border-red-200'
              }`}
            >
              <div className="flex items-center gap-3">
                {/* Status Icon */}
                <div
                  className={`w-4 h-4 rounded-full ${
                    isHealthy ? 'bg-green-500' : 'bg-red-500'
                  }`}
                ></div>

                {/* Region Info */}
                <div>
                  <p className="font-semibold text-gray-900">{region.name}</p>
                  <p className="text-xs text-gray-500">{region.code}</p>
                </div>
              </div>

              {/* Status Badge */}
              <div className="text-right">
                {isHealthy ? (
                  <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                    ✓ Healthy
                  </span>
                ) : (
                  <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800">
                    ✗ Unhealthy
                  </span>
                )}
                {health?.timestamp && (
                  <p className="text-xs text-gray-500 mt-1">
                    {new Date(health.timestamp).toLocaleTimeString()}
                  </p>
                )}
              </div>
            </div>
          )
        })
      )}
    </div>
  )
}
