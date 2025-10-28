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
}

const regions: RegionInfo[] = [
  {
    name: 'Seoul',
    code: 'ap-northeast-2',
  },
  {
    name: 'US East',
    code: 'us-east-1',
  },
  {
    name: 'US West',
    code: 'us-west-2',
  },
]

export default function LatencyTable() {
  const [latencies, setLatencies] = useState<LatencyResult[]>([])
  const [loading, setLoading] = useState(true)
  const [currentRegion, setCurrentRegion] = useState<string>('unknown')

  // Measure latency via backend API (server-to-server measurement)
  const measureAllLatencies = async () => {
    setLoading(true)

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001'
      const response = await fetch(`${apiUrl}/metrics/latency`, { cache: 'no-store' })
      const data = await response.json()

      setCurrentRegion(data.current_region || 'unknown')

      // Map backend response to our format
      const results: LatencyResult[] = data.endpoints.map((endpoint: any) => ({
        region: endpoint.region,
        url: endpoint.url,
        latency_ms: endpoint.latency_ms,
      }))

      setLatencies(results)
    } catch (error) {
      console.error('Error fetching latency metrics:', error)
      // Set error state for all regions
      setLatencies(
        regions.map((region) => ({
          region: region.code,
          url: 'error',
          latency_ms: null,
        }))
      )
    } finally {
      setLoading(false)
    }
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
