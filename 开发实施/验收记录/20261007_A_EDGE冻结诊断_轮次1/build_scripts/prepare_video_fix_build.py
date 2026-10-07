from pathlib import Path
import json,shutil,hashlib,sys
r=Path(".").resolve();p=r/"fpga/component_inspector";old=r/"tmp/sw_edge_td_build_20261005"
b=r/("tmp/"+(sys.argv[1] if len(sys.argv)>1 else "video_fix_td_build_20261006"))
assert not b.exists(),"Never overwrite a build"
inputs=json.loads((old/"inputs.json").read_text(encoding="utf-8"))
for entry in inputs:
 rel=entry["path"];dst=b/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/rel,dst)
for stage in ["syn_1","phy_1"]:
 dst=b/"td_project/camera_to_dsi_display_Runs"/stage;dst.mkdir(parents=True)
 for name in ["settings.cfg","build.tcl","camera_to_dsi_display.prj"]:
  shutil.copy2(old/"td_project/camera_to_dsi_display_Runs"/stage/name,dst/name)
manifest=[{"path":e["path"],"sha256":hashlib.sha256((b/e["path"]).read_bytes()).hexdigest(),"bytes":(b/e["path"]).stat().st_size} for e in inputs]
(b/"inputs.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("Prepared independent TD build:",len(manifest),"inputs",b)
p=r/"AGENTS.md";s=p.read_text(encoding="utf-8")
s=s.replace("未进行新综合、布局布线或镜像生成。","本轮独立综合在tmp/video_fix_td_build_20261006；通过全部测试后才发布新release。")
s=s.replace("诊断仿真已结束，无助手构建／JTAG后台任务；","本轮ModelSim实际ISP回归和TD独立综合正在运行；无助手JTAG任务；")
s=s.replace("**下一操作**：执行已批准的最小修复范围：","**下一操作**：修复RTL已落盘，专项Sobel/transport通过；继续实际ISP、4模式完整DDR/显示回归、TD综合与时序。已批准范围：")
s=s.replace("**本轮改动**：实现开始前","**本轮改动**：video_in/video_out、roi_sobel_view、实际96->128 packer、isp_top、top连接、roi_observation_snapshot、experiment_osd、SDC和相关sim/TB/资产；实现开始前")
p.write_text(s,encoding="utf-8")
