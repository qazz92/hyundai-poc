'use client'

import { useState, useEffect } from 'react'

interface LatencyResult {
  region: string
  url: string
  latency_ms: number | null
}

interface RegionInfo {
  name: string
  code: string
  healthUrl: string
}

const regions: RegionInfo[] = [
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

export default function LatencyTable() {
  const [latencies, setLatencies] = useState<LatencyResult[]>([])
  const [loading, setLoading] = useState(true)

  // Measure latency to a given URL
  const measureLatency = async (url: string, region: string): Promise<LatencyResult> => {
    const startTime = performance.now()

    try {
      await fetch(url, { method: 'GET', cache: 'no-store' })
      const endTime = performance.now()
      const latencyMs = Math.round(endTime - startTime)

      return {
        region,
        url,
        latency_ms: latencyMs,
      }
    } catch (error) {
      console.error(`Error measuring latency to ${region}:`, error)
      return {
        region,
        url,
        latency_ms: null,
      }
    }
  }

  // Measure latency to all regions
  const measureAllLatencies = async () => {
    setLoading(true)

    const results = await Promise.all(
      regions.map((region) => measureLatency(region.healthUrl, region.code))
    )

    setLatencies(results)
    setLoading(false)
  }

  // Initial measurement and auto-refresh every 5 seconds
  useEffect(() => {
    measureAllLatencies()

    const interval = setInterval(() => {
      measureAllLatencies()
    }, 5000)

    return () => clearInterval(interval)
  }, [])

  // Color coding based on latency
  const getLatencyColor = (latency: number | null): string => {
    if (latency === null) return 'text-gray-500'
    if (latency < 100) return 'text-green-600'
    if (latency < 200) return 'text-yellow-600'
    return 'text-red-600'
  }

  const getLatencyBgColor = (latency: number | null): string => {
    if (latency === null) return 'bg-gray-100'
    if (latency < 100) return 'bg-green-50'
    if (latency < 200) return 'bg-yellow-50'
    return 'bg-red-50'
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Region
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Region Code
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Endpoint
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
              Latency (ms)
            </th>
            <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
              Status
            </th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {loading && latencies.length === 0 ? (
            <tr>
              <td colSpan={5} className="px-6 py-4 text-center text-gray-500">
                Measuring latency...
              </td>
            </tr>
          ) : (
            regions.map((region, index) => {
              const result = latencies.find((l) => l.region === region.code)
              const latency = result?.latency_ms ?? null

              return (
                <tr key={region.code} className={getLatencyBgColor(latency)}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {region.name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {region.code}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 truncate max-w-xs">
                    {region.healthUrl}
                  </td>
                  <td
                    className={`px-6 py-4 whitespace-nowrap text-sm font-bold text-right ${getLatencyColor(
                      latency
                    )}`}
                  >
                    {latency !== null ? `${latency} ms` : 'Error'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-center">
                    {latency !== null ? (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        ✓ Online
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                        ✗ Offline
                      </span>
                    )}
                  </td>
                </tr>
              )
            })
          )}
        </tbody>
      </table>
    </div>
  )
}
