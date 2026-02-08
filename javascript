const envWs = process.env.REACT_APP_WS_URL || null;
const defaultOrigin = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;
const wsBase = envWs || defaultOrigin;
const WS_URL = wsBase.endsWith('/ws-audio') ? wsBase : wsBase + '/ws-audio';
const ws = new WebSocket(WS_URL);
