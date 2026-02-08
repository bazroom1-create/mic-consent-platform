const WS_HOST = window.__ENV?.WS_HOST || (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;
const ws = new WebSocket(`${WS_HOST}/ws-audio`);
