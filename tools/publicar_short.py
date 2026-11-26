#!/usr/bin/env python3
"""Unified YouTube Shorts Generator & Publisher for PhotoHacks.
Reads the short pipeline from data/shorts_estrategia.json, renders the episode,
and publishes it as PRIVATE on YouTube Studio via CDP, leaving it open for user validation.

Usage:
    python3 tools/publicar_short.py              # Automatically processes the next pending short
    python3 tools/publicar_short.py --id 1       # Forces a specific episode
    python3 tools/publicar_short.py --solo-video # Only renders the MP4 without uploading
"""
import os
import sys
import json
import time
import argparse
import subprocess
from datetime import datetime, timezone
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
JSON_PATH = os.path.join(ROOT, "data", "shorts_estrategia.json")
OUT_DIR = os.path.join(ROOT, "build", "video")
RAW_DIR = os.path.join(OUT_DIR, "raw")
BRAND = os.path.join(ROOT, "assets", "marca")
AUDIO = os.path.join(ROOT, "assets", "audio")
FONTS = os.path.join(ROOT, "assets", "fuentes")
AUTO_DIR = "/home/ganso/codigo/automatizaciones"

W = 1080
H = 1920
FONT_RUSSO = os.path.join(FONTS, "RussoOne-Regular.ttf")
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def get_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def create_shorts_badge(tag, headline, subline, filename, primary_neon=(255, 119, 0), accent_neon=(255, 200, 0), sub_color=(0, 210, 255)):
    """Creates a high-contrast pedagogical badge with solid plate backing for YouTube Shorts Safe Zone."""
    bw = 960
    bh = 260
    pad = 25
    total_w = bw + pad * 2
    total_h = bh + pad * 2

    # Drop shadow
    shadow = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    ds.rounded_rectangle([(pad - 4, pad + 6), (pad + bw + 4, pad + bh + 14)], radius=24, fill=(0, 0, 0, 240))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))

    # Outer bloom
    bloom = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    db = ImageDraw.Draw(bloom)
    db.rounded_rectangle([(pad, pad), (pad + bw, pad + bh)], radius=22, outline=tuple(primary_neon) + (230,), width=14)
    bloom = bloom.filter(ImageFilter.GaussianBlur(10))

    # Solid plate
    plate = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    dp = ImageDraw.Draw(plate)
    dp.rounded_rectangle([(pad, pad), (pad + bw, pad + bh)], radius=22, fill=(10, 14, 22, 255))

    # 8px main orange border
    dp.rounded_rectangle([(pad, pad), (pad + bw, pad + bh)], radius=22, outline=tuple(primary_neon) + (255,), width=8)
    dp.rounded_rectangle([(pad + 7, pad + 7), (pad + bw - 7, pad + bh - 7)], radius=16, outline=(255, 255, 255, 130), width=2)

    # Corner brackets (8px thick)
    c_len = 50
    p_acc = tuple(accent_neon) + (255,)
    dp.line([(pad + 16, pad), (pad + 16 + c_len, pad)], fill=p_acc, width=8)
    dp.line([(pad, pad + 16), (pad, pad + 16 + c_len)], fill=p_acc, width=8)
    dp.line([(pad + bw - 16 - c_len, pad), (pad + bw - 16, pad)], fill=p_acc, width=8)
    dp.line([(pad + bw, pad + 16), (pad + bw, pad + 16 + c_len)], fill=p_acc, width=8)

    dp.line([(pad + 16, pad + bh), (pad + 16 + c_len, pad + bh)], fill=p_acc, width=8)
    dp.line([(pad, pad + bh - 16 - c_len), (pad, pad + bh - 16)], fill=p_acc, width=8)
    dp.line([(pad + bw - 16 - c_len, pad + bh), (pad + bw - 16, pad + bh)], fill=p_acc, width=8)
    dp.line([(pad + bw, pad + bh - 16 - c_len), (pad + bw, pad + bh - 16)], fill=p_acc, width=8)

    f_tag = get_font(FONT_RUSSO if os.path.exists(FONT_RUSSO) else FONT_BOLD, 22)
    f_head = get_font(FONT_RUSSO if os.path.exists(FONT_RUSSO) else FONT_BOLD, 33)
    f_sub = get_font(FONT_BOLD, 24)

    # Header Tag Pill
    tag_bbox = dp.textbbox((0, 0), tag, font=f_tag)
    pill_w = (tag_bbox[2] - tag_bbox[0]) + 34
    pill_h = 40
    pill_x = pad + 35
    pill_y = pad + 24
    dp.rounded_rectangle([(pill_x, pill_y), (pill_x + pill_w, pill_y + pill_h)], radius=8, fill=tuple(primary_neon))
    dp.text((pill_x + 17, pill_y + 8), tag, font=f_tag, fill=(0, 0, 0, 255))

    # Headline
    hx = pad + 35
    hy = pad + 86
    for dx in (-3, 0, 3):
        for dy in (-3, 0, 3):
            dp.text((hx + dx, hy + dy), headline, font=f_head, fill=(0, 0, 0, 255))
    dp.text((hx, hy), headline, font=f_head, fill=(255, 255, 255))

    # Subline
    sy = pad + 168
    dp.line([(hx, sy - 14), (pad + bw - 35, sy - 14)], fill=(60, 80, 110, 220), width=2)
    dp.text((hx, sy), subline, font=f_sub, fill=tuple(sub_color))

    final = Image.alpha_composite(shadow, bloom)
    final = Image.alpha_composite(final, plate)
    out_path = os.path.join(OUT_DIR, filename)
    final.save(out_path)
    return out_path


def create_outro_card(filename):
    """Creates a full-frame 1080x1920 outro overlay with PhotoHacks brand plate."""
    box_w = 980
    box_h = 940
    bx = (W - box_w) // 2
    by = 470

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    ds.rounded_rectangle([(bx - 8, by + 8), (bx + box_w + 8, by + box_h + 20)], radius=28, fill=(0, 0, 0, 240))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))

    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    db = ImageDraw.Draw(bloom)
    db.rounded_rectangle([(bx, by), (bx + box_w, by + box_h)], radius=26, outline=(255, 119, 0, 240), width=16)
    bloom = bloom.filter(ImageFilter.GaussianBlur(12))

    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = ImageDraw.Draw(plate)
    dp.rounded_rectangle([(bx, by), (bx + box_w, by + box_h)], radius=26, fill=(10, 16, 26, 255))

    dp.rounded_rectangle([(bx, by), (bx + box_w, by + box_h)], radius=26, outline=(255, 119, 0, 255), width=10)
    dp.rounded_rectangle([(bx + 8, by + 8), (bx + box_w - 8, by + box_h - 8)], radius=20, outline=(255, 200, 0, 200), width=3)

    # Brand icon
    icon_path = os.path.join(BRAND, "icono.png")
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert("RGBA")
        icon.thumbnail((260, 260), Image.LANCZOS)
        iw, ih = icon.size
        plate.paste(icon, ((W - iw) // 2, by + 45), icon)

    f_title = get_font(FONT_RUSSO if os.path.exists(FONT_RUSSO) else FONT_BOLD, 42)
    f_sub = get_font(FONT_BOLD, 26)
    f_badge = get_font(FONT_BOLD, 25)
    f_cta = get_font(FONT_RUSSO if os.path.exists(FONT_RUSSO) else FONT_BOLD, 34)
    f_store = get_font(FONT_BOLD, 26)

    title = "PHOTOHACKS"
    bb = dp.textbbox((0, 0), title, font=f_title)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 285), title, font=f_title, fill=(255, 119, 0))

    text1 = "APRENDE FOTOGRAFÍA JUGANDO"
    bb = dp.textbbox((0, 0), text1, font=f_sub)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 345), text1, font=f_sub, fill=(255, 220, 100))

    dp.rounded_rectangle([(bx + 40, by + 420), (bx + box_w - 40, by + 500)], radius=14, fill=(20, 30, 48, 255), outline=(255, 119, 0, 220), width=3)
    pill_text = "100% GRATIS · SIN ANUNCIOS · CERO FILTROS"
    bb = dp.textbbox((0, 0), pill_text, font=f_badge)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 446), pill_text, font=f_badge, fill=(255, 255, 255))

    pill_text2 = "RÉFLEX · TELEMÉTRICA · TLR · ANALÓGICA"
    bb = dp.textbbox((0, 0), pill_text2, font=f_badge)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 535), pill_text2, font=f_badge, fill=(0, 210, 255))

    btn_w = 520
    btn_h = 72
    btn_x = (W - btn_w) // 2
    btn_y = by + 630
    dp.rounded_rectangle([(btn_x, btn_y), (btn_x + btn_w, btn_y + btn_h)], radius=14, fill=(255, 119, 0))
    cta = "JUEGA GRATIS EN ITCH.IO"
    bb = dp.textbbox((0, 0), cta, font=f_cta)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, btn_y + 16), cta, font=f_cta, fill=(0, 0, 0, 255))

    store = "DISPONIBLE PARA PC Y TELÉFONOS ANDROID"
    bb = dp.textbbox((0, 0), store, font=f_store)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 740), store, font=f_store, fill=(200, 220, 255))

    guide = "Busca: PhotoHacks en itch.io"
    bb = dp.textbbox((0, 0), guide, font=f_sub)
    tw = bb[2] - bb[0]
    dp.text(((W - tw) // 2, by + 810), guide, font=f_sub, fill=(255, 200, 0))

    final = Image.alpha_composite(shadow, bloom)
    final = Image.alpha_composite(final, plate)
    out_path = os.path.join(OUT_DIR, filename)
    final.save(out_path)
    return out_path


def create_preview_thumbnail(ep, filename):
    """Generates a high-contrast thumbnail/preview card with the preview text."""
    img = Image.new("RGBA", (W, H), (10, 14, 22, 255))
    dp = ImageDraw.Draw(img)

    preview_text = ep.get("preview_text", "")
    if preview_text:
        f_preview = get_font(FONT_RUSSO if os.path.exists(FONT_RUSSO) else FONT_BOLD, 72)
        bb = dp.textbbox((0, 0), preview_text, font=f_preview)
        tw = bb[2] - bb[0]
        th = bb[3] - bb[1]
        
        # Pill behind preview text
        pad_x, pad_y = 40, 20
        px = (W - tw) // 2
        py = 960 - th // 2
        dp.rounded_rectangle([(px - pad_x, py - pad_y), (px + tw + pad_x, py + th + pad_y)], radius=20, fill=(0, 0, 0, 220), outline=(255, 119, 0, 255), width=6)
        dp.text((px, py), preview_text, font=f_preview, fill=(255, 220, 100))

    out_path = os.path.join(OUT_DIR, filename)
    img.save(out_path)
    return out_path


def render_short_video(ep):
    """Renders the video for a PhotoHacks short episode."""
    print(f"\n[VIDEO BUILD] Rendering Episode #{ep['id']} ({ep['slug']})...")
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RAW_DIR, exist_ok=True)

    raw_bokeh = os.path.join(RAW_DIR, "short_raw_bokeh_sweep.avi")
    godot_bin = os.path.expanduser("~/bin/godot-4-fp")
    base_godot = [godot_bin, "--path", ROOT, "--disable-vsync", "--rendering-method", "forward_plus", "--fixed-fps", "30"]

    if os.path.exists(raw_bokeh):
        os.remove(raw_bokeh)

    print("Recording scene: Seated on bench tight telephoto bokeh sweep (135mm)...")
    subprocess.run(base_godot + [
        "--resolution", "1920x1080",
        "--write-movie", raw_bokeh,
        "--fixed-fps", "30",
        "--quit-after", "360", "--",
        "--profile=Ultra", "--time=day", "--stage=sentado",
        "--lens=2,5", "--focal=135", "--angle=125", "--pitch=-2",
        "--aperture-sweep", "--hud=0"
    ], check=True)

    # Generate custom high-voltage pedagogical badge
    b_main = create_shorts_badge(
        ep["tag_pill"],
        ep["headline"],
        ep["subline"],
        f"badge_ep_{ep['id']}.png",
        primary_neon=ep.get("primary_neon", [255, 119, 0]),
        accent_neon=ep.get("accent_neon", [255, 200, 0]),
        sub_color=ep.get("sub_color", [0, 210, 255])
    )
    b_outro = create_outro_card(f"outro_ep_{ep['id']}.png")

    # Render Scenes
    # Cut 1: Telephoto Bokeh sweep (12.0s) with live aperture indicator
    c1 = os.path.join(OUT_DIR, f"ep{ep['id']}_c1.mp4")
    f_badge = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    f1 = (
        f"[0:v]split=2[bg_src][gm_src];"
        f"[bg_src]scale=1080:1920,setsar=1,gblur=sigma=32,eq=brightness=-0.35[bg];"
        f"[gm_src]crop=1120:624:160:32,scale=1080:602:flags=lanczos,setsar=1[game];"
        f"[bg][game]overlay=0:658[framed];"
        f"[framed]drawbox=x=0:y=656:w=1080:h=606:color=0xff7700:t=4[framed2];"
        f"[1:v]format=rgba,fade=in:st=0.2:d=0.3:alpha=1[b1];"
        f"[framed2][b1]overlay=60:260:eof_action=repeat[v1];"
        f"[v1]drawbox=x=260:y=1285:w=560:h=50:color=0x0a0e16@0.92:t=fill,"
        f"drawbox=x=260:y=1285:w=560:h=50:color=0xff7700:t=2,"
        f"drawtext=fontfile={f_badge}:text='f/1.8 · MÁXIMO BOKEH':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,0,1.5)',"
        f"drawtext=fontfile={f_badge}:text='f/2.8 · CIERRA DIAFRAGMA':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,1.5,3.0)',"
        f"drawtext=fontfile={f_badge}:text='f/4.0 · EL FONDO APARECE':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,3.0,4.5)',"
        f"drawtext=fontfile={f_badge}:text='f/5.6 · SILUETAS VISIBLES':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,4.5,6.0)',"
        f"drawtext=fontfile={f_badge}:text='f/8.0 · PROFUNDIDAD MEDIA':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,6.0,7.5)',"
        f"drawtext=fontfile={f_badge}:text='f/11 · CASI TODO NÍTIDO':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=white:enable='between(t,7.5,9.0)',"
        f"drawtext=fontfile={f_badge}:text='f/16 · TODO EN ENFOQUE':x=(w-text_w)/2:y=1298:fontsize=23:fontcolor=0xffc800:enable='between(t,9.0,12.0)',setsar=1[outv]"
    )
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-ss", "0.0", "-t", "12.0", "-i", raw_bokeh,
        "-loop", "1", "-framerate", "30", "-i", b_main,
        "-filter_complex", f1,
        "-map", "[outv]",
        "-aspect", "9:16",
        "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
        "-t", "12.0",
        c1
    ], check=True)

    # Cut 2: Outro (4.0s)
    c2 = os.path.join(OUT_DIR, f"ep{ep['id']}_c2.mp4")
    f2 = (
        f"[0:v]scale=1080:1920,setsar=1,gblur=sigma=36,eq=brightness=-0.45[bg];"
        f"[1:v]format=rgba,fade=in:st=0.0:d=0.3:alpha=1[card];"
        f"[bg][card]overlay=0:0:eof_action=repeat,setsar=1[outv]"
    )
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-ss", "1.0", "-t", "4.0", "-i", raw_bokeh,
        "-loop", "1", "-framerate", "30", "-i", b_outro,
        "-filter_complex", f2,
        "-map", "[outv]",
        "-aspect", "9:16",
        "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
        "-t", "4.0",
        c2
    ], check=True)

    # Concat video
    concat_list = os.path.join(OUT_DIR, "concat_list.txt")
    with open(concat_list, "w") as f:
        f.write(f"file '{c1}'\nfile '{c2}'\n")

    video_only = os.path.join(OUT_DIR, f"ep{ep['id']}_video_only.mp4")
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-f", "concat", "-safe", "0", "-i", concat_list,
        "-c", "copy",
        video_only
    ], check=True)

    # Audio Design
    music = os.path.join(AUDIO, "musica_videos.mp3")
    s_shutter = os.path.join(AUDIO, "camara", "obturador_reflex.wav")
    s_dial = os.path.join(AUDIO, "camara", "dial_1.wav")
    s_birds = os.path.join(AUDIO, "ambiente", "pajaros_dia.wav")

    total_len = 16.0
    audio_mix_filter = (
        f"[1:a]volume=0.30,afade=t=in:st=0.0:d=1.0,afade=t=out:st={total_len - 1.5}:d=1.5[bgm];"
        f"[2:a]volume=0.40,afade=t=in:st=0.0:d=0.5,afade=t=out:st={total_len - 1.0}:d=1.0[amb];"
        f"[3:a]adelay=1500|1500,volume=0.85[d1];"
        f"[4:a]adelay=3000|3000,volume=0.85[d2];"
        f"[5:a]adelay=4500|4500,volume=0.85[d3];"
        f"[6:a]adelay=6000|6000,volume=0.85[d4];"
        f"[7:a]adelay=7500|7500,volume=0.85[d5];"
        f"[8:a]adelay=9000|9000,volume=0.85[d6];"
        f"[9:a]adelay=11500|11500,volume=1.0[shut];"
        f"[bgm][amb][d1][d2][d3][d4][d5][d6][shut]amix=inputs=9:duration=longest:dropout_transition=2,"
        f"loudnorm=I=-14:LRA=11:TP=-1.0[aout]"
    )

    out_file = ep["video_file"]
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-i", video_only,
        "-i", music,
        "-i", s_birds,
        "-i", s_dial,
        "-i", s_dial,
        "-i", s_dial,
        "-i", s_dial,
        "-i", s_dial,
        "-i", s_dial,
        "-i", s_shutter,
        "-filter_complex", audio_mix_filter,
        "-map", "0:v",
        "-map", "[aout]",
        "-c:v", "copy",
        "-aspect", "9:16",
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100",
        "-shortest",
        out_file
    ], check=True)

    print(f"[VIDEO BUILD] Complete: {out_file} ({os.path.getsize(out_file) // 1024} KB)")
    return out_file


def upload_via_cdp(ep):
    """Uploads the short to YouTube Studio via CDP in PRIVATE mode."""
    print(f"\n[UPLOAD] Initiating automated upload for Episode #{ep['id']} via CDP...")
    import urllib.request
    import websocket

    port = 9222
    # Ensure browser is running
    subprocess.run([os.path.join(AUTO_DIR, "launch-chrome.sh"), "geesebumps", "https://studio.youtube.com"], capture_output=True, text=True)
    time.sleep(2)

    tabs = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list").read())
    pages = [t for t in tabs if t.get("type") == "page"]
    if not pages:
        raise RuntimeError("No open tabs in Chromium")

    ws = websocket.create_connection(pages[0]["webSocketDebuggerUrl"], timeout=20, max_size=25 * 1024 * 1024)
    msg_id = 0

    def cdp_call(method, params=None):
        nonlocal msg_id
        msg_id += 1
        ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}))
        while True:
            resp = json.loads(ws.recv())
            if resp.get("id") == msg_id:
                if "error" in resp:
                    raise RuntimeError(f"CDP Error: {resp['error']}")
                return resp.get("result", {})

    def eval_js(js):
        res = cdp_call("Runtime.evaluate", {"expression": js, "returnByValue": True, "awaitPromise": True})
        return res.get("result", {}).get("value")

    # Check for login challenge
    curr_url = eval_js("window.location.href")
    if "accounts.google.com" in curr_url:
        print("\n>>> ATENCIÓN: Se requiere login en la ventana de Chromium abierta en pantalla <<<")
        ws.close()
        return None

    # Navigate to upload or click upload
    print("Navigating to upload dialog...")
    eval_js("""(() => {
        const btn = document.querySelector('#upload-icon') || document.querySelector('ytcp-icon-button[aria-label*="Subir"]');
        if (btn) btn.click();
    })()""")
    time.sleep(2)

    doc = cdp_call("DOM.getDocument")
    root_id = doc["root"]["nodeId"]
    res = cdp_call("DOM.querySelector", {"nodeId": root_id, "selector": "input[type=file]"})
    input_node_id = res.get("nodeId")

    if not input_node_id or input_node_id == 0:
        time.sleep(2)
        doc = cdp_call("DOM.getDocument")
        res = cdp_call("DOM.querySelector", {"nodeId": doc["root"]["nodeId"], "selector": "input[type=file]"})
        input_node_id = res.get("nodeId")

    if not input_node_id or input_node_id == 0:
        ws.close()
        raise RuntimeError("Could not find input[type=file] in upload modal")

    print(f"Feeding file: {ep['video_file']}")
    cdp_call("DOM.setFileInputFiles", {"files": [ep["video_file"]], "nodeId": input_node_id})
    time.sleep(5)

    # Set Title
    print("Setting Title...")
    escaped_title = json.dumps(ep["title"])
    eval_js(f"""(() => {{
        const el = document.querySelector('#title-textarea #textbox') || document.querySelectorAll('ytcp-social-suggestions-textbox #textbox')[0];
        if (el) {{
            el.focus();
            document.execCommand('selectAll', false, null);
            document.execCommand('insertText', false, {escaped_title});
            el.dispatchEvent(new Event('input', {{ bubbles: true }}));
        }}
    }})()""")
    time.sleep(1)

    # Set Description
    print("Setting Description...")
    escaped_desc = json.dumps(ep["description"])
    eval_js(f"""(() => {{
        const boxes = document.querySelectorAll('ytcp-social-suggestions-textbox #textbox');
        if (boxes.length >= 2) {{
            const descEl = boxes[1];
            descEl.focus();
            document.execCommand('selectAll', false, null);
            document.execCommand('insertText', false, {escaped_desc});
            descEl.dispatchEvent(new Event('input', {{ bubbles: true }}));
        }}
    }})()""")
    time.sleep(1)

    # Set Audience: Not Made for Kids
    print("Setting Audience: Not Made for Kids...")
    eval_js("""(() => {
        const notForKids = document.querySelector('tp-yt-paper-radio-button[name="VIDEO_MADE_FOR_KIDS_NOT_MFK"]');
        if (notForKids) notForKids.click();
    })()""")
    time.sleep(1)

    # Show More & Tags
    print("Setting Tags...")
    eval_js("""(() => {
        const toggle = document.querySelector('#toggle-button') || Array.from(document.querySelectorAll('button, ytcp-button')).find(b => b.innerText && (b.innerText.includes('MOSTRAR MÁS') || b.innerText.includes('SHOW MORE')));
        if (toggle) toggle.click();
    })()""")
    time.sleep(1)

    escaped_tags = json.dumps(ep["tags"])
    eval_js(f"""(() => {{
        const input = document.querySelector('#tags-container #text-input') || document.querySelector('input[aria-label*="Etiquetas"]');
        if (input) {{
            input.focus();
            document.execCommand('insertText', false, {escaped_tags} + ',');
            input.dispatchEvent(new Event('input', {{ bubbles: true }}));
            input.dispatchEvent(new KeyboardEvent('keydown', {{ key: 'Enter', keyCode: 13, bubbles: true }}));
        }}
    }})()""")
    time.sleep(1)

    # Step through wizard
    print("Stepping through wizard to Visibility...")
    eval_js("""(() => {
        const dialog = document.querySelector('ytcp-uploads-dialog');
        const step3 = dialog?.querySelector('#step-badge-3');
        if (step3) step3.click();
    })()""")
    time.sleep(2)

    # Select Private
    print("Selecting PRIVATE...")
    eval_js("""(() => {
        const priv = document.querySelector('tp-yt-paper-radio-button[name="PRIVATE"], #private-radio-button');
        if (priv) priv.click();
    })()""")
    time.sleep(1)

    # Grab assigned URL before closing dialog
    links = eval_js("""(() => {
        return Array.from(document.querySelectorAll('a'))
            .map(a => a.href)
            .filter(h => h && (h.includes('youtu.be/') || h.includes('youtube.com/shorts/')));
    })()""")
    short_url = links[0] if links else None

    # Save / Publish Video
    print("Saving video in Private mode...")
    eval_js("""(() => {
        const dialog = document.querySelector('ytcp-uploads-dialog');
        const c = dialog?.polymerController || dialog;
        if (c && typeof c.publishVideo === 'function') {
            c.publishVideo();
        } else {
            dialog?.querySelector('#done-button')?.click();
        }
    })()""")

    # Wait for dialog to dismiss naturally (up to 30s)
    print("Waiting for YouTube Studio to finalize save...")
    for _ in range(30):
        time.sleep(1)
        still_open = eval_js("!!document.querySelector('ytcp-uploads-dialog')")
        if not still_open:
            print("Dialog closed successfully.")
            break

    ws.close()

    # Navigate to Shorts list
    time.sleep(2)
    subprocess.run(["python3", os.path.join(AUTO_DIR, "cdp.py"), "-p", "geesebumps", "eval", "window.location.href = 'https://studio.youtube.com/channel/UC2wY7hsDgyrn_xU2COv_4Qg/videos/short'"], capture_output=True)

    return short_url


# ---- Episodes described as a recipe (data/shorts_estrategia.json: "takes" and "cuts") ----
# A take is a recording of the game (Godot's Movie Maker, 1440×810 at 30 FPS) with its own command
# line arguments; a cut is a stretch of a take («ss», «t»), the part of the screen it shows («crop»:
# "w:h:x:y" of the 1440×810 frame, or "full") and the captions under it («labels»: [start, end,
# text] in seconds of the cut). The game's own sound (shutter, dials, park) stays under the music.
def record_take(name, take, force=False):
    raw = os.path.join(RAW_DIR, f"take_{name}.avi")
    if os.path.exists(raw) and not force:
        return raw
    godot_bin = os.path.expanduser("~/bin/godot-4-fp")
    print(f"[TAKE] {name}: {' '.join(take['args'])}")
    subprocess.run([godot_bin, "--path", ROOT, "--disable-vsync", "--rendering-method", "forward_plus",
                    "--resolution", "1920x1080", "--write-movie", raw, "--fixed-fps", "30",
                    "--quit-after", str(int(take["secs"] * 30)), "--"] + take["args"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not os.path.exists(raw):
        raise SystemExit(f"La toma {name} no se ha grabado.")
    return raw


def render_cut(ep, k, cut, raw, badge):
    """One cut: the game framed in the middle of a 1080×1920 canvas over its own blurred image, the
    episode's badge in the top safe zone and the captions in a plate under the game."""
    out = os.path.join(OUT_DIR, f"ep{ep['id']}_cut{k}.mp4")
    crop = cut.get("crop", "1120:624:160:32")
    crop_f = "null" if crop == "full" else f"crop={crop}"
    labels = []
    for n, (start, end, text) in enumerate(cut.get("labels", [])):
        tf = os.path.join(OUT_DIR, f"ep{ep['id']}_cut{k}_l{n}.txt")
        open(tf, "w", encoding="utf-8").write(text)
        labels.append((start, end, tf))
    accent = "0x%02x%02x%02x" % tuple(ep.get("primary_neon", [255, 119, 0]))
    draw = ",".join(
        f"drawbox=x=80:y=1290:w=920:h=78:color=0x0a0e16@0.92:t=fill:enable='between(t,{a},{b})',"
        f"drawbox=x=80:y=1290:w=920:h=78:color={accent}:t=3:enable='between(t,{a},{b})',"
        f"drawtext=fontfile={FONT_BOLD}:textfile={tf}:expansion=none:x=(w-text_w)/2:y=1314:fontsize=32:"
        f"fontcolor=white:enable='between(t,{a},{b})'" for a, b, tf in labels) or "null"
    graph = (
        f"[0:v]split=2[bg_src][gm_src];"
        f"[bg_src]scale=-2:1920,crop=1080:1920,setsar=1,gblur=sigma=32,eq=brightness=-0.35[bg];"
        f"[gm_src]{crop_f},scale=1080:-2:flags=lanczos,setsar=1[game];"
        f"[bg][game]overlay=0:(H-h)/2-30[framed];"
        f"[framed]drawbox=x=0:y=(ih-608)/2-32:w=1080:h=612:color={accent}:t=4[framed2];"
        f"[1:v]format=rgba[b1];"
        f"[framed2][b1]overlay=60:230:eof_action=repeat[v1];"
        f"[v1]{draw},fade=t=in:st=0:d=0.25,fade=t=out:st={cut['t'] - 0.25}:d=0.25,setsar=1[outv];"
        f"[0:a]afade=t=in:st=0:d=0.25,afade=t=out:st={cut['t'] - 0.25}:d=0.25,aresample=48000[outa]"
    )
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(cut["ss"]), "-t", str(cut["t"]), "-i", raw,
                    "-loop", "1", "-framerate", "30", "-i", badge, "-filter_complex", graph,
                    "-map", "[outv]", "-map", "[outa]", "-t", str(cut["t"]), "-aspect", "9:16",
                    "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
                    "-c:a", "pcm_s16le", out], check=True)
    return out


def render_recipe(ep, force=False):
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RAW_DIR, exist_ok=True)
    raws = {name: record_take(name, take, force) for name, take in ep["takes"].items()}
    badge = create_shorts_badge(ep["tag_pill"], ep["headline"], ep["subline"], f"badge_ep_{ep['id']}.png",
                                primary_neon=ep.get("primary_neon", [255, 119, 0]),
                                accent_neon=ep.get("accent_neon", [255, 200, 0]),
                                sub_color=ep.get("sub_color", [0, 210, 255]))
    clips = [render_cut(ep, k, cut, raws[cut["take"]], badge) for k, cut in enumerate(ep["cuts"])]
    # The closing card over the blurred last frame of the last take, in silence (the music goes on).
    outro = create_outro_card(f"outro_ep_{ep['id']}.png")
    last = ep["cuts"][-1]
    c_out = os.path.join(OUT_DIR, f"ep{ep['id']}_outro.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(last["ss"]), "-t", "4", "-i", raws[last["take"]],
                    "-loop", "1", "-framerate", "30", "-i", outro, "-f", "lavfi", "-t", "4", "-i", "anullsrc=r=48000:cl=stereo",
                    "-filter_complex", "[0:v]scale=-2:1920,crop=1080:1920,setsar=1,gblur=sigma=36,eq=brightness=-0.45[bg];"
                    "[1:v]format=rgba,fade=in:st=0.0:d=0.3:alpha=1[card];[bg][card]overlay=0:0:eof_action=repeat,setsar=1[outv]",
                    "-map", "[outv]", "-map", "2:a", "-t", "4", "-aspect", "9:16", "-c:v", "libx264", "-preset", "fast",
                    "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "pcm_s16le", c_out], check=True)
    clips.append(c_out)
    lst = os.path.join(OUT_DIR, f"ep{ep['id']}_list.txt")
    open(lst, "w").write("".join(f"file '{c}'\n" for c in clips))
    joined = os.path.join(OUT_DIR, f"ep{ep['id']}_joined.mkv")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined], check=True)
    total = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", joined],
                                 capture_output=True, text=True).stdout)
    # Music under the game's sound, then -14 LUFS with the peak under -1 dBFS (two passes).
    music = os.path.join(AUDIO, "musica_videos.mp3")
    mix = (f"[1:a]volume=0.32,afade=t=in:st=0:d=1,afade=t=out:st={total - 2}:d=2[m];[0:a]volume=1.4[g];"
           f"[m][g]amix=inputs=2:duration=first:normalize=0")
    measure = subprocess.run(["ffmpeg", "-hide_banner", "-i", joined, "-i", music, "-filter_complex",
                              mix + ",loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                             capture_output=True, text=True).stderr
    m = json.loads(measure[measure.rindex("{"):measure.rindex("}") + 1])
    norm = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
            f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    out_file = ep["video_file"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", joined, "-i", music, "-filter_complex", mix + "," + norm + ",aresample=48000[a]",
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-aspect", "9:16", "-c:a", "aac", "-b:a", "192k",
                    "-movflags", "+faststart", "-shortest", out_file], check=True)
    print(f"[VIDEO BUILD] Complete: {out_file} ({total:.1f} s, {os.path.getsize(out_file) // 1024} KB)")
    return out_file


# ---- «Clase» format (season 2, 26-11-2026): a photography lesson, not an ad ----
# Four beats: the question (top plate, all along), the phenomenon (cuts with a title and a
# sentence under the image), the why (a cut, often a split of two takes) and the rule card with
# homework. No class number. Since 26-11-2026 (user: «quiero que la gente aprenda con los shorts, pero luego se
# vaya a la academia del juego a terminar de aprender») each class ends with a card of the game
# and where to practise that class in it («practica»), and the description says it near the top.
# Fields: "formato": "clase", "pregunta", "tema", "regla",
# "deberes"; cuts take "titulo"/"texto" (and "split": [left_take, right_take] with
# "split_labels").
C_BG = (10, 14, 22, 255)
C_GOLD = (255, 200, 90)
# The game, cut a little narrower than 16:9 to fill more of the 9:16 (1067×810 → 1080×820).
GAME_Y, GAME_H, GAME_CROP = 500, 820, "1067:810:(iw-1067)/2:0"
CAP_Y = GAME_Y + GAME_H + 18


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        test = (line + " " + word).strip()
        if draw.textbbox((0, 0), test, font=font)[2] > width and line:
            lines.append(line)
            line = word
        else:
            line = test
    return lines + ([line] if line else [])


def class_top_plate(ep, filename):
    """Topic pill and the question, in the top safe zone (y 230-560)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f_tag = get_font(FONT_BOLD, 26)
    f_q = get_font(FONT_RUSSO, 54)
    lines = wrap(d, ep["pregunta"], f_q, 900)
    h = 86 + 66 * len(lines) + 22
    d.rounded_rectangle([(50, 230), (W - 50, 230 + h)], radius=26, fill=(10, 14, 22, 225))
    d.rounded_rectangle([(50, 230), (W - 50, 230 + h)], radius=26, outline=C_GOLD + (255,), width=4)
    tag = ep["tema"].upper()
    tw = d.textbbox((0, 0), tag, font=f_tag)[2]
    d.rounded_rectangle([(90, 254), (90 + tw + 32, 254 + 44)], radius=10, fill=C_GOLD)
    d.text((106, 261), tag, font=f_tag, fill=(0, 0, 0))
    for k, line in enumerate(lines):
        d.text((90, 316 + 66 * k), line, font=f_q, fill=(255, 255, 255))
    out = os.path.join(OUT_DIR, filename)
    img.save(out)
    return out


def class_caption(title, text, filename, split_labels=None):
    """Title and sentence under the game (y 1270-1530), and, for a split, a label on each half."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f_title = get_font(FONT_RUSSO, 44)
    f_text = get_font(FONT_BOLD, 34)
    if title or text:
        lines = wrap(d, text or "", f_text, 900)
        h = 28 + (58 if title else 0) + 46 * len(lines) + 16
        d.rounded_rectangle([(50, CAP_Y), (W - 50, CAP_Y + h)], radius=22, fill=(10, 14, 22, 235))
        y = CAP_Y + 20
        if title:
            d.text((90, y), title, font=f_title, fill=C_GOLD)
            y += 58
        for line in lines:
            d.text((90, y), line, font=f_text, fill=(255, 255, 255))
            y += 46
    if split_labels:
        f_l = get_font(FONT_BOLD, 32)
        top = GAME_Y
        d.line([(W // 2, top), (W // 2, top + GAME_H)], fill=(255, 255, 255, 255), width=5)
        for k, lab in enumerate(split_labels):
            tw = d.textbbox((0, 0), lab, font=f_l)[2]
            x = (W // 4) * (1 + 2 * k) - tw // 2
            d.rounded_rectangle([(x - 16, top + 18), (x + tw + 16, top + 70)], radius=10, fill=(10, 14, 22, 220))
            d.text((x, top + 26), lab, font=f_l, fill=(255, 255, 255))
    out = os.path.join(OUT_DIR, filename)
    img.save(out)
    return out


def class_rule_card(ep, filename):
    """The rule and the homework, full screen over the blurred last image; a small icon at the foot."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f_head = get_font(FONT_BOLD, 30)
    f_rule = get_font(FONT_RUSSO, 60)
    f_hw = get_font(FONT_BOLD, 42)
    rule = wrap(d, ep["regla"], f_rule, 880)
    hw = wrap(d, ep["deberes"], f_hw, 880)
    y0 = 300
    h = 80 + 78 * len(rule) + 90 + 80 + 58 * len(hw) + 50
    d.rounded_rectangle([(50, y0), (W - 50, y0 + h)], radius=30, fill=(10, 14, 22, 240))
    d.rounded_rectangle([(50, y0), (W - 50, y0 + h)], radius=30, outline=C_GOLD + (255,), width=5)
    y = y0 + 40
    d.text((100, y), "LA REGLA", font=f_head, fill=C_GOLD)
    y += 56
    for line in rule:
        d.text((100, y), line, font=f_rule, fill=(255, 255, 255))
        y += 78
    y += 40
    d.line([(100, y), (W - 100, y)], fill=(80, 90, 110, 255), width=2)
    y += 40
    d.text((100, y), "PRUÉBALO HOY", font=f_head, fill=C_GOLD)
    y += 56
    for line in hw:
        d.text((100, y), line, font=f_hw, fill=(225, 232, 245))
        y += 58
    out = os.path.join(OUT_DIR, filename)
    img.save(out)
    return out


def class_game_card(ep, filename):
    """Closing card (user, 26-11-2026: learn with the short, then finish learning in the game's
    Academy): the game, what it is, where to practise this very class and where to get it."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1 = 50, 300, W - 50
    f_small = get_font(FONT_BOLD, 30)
    f_name = get_font(FONT_RUSSO, 72)
    f_text = get_font(FONT_BOLD, 38)
    f_prac = get_font(FONT_RUSSO, 44)
    f_link = get_font(FONT_BOLD, 34)
    what = wrap(d, "Una escuela de fotografía que se juega: 11 lecciones con teoría, práctica y examen.", f_text, 860)
    prac = wrap(d, ep["practica"], f_prac, 860)
    h = 40 + 170 + 52 * len(what) + 40 + 46 + 58 * len(prac) + 40 + 112 + 44
    d.rounded_rectangle([(x0, y0), (x1, y0 + h)], radius=30, fill=(10, 14, 22, 240))
    d.rounded_rectangle([(x0, y0), (x1, y0 + h)], radius=30, outline=(255, 119, 0, 255), width=5)
    y = y0 + 40
    icon_path = os.path.join(BRAND, "icono.png")
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert("RGBA")
        icon.thumbnail((130, 130), Image.LANCZOS)
        img.paste(icon, (100, y), icon)
    d.text((100 + 160, y + 8), "SIGUE APRENDIENDO EN", font=f_small, fill=C_GOLD)
    d.text((100 + 160, y + 46), "PhotoHacks", font=f_name, fill=(255, 119, 0))
    y += 170
    for line in what:
        d.text((100, y), line, font=f_text, fill=(235, 240, 250))
        y += 52
    y += 40
    d.text((100, y), "PRACTICA ESTA CLASE", font=f_small, fill=C_GOLD)
    y += 46
    for line in prac:
        d.text((100, y), line, font=f_prac, fill=(255, 255, 255))
        y += 58
    y += 40
    d.rounded_rectangle([(100, y), (x1 - 50, y + 112)], radius=16, fill=(255, 119, 0))
    for k, (line, font) in enumerate([("Gratis · PC, Mac, Linux, Android y navegador", get_font(FONT_BOLD, 28)), ("geese-bumps.itch.io/photohacks", f_link)]):
        tw = d.textbbox((0, 0), line, font=font)[2]
        d.text(((W - tw) // 2, y + 14 + 46 * k), line, font=font, fill=(0, 0, 0))
    out = os.path.join(OUT_DIR, filename)
    img.save(out)
    return out


def still_card(ep, raw, ss, card, secs, out, volume=0.6):
    """A card over the blurred image of a take, with the park's sound fading under it."""
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(ss), "-t", str(secs), "-i", raw,
                    "-loop", "1", "-framerate", "30", "-i", card,
                    "-filter_complex", "[0:v]scale=-2:1920,crop=1080:1920,setsar=1,gblur=sigma=36,eq=brightness=-0.4[bg];"
                    "[1:v]format=rgba,fade=in:st=0:d=0.4:alpha=1[c];[bg][c]overlay=0:0:eof_action=repeat,setsar=1[outv];"
                    f"[0:a]volume={volume},afade=t=out:st={secs - 1.5}:d=1.5,aresample=48000[outa]",
                    "-map", "[outv]", "-map", "[outa]", "-t", str(secs), "-aspect", "9:16", "-c:v", "libx264",
                    "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "pcm_s16le", out], check=True)
    return out


def class_raw(ep, name, force=False):
    raw = os.path.join(RAW_DIR, f"take_{name}.avi")
    if name in ep.get("takes", {}):
        return record_take(name, ep["takes"][name], force)
    if not os.path.exists(raw):
        raise SystemExit(f"Falta la toma {raw}")
    return raw


def render_class_cut(ep, k, cut, raws, top):
    out = os.path.join(OUT_DIR, f"ep{ep['id']}_cut{k}.mp4")
    cap = class_caption(cut.get("titulo", ""), cut.get("texto", ""), f"ep{ep['id']}_cap{k}.png", cut.get("split_labels"))
    t = cut["t"]
    y = GAME_Y
    fit = f"crop={GAME_CROP},scale=1080:{GAME_H}:flags=lanczos,setsar=1"
    if "split" in cut:
        a, b = cut["split"]
        inputs = ["-ss", str(cut["ss"]), "-t", str(t), "-i", raws[a], "-ss", str(cut["ss"]), "-t", str(t), "-i", raws[b]]
        game = (f"[0:v]{fit},split=2[ga][bg_src];"
                f"[1:v]{fit},crop=540:ih:540:0[gb];"
                "[ga][gb]overlay=540:0[game];")
        n = 2
    else:
        inputs = ["-ss", str(cut["ss"]), "-t", str(t), "-i", raws[cut["take"]]]
        game = f"[0:v]{fit},split=2[game][bg_src];"
        n = 1
    graph = (game +
             "[bg_src]scale=-2:1920,crop=1080:1920,setsar=1,gblur=sigma=32,eq=brightness=-0.35[bg];"
             f"[bg][game]overlay=0:{y}[framed];"
             f"[{n}:v]format=rgba[top];[{n + 1}:v]format=rgba[cap];"
             "[framed][top]overlay=0:0:eof_action=repeat[v1];[v1][cap]overlay=0:0:eof_action=repeat,"
             f"fade=t=in:st=0:d=0.25,fade=t=out:st={t - 0.25}:d=0.25,setsar=1[outv];"
             f"[0:a]afade=t=in:st=0:d=0.25,afade=t=out:st={t - 0.25}:d=0.25,aresample=48000[outa]")
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + inputs +
                   ["-loop", "1", "-framerate", "30", "-i", top, "-loop", "1", "-framerate", "30", "-i", cap,
                    "-filter_complex", graph, "-map", "[outv]", "-map", "[outa]", "-t", str(t), "-aspect", "9:16",
                    "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
                    "-c:a", "pcm_s16le", out], check=True)
    return out


def render_class(ep, force=False):
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RAW_DIR, exist_ok=True)
    names = set(ep.get("takes", {}))
    for cut in ep["cuts"]:
        names.update(cut.get("split", [cut.get("take")]))
    raws = {n: class_raw(ep, n, force) for n in names if n}
    top = class_top_plate(ep, f"ep{ep['id']}_top.png")
    clips = [render_class_cut(ep, k, cut, raws, top) for k, cut in enumerate(ep["cuts"])]
    # The rule card over the blurred last image, with the park's sound fading under it.
    card = class_rule_card(ep, f"ep{ep['id']}_regla.png")
    last = ep["cuts"][-1]
    lt = ep.get("regla_secs", 6)
    last_raw = raws[last.get("take") or last["split"][1]]
    clips.append(still_card(ep, last_raw, last["ss"], card, lt, os.path.join(OUT_DIR, f"ep{ep['id']}_regla.mp4")))
    # And the game: where to finish learning (user, 26-11-2026).
    gc = class_game_card(ep, f"ep{ep['id']}_juego.png")
    clips.append(still_card(ep, last_raw, last["ss"], gc, ep.get("juego_secs", 5),
                            os.path.join(OUT_DIR, f"ep{ep['id']}_juego.mp4"), volume=0.4))
    return finish_mix(ep, clips)


def finish_mix(ep, clips):
    lst = os.path.join(OUT_DIR, f"ep{ep['id']}_list.txt")
    open(lst, "w").write("".join(f"file '{c}'\n" for c in clips))
    joined = os.path.join(OUT_DIR, f"ep{ep['id']}_joined.mkv")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined], check=True)
    total = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", joined],
                                 capture_output=True, text=True).stdout)
    music = os.path.join(AUDIO, "musica_videos.mp3")
    mix = (f"[1:a]volume=0.32,afade=t=in:st=0:d=1,afade=t=out:st={total - 2}:d=2[m];[0:a]volume=1.4[g];"
           f"[m][g]amix=inputs=2:duration=first:normalize=0")
    measure = subprocess.run(["ffmpeg", "-hide_banner", "-i", joined, "-i", music, "-filter_complex",
                              mix + ",loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                             capture_output=True, text=True).stderr
    m = json.loads(measure[measure.rindex("{"):measure.rindex("}") + 1])
    norm = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
            f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    out_file = ep["video_file"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", joined, "-i", music, "-filter_complex", mix + "," + norm + ",aresample=48000[a]",
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-aspect", "9:16", "-c:a", "aac", "-b:a", "192k",
                    "-movflags", "+faststart", "-shortest", out_file], check=True)
    print(f"[VIDEO BUILD] Complete: {out_file} ({total:.1f} s, {os.path.getsize(out_file) // 1024} KB)")
    return out_file


def main():
    parser = argparse.ArgumentParser(description="Publicador de Shorts de PhotoHacks")
    parser.add_argument("--id", type=int, default=None, help="ID específico del episodio a publicar")
    parser.add_argument("--solo-video", action="store_true", help="Solo generar el vídeo sin subirlo")
    parser.add_argument("--skip-render", action="store_true", help="Omitir el render si el vídeo ya existe")
    parser.add_argument("--regrabar", action="store_true", help="Volver a grabar las tomas del juego aunque existan")
    args = parser.parse_args()

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    target_id = args.id or data.get("next_episode", 1)
    ep = next((e for e in data["episodes"] if e["id"] == target_id), None)
    if not ep:
        print(f"Error: Episodio con ID {target_id} no encontrado en {JSON_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"==================================================================")
    print(f" PHOTOHACKS SHORTS PIPELINE — Episodio #{ep['id']}: {ep['title']}")
    print(f"==================================================================")

    # 1. Render Video
    if args.skip_render and os.path.exists(ep["video_file"]):
        print(f"\n[SKIP-RENDER] Utilizando vídeo ya generado: {ep['video_file']}")
        video_file = ep["video_file"]
    else:
        video_file = (render_class(ep, args.regrabar) if ep.get("formato") == "clase" else
                          render_recipe(ep, args.regrabar) if ep.get("cuts") else render_short_video(ep))

    if args.solo_video:
        print(f"\n[OK] Vídeo generado: {video_file}")
        return

    # 2. Upload via CDP
    assigned_url = upload_via_cdp(ep)

    # 3. Update JSON
    ep["status"] = "publicado"
    ep["publish_date"] = datetime.now(timezone.utc).isoformat()
    if assigned_url:
        ep["youtube_url"] = assigned_url

    # Find next pending
    next_pending = next((e["id"] for e in data["episodes"] if e["status"] == "pendiente"), None)
    if next_pending:
        data["next_episode"] = next_pending
    data["last_updated"] = datetime.now(timezone.utc).isoformat()

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print("\n==================================================================")
    print(f" ¡EPISODIO #{ep['id']} SUBIDO CON ÉXITO EN MODO PRIVADO!")
    print(f"==================================================================")
    print(f"Fichero de vídeo: {video_file}")
    if assigned_url:
        print(f"URL de YouTube:   {assigned_url}")
    print(f"Siguiente en cola: Episodio #{data['next_episode']}")
    print("La ventana de Chromium se mantiene abierta para que lo valides.")


if __name__ == "__main__":
    main()
