const fs=require('fs'),path=require('path');
const parts=[['W01','木底板',650,350,12,1,'设备孔现场对中再钻'],['W02','木立板',300,12,360,1,'两列相机孔间距暂120；孔阵列试装后定位'],['W03','三角加强板',120,12,200,2,'直角边120与200；连接角码孔另定位'],['W04','进出料托板',100,100,12,2,'支脚长度待带面与样带确定'],['P01','加强托臂',24,170,45,2,'水平板厚10；根部厚10；筋厚6；槽4.5×70；根部竖槽4.5×22'],['P02','亚克力限位块',24,18,8,4,'承托深12；限位唇高2；通孔4.5；台阶和孔位置待实体设计'],['P03','灯架竖向导板',24,12,150,2,'竖槽4.5×100；上下固定区各25；固定孔待布置'],['P04','灯前后支臂',20,140,12,2,'前后槽4.5×70；根部连接板及加强另设计'],['P05','分体外夹圈主体',110,110,16,1,'内径91；两半成组；夹耳、分缝、线口避让未包含'],['P06','载带导向块包络',30,20,10,4,'固定槽4.5×16；样带接触轮廓未定，暂不打印']];
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
function draw(p){const [id,n,x,y,z,q,note]=p,s=Math.min(380/Math.max(x,y),240/Math.max(y,z));const fX=90,fY=620,tY=300,rX=590;let out=`<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="820" viewBox="0 0 1100 820"><rect width="1100" height="820" fill="white"/><style>text{font-family:'Microsoft YaHei',sans-serif;fill:#20313c} .part{fill:#e6eef0;stroke:#263e4c;stroke-width:1.6}.dim{stroke:#527582;stroke-width:1;fill:none}.slot{fill:white;stroke:#263e4c}</style><text x="40" y="45" font-size="25">${id} ${n} · 尺寸草案</text><text x="40" y="77" font-size="16">单位mm · 第三角布局 · 数量${q} · 同页三视同比例 · 不按纸面比例量取</text><text x="40" y="104" font-size="15">用户授权假设尺寸；未完成实体CAD、孔位配合与强度验证，不可直接打印。</text>`;
const text=(a,b,t,size=16)=>out+=`<text x="${a}" y="${b}" font-size="${size}">${esc(t)}</text>`;
const rect=(a,b,w,h,cl='part')=>out+=`<rect class="${cl}" x="${a}" y="${b}" width="${w}" height="${h}"/>`;
function dims(a,b,w,h,wl,hl){out+=`<path class="dim" d="M${a},${b+h+8}v20 M${a+w},${b+h+8}v20 M${a},${b+h+20}h${w} M${a+w+8},${b}h20 M${a+w+8},${b+h}h20 M${a+w+20},${b}v${h}"/>`;text(a+w/2-8,b+h+42,String(wl));text(a+w+25,b+h/2+5,String(hl));}
text(fX,145,'俯视（X×Y）');text(fX,365,'正视（X×Z）');text(rX,365,'右视（Y×Z）');
const topB=tY-y*s,frontB=fY-z*s;
if(id==='P05'){out+=`<circle class="part" cx="${fX+x*s/2}" cy="${topB+y*s/2}" r="${55*s}"/><circle class="slot" cx="${fX+x*s/2}" cy="${topB+y*s/2}" r="${45.5*s}"/>`;text(fX,topB-12,'主体 Ø110 / 内孔 Ø91');}else rect(fX,topB,x*s,y*s);
rect(fX,frontB,x*s,z*s);
if(id==='W03'){out+=`<path class="slot" d="M${fX},${frontB} H${fX+x*s} V${fY} Z"/>`;}
if(id==='P01'){out+=`<path class="part" d="M${rX},${fY-10*s} H${rX+(y-10)*s} V${frontB} H${rX+y*s} V${fY} H${rX} Z"/>`;out+=`<path class="dim" stroke-dasharray="5 3" d="M${rX+70*s},${fY-10*s} L${rX+(y-10)*s},${frontB+5*s}"/>`;}else rect(rX,frontB,y*s,z*s);
if(id==='P03')rect(fX+(x-4.5)*s/2,frontB+25*s,4.5*s,100*s,'slot');
if(['P01','P04'].includes(id))rect(fX+(x-4.5)*s/2,topB+(y-70)*s/2,4.5*s,70*s,'slot');
dims(fX,topB,x*s,y*s,x,y);dims(fX,frontB,x*s,z*s,x,z);dims(rX,frontB,y*s,z*s,y,z);
text(40,720,note,15);text(40,752,'浅色轮廓表示主体外形；未画出的孔、夹耳、台阶、连接结构不得凭图自行补加工。',14);text(40,783,'配套：08_默认尺寸与采购草案.md；先小件试配，再完成正式实体模型与加工图。',14);return out+'</svg>';}
let html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>简易支架尺寸草案</title><style>body{margin:24px auto;max-width:1150px;background:#eef2f3;font-family:Microsoft YaHei,sans-serif;color:#20313c}h1,p{margin:20px}section{background:white;margin:22px 0;padding:12px;border-radius:10px}img{width:100%;height:auto}a{color:#087769}@media print{section{break-after:page;margin:0}h1,.intro{display:none}}</style><h1>木板与打印件：尺寸草案</h1><p class="intro">默认尺寸已选定，但未形成可加工的实体CAD。图中注明的未定细节需要试配后补全。<a href="08_默认尺寸与采购草案.md">查看尺寸依据、备料数量与操作顺序</a></p>';
for(const p of parts){let file=p[0]+'_尺寸三视草案.svg';fs.writeFileSync(path.join(__dirname,file),draw(p),'utf8');html+=`<section><img src="${file}" alt="${p[1]}尺寸三视草案"></section>`;}
fs.writeFileSync(path.join(__dirname,'零件尺寸三视草案.html'),html+'</html>','utf8');console.log('Created 10 dimension sheets and HTML index');
