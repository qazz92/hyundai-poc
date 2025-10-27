// CloudFront Function for geographic origin selection
// This function runs at CloudFront edge locations (viewer-request)
// and selects the appropriate regional origin based on viewer country

function handler(event) {
    var request = event.request;
    var headers = request.headers;

    // Get viewer country from CloudFront header
    var country = headers['cloudfront-viewer-country'] ? headers['cloudfront-viewer-country'].value : 'US';

    // Add custom secret header to verify request came from CloudFront
    request.headers['x-cloudfront-secret'] = {
        value: 'hyundai-poc-secret-2024'
    };

    // Select origin based on country
    // Asia Pacific countries -> Seoul origin
    var asiaCountries = ['KR', 'JP', 'CN', 'TW', 'HK', 'SG', 'TH', 'VN', 'ID', 'MY', 'PH', 'IN'];

    // North America countries -> US-East origin
    var northAmericaCountries = ['US', 'CA', 'MX'];

    // Oceania countries -> US-West origin
    var oceaniaCountries = ['AU', 'NZ'];

    if (asiaCountries.indexOf(country) !== -1) {
        // Route to Seoul origin
        request.headers['x-origin-region'] = { value: 'seoul' };
    } else if (northAmericaCountries.indexOf(country) !== -1) {
        // Route to US-East origin
        request.headers['x-origin-region'] = { value: 'us-east' };
    } else if (oceaniaCountries.indexOf(country) !== -1) {
        // Route to US-West origin
        request.headers['x-origin-region'] = { value: 'us-west' };
    } else {
        // Default to US-East for all other countries (Europe, Africa, South America)
        request.headers['x-origin-region'] = { value: 'us-east' };
    }

    return request;
}
