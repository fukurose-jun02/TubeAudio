import os
import threading
import uuid
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify, render_template, send_file
import yt_dlp
from static_ffmpeg import run as ffmpeg_run

app = Flask(__name__)

DOWNLOADS_DIR = Path("downloads")
DOWNLOADS_DIR.mkdir(exist_ok=True)

ffmpeg_exe, _ = ffmpeg_run.get_or_fetch_platform_executables_else_raise()
ffmpeg_dir = os.path.dirname(ffmpeg_exe)

jobs = {}
jobs_lock = threading.Lock()
channel_icon_cache = {}
channel_icon_cache_lock = threading.Lock()


def format_duration(seconds):
    if not seconds:
        return "0:00"
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


def format_filesize(size_bytes):
    if size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes / (1024 * 1024):.1f} MB"


def format_upload_date(raw_date):
    if not raw_date:
        return ""
    try:
        return datetime.strptime(raw_date, "%Y%m%d").strftime("%Y-%m-%d")
    except ValueError:
        return ""


def select_channel_icon(thumbnails):
    """チャンネルページのサムネイル一覧からアバター画像を選ぶ。"""
    usable = [item for item in thumbnails or [] if item.get("url")]
    if not usable:
        return ""

    uncropped = next(
        (item for item in usable if item.get("id") == "avatar_uncropped"), None
    )
    if uncropped:
        return uncropped["url"]

    # yt-dlpはバナーのpreferenceを負数にする。正方形に近い候補を優先する。
    avatar_candidates = [
        item for item in usable if (item.get("preference") or 0) >= 0
    ]
    if not avatar_candidates:
        return ""

    def score(item):
        width = item.get("width") or 0
        height = item.get("height") or 0
        square_score = -abs(width - height) if width and height else -1
        return (square_score, width * height)

    return max(avatar_candidates, key=score)["url"]


def get_channel_icon(info):
    """動画情報のチャンネルURLから発信者アイコンを取得し、チャンネル単位でキャッシュする。"""
    channel_url = info.get("channel_url")
    channel_id = info.get("channel_id")
    cache_key = channel_id or channel_url
    if not channel_url or not cache_key:
        return ""

    with channel_icon_cache_lock:
        if cache_key in channel_icon_cache:
            return channel_icon_cache[cache_key]

    try:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "extract_flat": True,
            "playlistend": 1,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            channel_info = ydl.extract_info(channel_url, download=False)
        icon_url = select_channel_icon(channel_info.get("thumbnails"))
    except Exception:
        # アイコン取得失敗で動画情報の取得全体を失敗させない。
        icon_url = ""

    with channel_icon_cache_lock:
        channel_icon_cache[cache_key] = icon_url
    return icon_url


def make_progress_hook(job_id):
    def hook(d):
        with jobs_lock:
            if job_id not in jobs:
                return
            if d["status"] == "downloading":
                total = d.get("total_bytes") or d.get("total_bytes_estimate", 0)
                downloaded = d.get("downloaded_bytes", 0)
                if total > 0:
                    percent = int(downloaded / total * 80)
                    jobs[job_id]["progress"] = percent
                jobs[job_id]["status"] = "downloading"
            elif d["status"] == "finished":
                jobs[job_id]["progress"] = 85
                jobs[job_id]["status"] = "converting"
    return hook


def run_conversion(url, quality, fmt, job_id):
    job_dir = DOWNLOADS_DIR / job_id
    job_dir.mkdir(exist_ok=True)

    try:
        with jobs_lock:
            jobs[job_id]["status"] = "starting"
            jobs[job_id]["progress"] = 5

        ydl_opts = {
            "format": "bestaudio/best",
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": fmt,
                    "preferredquality": quality,
                }
            ],
            "ffmpeg_location": ffmpeg_dir,
            "outtmpl": str(job_dir / "%(title)s.%(ext)s"),
            "progress_hooks": [make_progress_hook(job_id)],
            "quiet": True,
            "no_warnings": True,
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            title = info.get("title", "Unknown")
            channel = info.get("uploader", "")
            duration = info.get("duration", 0)
            upload_date = format_upload_date(info.get("upload_date", ""))
            view_count = info.get("view_count", 0)

        # Find the converted file
        pattern = f"*.{fmt}"
        converted_files = list(job_dir.glob(pattern))

        if not converted_files:
            # fallback: any audio file
            converted_files = list(job_dir.glob("*.*"))

        if converted_files:
            file_path = converted_files[0]
            with jobs_lock:
                jobs[job_id].update(
                    {
                        "status": "done",
                        "progress": 100,
                        "file_path": str(file_path),
                        "filename": file_path.name,
                        "filesize": format_filesize(file_path.stat().st_size),
                        "title": title,
                        "channel": channel,
                        "duration": duration,
                        "upload_date": upload_date,
                        "view_count": view_count,
                    }
                )
        else:
            with jobs_lock:
                jobs[job_id]["status"] = "error"
                jobs[job_id]["error"] = "変換後のファイルが見つかりませんでした"

    except Exception as e:
        with jobs_lock:
            jobs[job_id]["status"] = "error"
            jobs[job_id]["error"] = str(e)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/info", methods=["POST"])
def get_info():
    data = request.json or {}
    url = data.get("url", "").strip()
    if not url:
        return jsonify({"error": "URLを入力してください"}), 400

    try:
        ydl_opts = {"quiet": True, "no_warnings": True}
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            channel_icon = get_channel_icon(info)
            return jsonify(
                {
                    "title": info.get("title", ""),
                    "thumbnail": info.get("thumbnail", ""),
                    "channel": info.get("uploader", ""),
                    "channel_icon": channel_icon,
                    "duration": info.get("duration", 0),
                    "duration_str": format_duration(info.get("duration", 0)),
                    "view_count": info.get("view_count", 0),
                }
            )
    except Exception as e:
        return jsonify({"error": f"動画情報の取得に失敗しました: {str(e)}"}), 400


@app.route("/api/convert", methods=["POST"])
def convert():
    data = request.json or {}
    url = data.get("url", "").strip()
    quality = data.get("quality", "192")
    fmt = data.get("format", "m4a")

    if not url:
        return jsonify({"error": "URLを入力してください"}), 400

    if fmt not in ("m4a", "mp3"):
        fmt = "m4a"
    if quality not in ("128", "192", "256", "320"):
        quality = "192"

    job_id = uuid.uuid4().hex[:10]
    with jobs_lock:
        jobs[job_id] = {
            "status": "queued",
            "progress": 0,
            "file_path": None,
            "filename": None,
            "filesize": None,
            "error": None,
            "title": "",
        }

    thread = threading.Thread(
        target=run_conversion, args=(url, quality, fmt, job_id), daemon=True
    )
    thread.start()

    return jsonify({"job_id": job_id})


@app.route("/api/status/<job_id>")
def status(job_id):
    with jobs_lock:
        job = jobs.get(job_id)
    if not job:
        return jsonify({"error": "ジョブが見つかりません"}), 404
    return jsonify(job)


@app.route("/api/download/<job_id>")
def download(job_id):
    with jobs_lock:
        job = jobs.get(job_id)

    if not job or job.get("status") != "done":
        return jsonify({"error": "ファイルの準備ができていません"}), 404

    file_path = job.get("file_path")
    if not file_path or not os.path.exists(file_path):
        return jsonify({"error": "ファイルが見つかりません"}), 404

    return send_file(
        file_path,
        as_attachment=True,
        download_name=job.get("filename", os.path.basename(file_path)),
    )


@app.route("/api/files")
def list_files():
    files = []
    for job_dir in DOWNLOADS_DIR.iterdir():
        if job_dir.is_dir():
            for f in job_dir.iterdir():
                if f.suffix.lower() in (".m4a", ".mp3", ".wav"):
                    files.append(
                        {
                            "name": f.name,
                            "size": format_filesize(f.stat().st_size),
                            "job_id": job_dir.name,
                        }
                    )
    files.sort(key=lambda x: x["name"])
    return jsonify(files)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    print(f"🎵 YouTube Audio Converter 起動中...")
    print(f"   http://localhost:{port} をブラウザで開いてください")
    app.run(debug=False, port=port, host="0.0.0.0")
