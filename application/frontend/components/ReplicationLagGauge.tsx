'use client'

import { useState, useEffect } from 'react'

interface MetricsData {
  region: string
  aurora: {
    replication_lag_ms: number | null
    connections: number
  }
  timestamp: string
}

export default function ReplicationLagGauge() {
  const [metrics, setMetrics] = useState<MetricsData | null>(null)
  const [loading, setLoading] = useState(true)

  // Fetch metrics from API
  const fetchMetrics = async () => {
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001'
      const response = await fetch(`${apiUrl}/metrics`, { cache: 'no-store' })
      const data = await response.json()
      setMetrics(data)
      setLoading(false)
    } catch (error) {
      console.error('Error fetching metrics:', error)
      setLoading(false)
    }
  }

  // Initial fetch and auto-refresh every 5 seconds
  useEffect(() => {
    fetchMetrics()

    const interval = setInterval(() => {
      fetchMetrics()
    }, 5000)

    return () => clearInterval(interval)
  }, [])

  // Determine lag status and color
  const getLagStatus = (lag: number | null): { status: string; color: string; bgColor: string } => {
    if (lag === null) {
      return { status: 'Unknown', color: 'text-gray-600', bgColor: 'bg-gray-200' }
    }
    if (lag < 500) {
      return { status: 'Excellent', color: 'text-green-600', bgColor: 'bg-green-500' }
    }
    if (lag < 1000) {
      return { status: 'Good', color: 'text-yellow-600', bgColor: 'bg-yellow-500' }
    }
    return { status: 'High', color: 'text-red-600', bgColor: 'bg-red-500' }
  }

  if (loading) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-500">Loading replication metrics...</p>
      </div>
    )
  }

  const lag = metrics?.aurora?.replication_lag_ms ?? null
  const { status, color, bgColor } = getLagStatus(lag)
  const connections = metrics?.aurora?.connections ?? 0

  // Calculate percentage for gauge (max 2000ms = 100%)
  const maxLag = 2000
  const percentage = lag !== null ? Math.min((lag / maxLag) * 100, 100) : 0

  return (
    <div className="space-y-6">
      {/* Gauge Visualization */}
      <div className="flex flex-col items-center">
        <div className="relative w-48 h-48">
          {/* Background circle */}
          <svg className="w-full h-full transform -rotate-90">
            <circle
              cx="96"
              cy="96"
              r="80"
              fill="none"
              stroke="#e5e7eb"
              strokeWidth="16"
            />
            {/* Progress circle */}
            <circle
              cx="96"
              cy="96"
              r="80"
              fill="none"
              stroke="currentColor"
              strokeWidth="16"
              strokeDasharray={`${(percentage / 100) * 502.4} 502.4`}
              className={bgColor === 'bg-green-500' ? 'text-green-500' : bgColor === 'bg-yellow-500' ? 'text-yellow-500' : bgColor === 'bg-red-500' ? 'text-red-500' : 'text-gray-400'}
            />
          </svg>
          {/* Center text */}
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <p className={`text-4xl font-bold ${color}`}>
              {lag !== null ? `${lag}` : 'N/A'}
            </p>
            <p className="text-sm text-gray-600">milliseconds</p>
          </div>
        </div>

        {/* Status */}
        <div className="mt-4 text-center">
          <p className={`text-lg font-semibold ${color}`}>{status}</p>
          <p className="text-xs text-gray-500 mt-1">
            Last updated: {metrics?.timestamp ? new Date(metrics.timestamp).toLocaleTimeString() : 'N/A'}
          </p>
        </div>
      </div>

      {/* Metrics Details */}
      <div className="grid grid-cols-2 gap-4 pt-4 border-t border-gray-200">
        <div>
          <p className="text-xs text-gray-500 uppercase">Replication Lag</p>
          <p className={`text-2xl font-bold ${color}`}>
            {lag !== null ? `${lag} ms` : 'N/A'}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500 uppercase">DB Connections</p>
          <p className="text-2xl font-bold text-hyundai-blue">{connections}</p>
        </div>
      </div>

      {/* Legend */}
      <div className="pt-4 border-t border-gray-200">
        <p className="text-xs text-gray-600 mb-2">Status Thresholds:</p>
        <div className="flex gap-4 text-xs">
          <div className="flex items-center gap-1">
            <span className="w-3 h-3 bg-green-500 rounded-full"></span>
            <span>Excellent (&lt;500ms)</span>
          </div>
          <div className="flex items-center gap-1">
            <span className="w-3 h-3 bg-yellow-500 rounded-full"></span>
            <span>Good (500-1000ms)</span>
          </div>
          <div className="flex items-center gap-1">
            <span className="w-3 h-3 bg-red-500 rounded-full"></span>
            <span>High (&gt;1000ms)</span>
          </div>
        </div>
      </div>
    </div>
  )
}
