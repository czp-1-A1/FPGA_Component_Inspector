from pathlib import Path
root=Path(__file__).resolve().parent
runner=(root/'run_mc.ps1').read_text()
runner=runner.replace('[int[]]$Pauses=@(0,1000,2000)', '[int[]]$Pauses=@(1200,1400,2000)')
runner=runner.replace('[int[]]$FirstModes=@(0,2)', '[int[]]$FirstModes=@(0)')
runner=runner.replace('$second=2-$first', '$second=0')
(root/'run_control.ps1').write_text(runner,encoding='utf-8')
print('Prepared matched RAW warm-frame/RAW second-frame control runner')
