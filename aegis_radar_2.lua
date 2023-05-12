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
T=table
sf=string.format
tU=T.unpack
tP=T.pack
ins=T.insert
sc_ln=prN('Scan')
zoom=tP(prN('Zoom1'),prN('Zoom2'),prN('Zoom3'),prN('Zoom4'),prN('Zoom5'))
min_th=prN('min_dist')
same_tr=prN('same_tr') --同トラック判定用
init_tr=prN('init_same_tr') --同トラック判定用
intvl=prN('intvl')
r_ln=prN('rdr') --レーダ数 1-4 マップへのスキャンライン描画用

function getN(...)local a={}for b,c in ipairs({...})do a[b]=I.getNumber(c)end;return tU(a)end
function getB(...)local a={}for b,c in ipairs({...})do a[b]=I.getBool(c)end;return tU(a)end
function outN(o, ...) for i,v in ipairs({...}) do O.setNumber(o+i-1,v) end end
function dist3d(a,b) return M.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end
function clamp(a,b,c) return M.min(M.max(a,b),c) end
function v_calc(n,o)
	t=n[4]-o[4]
	if t<1 then return 0,0,0 end
	return (n[1]-o[1])/t,(n[2]-o[2])/t,(n[3]-o[3])/t
end
function rot(x,y,r) return sc_ln*si(r*pi2)+x, sc_ln*co(r*pi2)+y end
conf=prN('suv_tick')
data={}
--scandata data={point1,2,3...}
--point={x,y,z,conf,alpha,dist}
tr_ln={}
--track_line tr_ln={track_id, {track_data1,2,3}, vx,vy,vz,update_flag}
--update_flag u:send update data / d:send delete / e:fin remove / -:nop
--track_data={x,y,z,tick}
ptch=false
zl=0
near=70
track_id=1
tick=0
function onTick()
    tick=tick+1
	gx,gy=getN(28,29)
	alt,cp,sc=getN(30,31,32)
	hd=-cp*pi*2
	
    data={} --data:1tickのレーダースキャン情報。近距離点を統合したもの
	for i=0,6 do
		if getB(i+1)==true then
			d=getN(4*i+1)
			if d > min_th then
				update=false
				az=getN(4*i+2)*pi*2
				pa=getN(4*i+3)*pi*2
				g_x=gx+d*si(hd+az)*co(pa)
				g_y=gy+d*co(hd+az)*co(pa)
				g_z=alt+d*si(pa)
				pnt=tP(g_x,g_y,g_z)
				pnt[4]=1
				lsc=-1
				for k,v in ipairs(data) do
					--同一のレーダースキャン内に近いデータ（別マージ）が存在するかチェック
					scr=dist3d(pnt, v)
					if lsc<0 then lsc=scr end
					if scr<=lsc and scr<(d*0.01+near) then 
						lsc=scr
						lk=k
						update=true
					end
				end
				if update==true then
					--近いデータは重みを付けて統合して一つの点に。
					alp=data[lk][4]/(data[lk][4]+data[lk][4])
					data[lk][1],data[lk][2],data[lk][3]=alp*data[lk][1]+(1-alp)*pnt[1],
					alp*data[lk][2]+(1-alp)*pnt[2],
					alp*data[lk][3]+(1-alp)*pnt[3]
					data[lk][4]=M.min(20,data[lk][4]+1)
				else
					--近くないデータは通常通り、別のデータとして扱う
				    ins(data,pnt)
				end
			end
		else
			break
		end
	end

    --トラック同定チェック
	for k,v in ipairs(data) do
		tracked=false
		t={v[1],v[2],v[3],tick}
		for i,trli in ipairs(tr_ln) do --tr_ln:トラックデータ系列
			tpt=trli[2][1]
			vx,vy,vz=trli[3],trli[4],trli[5]
			dt=tick-tpt[4]

			if dt <= intvl then
				--近いtickで近い場所のものは同一と見なして平均をとる
				dis=dist3d({v[1],v[2],v[3]},{tpt[1],tpt[2],tpt[3]})
				if dis <= same_tr then
					bf_tr=trli[2][1]
					new_x=(v[1]*2+bf_tr[1])/3
					new_y=(v[2]*2+bf_tr[2])/3
					new_z=(v[3]*2+bf_tr[3])/3
					trli[2][1]={new_x,new_y,new_z,tick}

					--可能であれば1と3で比較して速度算出
					vx,vy,vz=v_calc(trli[2][1],trli[2][M.min(#trli[2],3)])
					trli[3],trli[4],trli[5]=vx,vy,vz
					trli[6]="u"
					tracked=true
					break
				end
			else
				--tickが近くないデータは通常のトラック同定を行う
				fx=tpt[1]+vx*dt
				fy=tpt[2]+vy*dt
				fz=tpt[3]+vz*dt
				dis=dist3d(t,{fx,fy,fz})
				--速度情報が無い状態でのトラック同定は甘めに実施
				if M.abs(vx) <= 0.001 then tr_th=init_tr else tr_th=same_tr end
				if dis <= tr_th then
					--まずは単純に、近いものがあったらそれを採用
					--トラックラインを更新、最新のtrackデータ追加
					--todo:最も近いトラックデータを採用する
					ins(trli[2], 1, t)
					--可能であれば1と3で比較して速度算出
					bf_tr=trli[2][M.min(#trli[2],3)]
					vx,vy,vz=v_calc(t,bf_tr)
					trli[3]=vx
					trli[4]=vy
					trli[5]=vz
					trli[6]="u"
					tracked=true
					break
				end
			end
		end
		
		--トラックに当たらなかったので新しいポイント
		if not tracked then
			ins(tr_ln, {track_id, {t}, 0,0,0,"u"})
			track_id=track_id+1
		end
	end

	--Aegis Data Transfer System(send).
    --次のマイコンに渡す処理。
	l=1
	for i=1,4 do O.setBool(i,false) end
	for i,v in ipairs(tr_ln) do
		--トラック削除 confオーバー、dフラグがある場合はtick=0伝送してからデータ削除
		if (tick-v[2][1][4])>conf and v[6]~="e" then
			v[6]="d"
		end

		--123:xyz,456:v(xyz),7:tick,8:track_id(num)
		if v[6] == "u" then
			outN(8*(l-1)+1,v[2][1][1],v[2][1][2],v[2][1][3],v[3],v[4],v[5],v[2][1][4],v[1])
			O.setBool(l,true)
			v[6]="-"
			l=l+1
		elseif v[6] == "d" then
			--WCSではtickが0の場合に削除を行う。送信後はトラックデータも削除する
			outN(8*(l-1)+1,0,0,0,0,0,0,0,v[1])
			O.setBool(l,true)
			v[6]="e"
			l=l+1
		end
		--tick=0データ転送後にトラックデータから削除
		if v[6] == "e" then
			table.remove(tr_ln,i)
			break
		end
		if l >= 4 then break end
	end

	outN(25,gx,gy,alt,sc,0,0,cp)
end