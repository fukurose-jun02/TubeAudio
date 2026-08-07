let currentUrl = '';
let currentJobId = null;
let pollTimer = null;
let selectedFormat = 'm4a';
let selectedQuality = '192';

// ── URL input: fetch info on Enter ──
document.getElementById('urlInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') fetchInfo();
});

document.getElementById('urlInput').addEventListener('paste', () => {
  setTimeout(fetchInfo, 50);
});

// ── Fetch video info ──
async function fetchInfo() {
  const url = document.getElementById('urlInput').value.trim();
  if (!url) return;

  currentUrl = url;

  const btn = document.getElementById('fetchBtn');
  btn.disabled = true;
  btn.textContent = '取得中...';

  hideCards();

  try {
    const res = await fetch('/api/info', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url }),
    });
    const data = await res.json();

    if (data.error) {
      showError(data.error);
      return;
    }

    // Populate info card
    document.getElementById('thumbnail').src = data.thumbnail || '';
    document.getElementById('infoTitle').textContent = data.title || '';
    document.getElementById('infoChannel').textContent = data.channel || '';
    document.getElementById('infoDuration').textContent = data.duration_str || '';

    show('infoCard');
    show('settingsCard');
  } catch (err) {
    showError('ネットワークエラー: ' + err.message);
  } finally {
    btn.disabled = false;
    btn.textContent = '情報取得';
  }
}

// ── Format / Quality toggles ──
function setFormat(btn) {
  document.querySelectorAll('#formatGroup .toggle-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  selectedFormat = btn.dataset.value;
}

function setQuality(btn) {
  document.querySelectorAll('#qualityGroup .toggle-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  selectedQuality = btn.dataset.value;
}

// ── Start conversion ──
async function startConvert() {
  if (!currentUrl) return;

  const btn = document.getElementById('convertBtn');
  btn.disabled = true;

  hide('settingsCard');
  show('progressCard');
  hide('downloadSection');
  hide('errorSection');
  setProgress(0, '変換を開始しています...');

  try {
    const res = await fetch('/api/convert', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: currentUrl,
        format: selectedFormat,
        quality: selectedQuality,
      }),
    });
    const data = await res.json();

    if (data.error) {
      showJobError(data.error);
      btn.disabled = false;
      return;
    }

    currentJobId = data.job_id;
    startPolling();
  } catch (err) {
    showJobError('変換の開始に失敗しました: ' + err.message);
    btn.disabled = false;
  }
}

// ── Poll status ──
function startPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = setInterval(pollStatus, 800);
}

async function pollStatus() {
  if (!currentJobId) return;

  try {
    const res = await fetch(`/api/status/${currentJobId}`);
    const job = await res.json();

    if (job.error && !job.status) {
      showJobError(job.error);
      clearInterval(pollTimer);
      return;
    }

    const { status, progress, title, filename, filesize, error } = job;

    const labelMap = {
      queued: '待機中...',
      starting: '開始中...',
      downloading: 'ダウンロード中...',
      converting: 'オーディオに変換中...',
      done: '完了！',
      error: 'エラー',
    };
    setProgress(progress || 0, labelMap[status] || status);

    if (status === 'done') {
      clearInterval(pollTimer);
      showDone(title, filename, filesize);
    } else if (status === 'error') {
      clearInterval(pollTimer);
      showJobError(error || '不明なエラーが発生しました');
    }
  } catch (err) {
    // network hiccup — keep polling
  }
}

// ── Download ──
function downloadFile() {
  if (!currentJobId) return;
  const a = document.createElement('a');
  a.href = `/api/download/${currentJobId}`;
  a.click();
}

// ── UI helpers ──
function setProgress(pct, label) {
  document.getElementById('progressBar').style.width = pct + '%';
  document.getElementById('progressPercent').textContent = pct + '%';
  document.getElementById('progressLabel').textContent = label;
}

function showDone(title, filename, filesize) {
  setProgress(100, '変換完了！');
  document.getElementById('doneTitle').textContent = filename || title || '';
  document.getElementById('doneSize').textContent = filesize || '';
  show('downloadSection');
  loadHistory();
}

function showJobError(msg) {
  document.getElementById('errorText').textContent = msg;
  show('errorSection');
  document.getElementById('convertBtn').disabled = false;
}

function showError(msg) {
  // Inline error below URL (reuse errorSection briefly)
  alert(msg);
}

function show(id) {
  document.getElementById(id)?.classList.remove('hidden');
}

function hide(id) {
  document.getElementById(id)?.classList.add('hidden');
}

function hideCards() {
  hide('infoCard');
  hide('settingsCard');
  hide('progressCard');
  hide('downloadSection');
  hide('errorSection');
}

function resetApp() {
  if (pollTimer) clearInterval(pollTimer);
  currentJobId = null;
  document.getElementById('urlInput').value = '';
  document.getElementById('convertBtn').disabled = false;
  hideCards();
}

// ── History ──
async function loadHistory() {
  try {
    const res = await fetch('/api/files');
    const files = await res.json();
    const list = document.getElementById('historyList');

    if (!files.length) {
      list.innerHTML = '<li class="history-empty">まだ変換履歴がありません</li>';
      return;
    }

    list.innerHTML = files
      .map(
        (f) => `
      <li class="history-item">
        <span class="history-name" title="${esc(f.name)}">${esc(f.name)}</span>
        <span class="history-size">${esc(f.size)}</span>
        <button class="history-dl" onclick="dlByJobId('${esc(f.job_id)}')">DL</button>
      </li>`
      )
      .join('');
  } catch {
    // silently ignore
  }
}

function dlByJobId(jobId) {
  const a = document.createElement('a');
  a.href = `/api/download/${jobId}`;
  a.click();
}

function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Load history on page start
loadHistory();
