#!/usr/bin/env python3
"""Synthesize missing SFX as WAV (16-bit mono 22050) into assets/audio."""
import os, wave, struct, math
import numpy as np

OUT = r"C:/Users/seanm/Nextcloud2/Gamedev/GodotGames/Temu_skyrim/new-game-project/assets/audio"
os.makedirs(OUT, exist_ok=True)
SR = 22050

def write(name, sig):
	sig = np.clip(sig, -1, 1)
	data = (sig * 32000).astype(np.int16)
	with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
		w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
		w.writeframes(data.tobytes())

def env(n, a=0.01, d=0.2):
	t = np.linspace(0, n/SR, n, False)
	e = np.ones(n)
	at = min(int(a*SR), n//2); rt = min(int(d*SR), n - at)
	if at>0: e[:at] = np.linspace(0,1,at)
	if rt>0: e[-rt:] = np.linspace(1,0,rt)
	return e

def tone(freq, dur, vol=0.5, a=0.01, d=0.1, kind="sine"):
	n=int(dur*SR); t=np.linspace(0,dur,n,False)
	if kind=="sine": s=np.sin(2*np.pi*freq*t)
	elif kind=="square": s=np.sign(np.sin(2*np.pi*freq*t))
	elif kind=="saw": s=2*((freq*t)%1)-1
	else: s=np.sin(2*np.pi*freq*t)
	return s*env(n,a,d)*vol

def noise(dur,vol=0.5,a=0.01,d=0.2):
	n=int(dur*SR); return np.random.uniform(-1,1,n)*env(n,a,d)*vol

# UI click
write("ui_click", tone(880,0.06,0.4,0.005,0.05,"square"))
# pickup / coin handled by mp3; menu confirm
write("confirm", np.concatenate([tone(660,0.07,0.4),tone(990,0.09,0.4)]))
# magic cast — rising zap
n=int(0.4*SR); t=np.linspace(0,0.4,n,False)
freq=300+1400*t
write("cast", np.sin(2*np.pi*freq*t)*env(n,0.01,0.25)*0.5)
# frost impact
write("frost", (noise(0.3,0.4,0.005,0.25)+tone(440,0.3,0.2,0.005,0.25)))
# level up — arpeggio chime
lu=np.concatenate([tone(523,0.12,0.4),tone(659,0.12,0.4),tone(784,0.12,0.4),tone(1047,0.25,0.45,0.01,0.2)])
write("levelup", lu)
# shout — FUS RO DAH: three low booms with whoosh
boom=[]
for f in [120,90,70]:
	n=int(0.35*SR); t=np.linspace(0,0.35,n,False)
	fr=f*np.exp(-2*t)+f
	b=np.sin(2*np.pi*fr*t)*env(n,0.005,0.3)*0.6 + noise(0.35,0.25,0.005,0.3)
	boom.append(b)
write("shout", np.concatenate(boom))
# dragon roar — low growl with vibrato + noise
n=int(1.4*SR); t=np.linspace(0,1.4,n,False)
base=70+10*np.sin(2*np.pi*6*t)
roar=np.sin(2*np.pi*base*t)*0.5 + np.sin(2*np.pi*base*2*t)*0.25 + noise(1.4,0.3,0.05,0.5)
write("dragon_roar", roar*env(n,0.05,0.4))
# soul absorb — ethereal sweep
n=int(1.0*SR); t=np.linspace(0,1.0,n,False)
fr=200+600*t
write("soul", (np.sin(2*np.pi*fr*t)*0.4+np.sin(2*np.pi*fr*1.5*t)*0.2)*env(n,0.1,0.6))
# wolf growl/bark
write("wolf", (noise(0.25,0.4,0.005,0.2)+tone(180,0.25,0.3,0.005,0.2,"saw")))
# door / cloth menu
write("open", tone(300,0.15,0.3,0.01,0.12,"saw"))
print("audio synthesized OK")
