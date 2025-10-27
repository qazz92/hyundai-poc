import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Hyundai Motors Global Infrastructure POC',
  description: 'Multi-region AWS infrastructure demonstration with Aurora Global Database',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50">{children}</body>
    </html>
  )
}
