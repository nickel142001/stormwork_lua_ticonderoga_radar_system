M=math
pi=M.pi
pi2=pi*2
si=M.sin
co=M.cos
S=screen
dL=S.drawLine
dC=S.drawCircle
dTF=S.drawTriangleF
dTB=S.drawTextBox
dT=S.drawText
C=S.setColor
I=input
O=output
P=property
prB=P.getBool
prN=P.getNumber
mts=map.mapToScreen
T=table
sf=string.format
tU=T.unpack
tP=T.pack
ins=T.insert
sc_ln=prN('Scan')
zoom=tP(prN('Zoom1'),prN('Zoom2'),prN('Zoom3'),prN('Zoom4'),prN('Zoom5'))
intvl=prN('intvl')
r_ln=prN('rdr') --レーダ数 1-4 マップへのスキャンライン描画用

function getN(...)local a={}for b,c in ipairs({...})do a[b]=I.getNumber(c)end;return tU(a)end
function getB(...)local a={}for b,c in ipairs({...})do a[b]=I.getBool(c)end;return tU(a)end
function outN(o, ...) for i,v in ipairs({...}) do O.setNumber(o+i-1,v) end end
function dist3d(a,b) return M.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end
function clamp(a,b,c) return M.min(M.max(a,b),c) end
function rot(x,y,r) return sc_ln*si(r*pi2)+x, sc_ln*co(r*pi2)+y end
conf=prN('suv_tick')
cntct={}
--{1:x,2:y,3:z,4:vx,5:vy,6:vz,7:tick / key:%3.0f track_id}
ptch=false
zl=0
near=70
tick=0
hd=0
function onTick()
    tick=tick+1
	gx,gy,alt=getN(25,26,27)
	sc=getN(28)
	cp=getN(31)
	hd=-cp*pi*2
	scg={}
	for i=0,(r_ln-1) do
		scx,scy=rot(gx,gy,sc-cp+(1/r_ln)*i) --scx,scy:レーダー走査線を描くための座標
		ins(scg,tP(scx,scy))
	end
	tch=getB(32)

	if tch==true and ptch==false then
		zl=(zl+1)%5
	end
	rgm=zoom[zl+1]/1000
	ptch=tch

	--Aegis Data Transfer System(recv) lite
    --123:xyz,456:v(xyz),7:tick,8:track_id(num)
    for i=1,3 do
        if getB(i) then
            j=8*(i-1)+1
            id_s=sf("%3.0f",getN(j+7))
            if getN(j+6) < 1 then
                --tickが0ならdelete信号
                cntct[id_s]=nil
            else
                --それ以外はupdate/insert
                pc=tP(getN(j,j+1,j+2,j+3,j+4,j+5,j+6))
                cntct[id_s]=pc
            end
        end
    end

end

function onDraw()
    w,h = S.getWidth(), S.getHeight()
	S.setMapColorOcean(12,12,12,255)
	S.setMapColorShallows(30,30,30,255)
	S.setMapColorLand(78,78,78,255)
	S.setMapColorGrass(40,40,40,255)
	S.setMapColorSand(90,90,90,255)
	S.setMapColorSnow(200,200,200,255)
	S.drawMap(gx, gy, rgm)
	km=w/rgm --1km幅

	ind=0
	for k,v in pairs(cntct) do
		alti=clamp(v[3],0,200)/200
		C(0+255*alti,150-20*alti,255-255*alti,255*(1-clamp((tick-v[7])/conf,0,1)))

		px,py = mts(gx, gy, rgm, w, h, v[1], v[2])
		x,y = M.floor(px),M.floor(py)
	    dL(x-1,y,x+2,y)
	    dL(x,y-1,x,y+2)
		dT(x+3,y-3,sf("%.0f",tonumber(k)))

		C(255,255,255,50)
		direc=M.atan(v[4],v[5])
		dL(x,y,x+6*si(direc),y-6*co(direc))
	end
    C(0,255,0,127)
	sr=sf("%.1fkm",rgm)
	dTB(0,h-5,w,5,sr,1,1)

    C(180,255,180,30)
	myx,myy = mts(gx, gy, rgm,w, h, gx, gy)
	C(255,255,255,15)
	for i=1,5 do
		dC(myx,myy,km*i)
	end
	for i,v in ipairs(scg) do
		lx,ly = mts(gx, gy, rgm,w, h, v[1], v[2])
		dL(myx,myy,lx,ly)
	end
	C(0,255,0)
	dC(myx,myy,2)
	dL(myx,myy,myx+6*si(hd),myy-6*co(hd))
end
