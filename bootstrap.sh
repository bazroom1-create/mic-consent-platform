#!/usr/bin/env bash
# bootstrap.sh — creates mic-consent-platform repo locally and pushes to GitHub
set -e

# --- ضَع هنا اسم حساب GitHub الخاص بك ---
GITHUB_USER="YOUR_GITHUB_USER"
REPO_NAME="mic-consent-platform"
BACKEND_PORT=3000

if [ "$GITHUB_USER" = "YOUR_GITHUB_USER" ]; then
  echo "⚠️  عدّل المتغير GITHUB_USER في السكربت إلى اسم حساب GitHub الخاص بك ثم أعد التشغيل."
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "gh CLI غير مثبت. ثبته من https://cli.github.com/ ثم سجّل الدخول عبر 'gh auth login'."
  exit 1
fi

echo "إنشاء مجلد المشروع..."
rm -rf ${REPO_NAME}
mkdir ${REPO_NAME}
cd ${REPO_NAME}

# .gitignore
cat > .gitignore <<'GIT'
node_modules/
dist/
.env
.DS_Store
GIT

# README
cat > README.md <<'MD'
# mic-consent-platform
Proof-of-concept: consented microphone streaming to server (WebSocket), PCM Int16, optional storage & ASR.
MD

# BACKEND
mkdir backend
cat > backend/server.js <<'JS'
// Node.js - Express + ws receiver (save raw PCM to files, basic consent API)
const http = require('http');
const express = require('express');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);

app.post('/consent', (req, res) => {
  const rec = { ts: Date.now(), body: req.body };
  fs.appendFileSync(path.join(DATA_DIR, 'consents.jsonl'), JSON.stringify(rec) + '\n');
  res.json({ ok: true });
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws-audio' });

wss.on('connection', (ws, req) => {
  console.log('audio client connected');
  const fname = path.join(DATA_DIR, `recv_${Date.now()}.raw`);
  ws.on('message', (msg) => {
    const buf = Buffer.from(msg);
    fs.appendFile(fname, buf, (err) => { if (err) console.error(err); });
  });
  ws.on('close', () => console.log('client disconnected'));
});

server.listen(process.env.PORT || ${BACKEND_PORT}, () => console.log('Server listening on :${BACKEND_PORT}'));
JS

cat > backend/package.json <<'PJ'
{
  "name": "mic-backend",
  "version": "1.0.0",
  "main": "server.js",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.13.0"
  },
  "scripts": {
    "start": "node server.js"
  }
}
PJ

# FRONTEND (Vite React minimal)
npm init vite@latest frontend -- --template react >/dev/null 2>&1 || true

cat > frontend/src/main.jsx <<'REACT'
import React, { useState, useRef } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

function App() {
  const [running, setRunning] = useState(false);
  const wsRef = useRef(null);
  const procRef = useRef(null);
  const ctxRef = useRef(null);

  async function start() {
    if (running) return;
    const allowed = confirm("هل تسمح لهذا الموقع بالاستماع للميكروفون بشكل مستمر بعد الموافقة؟");
    if (!allowed) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      ctxRef.current = audioCtx;
      const src = audioCtx.createMediaStreamSource(stream);
      const proc = audioCtx.createScriptProcessor(4096, 1, 1);
      proc.onaudioprocess = (e) => {
        const input = e.inputBuffer.getChannelData(0);
        const buffer = new ArrayBuffer(input.length * 2);
        const view = new DataView(buffer);
        let offset = 0;
        for (let i = 0; i < input.length; i++, offset += 2) {
          let s = Math.max(-1, Math.min(1, input[i]));
          view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true);
        }
        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
          wsRef.current.send(buffer);
        }
      };
      src.connect(proc);
      proc.connect(audioCtx.destination);
      procRef.current = proc;

      const ws = new WebSocket("ws://localhost:${BACKEND_PORT}/ws-audio");
      ws.binaryType = "arraybuffer";
      ws.onopen = () => console.log("ws open");
      wsRef.current = ws;

      localStorage.setItem("micConsent", JSON.stringify({ granted: true, ts: Date.now() }));
      fetch('/consent', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({granted:true, ts:Date.now()}) }).catch(()=>{});
      setRunning(true);
    } catch (err) {
      alert('Error accessing microphone: ' + err.message);
    }
  }

  function stop() {
    if (!running) return;
    if (procRef.current) { procRef.current.disconnect(); procRef.current = null; }
    if (ctxRef.current) { ctxRef.current.close(); ctxRef.current = null; }
    if (wsRef.current) { wsRef.current.close(); wsRef.current = null; }
    localStorage.setItem("micConsent", JSON.stringify({ granted: false, ts: Date.now() }));
    fetch('/consent', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({granted:false, ts:Date.now()}) }).catch(()=>{});
    setRunning(false);
  }

  return (
    <div style={{padding:20}}>
      <h3>منصة الاستماع بالميكروفون (مع موافقة)</h3>
      <button onClick={start} disabled={running}>ابدأ (موافقة)</button>
      <button onClick={stop} disabled={!running}>أوقف</button>
      <p>الموافقة محفوظة محليًا ومرسلة للخادم.</p>
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
REACT

cat > frontend/index.html <<'HTML'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>mic-consent-platform</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

cat > frontend/src/style.css <<'CSS'
body { font-family: Arial, sans-serif; }
button { margin-right: 8px; padding: 8px 12px; }
CSS

# Git init & commit
git init
git add .
git commit -m "Initial commit - mic consent POC"

echo "إنشاء المستودع على GitHub ودفع الملفات..."
gh repo create ${GITHUB_USER}/${REPO_NAME} --public --source=. --remote=origin --push

echo "تثبيت تبعيات backend..."
cd backend
npm install --silent || true
cd ..

echo "✅ bootstrap انتهى. التعليمات التالية تظهر أدناه."
echo ""
echo "تشغيل محلي:"
echo "1) backend: cd ${REPO_NAME}/backend && npm start"
echo "2) frontend: cd ${REPO_NAME}/frontend && npm install && npm run dev"
echo ""
echo "لنشر:"
echo "- لنشر الواجهة (Vercel): cd ${REPO_NAME}/frontend && vercel --prod"
echo "- لنشر backend: استخدم Render أو VPS أو Cloud Run وأشر إلى مجلد backend مع أمر البدء: 'node server.js'"
echo ""
echo "تذكّر تحديث عنوان WebSocket في frontend إلى 'wss://<your-backend-host>/ws-audio' عند النشر."
