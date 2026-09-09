const fs=require('fs'),path=require('path');const dir=__dirname;let h=fs.readFileSync(path.join(dir,'背面折叠支架_调节与三视图.html'),'utf8');
h=h.replaceAll('结构方案 02','整体布局 V3 · 130×90板卡 / 420×110机身').replaceAll('max="4" step="1" value="2"','max="8" step="1" value="3"').replaceAll('min="110" max="190" step="1" value="160"','min="100" max="250" step="1" value="157"').replaceAll('hole:2,camY:0,lampY:0,lampZ:160','hole:3,camY:0,lampY:0,lampZ:157');
h=h.replace('下列mm数值只用于演示相对运动，均非实测。高度档距、槽长及最终工作距离尚待确认。','板卡130×90、机身420×110×80为用户提供；带面高80、镜头下伸20、检测面高85为假设。40—200 mm仅为机械调节目标。');
h=h.replace('购物图片文件名400×80 mm，按名义外形占位','用户提供：带面420×80；机身420×110×80 mm').replace('外观与尺寸为占位；背面摄像头由用户固定','板卡与上下亚克力130×90；下板厚1、组件上部30为假设').replace('确认实物型号、安装孔位置和螺纹；未按猜测孔位设计','新增外夹圈为自制件，外径110、内径91、高16；夹紧细节和防滑须试装').replace('从灯壳外侧承重，中央孔保持无遮挡。','新增分体外夹圈夹持灯壳；不假设灯自带支臂，夹耳细节待建模。');
const start=h.indexOf('function build()'),end=h.indexOf('function project(',start);if(start<0||end<0)throw Error('build location');
const build=`function build(){faces=[];const H=151+S.hole*20,Y=S.camY,LY=S.lampY,LZ=S.lampZ;
box(0,30,0,650,350,12,C.wood,'底板650×350×12');box(0,116,12,300,12,360,C.wood,'立板300×360×12');brace(-138);brace(138);
for(let x of [-65,65])for(let z=115;z<=315;z+=20)hole(x,z);
box(0,0,64,420,110,26,C.white,'机身包络420×110×80');box(0,0,90,420,80,2,'#fafaf5','带面420×80；带高假设80');for(let x of [-160,160])for(let y of [-40,40])box(x,y,12,18,14,52,C.white,'传送带支脚占位');box(190,-41,43,35,28,27,'#e5be37','电机位置占位');
for(let x of [-260,260]){box(x,0,85,100,100,12,C.wood,'托料板100×100×12');for(let dx of [-35,35])box(x+dx,0,12,12,80,73,C.wood,'托料脚高度待样带');}
box(0,0,96,630,12,1,C.tape,'载带宽12为占位');for(let x=-300;x<=300;x+=12){box(x,0,97,7,6,.6,'#859193','样品穴位');}
for(let x of [-165,165])for(let sign of [-1,1])box(x,sign*21,92,30,20,10,C.print,'导向块占位');
for(let x of [-65,65]){box(x,101,H-35,24,18,45,C.print,'托臂根部');box(x,20,H-4,24,170,10,C.print,'前后托臂');box(x,0,H+6.1,4.5,70,.5,'#141d24','前后槽');for(let yy of [Y-25,Y+30]){box(x,yy,H+6,24,18,8,C.print,'承托限位块');ring(x,yy,H+14,4.5,0,3,C.metal,'锁紧件',12);}}
box(0,Y,H+14,130,90,1,C.plate,'下亚克力130×90×1假设');box(0,Y,H+24,130,90,2,C.board,'板卡130×90');box(0,Y,H+43,130,90,1,C.plate,'上亚克力厚度占位');for(let x of [-55,55])for(let yy of [-35,35])ring(x,Y+yy,H+15,2.5,0,28,C.metal,'隔离柱占位');box(-20,Y+12,H+26,25,22,4,'#202a34','芯片占位');for(let x=-40;x<50;x+=18)box(x,Y-15,H+26,12,8,4,'#34434c','器件占位');
box(0,Y,H+10,26,26,3,C.camera,'背面摄像头占位');ring(0,Y,H-6,7,0,18.3,'#202b31','镜头直径14高18.3');box(0,Y-43,H+12,12,2,15,C.gold,'排线占位');
for(let x of [-75,75]){box(x,89,12,28,36,10,C.print,'灯架底座');box(x,93,22,16,14,258,C.print,'灯架竖槽杆占位');box(x,85.8,100,5,.7,150,'#182329','灯高槽');box(x,86,LZ+4,25,18,18,C.print,'灯高滑块');box(x,(LY+87)/2,LZ+8,20,87-LY+15,12,C.print,'灯前后支臂');box(x*.79,LY,LZ+8,30,14,8,C.print,'自制连接耳占位');}
ring(0,LY,LZ,45,20,22,C.print,'现成环形灯90/40/22');ring(0,LY,LZ-.5,43,22,.6,'#e7efdc','发光面');ring(0,LY,LZ+3,55,45.5,16,'#68838d','新增外夹圈110/91/16；分缝夹耳未细化');box(215,-110,12,88,68,36,'#34434c','控制器占位');
anchors={H,Y,LY,LZ,lensBottom:H-6,tapeZ:97};}
`;
// H is an internal rail datum. Support plane H+14; lens extends20 below it.
h=h.slice(0,start)+build+h.slice(end);
h=h.replaceAll('210+S.hole*20-24-22-10','151+S.hole*20-6-22-10').replaceAll('Math.min(190,','Math.min(250,').replaceAll('anchors.lensBottom-85','anchors.lensBottom-97').replaceAll('S.lampZ-85','S.lampZ-97').replaceAll('[0,S.camY,85]','[0,S.camY,97]').replaceAll('[0,S.lampY,85]','[0,S.lampY,97]').replaceAll('[0,y,85]','[0,y,97]');
// Shift default to measured-distance illustration: H=203 yields100 above97.
h=h.replaceAll('151+S.hole*20','143+S.hole*20');
h=h.replaceAll('背面折叠支架 三视结构示意','整体布局V3 三视结构示意').replace('结构三视示意，非加工图。','整体三视示意，非零件加工图。').replace('两侧承托，中间留空','两侧承托，中间留空');
// User-approved assumption: lens is +20 along the 130mm board edge.
// Keep both supports and their holes symmetric. Shift only the existing board assembly.
h=h.replace('box(0,Y,H+14,130,90,1,C.plate', 'const boardFaceStart=faces.length;box(0,Y,H+14,130,90,1,C.plate');
h=h.replace("box(0,Y,H+10,26,26,3,C.camera", "for(let p of new Set(faces.slice(boardFaceStart).flatMap(f=>f.p)))p[0]-=20;box(0,Y,H+10,26,26,3,C.camera");
h=h.replace('anchors={H,Y,LY,LZ,lensBottom:H-6,tapeZ:97}', 'anchors={H,Y,LY,LZ,lensBottom:H-6,tapeZ:97,boardCenterX:-20,lensCenterX:0,lensOffsetX:20}');
h=h.replace('先让镜头对准器件，再让环形灯对准镜头。相机与隔离板的内部固定由你完成。', '托臂与木板孔位保持左右对称，不错开20 mm。仅板卡组件左移20 mm示意镜头对中；此位置下右侧承托不足，实际摆放须确认两侧接触，当前不是已验证装配。');
h=h.replace('板卡与上下亚克力130×90；下板厚1、组件上部30为假设', '板卡与上下亚克力130×90；镜头相对板中心X偏置+20、Y偏置0为假设；下板厚1');
h=h.replace('当前示意：第${S.hole+1}档；', '偏心假设+20 mm，板中心−20 mm；第${S.hole+1}档；');
h=h.replace('所有位置数值仅演示，须实测后确定尺寸与配合。','镜头偏心+20、板中心−20为假设，安装时核对。');
fs.writeFileSync(path.join(dir,'整体布局V3_审阅.html'),h,'utf8');console.log('V3 created with assumed lens offset +20mm');
