// JavaScript
// ديناميكي: يستخدم متغير بيئة إذا وُجد، وإلا يبني URL تلقائياً (يدعم wss/ws).
const envWsBase = (typeof process !== 'undefined' && process.env.REACT_APP_WS_URL) ? process.env.REACT_APP_WS_URL : null;
const defaultOrigin = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;
const wsBase = envWsBase || defaultOrigin; // envWsBase مثل 'https://api.example.com' أو 'wss://api.example.com'
const WS_URL = wsBase.endsWith('/ws-audio') ? wsBase : wsBase + '/ws-audio';
const ws = new WebSocket(WS_URL);
