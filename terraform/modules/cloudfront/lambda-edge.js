'use strict';

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;

    // Get viewer country from CloudFront header
    const country = headers['cloudfront-viewer-country']
        ? headers['cloudfront-viewer-country'][0].value
        : 'US';

    // Define country to region mapping for optimal latency
    const asiaCountries = ['KR', 'JP', 'CN', 'TW', 'HK', 'SG', 'TH', 'VN', 'ID', 'MY', 'PH', 'IN'];
    const northAmericaCountries = ['US', 'CA', 'MX'];
    const oceaniaCountries = ['AU', 'NZ'];

    // Select origin based on viewer country
    let originDomainName;
    if (asiaCountries.indexOf(country) !== -1) {
        // Route to Seoul origin for Asia Pacific
        originDomainName = '${seoul_alb_dns_name}';
    } else if (oceaniaCountries.indexOf(country) !== -1) {
        // Route to US-West origin for Oceania
        originDomainName = '${us_west_alb_dns_name}';
    } else {
        // Route to US-East origin for all others
        originDomainName = '${us_east_alb_dns_name}';
    }

    // Update request to use selected origin with HTTPS
    request.origin = {
        custom: {
            domainName: originDomainName,
            port: 443,
            protocol: 'https',
            path: '',
            sslProtocols: ['TLSv1.2'],
            readTimeout: 30,
            keepaliveTimeout: 5,
            customHeaders: {
                'x-cloudfront-secret': [{
                    key: 'X-CloudFront-Secret',
                    value: 'hyundai-poc-secret-2024'
                }]
            }
        }
    };
    
    // Update Host header to match origin domain
    request.headers['host'] = [{ key: 'Host', value: originDomainName }];

    callback(null, request);
};
