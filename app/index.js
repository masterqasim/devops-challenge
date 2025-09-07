const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3000;

const APP_MESSAGE = process.env.APP_MESSAGE || "Hello from demo-metrics-app!";

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const requestCount = new client.Counter({
  name: 'demo_requests_total',
  help: 'Total number of requests',
  labelNames: ['route', 'method', 'code'],
});
register.registerMetric(requestCount);

const responseHistogram = new client.Histogram({
  name: 'demo_response_seconds',
  help: 'Response latency in seconds',
  buckets: [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2],
  labelNames: ['route', 'method', 'code'],
});
register.registerMetric(responseHistogram);

app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const seconds = Number(end - start) / 1e9;
    responseHistogram.labels(req.path, req.method, res.statusCode.toString()).observe(seconds);
    requestCount.labels(req.path, req.method, res.statusCode.toString()).inc();
  });
  next();
});

app.get('/', (_req, res) => {
  res.status(200).send(APP_MESSAGE);
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(port, () => {
  console.log(`demo-metrics-app listening on :${port}`);
});