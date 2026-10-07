# Li47任务交接操作

工作仓库：<https://github.com/czp-1-A1/FPGA_Component_Inspector>。

本机完整Git工作区为`C:/Users/Li47/Desktop/aa/FPGA_Component_Inspector_git`，Li47交接分支为`handoff/li47`。原`FPGA_Component_Inspector/`目录是保留的源码快照，后续复用完整Git工作区，不重复克隆。

## 继续本人的任务

开始时先运行以下只读检查，核对当前分支、HEAD和全部未提交文件，再阅读`AGENTS.md`断点。分支不符或存在他人改动时先核实，不自动切换、覆盖或清理。

```powershell
Set-Location 'C:\Users\Li47\Desktop\aa\FPGA_Component_Inspector_git'
git status --short --branch --untracked-files=all
git branch -avv
git rev-parse HEAD
git remote -v
```

## 交给其他队员

1. 停止本端开发与可能写入工程的进程，更新`AGENTS.md`。写清目标、分支/基线、改动、证据、未决事项、下一操作、运行中进程/设备和提交/推送状态。
2. 检查未提交、暂存及未跟踪文件，只暂存本轮必要代码、交接说明和证据。不要用全部暂存把无关文件带入；凭据与机器进程不能通过Git交接。
3. 按用户授权提交并推送`handoff/li47`。首次推送用`git push -u origin handoff/li47`，之后用`git push`；禁止强推或未经确认合并到`main`。
4. 核对本地HEAD、上游分支与远端SHA一致，成功后才报告已同步。把分支名、提交SHA和未随Git传递的依赖告知接棒者；WIP仍按WIP说明，不作为验收通过。

## 接续其他队员的分支

先由用户确认接棒、给出目标分支并确认前一实现端已停止。确认后检查本机改动，再`git fetch origin`；已存在的本地目标分支继续复用，未存在时从对应远端分支建立跟踪分支。不得直接覆盖当前未提交改动，不盲目重置、拉取或强推。

切换完成后再次核对分支、HEAD、工作区及实际文件，并阅读该分支的`AGENTS.md`。确认工具依赖、必要证据和现场设备后，从断点继续，不重做已验证工作。

Git文件同步不代表FPGA验收通过。上板、编译、仿真和人工复核分别记录；冻结代码/镜像后才可独立测试，测试中不得改答案或降低目标。

本机Git使用Windows已有代理`127.0.0.1:10090`；代理和GitHub凭据只保存在本机配置，各队员按自己电脑配置。被忽略的官方大压缩包仍需另行取得。
