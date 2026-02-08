git status
git log --oneline -n 3
git branch --show-current
git push -u origin main


cd frontend
npm install
npm run build
# ثم تأكد من وجود مجلد dist أو build
ls -la dist || ls -la build || true


cd backend
npm install
npm start
# أو شغّل في background وراقب logs


const WS_HOST = window.__ENV?.WS_HOST || (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;
const ws = new WebSocket(`${WS_HOST}/ws-audio`);
