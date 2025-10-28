'use strict';

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;

    // CloudFront 정책에서 헤더를 추가했는지 로깅
    console.log('Available headers:', Object.keys(headers));

    // Get viewer country from CloudFront header
    const country = headers['cloudfront-viewer-country']
        ? headers['cloudfront-viewer-country'][0].value
        : 'US';

    // Get viewer longitude for US East/West routing
    const longitude = headers['cloudfront-viewer-longitude']
        ? parseFloat(headers['cloudfront-viewer-longitude'][0].value)
        : null;

    // 로깅: 개발 단계에서 디버깅용
    console.log('Country: ' + country + ', Longitude: ' + longitude);

    // Define country to region mapping
    const asiaCountries = ['KR', 'JP', 'CN', 'TW', 'HK', 'SG', 'TH', 'VN', 'ID', 'MY', 'PH', 'IN'];
    const northAmericaCountries = ['US', 'CA', 'MX'];
    const oceaniaCountries = ['AU', 'NZ'];

    // Select origin based on viewer country and location
    let originDomainName;
    if (asiaCountries.indexOf(country) !== -1) {
        originDomainName = '${seoul_alb_dns_name}';
    } else if (oceaniaCountries.indexOf(country) !== -1) {
        originDomainName = '${us_west_alb_dns_name}';
    } else if (northAmericaCountries.indexOf(country) !== -1 && longitude !== null) {
        // 경도 -95를 기준으로 동/서 구분
        // -95보다 작음 = 서쪽 (US-West)
        // -95보다 큼 = 동쪽 (US-East)
        if (longitude < -95) {
            originDomainName = '${us_west_alb_dns_name}';
        } else {
            originDomainName = '${us_east_alb_dns_name}';
        }
    } else {
        originDomainName = '${us_east_alb_dns_name}';
    }

    // Update request origin
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
                    key: 'x-cloudfront-secret',  // 소문자
                    value: 'hyundai-poc-secret-2024'
                }]
            }
        }
    };
    
    // Update Host header
    request.headers['host'] = [{
        key: 'host',
        value: originDomainName
    }];

    // 로깅: 선택된 origin
    console.log('Routing to: ' + originDomainName);

    callback(null, request);
};
