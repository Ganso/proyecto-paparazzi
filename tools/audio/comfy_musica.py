#!/usr/bin/env python3
"""Music for PhotoHacks with the local ComfyUI and ACE-Step 1.5 turbo (~/docker/ComfyUI: ./start.sh;
model ace_step_1.5_turbo_aio, the same workflow as Notrunner's radio).

    python3 tools/audio/comfy_musica.py tools/audio/encargo_musica_menu.json <carpeta de salida>

Job fields: name, tags (style in English, "instrumental"), bpm, key ("F major", "Bb major": as the
node names them), seed, seconds (120). Takes of 2 min in about 100 s; they end with a few seconds of
silence. The take becomes a loop with tools/audio/hacer_bucle.py (docs/futuro/24, «Música»)."""
import json, sys, time, urllib.request, os
URL = "http://localhost:8188"
def post(path, data):
    req = urllib.request.Request(URL + path, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req).read())
def get(path):
    return json.loads(urllib.request.urlopen(URL + path).read())
def workflow(job):
    secs = float(job.get("seconds", 120)); seed = job["seed"]
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "ace_step_1.5_turbo_aio.safetensors"}},
        "2": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.0}},
        "3": {"class_type": "TextEncodeAceStepAudio1.5", "inputs": {"clip": ["1", 1], "tags": job["tags"], "lyrics": "[Instrumental]", "seed": seed,
            "bpm": job["bpm"], "duration": secs, "timesignature": "4", "language": "en", "keyscale": job["key"],
            "generate_audio_codes": True, "cfg_scale": 2.0, "temperature": 0.85, "top_p": 0.9, "top_k": 0, "min_p": 0.0}},
        "4": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["3", 0]}},
        "5": {"class_type": "EmptyAceStep1.5LatentAudio", "inputs": {"seconds": secs, "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0,
            "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveAudio", "inputs": {"audio": ["7", 0], "filename_prefix": "photohacks/menu_" + job["name"]}},
    }
jobs = json.load(open(sys.argv[1], encoding="utf-8")); out = sys.argv[2]
for job in jobs:
    pid = post("/prompt", {"prompt": workflow(job)})["prompt_id"]; t0 = time.time()
    while True:
        h = get("/history/" + pid)
        if pid in h and (h[pid].get("outputs") or h[pid].get("status", {}).get("status_str") == "error"): break
        if time.time() - t0 > 2400: raise SystemExit("timeout " + job["name"])
        time.sleep(2)
    if h[pid].get("status", {}).get("status_str") == "error":
        print("ERROR", job["name"], json.dumps(h[pid]["status"])[:600], flush=True); continue
    for node in h[pid]["outputs"].values():
        for au in node.get("audio", []):
            q = "/view?filename=%s&subfolder=%s&type=%s" % (au["filename"], au["subfolder"], au["type"])
            path = os.path.join(out, job["name"] + os.path.splitext(au["filename"])[1])
            open(path, "wb").write(urllib.request.urlopen(URL + q.replace(" ", "%20")).read())
            print("%s: %s en %.0f s" % (job["name"], path, time.time() - t0), flush=True)
