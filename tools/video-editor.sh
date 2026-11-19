#!/usr/bin/env bash
# Makes Claude a video editor: Adam sends clips and photos, Claude returns a
# finished video (cuts, titles, transitions, captions, music, sound mix).
#
# The finishing timeline is HyperFrames (tools/hyperframes.sh), which already
# brings titles, ~450 catalog blocks, captions, grades and the audio mixer.
# This script adds what an editor needs around it:
#   - Kinocut (github.com/KyaniteLabs/kinocut, Apache-2.0, formerly mcp-video),
#     pinned, in its own venv: a local editing engine built for AI agents.
#     Trim, merge, silence removal, stabilise, scene detection, ducking,
#     loudness, quality gates. CLI `kino` and an MCP server `kinocut`.
#   - /usr/local/bin/footage-intake: look at everything in a folder at once
#     (facts, contact sheets, transcripts) and convert phone footage (HEVC,
#     HDR, HEIC photos) into files every tool reads.
#   - /usr/local/bin/dropbox-files: pull a job's folder from Dropbox and push the
#     finished video back (official API; keys come from the environment).
#   - /usr/local/bin/video-finish: master loudness, web-ready encode, and a
#     measured QC report with a contact sheet.
#   - a video-editor skill: the house workflow and the rules of a clean cut.
# Needs ffmpeg and whisper-cli, both present (whisper-cli from hyperframes.sh).
set -euo pipefail

KINOCUT_VERSION=2.0.1
VENV=/opt/kinocut-venv
SKILLS="$HOME/.claude/skills"
log() { printf '[video-editor-setup] %s\n' "$*"; }

# 1. Kinocut, plus Pillow + pillow-heif for iPhone HEIC photos.
have=$("$VENV/bin/kino" --version 2>/dev/null | awk '{print $2}' || true)
if [ "$have" != "$KINOCUT_VERSION" ] || ! "$VENV/bin/python" -c "import pillow_heif" 2>/dev/null; then
  if command -v uv >/dev/null 2>&1; then
    [ -x "$VENV/bin/python" ] || uv venv -q "$VENV"
    uv pip install -q --python "$VENV/bin/python" "kinocut==$KINOCUT_VERSION" pillow pillow-heif
  else
    [ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q "kinocut==$KINOCUT_VERSION" pillow pillow-heif
  fi
fi
ln -sf "$VENV/bin/kino" /usr/local/bin/kino
log "kinocut $("$VENV/bin/kino" --version | awk '{print $2}') ready"

# 2. footage-intake.
cat > /usr/local/bin/footage-intake <<'PY'
#!/opt/kinocut-venv/bin/python
"""footage-intake <folder> [--conform] [--no-transcribe]

Looks at every video, photo and audio file in a folder (not subfolders) and
writes <folder>/_intake/:
  inventory.md      one row per file: size, length, frame rate, codec, HDR,
                    rotation, sound level, and what needs converting
  sheets/<name>.jpg 8 frames of each video on one image
  photos.jpg        every photo on one image
  transcripts/<name>.txt and .json (word timings) for videos with speech
--conform also writes _intake/conformed/: H.264, 8-bit, standard colour,
constant frame rate copies of footage that needs it (HEVC, HDR, 10-bit,
variable frame rate) and JPG copies of HEIC photos. Originals are never changed.
"""
import json, os, pathlib, subprocess, sys

VIDEO = {".mp4", ".mov", ".m4v", ".mkv", ".webm", ".avi", ".mts", ".3gp"}
PHOTO = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".tif", ".tiff"}
AUDIO = {".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg"}
HDR = {"smpte2084": "HDR10/Dolby Vision", "arib-std-b67": "HLG (iPhone HDR)"}


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def probe(p):
    r = run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", str(p)])
    return json.loads(r.stdout or "{}")


def rate(s):
    try:
        a, b = s.split("/")
        return float(a) / float(b) if float(b) else 0.0
    except Exception:
        return 0.0


def loudness(p):
    r = run(["ffmpeg", "-hide_banner", "-nostats", "-t", "300", "-i", str(p), "-vn", "-af", "ebur128", "-f", "null", "-"])
    for line in reversed(r.stderr.splitlines()):
        if line.strip().startswith("I:"):
            return line.split()[1]
    return ""


def transcribe(p, outdir):
    model = os.environ.get("WHISPER_MODEL") or str(pathlib.Path.home() / ".cache/hyperframes/whisper/models/ggml-small.en.bin")
    if not pathlib.Path(model).exists():
        pathlib.Path(model).parent.mkdir(parents=True, exist_ok=True)
        run(["curl", "-fsSL", "-o", model, "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + pathlib.Path(model).name])
    wav = outdir / (p.stem + ".wav")
    run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(p), "-vn", "-ar", "16000", "-ac", "1", str(wav)])
    base = outdir / p.stem
    # -ml 1 -sow: one word per segment, so the JSON carries word timings.
    run(["whisper-cli", "-m", model, "-f", str(wav), "-ml", "1", "-sow", "-oj", "-of", str(base), "-np"])
    wav.unlink(missing_ok=True)
    words = []
    try:
        for seg in json.loads(base.with_suffix(".json").read_text())["transcription"]:
            t = seg["text"].strip()
            if t and not t.startswith("["):
                words.append({"text": t, "start": seg["offsets"]["from"] / 1000, "end": seg["offsets"]["to"] / 1000})
    except Exception:
        return 0
    base.with_suffix(".json").write_text(json.dumps(words))
    # Phrase lines with times: break on a pause of 0.5 s or a sentence end.
    lines, cur = [], []
    for i, w in enumerate(words):
        cur.append(w)
        gap = words[i + 1]["start"] - w["end"] if i + 1 < len(words) else 9
        if gap >= 0.5 or w["text"][-1:] in ".?!":
            lines.append(f"[{cur[0]['start']:07.2f}-{cur[-1]['end']:07.2f}] " + " ".join(x["text"] for x in cur))
            cur = []
    base.with_suffix(".txt").write_text("\n".join(lines) + "\n")
    return len(words)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    conform, do_tr = "--conform" in sys.argv, "--no-transcribe" not in sys.argv
    folder = pathlib.Path(args[0]).resolve()
    out = folder / "_intake"
    for d in ("sheets", "transcripts"):
        (out / d).mkdir(parents=True, exist_ok=True)
    files = sorted(f for f in folder.iterdir() if f.is_file())
    rows, photos, total = [], [], 0.0
    for f in files:
        ext = f.suffix.lower()
        if ext in VIDEO:
            d = probe(f)
            v = next((s for s in d.get("streams", []) if s.get("codec_type") == "video"), None)
            a = next((s for s in d.get("streams", []) if s.get("codec_type") == "audio"), None)
            if not v:
                continue
            dur = float(d.get("format", {}).get("duration") or 0)
            total += dur
            w, h = v.get("width", 0), v.get("height", 0)
            rot = 0
            for sd in v.get("side_data_list", []):
                rot = int(sd.get("rotation", rot) or rot)
            if abs(rot) in (90, 270):
                w, h = h, w
            fps, avg = rate(v.get("r_frame_rate", "0/1")), rate(v.get("avg_frame_rate", "0/1"))
            needs = []
            if v.get("codec_name") != "h264":
                needs.append(v.get("codec_name", "?"))
            if v.get("color_transfer") in HDR:
                needs.append(HDR[v["color_transfer"]])
            if "10" in v.get("pix_fmt", ""):
                needs.append("10-bit")
            if avg and abs(fps - avg) / avg > 0.02:
                needs.append("variable frame rate")
            lufs = loudness(f) if a else ""
            nwords = ""
            if a and do_tr and lufs and float(lufs) > -45:
                nwords = transcribe(f, out / "transcripts")
            step = max(dur / 8, 0.01)
            run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(f), "-vf",
                 f"fps=1/{step:.3f},scale=480:-2:force_original_aspect_ratio=decrease,tile=4x2", "-frames:v", "1",
                 str(out / "sheets" / (f.stem + ".jpg"))])
            target = ""
            if conform and needs:
                (out / "conformed").mkdir(exist_ok=True)
                dst = out / "conformed" / (f.stem + ".mp4")
                vf = []
                if v.get("color_transfer") in HDR:
                    vf.append("zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv")
                vf.append("format=yuv420p")
                cfr = round(avg or fps or 30)
                cfr = {24: "24000/1001" if abs((avg or fps) - 23.976) < 0.01 else "24", 30: "30000/1001" if abs((avg or fps) - 29.97) < 0.01 else "30",
                       60: "60000/1001" if abs((avg or fps) - 59.94) < 0.01 else "60"}.get(cfr, str(cfr))
                r = run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(f), "-vf", ",".join(vf), "-r", cfr, "-fps_mode", "cfr",
                         "-c:v", "libx264", "-preset", "fast", "-crf", "16", "-colorspace", "bt709", "-color_primaries", "bt709",
                         "-color_trc", "bt709", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(dst)])
                target = f"conformed/{dst.name}" if r.returncode == 0 else "CONFORM FAILED: " + r.stderr.strip()[-120:]
            rows.append((f.name, "video", f"{dur:.1f}s", f"{w}x{h}", f"{avg or fps:.2f}", v.get("codec_name", ""),
                         (lufs + " LUFS") if lufs else "no sound", str(nwords) if nwords != "" else "-",
                         ", ".join(needs) or "ok", target))
        elif ext in PHOTO:
            src = f
            note, target = "ok", ""
            if ext in (".heic", ".heif"):
                note = "HEIC"
                if conform:
                    from PIL import Image, ImageOps
                    import pillow_heif
                    pillow_heif.register_heif_opener()
                    (out / "conformed").mkdir(exist_ok=True)
                    src = out / "conformed" / (f.stem + ".jpg")
                    ImageOps.exif_transpose(Image.open(f)).convert("RGB").save(src, quality=95)
                    target = f"conformed/{src.name}"
            d = probe(src)
            v = next((s for s in d.get("streams", []) if s.get("codec_type") == "video"), {})
            if src.suffix.lower() not in (".heic", ".heif"):
                photos.append(src)
            rows.append((f.name, "photo", "-", f"{v.get('width', '?')}x{v.get('height', '?')}", "-", "-", "-", "-", note, target))
        elif ext in AUDIO:
            d = probe(f)
            dur = float(d.get("format", {}).get("duration") or 0)
            rows.append((f.name, "audio", f"{dur:.1f}s", "-", "-", "-", loudness(f) + " LUFS", "-", "ok", ""))
    if photos:
        n = len(photos)
        cols = min(n, 5)
        inputs = []
        for p in photos:
            inputs += ["-i", str(p)]
        fc = "".join(f"[{i}:v]scale=384:384:force_original_aspect_ratio=decrease,pad=384:384:(ow-iw)/2:(oh-ih)/2,setsar=1[p{i}];" for i in range(n))
        fc += "".join(f"[p{i}]" for i in range(n)) + (f"xstack=inputs={n}:layout=" + "|".join(f"{(i % cols) * 384}_{(i // cols) * 384}" for i in range(n)) + ":fill=black" if n > 1 else "null")
        run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex", fc, "-frames:v", "1", str(out / "photos.jpg")])
    head = ("file", "kind", "length", "size", "fps", "codec", "sound", "words", "needs converting", "converted copy")
    md = ["# Footage inventory", "", f"{len(rows)} files, {total:.0f}s of video. Sheets: `_intake/sheets/`. Photos: `_intake/photos.jpg`. Transcripts: `_intake/transcripts/`.", "",
          "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    md += ["| " + " | ".join(r) + " |" for r in rows]
    (out / "inventory.md").write_text("\n".join(md) + "\n")
    print("\n".join(md))


main()
PY
chmod 0755 /usr/local/bin/footage-intake

# 3. video-finish.
cat > /usr/local/bin/video-finish <<'SH'
#!/usr/bin/env bash
# video-finish <rendered.mp4> [output.mp4]
# Masters a rendered edit for delivery and measures the result:
#   - sound set to LUFS (default -14, the level social platforms play at; -16
#     for YouTube long-form or podcasts) with true peak under -1.5 dBTP
#   - H.264 high profile, yuv420p, standard colour tags, faststart (plays
#     everywhere, starts instantly on the web); CRF (default 18)
#   - prints a QC report and writes <output>.qc.jpg (16 frames on one image)
# Env: LUFS, CRF, KEEP_VIDEO=1 (copy the picture untouched, sound only).
set -euo pipefail
in=${1:?usage: video-finish <rendered.mp4> [output.mp4]}
out=${2:-"${in%.*}-final.mp4"}
lufs=${LUFS:--14}; crf=${CRF:-18}
[ "$(realpath "$in")" != "$(realpath -m "$out")" ] || { echo "output must differ from input" >&2; exit 2; }
has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$in" | head -1)
vopts=(-c:v libx264 -preset medium -crf "$crf" -pix_fmt yuv420p -profile:v high
       -colorspace bt709 -color_primaries bt709 -color_trc bt709)
[ "${KEEP_VIDEO:-0}" = 1 ] && vopts=(-c:v copy)
if [ -n "$has_audio" ]; then
  # Two-pass loudnorm: measure, then apply linearly with the measured values.
  m=$(ffmpeg -hide_banner -nostats -i "$in" -vn -af "loudnorm=I=$lufs:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
  g() { printf '%s' "$m" | python3 -c "import json,sys;print(json.load(sys.stdin)['$1'])"; }
  af="loudnorm=I=$lufs:TP=-1.5:LRA=11:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):offset=$(g target_offset):linear=true"
  ffmpeg -hide_banner -loglevel error -y -i "$in" "${vopts[@]}" -af "$af" -ar 48000 -c:a aac -b:a 256k -movflags +faststart "$out"
else
  ffmpeg -hide_banner -loglevel error -y -i "$in" "${vopts[@]}" -an -movflags +faststart "$out"
fi

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")
echo "== QC report: $out"
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,pix_fmt -of default=nw=1 "$out" | paste -sd' '
echo "length: ${dur}s   size: $(du -h "$out" | cut -f1)"
log=$(ffmpeg -hide_banner -nostats -i "$out" -vf "blackdetect=d=0.4:pix_th=0.06,freezedetect=n=-55dB:d=2" -af "ebur128=peak=true,silencedetect=noise=-50dB:d=1.5" -f null - 2>&1 || true)
if [ -n "$has_audio" ]; then
  echo "loudness: $(printf '%s\n' "$log" | grep -E '^\s+I:' | tail -1 | xargs)  (target $lufs LUFS)   true peak: $(printf '%s\n' "$log" | grep -E '^\s+Peak:' | tail -1 | xargs)"
else
  echo "loudness: NO SOUND TRACK"
fi
for k in black_start silence_start freeze_start; do
  hits=$(printf '%s\n' "$log" | grep -o "$k[:=] *[0-9.]*" | sed 's/.*[:=] *//' | paste -sd' ' || true)
  echo "${k%_start} sections start at: ${hits:-none}"
done
step=$(python3 -c "print(max(float('$dur')/16,0.04))")
ffmpeg -hide_banner -loglevel error -y -i "$out" -vf "fps=1/$step,scale=480:-2,tile=4x4" -frames:v 1 "${out%.*}.qc.jpg"
echo "frames: ${out%.*}.qc.jpg  (look at it before delivering)"
SH
chmod 0755 /usr/local/bin/video-finish
# 3b. dropbox-files: pull a Dropbox folder, push finished files back.
cat > /usr/local/bin/dropbox-files <<'PY'
#!/usr/bin/env python3
"""dropbox-files: move files between a cloud session and Dropbox.

  dropbox-files check                      confirm the connection, show the account
  dropbox-files ls [/folder]               list a folder
  dropbox-files pull </folder> <local dir> download every file in a folder
                                           (skips names starting FINAL and files
                                           already downloaded at the same size)
  dropbox-files push <file>... </folder>   upload files (any size), keeping
                                           earlier versions: a taken name gets (1)
  dropbox-files auth --app-key KEY         first-time set-up: print the sign-in link
  dropbox-files auth <code>                trade the code Dropbox shows for a token

Reads DROPBOX_APP_KEY and DROPBOX_REFRESH_TOKEN (and DROPBOX_APP_SECRET if the
token was made with one) from the environment, else from
~/.config/dropbox-files/credentials.json, which `auth` writes for this session.
With an "App folder" Dropbox app, "/" is Dropbox/Apps/<app name>/.
"""
import base64, hashlib, json, os, pathlib, secrets, sys, urllib.error, urllib.parse, urllib.request

CFG = pathlib.Path.home() / ".config/dropbox-files"
CRED, PENDING = CFG / "credentials.json", CFG / "pending.json"
API, CONTENT, OAUTH = "https://api.dropboxapi.com/2/", "https://content.dropboxapi.com/2/", "https://api.dropbox.com/oauth2/token"
CHUNK = 64 * 1024 * 1024


def die(msg):
    print(f"dropbox-files: {msg}", file=sys.stderr)
    sys.exit(1)


def http(url, data=None, headers=None, timeout=900):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": "dropbox-files", **(headers or {})}, method="POST")
    try:
        return urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.HTTPError as e:
        die(f"Dropbox answered {e.code}: {e.read().decode(errors='replace')[:300]}")


def creds():
    c = {k: os.environ.get(k, "").strip() for k in ("DROPBOX_APP_KEY", "DROPBOX_APP_SECRET", "DROPBOX_REFRESH_TOKEN")}
    if not (c["DROPBOX_APP_KEY"] and c["DROPBOX_REFRESH_TOKEN"]) and CRED.exists():
        c.update(json.loads(CRED.read_text()))
    if not (c.get("DROPBOX_APP_KEY") and c.get("DROPBOX_REFRESH_TOKEN")):
        die("Dropbox is not connected: DROPBOX_APP_KEY and DROPBOX_REFRESH_TOKEN are not set. See the video-editor skill, 'Connecting Dropbox'.")
    return c


_tok = None


def token():
    global _tok
    if not _tok:
        c = creds()
        body = {"grant_type": "refresh_token", "refresh_token": c["DROPBOX_REFRESH_TOKEN"], "client_id": c["DROPBOX_APP_KEY"]}
        if c.get("DROPBOX_APP_SECRET"):
            body["client_secret"] = c["DROPBOX_APP_SECRET"]
        _tok = json.load(http(OAUTH, urllib.parse.urlencode(body).encode()))["access_token"]
    return _tok


def rpc(endpoint, arg):
    data = b"null" if arg is None else json.dumps(arg).encode()
    return json.load(http(API + endpoint, data, {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}))


def norm(path):
    path = "/" + path.strip().strip("/")
    return "" if path == "/" else path


def listing(path):
    r = rpc("files/list_folder", {"path": norm(path), "limit": 2000})
    items = r["entries"]
    while r["has_more"]:
        r = rpc("files/list_folder/continue", {"cursor": r["cursor"]})
        items += r["entries"]
    return items


def cmd_ls(path="/"):
    for e in sorted(listing(path), key=lambda e: (e[".tag"] != "folder", e["name"].lower())):
        print(f"{'[folder]' if e['.tag'] == 'folder' else format(e.get('size', 0) / 1e6, '8.1f') + ' MB'}  {e['name']}")


def cmd_pull(path, local):
    local = pathlib.Path(local)
    local.mkdir(parents=True, exist_ok=True)
    n = 0
    for e in listing(path):
        if e[".tag"] != "file" or e["name"].upper().startswith("FINAL"):
            continue
        dst = local / e["name"]
        if dst.exists() and dst.stat().st_size == e["size"]:
            print(f"have  {e['name']}")
            continue
        arg = json.dumps({"path": e["id"]})
        with http(CONTENT + "files/download", None, {"Authorization": f"Bearer {token()}", "Dropbox-API-Arg": arg}) as r, open(dst, "wb") as f:
            while chunk := r.read(8 * 1024 * 1024):
                f.write(chunk)
        if dst.stat().st_size != e["size"]:
            die(f"{e['name']} came down incomplete ({dst.stat().st_size} of {e['size']} bytes)")
        n += 1
        print(f"got   {e['name']}  ({e['size'] / 1e6:.1f} MB)")
    print(f"{n} file(s) downloaded to {local}")


def ascii_arg(obj):
    # HTTP headers are Latin-1: escape anything beyond ASCII, as Dropbox asks.
    return json.dumps(obj, ensure_ascii=True)


def cmd_push(files, folder):
    for f in map(pathlib.Path, files):
        if not f.is_file():
            die(f"no such file: {f}")
        size, dest = f.stat().st_size, f"{norm(folder)}/{f.name}"
        commit = {"path": dest, "mode": "add", "autorename": True, "mute": False}
        hdr = {"Authorization": f"Bearer {token()}", "Content-Type": "application/octet-stream"}
        with open(f, "rb") as fh:
            if size <= CHUNK:
                r = json.load(http(CONTENT + "files/upload", fh.read(), {**hdr, "Dropbox-API-Arg": ascii_arg(commit)}))
            else:
                sid = json.load(http(CONTENT + "files/upload_session/start", fh.read(CHUNK), {**hdr, "Dropbox-API-Arg": "{}"}))["session_id"]
                off = CHUNK
                while size - off > CHUNK:
                    http(CONTENT + "files/upload_session/append_v2", fh.read(CHUNK),
                         {**hdr, "Dropbox-API-Arg": ascii_arg({"cursor": {"session_id": sid, "offset": off}})})
                    off += CHUNK
                r = json.load(http(CONTENT + "files/upload_session/finish", fh.read(),
                                   {**hdr, "Dropbox-API-Arg": ascii_arg({"cursor": {"session_id": sid, "offset": off}, "commit": commit})}))
        if r.get("size") != size:
            die(f"{f.name}: Dropbox has {r.get('size')} bytes, expected {size}")
        print(f"uploaded {r['path_display']}  ({size / 1e6:.1f} MB)")


def cmd_auth(argv):
    CFG.mkdir(parents=True, exist_ok=True)
    os.chmod(CFG, 0o700)
    if argv and argv[0] == "--app-key":
        key = argv[1].strip()
        verifier = secrets.token_urlsafe(64)
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
        PENDING.write_text(json.dumps({"key": key, "verifier": verifier}))
        os.chmod(PENDING, 0o600)
        print("Open this link, click Allow, and copy the code Dropbox shows:\n")
        print("https://www.dropbox.com/oauth2/authorize?" + urllib.parse.urlencode({
            "client_id": key, "response_type": "code", "token_access_type": "offline",
            "code_challenge": challenge, "code_challenge_method": "S256"}))
        print("\nThen: dropbox-files auth <code>")
        return
    if not argv or not PENDING.exists():
        die("start with: dropbox-files auth --app-key <App key>")
    p = json.loads(PENDING.read_text())
    r = json.load(http(OAUTH, urllib.parse.urlencode({"code": argv[0].strip(), "grant_type": "authorization_code",
                                                       "client_id": p["key"], "code_verifier": p["verifier"]}).encode()))
    CRED.write_text(json.dumps({"DROPBOX_APP_KEY": p["key"], "DROPBOX_REFRESH_TOKEN": r["refresh_token"]}, indent=2) + "\n")
    os.chmod(CRED, 0o600)
    PENDING.unlink()
    print(f"Connected for this session. The two values to save in the environment are in {CRED}")
    print("(do not print the refresh token into the chat).")


def main():
    a = sys.argv[1:]
    if not a or a[0] in ("-h", "--help"):
        sys.exit(__doc__)
    if a[0] == "auth":
        cmd_auth(a[1:])
    elif a[0] == "check":
        acct = rpc("users/get_current_account", None)
        print("Dropbox OK:", acct["name"]["display_name"])
        cmd_ls("/")
    elif a[0] == "ls":
        cmd_ls(a[1] if len(a) > 1 else "/")
    elif a[0] == "pull" and len(a) == 3:
        cmd_pull(a[1], a[2])
    elif a[0] == "push" and len(a) >= 3:
        cmd_push(a[1:-1], a[-1])
    else:
        sys.exit(__doc__)


main()
PY
chmod 0755 /usr/local/bin/dropbox-files
log "footage-intake, video-finish and dropbox-files ready"

# 4. The skill.
mkdir -p "$SKILLS/video-editor"
cat > "$SKILLS/video-editor/SKILL.md" <<'MD'
---
name: video-editor
description: Edit the user's own footage into a finished video - they send video clips, photos, a logo or music and want them cut together with titles, transitions, captions, music and a clean sound mix, as a promo, reel, short, ad, recap, testimonial or talking-head edit. Use when the user sends or points to clips or photos and asks for a video, an edit, a reel, a cut-down, captions on a video, or a vertical version. Not for watching someone else's video (watch-video) or a video made with no footage (hyperframes).
---

# Video editor

You are the company's video editor. The user sends raw material; you return a
finished, publishable video and say plainly what you did. You cannot hear and
you only see frames you extract, so **measure and look; never assume**.

## Tools

| Job | Tool |
|---|---|
| See everything that was sent | `footage-intake <folder> --conform` |
| The edit itself: timeline, titles, lower thirds, transitions, captions, grades, sound mix | HyperFrames: load the `hyperframes:hyperframes` skill and follow it; `hyperframes:media-use` for voice, music, grades; `hyperframes:hyperframes-registry` before hand-building any title, transition or caption style |
| Prepare a clip: trim, remove silences, stabilise, speed, detect scenes | `kino <command>` (`kino --help`), or the `kinocut` MCP tools, or plain `ffmpeg` |
| Master and check the render | `video-finish render.mp4 final.mp4` |
| Long talking-head or podcast edits, studio-quality voice clean-up | Descript connector (`mcp__Descript__*`), if the user wants it |
| Generated b-roll, images, upscaling | fal or Higgsfield connectors. They cost money per run: say the price and ask first |
| A share link that streams | Mux connector, if connected |

## 1. Get the footage

- **Dropbox, the usual way**: each job is a folder in the editing folder
  (`Dropbox/Apps/<app name>/<job>/` with an App-folder app, where `/` below
  is that app folder). `dropbox-files ls /` shows the jobs;
  `dropbox-files pull "/<job>" ~/video-jobs/<job>/footage` downloads every
  file in it (it skips earlier `FINAL...` uploads).
- **Dropbox, anywhere else in the account** (or if `dropbox-files check` says
  it is not connected): find the files with `mcp__Dropbox__search` or
  `list_folder`, get links with `mcp__Dropbox__download_link` (up to 25 per
  call), and download each with `curl -fsSL -o <name> "<url>"` straight away.
  Each link works **once** and expires in 10 minutes: no HEAD, no retry on the
  same link. This route can download but cannot upload.
- **Uploaded in the chat**: copy the files into the job folder.
- **A public link**: `yt-dlp` or `curl`. Never cookies or logins.
- Put everything in one job folder, `~/video-jobs/<short-name>/footage/`, and
  never modify an original.

## 2. Look before you plan

```bash
footage-intake ~/video-jobs/<name>/footage --conform
```

Read `_intake/inventory.md`, look at every sheet in `_intake/sheets/` and
`_intake/photos.jpg` with the Read tool, and read every transcript. Phone
footage is usually HEVC, often HDR, and photos HEIC: **use the copies in
`_intake/conformed/` whenever the inventory lists one**. A converted HDR clip
can come out darker than it should: compare it with the other clips and lift
its exposure in the grade if so. For a moment that
matters, pull frames yourself:
`ffmpeg -ss 12.5 -i clip.mp4 -frames:v 1 -vf scale=960:-2 f.jpg`.

Note for each clip what is in it, its best seconds, and its problems (shaky,
dark, wind noise, someone mid-word at the end, burned-in text, vertical or
horizontal).

## 3. Agree the plan

Ask only what the material does not answer, in one message: what the video is
for and where it will be posted (this sets shape and length), the brand (logo,
colours, fonts, website, call to action), the tone, music, and anything that
must be in or out. Then propose the edit in 4 to 8 plain sentences: structure
beat by beat, length, shape, title and caption style, music, what you will
leave out. **Wait for a yes** before building, unless the user said not to
ask.

Defaults when the user has no preference:

| Destination | Shape | Length |
|---|---|---|
| Instagram Reels, TikTok, YouTube Shorts, Facebook Reels | 1080x1920 | 15-45 s |
| Instagram or Facebook feed | 1080x1350 | 15-60 s |
| YouTube, website, presentation | 1920x1080 | as needed |

30 fps. Sound at -14 LUFS for social, -16 for long YouTube and podcasts.

## 4. Build

Set the project up with HyperFrames in `~/video-jobs/<name>/edit/` and follow
its skill for the format, its check and its review. On top of that:

**The cut**
- Hook in the first 2 seconds: the strongest picture or line goes first.
- Cut on action or on a word boundary, never inside a word. Take word times
  from `_intake/transcripts/<clip>.json`; leave 50-150 ms of air either side.
- Every shot earns its place; a shot with no speech rarely needs more than
  2-4 s. Vary the framing from shot to shot.
- Speech drives the edit: lay the best lines down first, then cover the joins
  with b-roll. Keep laughs and reactions; they are the beat.
- Remove dead air from talking clips first:
  `kino video-ai-remove-silence in.mp4 --silence-threshold -40 -o tight.mp4`.
- Shaky clip: `kino stabilize in.mp4 -o steady.mp4`, then check the frames;
  it crops in a little.

**Picture**
- Use hard cuts by default. One transition style per video, used with a
  reason (a change of place or time), 0.3-0.6 s. Not a different effect on
  every cut.
- Photos always move: a slow push-in or drift of 4-8 % over the shot.
- Mixed sources need matching: fix exposure and white balance per clip, then
  one look over everything (HyperFrames `media-treatment`, never CSS filters).
- Titles: two typefaces at most, the brand's if given. Keep text inside the
  title-safe area and on screen long enough to read twice. At phone size
  nothing under 28 px on a 1080 px-wide frame.
- Captions on anything with speech that goes to social (most people watch
  muted). Word timings from the transcript. Captions must never collide with a
  lower third or the platform's own buttons: on 9:16 keep them out of the
  bottom 20 % and top 10 %.
- **A vertical or square version is a new layout, not a resize.** Rebuild at
  the new size and choose where each shot is cropped (`object-fit: cover` and
  `object-position` on the subject). Never letterbox or pillarbox with bars:
  `kino resize -a 9:16` pads with black, so do not use it for this. Footage
  with baked-in black bars gets cropped in.

**Sound**
- Speech is the reference. Music sits 14-20 dB under speech while anyone
  talks (a volume lane at about 0.3) and comes up in the gaps.
- Fade every audio edit 20-30 ms so nothing clicks; fade music out over
  1.5-3 s at the end, never a dead stop.
- Clip sound you keep (a cheer, waves, a door) is levelled against speech, not
  left at camera level. Mute camera sound under music unless it adds something.
- **Music must be licensed for business use.** In order: a track the user
  supplies; the HeyGen catalog through `media-use` (needs the user's free
  HeyGen sign-in); a paid generation through fal or Higgsfield (ask first).
  Local MusicGen is for drafts only: its model weights are published under a
  non-commercial licence, so do not ship it in client or advertising work
  without the user's say-so. Never use a commercial song the user has no
  licence for; say why.

## 5. Check, master, deliver

1. HyperFrames `check` passes; look at snapshots of every title, caption group
   and transition.
2. Render, then `video-finish render.mp4 final.mp4`. Read its report: loudness
   on target, no unexpected black, silent or frozen sections, and the length
   you promised. Look at the `.qc.jpg` it writes.
3. Look hard at the first frame (it is the thumbnail), each cut (frames 0.1 s
   either side) and the last 2 s.
4. `kino release-checkpoint final.mp4` gives a second opinion. Its score is a
   guide: read its reasons, and ignore "desaturated" on footage that is
   meant to be pale.
5. Up to three fix-and-check rounds, then deliver anyway and list what is
   still not right.

Name the file `FINAL - <job> - <shape> v1.mp4` (v2, v3 for revisions) and
upload it to the job's own Dropbox folder:
`dropbox-files push "FINAL - <job> - 9x16 v1.mp4" "/<job>"`. It never
overwrites: Dropbox keeps every version. Also send it with SendUserFile
(`display: render`). If Dropbox is not connected, say so and send the file in
the chat only. Then say in a few lines:
length, shape, what is in it, what you left out and why, any music or licence
note, and what you could not check (you cannot hear it: give the numbers).
Offer the other shapes if they would help.

## Revisions and keeping work

Keep the job folder for the whole session; a change is an edit to the
project, then a new render with a new file name (`-v2`). Never re-transcribe
or re-convert what is already in `_intake/`. The container is wiped when the
session ends: tell the user the final files are theirs to save, and that the
source footage should stay in Dropbox so a later session can rebuild.

## Connecting Dropbox (once per environment)

Only the user can do steps 1 and 4. Never print the refresh token in the chat.

1. The user creates a Dropbox app: dropbox.com/developers/apps, Create app,
   Scoped access, **App folder**, a name (for example "Claude Video Editor").
   On the **Permissions** tab tick `files.metadata.read`, `files.content.read`
   and `files.content.write`, then Submit. On **Settings** copy the **App key**
   (not the secret; it is not needed).
2. `dropbox-files auth --app-key <App key>` prints a link. The user opens it,
   clicks Allow, and pastes back the code Dropbox shows (single use).
3. `dropbox-files auth <code>`, then `dropbox-files check`. Dropbox now works
   for this session.
4. For every later session, the user saves two **Environment variables** in
   the environment (session title bar, environment menu, Edit):
   `DROPBOX_APP_KEY` and `DROPBOX_REFRESH_TOKEN`, copied from
   `~/.config/dropbox-files/credentials.json` (copy that file to the
   scratchpad so they can open it; delete the copy afterwards).

## Rights

Edit what the user owns or is allowed to use. People who are clearly
identifiable in an advert should have agreed to be in it. Someone else's
video, music or images need permission; say so when it comes up.
MD
log "video-editor skill ready"

# 5. The Kinocut MCP server (user scope, ~/.claude.json). Its default surface
# lists 18 tools; the rest are reached through its operation families.
python3 - <<'PY'
import json, pathlib
state = pathlib.Path.home() / ".claude.json"
c = json.loads(state.read_text()) if state.exists() else {}
c.setdefault("mcpServers", {})["kinocut"] = {
    "type": "stdio", "command": "/usr/local/bin/kino", "args": ["--mcp"], "env": {}}
state.write_text(json.dumps(c, indent=2) + "\n")
PY
log "done"
