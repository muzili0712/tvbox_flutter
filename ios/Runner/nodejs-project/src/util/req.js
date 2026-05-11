const _axios = require('axios');
const https = require('https');
const http = require('http');

const req = _axios.create({
    httpsAgent: new https.Agent({ keepAlive: true, rejectUnauthorized: false }),
    httpAgent: new http.Agent({ keepAlive: true }),
});

req.get = function(url, options = {}) {
    return _axios.get(url, { ...options, httpsAgent: req.httpsAgent, httpAgent: req.httpAgent });
};

req.post = function(url, data, options = {}) {
    return _axios.post(url, data, { ...options, httpsAgent: req.httpsAgent, httpAgent: req.httpAgent });
};

module.exports = req;
