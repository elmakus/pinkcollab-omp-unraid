const http = require('node:http');
const net = require('node:net');

function pinkHealth() {
  return new Promise(resolve => {
    const req = http.get('http://127.0.0.1:8787/health', res => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.setTimeout(2500, () => req.destroy());
    req.on('error', () => resolve(false));
  });
}
function orcaHealth() {
  return new Promise(resolve => {
    const socket = net.connect({ host: '127.0.0.1', port: 6768 });
    socket.setTimeout(2500);
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => resolve(false));
    socket.once('timeout', () => { socket.destroy(); resolve(false); });
  });
}
Promise.all([pinkHealth(), orcaHealth()])
  .then(results => process.exit(results.every(Boolean) ? 0 : 1))
  .catch(() => process.exit(1));
