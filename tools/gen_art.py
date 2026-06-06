#!/usr/bin/env python3
"""
gen_art.py — procedural Nordic pixel-art pack for Temu Skyrim.
All art drawn at display resolution (1:1) to match the 64px LPC characters.
Outputs into new-game-project/assets/{env,props,enemies,fx,items,ui}.
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont

random.seed(7)
ROOT = r"C:/Users/seanm/Nextcloud2/Gamedev/GodotGames/Temu_skyrim/new-game-project/assets"

P = {
	"snow_hi": (233,238,243), "snow": (205,216,224), "snow_sh": (179,194,205),
	"ice": (169,200,216), "ice_d": (127,168,191),
	"stone_hi":(124,128,136),"stone":(80,84,90),"stone_d":(56,59,64),"stone_dd":(40,42,46),
	"wood":(107,74,43),"wood_d":(78,54,32),"wood_hi":(140,100,60),
	"dirt":(122,106,82),"dirt_d":(94,80,64),
	"pine":(47,93,68),"pine_d":(36,74,54),"pine_dd":(28,58,42),
	"blood":(139,30,30),"gold":(230,195,77),"gold_d":(176,140,40),
	"fire":(255,122,42),"fire_hi":(255,210,74),"magic":(74,166,255),"magic_hi":(190,225,255),
	"shout":(207,232,255),"dragon":(58,74,63),"dragon_d":(42,55,48),"bone":(216,210,192),
	"eye":(255,90,42),"black":(20,22,26),"white":(240,244,248),
	"temu_orange":(255,108,45),"temu_dark":(34,30,28),
}

def newimg(w,h): return Image.new("RGBA",(w,h),(0,0,0,0))
def save(img, sub, name):
	d=os.path.join(ROOT,sub); os.makedirs(d,exist_ok=True)
	img.save(os.path.join(d,name+".png"))

def speckle(dr,x0,y0,x1,y1,col,n,a=255):
	for _ in range(n):
		x=random.randint(x0,x1-1); y=random.randint(y0,y1-1)
		dr.point((x,y),fill=col+(a,) if len(col)==3 else col)

# ── Seamless ground tiles (64x64) ──────────────────────────────────────────
def tile_snow():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["snow"]+(255,))
	speckle(d,0,0,64,64,P["snow_hi"],90)
	speckle(d,0,0,64,64,P["snow_sh"],60)
	for _ in range(6):
		x=random.randint(4,58);y=random.randint(4,58)
		d.ellipse([x,y,x+random.randint(3,7),y+random.randint(2,4)],fill=P["snow_hi"]+(255,))
	save(im,"env","tile_snow")

def tile_snow_rock():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["snow"]+(255,))
	speckle(d,0,0,64,64,P["snow_hi"],50)
	for _ in range(4):
		x=random.randint(2,50);y=random.randint(2,50);w=random.randint(8,16)
		d.ellipse([x,y,x+w,y+w-3],fill=P["stone"]+(255,))
		d.ellipse([x,y,x+w,y+4],fill=P["stone_hi"]+(255,))
	save(im,"env","tile_snowrock")

def tile_path():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["dirt"]+(255,))
	speckle(d,0,0,64,64,P["dirt_d"],120)
	speckle(d,0,0,64,64,P["snow_sh"],30)
	for _ in range(8):
		x=random.randint(2,60);y=random.randint(2,60)
		d.point((x,y),fill=P["stone"]+(255,))
	save(im,"env","tile_path")

def tile_ice():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["ice"]+(255,))
	for _ in range(5):
		x0=random.randint(0,40);y0=random.randint(0,40)
		d.line([x0,y0,x0+random.randint(10,24),y0+random.randint(6,18)],fill=P["ice_d"]+(255,),width=1)
	speckle(d,0,0,64,64,P["snow_hi"],40)
	save(im,"env","tile_ice")

def tile_stonefloor():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["stone"]+(255,))
	for gy in range(0,64,16):
		for gx in range(0,64,16):
			off= 8 if (gy//16)%2 else 0
			x=(gx+off)%64
			d.rectangle([x+1,gy+1,x+14,gy+14],fill=P["stone_d"]+(255,))
			d.rectangle([x+1,gy+1,x+14,gy+2],fill=P["stone_hi"]+(255,))
	speckle(d,0,0,64,64,P["stone_dd"],60)
	save(im,"env","tile_stone")

def tile_wood():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["wood"]+(255,))
	for y in range(0,64,8):
		d.line([0,y,63,y],fill=P["wood_d"]+(255,))
	speckle(d,0,0,64,64,P["wood_hi"],40)
	save(im,"env","tile_woodfloor")

# ── Props ───────────────────────────────────────────────────────────────────
def pine(big=True):
	w,h=(72,112) if big else (56,84)
	im=newimg(w,h); d=ImageDraw.Draw(im)
	cx=w//2
	# trunk
	d.rectangle([cx-4,h-22,cx+4,h-4],fill=P["wood_d"]+(255,))
	# shadow
	d.ellipse([cx-22,h-12,cx+22,h-2],fill=(0,0,0,60))
	tiers=4
	for i in range(tiers):
		ty=14+i*(h-40)//tiers
		tw=10+i*(w//2-8)//tiers
		col=P["pine"] if i%2==0 else P["pine_d"]
		d.polygon([(cx,ty-14),(cx-tw,ty+18),(cx+tw,ty+18)],fill=col+(255,))
	# snow caps
	for i in range(tiers):
		ty=14+i*(h-40)//tiers
		tw=10+i*(w//2-8)//tiers
		d.polygon([(cx,ty-14),(cx-tw//2,ty+2),(cx+tw//2,ty+2)],fill=P["snow_hi"]+(230,))
	save(im,"props","pine_big" if big else "pine_small")

def rock(name="rock", w=48,h=40):
	im=newimg(w,h); d=ImageDraw.Draw(im)
	d.ellipse([4,h-10,w-4,h-2],fill=(0,0,0,60))
	d.polygon([(6,h-8),(w//2-8,8),(w//2+10,4),(w-6,h-8)],fill=P["stone"]+(255,))
	d.polygon([(6,h-8),(w//2-8,8),(w//2+10,4)],fill=P["stone_hi"]+(255,))
	d.polygon([(w//2+10,4),(w-6,h-8),(w//2,h-8)],fill=P["stone_d"]+(255,))
	d.polygon([(w//2-8,8),(w//2+10,4),(w//2+2,16)],fill=P["snow_hi"]+(220,))
	save(im,"props",name)

def shrub():
	im=newimg(40,30); d=ImageDraw.Draw(im)
	d.ellipse([2,12,38,28],fill=P["pine_dd"]+(255,))
	for _ in range(20):
		x=random.randint(4,34);y=random.randint(8,24)
		d.point((x,y),fill=P["pine"]+(255,))
	speckle(d,4,8,36,18,P["snow_hi"],14)
	save(im,"props","shrub")

def signpost():
	im=newimg(40,56); d=ImageDraw.Draw(im)
	d.rectangle([18,16,23,52],fill=P["wood_d"]+(255,))
	d.rectangle([4,18,36,32],fill=P["wood"]+(255,))
	d.rectangle([4,18,36,20],fill=P["wood_hi"]+(255,))
	d.polygon([(36,18),(40,25),(36,32)],fill=P["wood"]+(255,))
	save(im,"props","sign")

def torch():
	im=newimg(20,48); d=ImageDraw.Draw(im)
	d.rectangle([8,16,12,46],fill=P["wood_d"]+(255,))
	d.ellipse([3,2,17,20],fill=P["fire"]+(255,))
	d.ellipse([6,4,14,16],fill=P["fire_hi"]+(255,))
	save(im,"props","torch")

def campfire():
	im=newimg(48,40); d=ImageDraw.Draw(im)
	d.ellipse([6,26,42,38],fill=(0,0,0,70))
	for a in range(6):
		x=10+a*6
		d.line([x,36,x+8,24],fill=P["wood_d"]+(255,),width=3)
	d.polygon([(24,8),(14,32),(34,32)],fill=P["fire"]+(255,))
	d.polygon([(24,16),(18,32),(30,32)],fill=P["fire_hi"]+(255,))
	save(im,"props","campfire")

def barrel():
	im=newimg(32,40); d=ImageDraw.Draw(im)
	d.ellipse([2,30,30,40],fill=(0,0,0,60))
	d.rectangle([4,8,28,36],fill=P["wood"]+(255,))
	d.ellipse([4,4,28,12],fill=P["wood_hi"]+(255,))
	d.rectangle([4,14,28,16],fill=P["wood_d"]+(255,))
	d.rectangle([4,26,28,28],fill=P["wood_d"]+(255,))
	save(im,"props","barrel")

def chest(open_=False):
	im=newimg(40,32); d=ImageDraw.Draw(im)
	d.ellipse([4,26,36,32],fill=(0,0,0,60))
	d.rectangle([4,14,36,30],fill=P["wood"]+(255,))
	d.rectangle([4,14,36,16],fill=P["wood_hi"]+(255,))
	if open_:
		d.polygon([(4,14),(36,14),(36,4),(4,4)],fill=P["wood_d"]+(255,))
		d.rectangle([8,16,32,28],fill=P["gold_d"]+(255,))
		d.rectangle([10,18,30,24],fill=P["gold"]+(255,))
	else:
		d.rectangle([4,8,36,16],fill=P["wood_d"]+(255,))
		d.rectangle([18,12,22,18],fill=P["gold"]+(255,))
	save(im,"props","chest_open" if open_ else "chest")

def house(longhouse=False):
	w,h=(160,140) if longhouse else (112,112)
	im=newimg(w,h); d=ImageDraw.Draw(im)
	# body
	d.rectangle([8,h-70,w-8,h-8],fill=P["wood"]+(255,))
	for x in range(8,w-8,6):
		d.line([x,h-70,x,h-8],fill=P["wood_d"]+(255,))
	# roof (snowy)
	d.polygon([(0,h-60),(w//2,8),(w,h-60)],fill=P["wood_d"]+(255,))
	d.polygon([(0,h-60),(w//2,8),(w,h-60),(w-16,h-52),(16,h-52)],fill=P["wood_d"]+(255,))
	d.polygon([(8,h-62),(w//2,14),(w-8,h-62)],fill=P["snow"]+(255,))
	d.polygon([(8,h-62),(w//2,14),(w//2,h-62)],fill=P["snow_hi"]+(255,))
	# door
	dw=22
	d.rectangle([w//2-dw//2,h-44,w//2+dw//2,h-8],fill=P["wood_d"]+(255,))
	d.rectangle([w//2-dw//2+2,h-42,w//2+dw//2-2,h-10],fill=(60,42,26,255))
	d.ellipse([w//2+3,h-28,w//2+7,h-24],fill=P["gold"]+(255,))
	# windows
	for wx in ([24,w-40] if not longhouse else [24,w//2-10,w-40]):
		d.rectangle([wx,h-58,wx+16,h-44],fill=(40,60,80,255))
		d.line([wx+8,h-58,wx+8,h-44],fill=P["wood_d"]+(255,))
		d.line([wx,h-51,wx+16,h-51],fill=P["wood_d"]+(255,))
	save(im,"props","longhouse" if longhouse else "house")

def keep():
	# the jarl's keep / castle-ish tower
	w,h=200,180; im=newimg(w,h); d=ImageDraw.Draw(im)
	d.rectangle([20,h-120,w-20,h-8],fill=P["stone"]+(255,))
	for gy in range(h-120,h-8,16):
		for gx in range(20,w-20,18):
			d.rectangle([gx+1,gy+1,gx+16,gy+14],fill=P["stone_d"]+(255,))
	# towers
	for tx in [10,w-46]:
		d.rectangle([tx,h-150,tx+36,h-8],fill=P["stone_d"]+(255,))
		for cx in range(tx,tx+36,12):
			d.rectangle([cx,h-156,cx+8,h-150],fill=P["stone_d"]+(255,))
		d.polygon([(tx-4,h-150),(tx+18,h-176),(tx+40,h-150)],fill=P["pine_dd"]+(255,))
		d.polygon([(tx,h-152),(tx+18,h-172),(tx+36,h-152)],fill=P["snow"]+(255,))
	# big door
	d.rectangle([w//2-26,h-70,w//2+26,h-8],fill=P["wood_d"]+(255,))
	d.rectangle([w//2-22,h-66,w//2+22,h-8],fill=(54,38,24,255))
	d.arc([w//2-26,h-90,w//2+26,h-50],180,360,fill=P["wood_d"],width=4)
	save(im,"props","keep")

def stall():
	im=newimg(96,90); d=ImageDraw.Draw(im)
	# counter
	d.rectangle([8,56,88,82],fill=P["wood"]+(255,))
	d.rectangle([8,56,88,60],fill=P["wood_hi"]+(255,))
	# posts
	for px in [10,82]:
		d.rectangle([px,18,px+6,82],fill=P["wood_d"]+(255,))
	# awning (striped)
	for i,seg in enumerate(range(8,88,16)):
		col=P["temu_orange"] if i%2==0 else P["white"]
		d.polygon([(seg,18),(seg+16,18),(seg+8,34)],fill=col+(255,))
	d.rectangle([6,14,90,20],fill=P["wood_d"]+(255,))
	# goods
	d.ellipse([20,48,30,58],fill=P["fire"]+(255,))
	d.ellipse([40,48,50,58],fill=P["gold"]+(255,))
	d.rectangle([58,46,74,58],fill=P["magic"]+(255,))
	save(im,"props","stall")

def banner():
	im=newimg(28,64); d=ImageDraw.Draw(im)
	d.rectangle([6,2,22,52],fill=P["temu_orange"]+(255,))
	d.polygon([(6,52),(14,44),(22,52)],fill=P["temu_orange"]+(255,))
	d.polygon([(12,12),(16,12),(14,30),(18,22),(14,40),(10,22),(14,30)],fill=P["white"]+(255,))
	save(im,"props","banner")

def gravestone():
	im=newimg(32,40); d=ImageDraw.Draw(im)
	d.ellipse([4,32,28,40],fill=(0,0,0,60))
	d.rounded_rectangle([8,8,24,36],6,fill=P["stone"]+(255,))
	d.line([12,16,20,16],fill=P["stone_dd"]+(255,),width=2)
	d.line([16,12,16,24],fill=P["stone_dd"]+(255,),width=2)
	save(im,"props","grave")

def dungeon_wall():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.rectangle([0,0,63,63],fill=P["stone_dd"]+(255,))
	for gy in range(0,64,16):
		for gx in range(0,64,21):
			off=10 if (gy//16)%2 else 0
			x=(gx+off)%64
			d.rectangle([x+1,gy+1,x+18,gy+14],fill=P["stone_d"]+(255,))
			d.rectangle([x+1,gy+1,x+18,gy+2],fill=P["stone"]+(255,))
	save(im,"env","tile_dwall")

# ── Enemies (non-LPC) ────────────────────────────────────────────────────────
def wolf():
	# top-down-ish wolf facing right; 2 frames
	for f in range(2):
		im=newimg(48,32); d=ImageDraw.Draw(im)
		off=f*2
		d.ellipse([4,16,40,28],fill=(0,0,0,50))
		d.ellipse([8,8,38,22],fill=P["stone"]+(255,))          # body
		d.ellipse([8,8,38,14],fill=P["stone_hi"]+(255,))        # back highlight
		d.ellipse([30,6,46,18],fill=P["stone"]+(255,))          # head
		d.polygon([(34,6),(37,0),(39,6)],fill=P["stone_d"]+(255,))  # ear
		d.polygon([(40,6),(43,1),(44,7)],fill=P["stone_d"]+(255,))
		d.point((43,11),fill=P["eye"]+(255,))                   # eye
		d.polygon([(6,12),(0,8+off),(6,16)],fill=P["stone_d"]+(255,))  # tail
		# legs
		for lx in [12,28]:
			d.rectangle([lx,20+off,lx+3,30],fill=P["stone_d"]+(255,))
			d.rectangle([lx+8,20-off,lx+11,30],fill=P["stone_d"]+(255,))
		im.save(os.path.join(ROOT,"enemies","wolf_%d.png"%f)) if os.path.isdir(os.path.join(ROOT,"enemies")) else None
		save(im,"enemies","wolf_%d"%f)

def dragon():
	# big top-down dragon, 2 wing frames
	for f in range(2):
		W,H=192,160; im=newimg(W,H); d=ImageDraw.Draw(im)
		cx=W//2
		wingy = 0 if f==0 else 18
		d.ellipse([cx-40,H-30,cx+40,H-10],fill=(0,0,0,70))
		# tail
		d.polygon([(cx,90),(cx-8,150),(cx+8,150)],fill=P["dragon_d"]+(255,))
		d.polygon([(cx-6,150),(cx+6,150),(cx,160)],fill=P["dragon"]+(255,))
		# wings
		d.polygon([(cx-10,60),(20,20+wingy),(8,70+wingy),(cx-12,90)],fill=P["dragon_d"]+(255,))
		d.polygon([(cx+10,60),(W-20,20+wingy),(W-8,70+wingy),(cx+12,90)],fill=P["dragon_d"]+(255,))
		# wing membrane lines
		for wx in [(20,20+wingy),(8,70+wingy)]:
			d.line([cx-10,60,wx[0],wx[1]],fill=P["dragon"]+(255,),width=2)
		for wx in [(W-20,20+wingy),(W-8,70+wingy)]:
			d.line([cx+10,60,wx[0],wx[1]],fill=P["dragon"]+(255,),width=2)
		# body
		d.ellipse([cx-22,50,cx+22,110],fill=P["dragon"]+(255,))
		d.ellipse([cx-22,50,cx+22,75],fill=(72,90,78,255))
		# belly scales
		for sy in range(60,108,8):
			d.line([cx-10,sy,cx+10,sy],fill=P["dragon_d"]+(255,))
		# neck + head
		d.ellipse([cx-12,24,cx+12,60],fill=P["dragon"]+(255,))
		d.ellipse([cx-14,8,cx+14,36],fill=P["dragon"]+(255,))      # head
		# horns
		d.polygon([(cx-12,12),(cx-20,-2),(cx-8,10)],fill=P["bone"]+(255,))
		d.polygon([(cx+12,12),(cx+20,-2),(cx+8,10)],fill=P["bone"]+(255,))
		# snout + eyes
		d.polygon([(cx-6,8),(cx,-4),(cx+6,8)],fill=P["dragon_d"]+(255,))
		d.ellipse([cx-9,14,cx-4,19],fill=P["eye"]+(255,))
		d.ellipse([cx+4,14,cx+9,19],fill=P["eye"]+(255,))
		# legs/claws
		for lx in [cx-26,cx+18]:
			d.polygon([(lx,80),(lx-10,108),(lx+6,100)],fill=P["dragon_d"]+(255,))
		save(im,"enemies","dragon_%d"%f)

def dragon_soul():
	im=newimg(96,96); d=ImageDraw.Draw(im)
	for r,a in [(44,40),(32,80),(20,140),(10,220)]:
		d.ellipse([48-r,48-r,48+r,48+r],fill=P["magic_hi"]+(a,))
	save(im,"fx","dragonsoul")

# ── FX ───────────────────────────────────────────────────────────────────────
def slash_arc():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	d.arc([6,6,58,58],300,60,fill=P["white"],width=5)
	d.arc([12,12,52,52],300,60,fill=(255,255,255,160),width=2)
	save(im,"fx","slash")

def fireball():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.ellipse([4,4,28,28],fill=P["fire"]+(255,))
	d.ellipse([9,9,23,23],fill=P["fire_hi"]+(255,))
	save(im,"fx","fireball")

def frostbolt():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.polygon([(16,2),(20,16),(16,30),(12,16)],fill=P["magic_hi"]+(255,))
	d.polygon([(2,16),(16,12),(30,16),(16,20)],fill=P["magic"]+(255,))
	save(im,"fx","frostbolt")

def shout_wave():
	im=newimg(128,128); d=ImageDraw.Draw(im)
	for i,a in enumerate([60,120,200]):
		r=60-i*16
		d.arc([64-r,64-r,64+r,64+r],300,420,fill=P["shout"]+(a,),width=6)
	save(im,"fx","shout")

def hit_spark():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	for ang in range(0,360,45):
		x=16+int(13*math.cos(math.radians(ang))); y=16+int(13*math.sin(math.radians(ang)))
		d.line([16,16,x,y],fill=P["white"],width=2)
	save(im,"fx","spark")

def blood():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	speckle(d,2,2,30,30,P["blood"],40)
	save(im,"fx","blood")

def levelup():
	im=newimg(64,64); d=ImageDraw.Draw(im)
	for ang in range(0,360,30):
		x=32+int(26*math.cos(math.radians(ang))); y=32+int(26*math.sin(math.radians(ang)))
		d.line([32,32,x,y],fill=P["gold"]+(180,),width=2)
	d.ellipse([22,22,42,42],fill=P["gold_hi"] if "gold_hi" in P else P["gold"]+(255,))
	save(im,"fx","levelup")

def snowflake():
	im=newimg(6,6); d=ImageDraw.Draw(im)
	d.ellipse([1,1,4,4],fill=P["white"]+(230,))
	save(im,"fx","snow")

# ── Items / icons (32x32) ─────────────────────────────────────────────────────
def icon_sword():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.polygon([(15,2),(18,2),(17,22),(16,22)],fill=P["white"]+(255,))
	d.rectangle([16,2,17,22],fill=(200,210,220,255))
	d.rectangle([11,22,21,25],fill=P["gold"]+(255,))
	d.rectangle([15,25,18,30],fill=P["wood"]+(255,))
	save(im,"items","sword")

def icon_axe():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.rectangle([15,4,18,30],fill=P["wood"]+(255,))
	d.polygon([(18,4),(28,8),(28,16),(18,14)],fill=P["stone_hi"]+(255,))
	d.polygon([(15,4),(6,8),(6,16),(15,14)],fill=P["stone"]+(255,))
	save(im,"items","axe")

def icon_potion(col,name):
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.rectangle([13,4,19,9],fill=P["wood"]+(255,))
	d.ellipse([8,8,24,28],fill=(220,230,235,255))
	d.ellipse([10,14,22,26],fill=col+(255,))
	d.ellipse([12,16,16,20],fill=P["white"]+(180,))
	save(im,"items",name)

def icon_coin():
	im=newimg(24,24); d=ImageDraw.Draw(im)
	d.ellipse([3,3,21,21],fill=P["gold_d"]+(255,))
	d.ellipse([5,5,19,19],fill=P["gold"]+(255,))
	d.text((9,6),"$",fill=P["gold_d"]+(255,))
	save(im,"items","coin")

def icon_sweetroll():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.ellipse([4,10,28,26],fill=(park:=(196,140,70))+(255,))
	d.ellipse([4,6,28,22],fill=(214,158,86)+(255,))
	for a in range(0,360,40):
		x=16+int(8*math.cos(math.radians(a))); y=14+int(5*math.sin(math.radians(a)))
		d.line([16,14,x,y],fill=P["white"]+(220,),width=2)
	save(im,"items","sweetroll")

def icon_book():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.rectangle([6,6,26,26],fill=P["blood"]+(255,))
	d.rectangle([8,8,24,24],fill=(200,190,160,255))
	d.line([16,8,16,24],fill=P["wood_d"]+(255,))
	save(im,"items","book")

def icon_claw():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	for i in range(3):
		d.polygon([(8+i*7,28),(11+i*7,6),(14+i*7,28)],fill=P["bone"]+(255,))
	d.rectangle([6,26,26,30],fill=P["gold"]+(255,))
	save(im,"items","claw")

def icon_helm():
	im=newimg(32,32); d=ImageDraw.Draw(im)
	d.ellipse([6,6,26,28],fill=P["stone"]+(255,))
	d.rectangle([6,16,26,20],fill=P["stone_dd"]+(255,))
	d.rectangle([15,8,17,24],fill=P["stone_dd"]+(255,))
	save(im,"items","helm")

# ── UI ────────────────────────────────────────────────────────────────────────
def ui_panel(name,col,w=200,h=24):
	im=newimg(w,h); d=ImageDraw.Draw(im)
	d.rectangle([0,0,w-1,h-1],fill=col+(255,))
	save(im,"ui",name)

def temu_logo():
	im=newimg(180,56); d=ImageDraw.Draw(im)
	d.rounded_rectangle([2,2,178,54],10,fill=P["temu_orange"]+(255,))
	try:
		f=ImageFont.truetype("arialbd.ttf",34)
	except Exception:
		f=ImageFont.load_default()
	d.text((18,8),"Temu",fill=P["white"]+(255,),font=f)
	save(im,"ui","temu_logo")

def compass_marker():
	im=newimg(16,16); d=ImageDraw.Draw(im)
	d.polygon([(8,0),(15,15),(8,11),(1,15)],fill=P["white"]+(255,))
	save(im,"ui","marker")

def star():
	im=newimg(16,16); d=ImageDraw.Draw(im)
	pts=[]
	for i in range(10):
		ang=math.radians(i*36-90); r=7 if i%2==0 else 3
		pts.append((8+r*math.cos(ang),8+r*math.sin(ang)))
	d.polygon(pts,fill=P["gold"]+(255,))
	save(im,"ui","star")

def main():
	tile_snow(); tile_snow_rock(); tile_path(); tile_ice(); tile_stonefloor(); tile_wood(); dungeon_wall()
	pine(True); pine(False); rock("rock"); rock("boulder",72,60); shrub(); signpost(); torch(); campfire()
	barrel(); chest(False); chest(True); house(False); house(True); keep(); stall(); banner(); gravestone()
	wolf(); dragon(); dragon_soul()
	slash_arc(); fireball(); frostbolt(); shout_wave(); hit_spark(); blood(); snowflake()
	icon_sword(); icon_axe(); icon_potion(P["blood"],"potion_health"); icon_potion(P["magic"],"potion_magicka")
	icon_potion((90,200,120),"potion_stamina"); icon_coin(); icon_sweetroll(); icon_book(); icon_claw(); icon_helm()
	temu_logo(); compass_marker(); star()
	# level up needs gold_hi guard
	try: levelup()
	except Exception as e: print("levelup skip",e)
	print("art generated OK")

if __name__=="__main__":
	main()
