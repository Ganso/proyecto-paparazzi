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

    pill_text2 = "RÉFLEX · TELEMÉTRICA · TLR · ANÁLOGICA"
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


def main():
    parser = argparse.ArgumentParser(description="Publicador de Shorts de PhotoHacks")
    parser.add_argument("--id", type=int, default=None, help="ID específico del episodio a publicar")
    parser.add_argument("--solo-video", action="store_true", help="Solo generar el vídeo sin subirlo")
    parser.add_argument("--skip-render", action="store_true", help="Omitir el render si el vídeo ya existe")
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
        video_file = render_short_video(ep)

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
