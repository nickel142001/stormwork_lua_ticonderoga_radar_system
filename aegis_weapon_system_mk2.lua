--AWSCC
M=math
pi2=M.pi*2
si=M.sin
co=M.cos
S=screen
dL=S.drawLine
dTF=S.drawTriangleF
dRf=S.drawRectF
dT=S.drawText
C=S.setColor
I=input
O=output
T=table
sf=string.format
tU=T.unpack
tP=T.pack
ins=T.insert
rem=T.remove
tick=0
outB=O.setBool
cntct={}
--{1:x,2:y,3:z,4:vx,5:vy,6:vz,7:tick,8:f_ctrl,9:recalc_tick,10:eta,11:close_dist,12:threat}
--f_ctrl : 割り当てされているFUの番号を格納、通常時0、FU1～4
--recalc_tick : FU割り当て後再評価までのtick
--eta : 到達予想時間
--close_dist : 到達予想時間での距離
--threat : eta=-1 → -100 / eta:15s and close:400m 以内 + 100pt / eta:15s-30s and close:600m 25pt / eta:30-40 5pt , close 1000m 5pt
thl=100
up,pup,dw=false,false,false
csr=1
fu={{false,2000,250,7,1,{}},{false,2000,250,7,1,{}},{false,6000,325,10,4,{}},{false,6000,325,10,4,{}}}
-- fu : fire unitの配列、1～4
-- 1,2:ESSM 3,4:中SAM {1:busy(t/f),2:battle_dist(m),3:spd(m/s),4:hit_time,5:assign_num,6:{assinged_track(str),assign_tick}....}
--busy true:処理中、割り当て不可、 assinged_track:割り当てられたターゲットの添え字、battle_dist:標準交戦距離、 spd：飛翔速度
function getN(...)local a={}for b,c in ipairs({...})do a[b]=I.getNumber(c)end;return tU(a)end
function getB(...)local a={}for b,c in ipairs({...})do a[b]=I.getBool(c)end;return tU(a)end
function outN(o, ...) for i,v in ipairs({...}) do O.setNumber(o+i-1,v) end end
function dist3d(a,b) return M.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2) end
function clamp(a,b,c) return M.min(M.max(a,b),c) end
function push(a,b) return not a and b end
function nearest(g,h)
    bt=60
    bd=M.sqrt((g[1]-(h[1]))^2+(g[2]-(h[2]))^2)
    d=M.sqrt((g[1]-(h[1]+h[4]*bt))^2+(g[2]-(h[2]+h[5]*bt))^2)
    hv=M.sqrt(h[4]^2+h[5]^2)
    if hv<0.5 and h[6]<-0.1 then return -1,bd end --30m/sも動いていない場合はホバリングor自由落下とみてeta=-1
    if bd<d then return -1,bd end --遠ざかっている場合はeta=-1
    bsc=300 --5s
    bt=bt+bsc
    for i=1,20 do
        d=M.sqrt((g[1]-(h[1]+h[4]*bt))^2+(g[2]-(h[2]+h[5]*bt))^2)
        if bd < d then --遠ざかった場合は近点を通り過ぎた
            bsc=bsc/2
            bt=bt-bsc
        else --近づいた場合は更に時間を経過させ、かつ比較対象bdを置き換え
            bt=bt+bsc
            bd=d
        end
    end
    return bt,d
end
function p_calc(e,d)
    local p=0
    e=e/60
    if e<0 then p=-50
    elseif e<15 then
        if d<200 then p=100
        elseif d<400 then p=50 elseif d<800 then p=15 else p=-15 end
    elseif e<30 then
        if d<800 then p=25
        elseif d<1200 then p=10 else p=-10 end
    elseif e<50 then p=5
    end
    return p
end
function n_calc(p,t) return p[1]+p[4]*60*t,p[2]+p[5]*60*t,p[3]+p[6]*60*t end

function onTick()
    tick=tick+1
    gps=tP(getN(25,26,27))
    cp=getN(31)
    fr=tP(getB(22,23,24,25))
    at=tP(getB(29,30,31,32))
    pup,pdw,pfire=up,dw,fire
    up,dw,fire=getB(26,27,28)
    if push(pup,up) then
        csr=csr-1
    elseif push(pdw,dw) then
        csr=csr+1
    end
    csr=clamp(csr,1,9)

    --Aegis Data Transfer System(recv)
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
                pc[10],pc[11]=nearest(gps,pc)
                if cntct[id_s] ~= nil then
                    pc[8],pc[9]=cntct[id_s][8],cntct[id_s][9]
                    pc[12]=clamp(cntct[id_s][12]+p_calc(pc[10],pc[11]),-100,350)
                else 
                    pc[8],pc[9]=0,0
                    pc[12]=clamp(p_calc(pc[10],pc[11]),-100,350)
                end
                cntct[id_s]=pc
            end
        end
    end
    --fuのステータスリセット
    for i,v in ipairs(fr) do
        if v then
            fu[i][1]=false
        end
    end
    if push(pfire,fire) then
        idx=1
        for k,v in pairs(cntct) do
            if idx == csr then
                --todo fu1以外にも対応する
                npos=tP(n_calc(v,7))
                d=dist3d(gps,npos)
                for i,f in ipairs(fu) do
                    if not(f[1]) and d<f[2] and at[i] then
                        f[1]=true
                        ins(f[6],1,{k,tick})
                        if #f[6]>f[5] then rem(f[6]) end
                        v[8]=i
                        v[9]=(d/f[3]+3)*60
                        break
                    end
                end
                break
            end
            idx=idx+1
        end
    end


    --まだFUに割り当てられていないターゲットを脅威度順に並べる
    tgt={}
    for k,v in pairs(cntct) do
        if v[12]>=thl and v[8]==0 then
            upd=false
            for i=1,#tgt do
                if v[12]>=tgt[i][2][12] then
                    ins(tgt,i,{k,v})
                    upd=true
                    break
                end
            end
            if not(upd) then ins(tgt,{k,v}) end
        end
        --割り当てを得ているターゲットのヒット予想時刻カウンターをカウントダウン、0になったら割り当て解除
        if v[9]>0 then 
            v[9]=v[9]-1
            if v[9]<=0 then v[8],v[9]=0,0 end
        end
    end
    for i,p in ipairs(tgt) do
        --todo : 高脅威度の目標に対して適切なFUを割り当て、発射態勢へ
        --7s後に2,000m以内に到達するならESSM、それ以外なら中SAM
        --SAM側で衝突予定時刻を計算してcontactsに格納する。そのtick待って次の評価へ。
        npos=tP(n_calc(cntct[p[1]],7))
        d=dist3d(gps,npos)
        for i,v in ipairs(fu) do
            if not(v[1]) and d<v[2] and at[i] then
                v[1]=true
                ins(v[6],1,{p[1],tick})
                if #v[6]>v[5] then rem(v[6]) end
                cntct[p[1]][8]=i
                cntct[p[1]][9]=(d/v[3]+3)*60
                break
            end
        end
    end
    for i=1,32 do
        outB(i,false)
        outN(i,0)
    end
    for i,v in ipairs(fu) do
        if #v[6]~=0 then
            if cntct[v[6][1][1]]==nil then
                rem(v[6],1)
            else
                c=cntct[v[6][1][1]]
                if v[6][1][2]~=tick then outB(i,true) end
                --123:xyz,456:v(xyz),7:tick,8:track_id(num)
                --フォーマットはADTSと同じ
                --送出するデータはfu[6]のリストの1番、送出後、そのデータはリストの最後に送る
                outN(8*(i-1)+1,c[1],c[2],c[3],c[4],c[5],c[6],c[7],tonumber(v[6][1][1])+v[6][1][2])
                p=v[6][1]
                rem(v[6],1)
                ins(v[6],p)
            end
        end
    end
end

function onDraw()
    w=160
    h=96
    a=h-3
    
    --header
    C(245,150,0)
    dRf(1,2,w-2,9)
    C(0,0,0)
    dT(6,4,"ID DIST BEA  ALT  SPD  THR FU")
    --cursor
    C(255,255,255,120)
    dRf(1,2+9*csr,w-2,9)
    C(255,0,0,180)
    dTF(w-7,2+9*csr+5,w-5,2+9*csr+3,w-5,2+9*csr+7)

    --line
    C(245,155,50)
    for i=2,h,9 do dL(1,i,w-1,i) end
    dL(1,2,1,a)
    dL(17,2,17,a) --track_id 3
    dL(42,2,42,a) --dist x.xx km
    dL(62,2,62,a) --bear xxx deg
    dL(87,2,87,a) --ALT xxxx m
    dL(112,2,112,a) --SPD xxxx m
    dL(137,2,137,a) --THR
    dL(150,2,150,a) --FU
    dL(w-2,2,w-2,a) --blank

    --status
    --todo : 高脅威度を強調表示、発射態勢も強調表示
    --todo : ズラしたステータス表示を直す。ブランク部分を動かしてETAか脅威度を出すのが良い？
    C(255,255,255)
    l=1
    for k,v in pairs(cntct) do
        tar=M.atan(v[1]-gps[1], v[2]-gps[2])/pi2
        bea=((cp+tar)*360+360)%360
        -- dT(2,9*l+4,sf("%s %5.2f %3.0f %5.0f %1.0f",k,dist3d(gps,v)/1000,v[10]/60,v[11],v[12]))
        if l>9 then
            C(0,0,0)
            dRf(2,84,w-4,8)
            C(255,0,0)
            dT(9,85,"more>>>")
            break
        end
        dT(2,9*l+4,sf("%s%5.2f %3.0f %4.0f %4.0f %4.0f %1.0f",k,dist3d(gps,v)/1000,bea,v[3],M.sqrt((v[4]*60)^2+(v[5]*60)^2+(v[6]*60)^2),v[12],v[8]))
        l=l+1
    end
 end
