import { render, screen } from '@testing-library/react'
import RegionIndicator from '@/components/RegionIndicator'
import '@testing-library/jest-dom'

describe('Frontend Components', () => {
  /**
   * Test: RegionIndicator renders with region name
   */
  test('RegionIndicator should render Seoul region', () => {
    render(<RegionIndicator region="ap-northeast-2" />)

    expect(screen.getByText(/Seoul, South Korea/i)).toBeInTheDocument()
    expect(screen.getByText('ap-northeast-2')).toBeInTheDocument()
  })

  /**
   * Test: RegionIndicator renders US East region
   */
  test('RegionIndicator should render US East region', () => {
    render(<RegionIndicator region="us-east-1" />)

    expect(screen.getByText(/Virginia, United States/i)).toBeInTheDocument()
    expect(screen.getByText('us-east-1')).toBeInTheDocument()
  })

  /**
   * Test: RegionIndicator renders US West region
   */
  test('RegionIndicator should render US West region', () => {
    render(<RegionIndicator region="us-west-2" />)

    expect(screen.getByText(/Oregon, United States/i)).toBeInTheDocument()
    expect(screen.getByText('us-west-2')).toBeInTheDocument()
  })

  /**
   * Test: RegionIndicator handles unknown region
   */
  test('RegionIndicator should handle unknown region gracefully', () => {
    render(<RegionIndicator region="unknown-region" />)

    expect(screen.getByText('unknown-region')).toBeInTheDocument()
  })

  /**
   * Test: RegionIndicator displays loading state
   */
  test('RegionIndicator should display loading state', () => {
    render(<RegionIndicator region="loading..." />)

    expect(screen.getByText(/Loading.../i)).toBeInTheDocument()
  })
})
