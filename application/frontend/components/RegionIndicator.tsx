'use client'

interface RegionIndicatorProps {
  region: string
}

const regionNames: Record<string, string> = {
  'ap-northeast-2': 'Seoul, South Korea',
  'us-east-1': 'Virginia, United States',
  'us-west-2': 'Oregon, United States',
  'loading...': 'Loading...',
  'error': 'Error loading region',
  'unknown': 'Unknown Region',
}

const regionFlags: Record<string, string> = {
  'ap-northeast-2': '🇰🇷',
  'us-east-1': '🇺🇸',
  'us-west-2': '🇺🇸',
}

export default function RegionIndicator({ region }: RegionIndicatorProps) {
  const displayName = regionNames[region] || region
  const flag = regionFlags[region] || '🌐'

  return (
    <div className="bg-white rounded-lg shadow-lg p-8 text-center border-t-4 border-hyundai-lightblue">
      <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">Current Serving Region</p>
      <div className="flex items-center justify-center gap-4">
        <span className="text-6xl" role="img" aria-label="region flag">
          {flag}
        </span>
        <div className="text-left">
          <h2 className="text-3xl font-bold text-hyundai-blue">{displayName}</h2>
          <p className="text-gray-500 text-sm mt-1">{region}</p>
        </div>
      </div>
    </div>
  )
}
