'use client'

import { useState, useEffect } from 'react'
import RegionIndicator from '@/components/RegionIndicator'
import LatencyTable from '@/components/LatencyTable'
import ReplicationLagGauge from '@/components/ReplicationLagGauge'
import HealthStatus from '@/components/HealthStatus'

export default function Home() {
  const [currentRegion, setCurrentRegion] = useState<string>('loading...')

  // Fetch current region on mount
  useEffect(() => {
    const fetchRegion = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001'
        const response = await fetch(`${apiUrl}/health`)
        const data = await response.json()
        setCurrentRegion(data.region || 'unknown')
      } catch (error) {
        console.error('Error fetching region:', error)
        setCurrentRegion('error')
      }
    }

    fetchRegion()
  }, [])

  return (
    <main className="min-h-screen bg-gradient-to-br from-gray-50 to-blue-50">
      {/* Header */}
      <header className="bg-hyundai-blue text-white py-6 shadow-lg">
        <div className="container mx-auto px-4">
          <h1 className="text-3xl font-bold">Hyundai Motors Global Infrastructure POC</h1>
          <p className="text-blue-200 mt-2">
            Multi-region AWS deployment with Aurora Global Database
          </p>
        </div>
      </header>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-8">
        {/* Current Region */}
        <div className="mb-8">
          <RegionIndicator region={currentRegion} />
        </div>

        {/* Metrics Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Health Status */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <h2 className="text-xl font-semibold text-hyundai-blue mb-4">
              Regional Health Status
            </h2>
            <HealthStatus />
          </div>

          {/* Replication Lag */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <h2 className="text-xl font-semibold text-hyundai-blue mb-4">
              Aurora Replication Lag
            </h2>
            <ReplicationLagGauge />
          </div>
        </div>

        {/* Latency Table - Full Width */}
        <div className="mt-6 bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-semibold text-hyundai-blue mb-4">
            Cross-Region Latency Measurements
          </h2>
          <LatencyTable />
        </div>

        {/* Footer Info */}
        <div className="mt-8 text-center text-gray-600 text-sm">
          <p>Metrics auto-refresh every 5 seconds</p>
          <p className="mt-1">
            Regions: Seoul (ap-northeast-2) · Virginia (us-east-1) · Oregon (us-west-2)
          </p>
        </div>
      </div>
    </main>
  )
}
