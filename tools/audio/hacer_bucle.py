#!/usr/bin/env python3
"""Seamless loop from a generated take: a whole number of bars, the cut chosen where the music
matches itself best, aligned to the sample and closed with an equal-power crossfade taken from
the music that follows the loop (docs/futuro/24, «Música»).

    python3 tools/audio/hacer_bucle.py toma.flac bucle.wav <bpm>
    ffmpeg -i bucle.wav -c:a libvorbis -q:a 6 -ar 48000 assets/audio/musica/<nombre>.ogg

Searches 40–51 bars (tempo ±1.5 %) for the stretch whose start and end sound most alike, then
aligns the cut on the beat (onsets of 8 bars, 1 ms steps) and on the waveform (±1.5 ms)."""
import subprocess, sys, numpy as np
src, dst, bpm = sys.argv[1], sys.argv[2], float(sys.argv[3])
SR = 48000
raw = subprocess.run(["ffmpeg","-v","error","-i",src,"-f","f32le","-ac","2","-ar",str(SR),"-"],capture_output=True,check=True).stdout
x = np.frombuffer(raw,dtype=np.float32).reshape(-1,2).astype(np.float64)
mono = x.mean(1)
# where the music ends (the generator leaves a silent tail)
env = np.sqrt(np.convolve(mono**2,np.ones(SR//10)/(SR//10),mode="same"))
live = np.where(env > 10**(-45/20))[0]
end = live[-1]/SR
print("música hasta %.2f s" % end)
bar = 4*60.0/bpm
# spectral fingerprint: band energies every 50 ms
hop = SR//20; win = 4096
frames = np.lib.stride_tricks.sliding_window_view(mono,win)[::hop]*np.hanning(win)
spec = np.abs(np.fft.rfft(frames,axis=1))
edges = np.geomspace(40,12000,25); freqs = np.fft.rfftfreq(win,1/SR)
bands = np.stack([spec[:,(freqs>=lo)&(freqs<hi)].sum(1) for lo,hi in zip(edges[:-1],edges[1:])],1)
bands = np.log1p(bands); bands -= bands.mean(0)
def fp(t, length=8*bar):
    i = int(t*SR/hop); n = int(length*SR/hop)
    return bands[i:i+n].ravel()
XF = 1.5   # crossfade seconds (taken from after the loop's end)
best = None
for bars in range(40,52):
    for a in np.arange(0.3,8.0,0.05):
        for stretch in np.linspace(.985,1.015,13):
            L = bars*bar*stretch
            if a+L+XF+0.2 > end: continue
            f1, f2 = fp(a), fp(a+L)
            if len(f1) != len(f2): continue
            c = np.dot(f1,f2)/np.sqrt(np.dot(f1,f1)*np.dot(f2,f2))
            if best is None or c > best[0]: best = (c,bars,a,L)
c,bars,a,L = best
print("mejor: %d compases, inicio %.2f s, largo %.3f s (tempo real %.2f BPM), parecido %.3f" % (bars,a,L,bars*4*60/L,c))
# rhythm first: the onsets of 8 bars after the cut must fall where those after the start do
# (1 ms steps, ±100 ms); then the waveform, within ±1.5 ms, so the crossfade sums in phase
fh = SR//1000
fr2 = np.lib.stride_tricks.sliding_window_view(mono,1024)[::fh]*np.hanning(1024)
S2 = np.log1p(np.abs(np.fft.rfft(fr2,axis=1)))
flux = np.maximum(np.diff(S2,axis=0),0).sum(1)
flux = np.convolve(flux,np.hanning(15)/np.hanning(15).sum(),mode="same")
i0 = int(a*SR); span = int(8*bar*1000)
ref = flux[int(a*1000):int(a*1000)+span]; ref = ref-ref.mean()
best_l, best_r = L, -2
for ms in range(-100,101):
    j = int((a+L)*1000)+ms
    cand = flux[j:j+span]
    if len(cand) < span: continue
    cand = cand-cand.mean()
    r = np.dot(ref,cand)/np.sqrt(np.dot(ref,ref)*np.dot(cand,cand))
    if r > best_r: best_r, best_l = r, L+ms/1000
iL = int((a+best_l)*SR)
print("ritmo: corte movido %+.0f ms, golpes alineados %.3f" % ((best_l-L)*1000,best_r))
seg = mono[i0:i0+int(.05*SR)]
best_off, best_c = 0, -2
for off in range(-int(.0015*SR),int(.0015*SR)+1):
    s2 = mono[iL+off:iL+off+len(seg)]
    cc = np.dot(seg,s2)/np.sqrt(np.dot(seg,seg)*np.dot(s2,s2)+1e-12)
    if cc > best_c: best_c, best_off = cc, off
iL += best_off
print("onda: %+d muestras, correlación %.3f" % (best_off,best_c))
n = iL-i0; xf = int(XF*SR)
loop = x[i0:iL].copy()
t = np.linspace(0,np.pi/2,xf)[:,None]
loop[:xf] = x[i0:i0+xf]*np.sin(t) + x[iL:iL+xf]*np.cos(t)
# the seam: last sample → first sample
jump = np.abs(loop[-1]-loop[0]).max(); typical = np.abs(np.diff(loop,axis=0)).mean()
print("salto en el empalme %.4f (paso típico entre muestras %.4f) · bucle de %.3f s" % (jump,typical,n/SR))
peak = np.abs(loop).max(); loop *= 10**(-1/20)/peak   # peak at −1 dBFS
subprocess.run(["ffmpeg","-v","error","-y","-f","f64le","-ac","2","-ar",str(SR),"-i","-",dst],input=loop.astype(np.float64).tobytes(),check=True)
