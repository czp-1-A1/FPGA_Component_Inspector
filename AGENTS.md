# D3 当前最后一次尝试 R37；失败后必须停下分析（2026-10-30 20:25，最高优先级）

- 用户已明确：**显示精简还要考虑，先过完整功能版；“这版不成功就先停下来，分析一下解决方法，在继续执行”**。已向用户承诺：当前候选作为本轮最后一次尝试，若布局布线/时序不通过，停止新构建，先交付原因/证据/下一步方案，等用户看过再继续。**不得再自行换seed/策略/RTL连跑下一候选。** 没有删模式、算法、计数/停车/调试功能。
- 生产HEAD仍3c0c86d3/R28四项无损源，未采用新候选，无bit发布、无推送/实板/电机动作。主工作区只有检查/文档/实验脚本和夹具修改，原生产RTL未覆盖。
- R31已19:03核对唯一TD PID35064 parent28696后停止；best iter20 over4070→21 4296→22 4595→23 4598，单轮耗时219→243→296→406秒。D:/CodexWork/D3_Congestion_Physical_R31_20261030/ABORT_REASON.json含退出后日志SHA（Windows写锁阻止退出前GetFileHash），session8555已结束exit1为主动停止后runnerassert，未完整route，非最终时序判决。
- **唯一活动全TD R37** E:/2026FPGA/.codex_tmp/d3_lossless_physical_r37_20261030，session46883，TD PID35536 parent31824，20:22开始，Default/seed4，当前全局布局。冻结704源/107依赖，复用R36实际gate.db，EXACT_SYNTHESIS_REUSE完整。若本轮失败遵守上条停止，不再尝试R38等。
- R36综合已完成200.3秒：E:/2026FPGA/.codex_tmp/d3_lossless_synthesis_r36_20261030，session35501已poll结束，Slice*22073（R28 22188省115），LUT28554、FF23294、ERAM103（省1）、DSP31/PLL5。源manifest f9111f8ff04af80f17eb058361999c7bb550eb96c547a67120d9acfa1920f115，gateDB69c57457062524924def97e412d16a0c0ef576ddc6263ef6687d01b9b0a1a562。是SYN估算而非物理数。额外优化来自R32 full10bit数学共享、R35 bytefont（95ASCII*16行+7CJK*24行*3byte=2024byte，原padding全零验证、1物理ERAM/19LUT/noDSP）；observer仅两个bram属性，但**迁RAM没有实现**，DRAMLUT792保持。
- R36 SYN实际警告已找到根因：console行1457/1460 SYN-5105：observer第259行的记录RAM无法推断bram，因输出寄存器同步复位与读地址寄存器异步复位不受支持，回退DRAM；原distributed属性还报SYN-5041 auto。这是后续分析证据，**本轮不再改RTL试修**。后续可提出拆分RAM无复位同步读与有效/复位门控，保持原读口周期/复位行为、FSM/编号不变，再逐拍对照+实际映射验证，须先交给用户审阅。
- 新候选仍隔离：E:/2026FPGA/.codex_tmp/d3_byte_font_source_r35_20261030/project。scripts/probe_d3_byte_font.py生成；scripts/run_d3_prepared_synthesis.py仅运行冻结源且拒绝并发TD。R35字体73728type/address/col、OSD3栅格+8重叠栅格已PASS实际PH1P_PHY_ERAM_V2 vendor模型，verification在d3_byte_font_equivalence_r35_20261030。RAM属性13case仍可从D:/CodexWork/D3_Record_RAM_Cases_R34_20261030逐SHA复用，1197公开位每拍原R27B对照。
- 运行当前R37的必要验证：**session68271** E:/2026FPGA/.codex_tmp/d3_lossless_units_r8_20261030，13bench sequential（pixels/rank/cache/distance/osd/keys/metadata/tracker/resize/ring/wide/mathbounds/真实100MHz1秒），R35模型已由relay_left_checks.py自动加载；**session91901** d3_lossless_native_r8_20261030（当前R37源12真实RAW/双计数/DDR全显示，permit0，不冒称RAW停车），20:24开始尚未PASS。尚待同源empty_native及最终软件profile收据；本轮若物理失败不再启动新构建。
- 新实际R36相机SYN锥导出/两次复位126I2C已PASS：d3_lossless_camera_r4_20261030，session55912尚可poll关闭，R36 CAMERA_EXPORT和netlist已复制R37，302cell新DB实际证明，不复用旧网表。当前新profile预计32项（原30+字体穷举+数学穷举），**尚未汇总，不得宣称32PASS**。原生产R28/R31的30精确源PASS仍有效但不能冒充R37源。
- scripts/check_d3_observed_counter.py新增--source/--out，只允许额外去除ledger/empty_ids EXACT两条bram属性后恢复原R27B全文（不允许其他FSM/memory行为/参数/时钟修改）；R36/OBSERVER_PROOF.json已PASS；未覆盖生产docs旧proof。verify_d3_checks.py已额外核vendor_inputs冻结SHA，当前生产仍lossless-v3/30要求。
- E约5GB/D约1.96GB，用户已清出E，R35/36/37均在E。无子代理，保护旧BIT_FLASH三版。所有后续bit仍需完整route/setup+hold/实际资源与704Git源审核通过后封包+BIT_FLASH同SHA；本轮失败不得发布未验收bit。

# D3 最新：显示取舍分析，完整功能 R31 仍布线（2026-10-30 18:55，以下为历史）

- 最新用户询问若本版无法跑通，删除边缘显示但保留算法是否可行，以及当前功能清单。已核源码两套边缘路径：全帧 roi_sobel_view 用于显示，frame_shape_search 内 local_edge_surface_check 用于识别。仅删模式2、保留模式3预计收益小；RAW+灰度候选可研究移除显示全帧通路但保留局部识别。**用户尚未选择删功能，不得擅自采用。** docs/D3_FEATURE_RESOURCE_OPTIONS.md 是选择清单，不是实施记录。
- 生产 HEAD **3c0c86d3**，四项无损 RTL 同55c092a9/R28；未推送，无新bit/实板/电机操作，无子代理。700其他冻结输入及 R27B 主计数原件保持。当前30项软件检查lossless-v3精确绑定R31全部PASS；新增tb_d3_rgb_wide覆盖4完整720p/4模式/3686400像素/460800梯度，原R11逐拍对照。软件30PASS不是物理通过。
- **唯一活动完整TD R31** D:/CodexWork/D3_Congestion_Physical_R31_20261030，session8555，TD PID35064 parent28696，官方CongestionMedium/seed2，相同704源和R28实际gate.db。实际place20904 Slice/98.53%、104ERAM、31DSP、5PLL；18:53左右route iter20 over4070→21 over4296，未完成，不得宣称最终时序PASS。R29默认布局20737/97.74%比旧R11 21160/99.74%省423真实placed Slice，但R29路由迭代20→23变差后已终止留ABORT_REASON。**R30 MacroTiming已TD工具崩溃**，TOOL_CRASH.json及minidump留证，不再运行。不得并发第二个全TD作业。
- 主工作区未提交：verify_d3_checks.py及publish_dual_stop_d3.py支持/要求30lossless-v3；docs/D3_SOFTWARE_VERIFICATION.json是实际R31的30PASS；tb_d3_rgb_wide.sv需明确stage；relay_left_checks.py新增仅在物理字体候选自动加载vendor ERAM仿真模型，当前生产30检查未用此模型。其他旧未跟踪station/bank/sim文件不要stage-all。
- **仅隔离实验，未采用也无综合收益数字**：R32 D3_Math_Source_R32预计算resize×3和共享Sobel绝对值，穷举1048576绝对值+resize131072/36流+48ring+4全720p全部PASS；R33 D3_Font_Primitive_Source_R33直接PH1P_PHY_ERAM_V2字体保留全部glyph，实际vendor模型73728地址及3+8完整OSD栅格PASS，试省字库RAM但未SYN；R34 D3_Record_RAM_Source_R34仅observer的ledger/empty_ids两RAM加ram_style="bram"，13case全部已完成verification.json。R34尚需看实际SYN映射，若采用需更新observer可逆证明只允许移除这两个属性、补vendor依赖HASH校验、源绑定新camera/native/软件/物理，不可把旧30PASS冒充新源。R33推测省RAM/R34推测省DRAMLUT均未测，不得当实际收益。
- 继续保护BIT_FLASH旧RL7/D2/LATEST_READONLY；无新bit前不覆盖发布入口。E约1GB/D约2GB，不删除用户/旧证据。完整route和严格setup/hold/源HASH审计通过才可发布。上一段18:14仅历史，尤其R30活动状态已失效。

# D3 R30 宏布局策略进行中（2026-10-30 18:14，以下为历史）

- 生产提交 **55c092a9**（分支codex/r27b-dual-count-and-stop-d3，未推送）：已合入4份无损优化源；704个冻结输入与HEAD blob全部核对。其他700输入、原R27B计数核心、全部字体/诊断、32队列/完整1秒/双列五空/按键V2/ADC/SDC保持。详见下方17:43记录。没有新bit、无子代理/实板/电机操作。
- **全部29项精确源码软件检查已PASS**：scripts/verify_d3_checks.py --work D:/CodexWork/D3_Lossless_Physical_R29_20261030；新native_r6真实12RAW/24显示/22940160精确像素、每列4/P2/E2、晚WB取消，17:57结束，native permit0，停车由独立case检查不混称RAW停车。empty_native_r6也PASS。所有ModelSim已结束。docs/D3_SOFTWARE_VERIFICATION.json保存相同回执，目前尚未提交（gitignore可能需-f add）。
- **同阶段真实物理节省**：从R11与R29各自实际place.db只读导出，Slice21160/99.74%→20737/97.74%，省423、空闲56→479；ERAM107→104；DSP31/PLL5不变。导出原始报告、DB/脚本/报告SHA在R29/placed_intermediate.area、baseline_r11_placed.area、PLACED_AREA_PROVENANCE.json、BASELINE_PLACED_AREA_PROVENANCE.json。仅Placed，不是最终routed验收。
- **R29路由已终止未完成，不是PASS/最终时序失败**。默认PHY/seed2初期setup+.044、crit0，但iteration20 over3780→21 3852→22 4038→23 4374连续变差，线路增长，已核唯一TD PID15624 parent23280无child后停止，ABORT_REASON.json留证。原place.db/日志保持。session90647需poll结束，无bit可发布。
- **唯一活动完整TD：R30** D:/CodexWork/D3_Macro_Physical_R30_20261030，session21685，TD PID11764 parent31704。复用R28相同704源+实际gate.db，EXACT_SYNTHESIS_REUSE，官方MacroTiming/seed2，针对104ERAM的macro_congestion/anchor布局；所有时钟/SDC/IO不改。18:13仍Placement优化，未有最终资源。scripts/build_r22_relay.py增加MacroTiming选择尚未提交。
- R30/CHECK_PROFILE.json、CAMERA_EXPORT/302cell实际相机网表证明与R28同SHA DB已复制；**R30 verify_d3_checks已重新精确核源29PASS**，不重跑22分钟RAW。源码仍R28，后续仅不同物理策略。不要开第二个TD全构建或改冻结源。
- 主工作区本轮未提交：docs/D3_RESOURCE_ANALYSIS.md/json已增加同阶段Placed实际数字；scripts/report_d3_resources.py增加读取中间area，build脚本MacroTiming；docs/D3_SOFTWARE_VERIFICATION.json可能被ignore。发布准备脚本在55c已要求29项lossless-v2、104ERAM/31DSP、原49bounds/20Gray/9mailbox/双alarm到V2；先完整route/setup+hold都通过，再严格audit/publisher。物理若继续不收敛，须继续无损优化/针对实际物理路径，不能关闭功能或松约束。

# D3 无损优化 R29 完整物理构建中（2026-10-30 17:43，以下为历史）

- 最新用户要求继续优化Slice，包括调试，但绝不影响功能。本轮已采用四份源的无损重排：rank记录存一次+指针排序、选中标签后共享字符格式、显示缩放加法合并、RGB三行环形缓存（灰度仍四行/原溢出保护不改）。**最终保留原ASCII/CJK字库；合并字库因352LUT+1DSP反而不利被拒绝，未合入。** R11其余700份冻结输入逐SHA不变，R27B计数核心原件SHA67dfbdd7...仍不变，所有功能/调试信息/按键/IO/SDC保留。
- 已把采用的四份源合入主工作区，生产FSS SHAe031d235d78b1bfbd271f33718d064d15c0eeb80f55b3cd6f938dacd358813a4，bounds证明已重新生成。尚未提交本轮/尚无新bit发布，无推送、子代理、硬件动作。
- **R28已完成默认综合** D:/CodexWork/D3_Lossless_Synthesis_R28_20261030：Slice*22821→22188（省633/2.77%），LUT29345→28596，FF23557→23262，ERAM107→104，DSP31/PLL5不变。不要把综合估算当实际物理Slice；实际收益/时序仍待R29。
- **唯一活动完整TD：R29** D:/CodexWork/D3_Lossless_Physical_R29_20261030，session90647。从R28逐SHA相同704源+实际gate.db复用，EXACT_SYNTHESIS_REUSE.json；默认PHY/seed2，原SDC不改。17:42已完成GlobalPlacement、进入DetailedPlacement。不能提前宣布资源/布线通过。
- **新实际相机综合网表已PASS** d3_lossless_camera_r3_20261030：302cells闭合锥、两复位×126完整I2C EXP1092/GAIN40/WB100100；R28/CAMERA_EXPORT.json及网表/导出日志SHA已复制R29，绑定同SHA gate.db，不复用旧相机结论。
- 29项选定检查由verify_d3_checks.py中的lossless-v2 profile列出并固定必需测试名；R29/CHECK_PROFILE.json绑定源manifest。原24项保留、额外5项rank/OSD等价/重叠/resize/ring。旧核心17项编译源完全不变可逐SHA复用；新d3_lossless_units_r6（5项）全部PASS；OSD两项d3_osd_share_pixels_r1、resize_r1、rgb_ring_r2精确编译源匹配。docs/D3_LOSSLESS_OPTIMIZATION.json及scripts/check_d3_lossless.py已PASS旧参考真实性/原字体/8082地址边界/9项新源检查。
- **RAW仍待收尾**：新d3_lossless_native_r6_20261030，session26321，精确R27/R28源，17:42 source3/12；新d3_lossless_empty_native_r6已完成PASS（session43747尚可poll结束），两RAW暗/亮且两种proof时序。旧r4参数PASS token拼错提前终止；旧r5因候选更换到三行缓存且源不一致终止，ABORT_REASON都保留，均不选作PASS。
- auditor/publisher更新具体资源期望104ERAM/31DSP（实际新SYN，未放松容量），publisher要求29项lossless-v2+原49bounds/20Gray/9邮箱/双alarm→注册V2严格物理审计。run_d3_prepared.py已修默认策略无需PHYSICAL_STRATEGY的seed读取；活动旧进程为兼容已记录真实Default/seed2元数据。发布前更新实际final资源和docs、commit全部冻结源、704HEAD blob核验，再publisher check-only→release/ZIP→BIT_FLASH副本SHA。目标R27B_DualCount_DualStop_D3_20261030.bit，旧RL7/D2/只读R2均不覆盖。
- 新build放D盘避开E盘低空间（17:35 E约1.1GB、D2.9GB）；不要删旧证据/用户文件，不要重跑未变源测试。不要启动第二个TD全构建。git diff校验必须-c core.whitespace=cr-at-eol，避免CRLF巨量噪声；不要stage-all，旧实验station/bank和sim产物保持未跟踪。9个新增等价夹具、4个原始参考和生成/检查脚本按明确清单stage。

# D3 无损资源优化实验（2026-10-30 17:22，以下为历史）

- 用户要求继续优化 Slice，优先调试/显示/重复计算，**绝对不能影响功能**。两列识别、独立计数/编号、各32停车队列、完整1s、每列五空报警、四键/SW3、V2/板载5V均保留；不能关闭诊断、缩短缓存/队列或松约束换资源。没有子代理、硬件或推送操作。
- R14/R15路由均已中止，分别 ABORT_REASON.json，未完成验收、无新bit。R14初步20911/21216 Slice，107/108ERAM；R15 CongestionHigh初步21117且时序更差，已拒绝。旧R11生产RTL仍在Git，未被实验覆盖。
- 新隔离候选：E:/2026FPGA/.codex_tmp/d3_resize_share_source_r22_20261030/project，仅3份源相对R11改变：frame_shape_search无损候选rank存储、compact_inspector_osd共享标签格式+合并字体零填充、rgb_resize_2_3合并完整精度加权加法。唯一活动TD为 d3_font_resize_synthesis_r23_20261030，session21054，synthesis-only/默认策略，尚无最终资源；不要另开TD完整任务。R17/R19综合已结束。
- R17 rank存储：Slice*22821→22637，LUT29345→29107，reg23557→23263，107ERAM不变；R19再共享标签：Slice*22543，LUT28953，107ERAM。这些都是综合估算，不冒充实际Slice或最终时序。原R11/R27B主计数核原件不改，18bit排序计数不截断。
- 已PASS：rank_r9六RGB/64目标；rank_stress_pixels_r1九幅完整RGB、拥挤>4候选/等距/远端锁定/丢锁定/大面积18bit计数与FG饱和，1216候选+304显示+128trace+occupied对照原R11四区；osd_share_pixels_r1和shared_font_pixels_r2各11幅完整1280x720图像逐像素对照原R11（双页/重叠/上下边界/无效/跨RUN/帧内突变）；字体全73728类型地址列与原ASCII/CJK逐项同拍一致；resize_share_pixels_r1全部131072输入权重+36连续/间隙/取消/错行尾流逐拍一致。
- 新参考/夹具及生成脚本在 scripts/probe_d3_*.py、scripts/make_d3_*equivalence.py、tests/dual_stop_d3/r11_reference_*.sv、tb_d3_*equivalence/overlap/shared_font/rank_pixels.sv，原始SHA在docs/D3_RANK_REFERENCE.json与D3_RESIZE_REFERENCE.json。仅输出未接引脚的ModelSim warning，旧参考只改模块名/换行。shared_font_pixels_r1是声明顺序编译失败，已留原件；r2通过，未改期望。
- 后续先收R23实际综合收益。若采用需把3份源合入主树、刷新bounds SHA、源一致验证目录profile；重跑所有编译到改变源的检查（包括native RAW及实际新SYN相机锥），不能把旧24项当新源PASS。完整物理布局布线/原49bounds/20Gray/9邮箱/双报警到V2注册输出审计仍必须过，不能提前交付bit。新bit仍须额外复制BIT_FLASH并核SHA，旧RL7/D2/只读R2保持。

# D3 R14 布线中（2026-10-30 16:02，以下为历史）

- 活动唯一TD完整构建仍R14 E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r14_area_high_20261030，session71970，SYN已完成1154.2秒（官方AreaOptimizeHigh）。当前完整route早期Stage2.5.1.4 Rip-up And ReRoute，原时钟/SDC不改。**初步映射20911Slice=776+20135，98.56%，107ERAM31DSP5PLL。Placed SWNS+.115/TNS0，HWNS-.304/TNS-69.997只是布局。路由早期setup已收敛到-0.010/TNS-.010/仅1endpoint，仍未最终验收。不能提前交付bit。**
- R14实际SYN：28865LUT、22985Slice*估算（比默认R11 LUT29345少480，但估算Slice22821→22985变大；实际映射却21065→20911少154，必须区分口径）。default完整r13已中止拥塞，不再运行。当前主RTL仍704份与R11原始字节一致，生产6d43dcf0；最新Git249359cf只增加官方策略/相机导出工具，不改生产。未推送、无硬件动作、无子代理。
- **R14门级相机已重新PASS**：scripts/export_d3_camera.py --work R14 --check-directory E:/2026FPGA/.codex_tmp/d3_area_camera_r2_20261030，session23177完成exit0。闭合锥292cells（不是R11的303），只有clock/reset/SDA三个外部输入，两复位x126完整I2C EXP1092/GAIN40/WB100100。R14/CAMERA_EXPORT.json绑定实际新SYN gate.db+netlist+日志SHA。verifier中的相机cell数已改为从回执读取，模式ACTUAL_CANDIDATE_SYNTHESIS_CAMERA_CONE，不伪称相同SYN。这处scope改动尚未提交。
- scripts/verify_d3_checks.py --work R14 已PASS全部24项（23项同704RTL精确SHA复用 + 新实际R14门级相机）；R14/SOFTWARE_VERIFICATION.json已生成。不要再重跑21分钟RAW，除非生产RTL变化。所有ModelSim已结束。
- docs/D3_RESOURCE_ANALYSIS.json已刷新含RL7两个counter层级+R11默认+R14AreaHigh策略SHA/参数/SYN数据，待final.area出来再次刷新；docsD3_RESOURCE_ANALYSIS.md还需补最新High实测数据、最终审计。rootAGENTS及该JSON/verify相机scope目前有未提交修改。先保留活动冻结源不变。
- 剩余：等R14完整bit/Route结束；strict scripts/audit_dual_stop_d3.py --work R14 --dual-stop-d3 --keys-v3 --adjacent-v6 --five-empty-v7，原49bounds/20Gray/9邮箱/四键SW3/V2双alarm实际FF连通，资源107/31/5具体期望未改。如果真实setup/hold失败，不能发布；针对实际路径修。若通过，更新文档/策略rebuild说明、Git提交工具+说明（704源HEAD blob仍需核），publisher --check-only→publish→BIT_FLASH副本与构建/发布SHA一致→最终Git载荷审计。目标R27B_DualCount_DualStop_D3_20261030.bit与release r27b_dual_count_dual_stop_d3_20261030。旧RL7/D2/固定只读R2绝不覆盖。
- 若需要源码原始协议/各回归目录，读scripts/verify_d3_checks.py及下文历史。源核心参数仍两列计数、两列停车、各32队列、完整1s、各列五空报警、K1新RUN/K2暂停继续/K3清停/K4停/SW3兼容、右J2 pin1/V2/板载5V/无LED。用户最新是“继续”，不得停止只给计划或为确认重复提问。

# D3 面积优先映射当前接续（2026-10-30 15:37，以下为历史）

- 用户最新“继续”，任务仍两列识别/计数/停车，并解释/优化资源。已commit 6d43dcf0（分支codex/r27b-dual-count-and-stop-d3），704源Git HEAD blob与冻结raw SHA全部匹配，未推送。主RTL全部仍精确R11，不开子代理、不做任何硬件操作。
- **最新唯一完整TD工作R14**：E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r14_area_high_20261030，session71970，704相同源/107依赖，seed2，原SDC/时钟不改；使用TD本机官方 E:/TD/doc/strategies/official_strategy_ph1.json 的 AreaOptimizeHigh（official SHA b264a5c4ae939a4be0fcf5d2c242a8005132c4812f01d4d060590adee2030729）。参数gate add_map_lut_struct high/map_mode area_prior/multi_thread_mapping partition；RTL resource_sharing auto/shifter_style shifter_reg。build/BUILD_STRATEGY.json保留参数与官方SHA；scripts/build_r22_relay.py新增--synthesis-strategy选项，旧默认Default不变。目前Map Gate显示“extra runtime-consuming opt”，尚无SYN gate.area/DB，继续等待，不可写资源收益结论。
- R13初期21065Slice可装，但实际路由持续拥塞（12/13轮仍约1.3万overflow，初期SWNS-1.161），未完成路由；已核TD PID18264父8184为r13且无子进程后停止，ABORT_REASON.json留证。不是最终routed失败/PASS；不再靠不断换seed，改比较官方面积优先映射。原R11placed SWNS+.061/HWNS-.264，place.db保留，可做后备独立opt_route续跑，但须标明实际place数据库复用而非新SYN，当前未启动此路线。
- **软件24项最终组已全部PASS并精确核源**：scripts/verify_d3_checks.py --work r13 已输出 SOFTWARE_VERIFICATION.json。native_r3已完成12真实RAW/24整幅显示/22940160精确像素/双列各4P2E2/WB取消，所有ModelSim均已结束。24组目录在脚本常量，core/Pixels/cache/metadata/key/selector/UI以及两个RAW，另外303cell实际R11 gate相机两复位x126I2C。R14同704源可以复用23项RTL结果，**实际SYN DB改变，必须重新导出/验证R14相机锥**，不可复用旧门级相机证据。
- scripts/export_d3_camera.py新建（未提交）：--work R14 --check-directory E:/2026FPGA/.codex_tmp/d3_area_camera_r2_20261030；SYN DB完成后才能调用。单行source正确完整TCL，记录CAMERA_EXPORT.json的实际DB/网表/日志SHA，执行check_camera_gain_fix.py。若AreaHigh改了FF别名/primitive，严格闭合锥及实际串行总线检查不能削弱。verify_d3_checks.py已支持当前work/CAMERA_EXPORT.json绑定新门级；没有它才允许原R11精确SYN复用，旧R13调用验证仍24PASS。
- scripts/publish_dual_stop_d3.py已支持BUILD_STRATEGY/CAMERA_EXPORT及正确seed/strategy重建命令，仍24项+严格物理+704HEAD才发布。期望DSP目前31/ERAM107（audit_dual_stop_d3.py），R14实际SYN若官方映射改变计数须核模块/映射事实后更新具体期望，不能仅为通过而放松上限或关闭功能。还没有新bit/发布包。
- **资源解释新增关键证据**：旧RL7不是只有一个核，gate.area有右 classified_counting$pipeline/counter 和左 left_station$station/counter 两个完整计数/关联核；R27B双计数也是两核。初始直接合并变四核超限，当前R11/R14保留两主核+一个共享专用位置tracker。docs/D3_RESOURCE_ANALYSIS.md已加表，用户已看到此解释。RL4实85.58/RL7实89.42/R27B实89.14。初始D3综合25976→R11 22821/4DSP减少（12.15%），R14新值未出。
- Git sparse checkout：新增tests/dual_stop_d3需要git add --sparse；.gitattributes已在6d43添加D3/tests/docs/scripts/releases -text原始字节。不要跑裸git diff --check，会把CRLF上百万行当trailing whitespace产生巨量输出；应git -c core.whitespace=cr-at-eol diff --check并捕获输出，已0通过。不能为换行改冻结生产/fixtures。当前未提交修改7个脚本/文档和.gitattributes增加export_d3_camera -text；新export脚本未跟踪。旧实验4station RTL、bank extraction、旧sim产物仍未跟踪，不stage-all/不删除用户旧产物。
- 还需：R14 SYN/PHY实际资源与setup/hold；原49bounds/20Gray/9邮箱/四键SW3/V2两个alarm到实际motor FF审计；R14相机门级；更新资源报告/分析/fieldguide，提交新工具及证明，publisher --check-only→封包→BIT_FLASH同SHA→必要Git载荷审计。固定以太网/旧RL7/D2 SHA保留。不要提前称资源/时序整体PASS或实板成功。

# D3 当前物理验收接续（2026-10-30 15:10，以下为历史）

- 最新用户“继续”，保持原完整交付目标，不停在分析。主源码已恢复精确R11：FSS SHAf19d1305bea604ee4eeaef1d4ac073c03856f17df9451a32fe69855d454b5739，灰度两拍写地址/数据/valid及distance9保留。
- 区域内固定搬移R12：六RGB/64目标、32768次literal三task时序对照均PASS，但实际映射21717>21216，已REJECTED_RESOURCE.json保留，绝不发布。currentFSS已按SHA恢复R11。R12 native_r4 kernel32924身份/输出目录核验后终止，ABORT_REASON.json，不选为PASS；原r11 native_r3 kernel29320仍运行，已到source11，各列4/P2/E2，最后12WB取消待收尾。
- 当前唯一完整TD任务：r13 E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r13_resource_seed3_20261030，session39145，来自R11完全相同704源+实际gate.db，EXACT_SYNTHESIS_REUSE.json证明，physical seed3。初步映射21065（776+20289）/99.29%，107ERAM31DSP；在Detailed Placement，完整布线/时序未验收。R11 placed SWNS+.061/HWNS-.264，只是Placed，不能说最终hold失败/PASS。R11此前被终止且ABORT_REASON保留；r13若失败可针对具体路径，或复制R11实际place.db到独立新构建opt_route续跑（不能声称重新SYN），不修改冻结目录。
- R11最终选定24项软件证明已准备scripts/verify_d3_checks.py，严格核每个实际编译源/夹具/日志SHA、actualtop motor及metadata literal映射、observer恢复原件、distance穷举267648中心点。仍等待native_r3 verification.json所以尚未生成最终SOFTWARE_VERIFICATION.json；其他组已过源一致核验。最新UI d3_final_ui_r4绑定r13 SHA PASS。原d3_distance_selection_r1是R11源、65,536实际selector检查PASS；cache_address_r1全部20440字/20bank及取消恢复PASS；pixels_r7六完整RGB/64对象主区与R27B相同。
- empty_native_r3 R11源已PASS：第二例FEdelay4000实测detector先于proof23120ns，accept在proof后10ns；第一例proof先于detector12430ns。真实完整RAW/原vendorRAM/两个LOCKING零事件/下一FS保护。
- camera_r1已从R11实际gate.db导出303cell相机锥并PASS两复位x126串行I2C。导出首次把TCL正文pipe给交互TD出现missingbrace，已改为单行source完整TCL重跑并有export_camera.log，实际新网表SHA与回执绑定。r13复用同SHA gate.db可透明复用相机证据，不冒称新导出。非实物读回。
- docs/D3_RESOURCE_ANALYSIS.md/.json及scripts/report_d3_resources.py提供同阶段对照；实际RL4 85.58%、RL7 89.42%、R27B89.14%，不能把R27B综合96.74和最终89.14混比。初始D3综合25976→22821，省3155估算Slice/4DSP；r12失败已明确。新docs D3_DISTANCE_BOUNDS.json已恢复绑定最终FSS。
- scripts/publish_dual_stop_d3.py已准备，需最终物理严格审计、24软件PASS、704 Git HEAD blob一致才可--check-only再发布。目标R27B_DualCount_DualStop_D3_20261030.bit，release r27b_dual_count_dual_stop_d3_20261030，固定BIT_FLASH副本+SHA，保护旧RL7/D2/以太网R2。尚未提交本轮Git、尚未产生可交付bit。audit_dual_stop_d3.py期望ERAM107/DSP31，原49bounds/20Gray/9邮箱/双alarm→注册V2，约束未松。

# D3 资源优化接续（2026-10-30 14:49，以下为历史）

- 用户最新追问86%双列计数/85%单列为何合并超限，要求认真资源优化；仍保持两列识别/计数/停车交付目标。不能切功能、降队列、松SDC，只优化重复计算和存储表示。
- 已从实际final.area核实：RL4 18156/85.58%，RL7 18972/89.42%（下文某处18672是RL6），R27B 18913/89.14%。R27B SYN Slice*=20524/96.74%，不能拿综合估算与最终Slice混比。R27B101ERAM，初始D3重复左计数SYN25976/122.44%，直接全局tracker r9为22886/107.87%、107ERAM32DSP。scripts/report_d3_resources.py输出逐报告SHA和层级占用，docs/D3_RESOURCE_ANALYSIS.json尚待当前candidate完整报告刷新。
- r9实际映射21496超限；r10同源seed2初步映射20943可装下，但placed SWNS-1.049ns，主要cap_row→surface/write_address经过重复station行乘法和bankdecode。已核TD PID19940父23008为r10且无子进程后终止未完成r10，ABORT_REASON.json保留，不能称最终routed失败/PASS。没有bit交付。
- 当前r11全新SYN+PHY（seed2）冻结704源/107依赖，E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r11_resource_opt_20261030，session22077。仅另改frame_shape_search/local_edge_surface_check：固定1280x720四区存储distance12→9（瞬时distance仍12，非本配置仍12）；四区267648坐标穷举最大324，docs/D3_DISTANCE_BOUNDS.json。缓存写入先选row再乘一次42、address/data/enable成对两拍、cancel同时清有效，captured跟实际commit，原DUAL_STOP0不变。r11冻结后生产源未再改。
- 当前新增检查：d3_resource_opt_pixels_r7六完整RGB/64目标、主608+trace与R27B逐位PASS；d3_resource_cache_address_r1穷举20440字/20bank的地址数据、所有边界/间隙/空闲、双阶段取消恢复PASS。tests/dual_stop_d3/tb_d3_cache_address.sv。
- r9冻结完整RAW final_native_r2已PASS：12真实1920x1080 RAW/24全显示/22940160精确像素、双P,E,E,P/变速/WB取消/实际顶层DDR映射，permit0故不冒称RAW停车周期。新r11要跑同源绑定，不能拿r9不同缓存/FSS源当最终。
- final_empty_r2虽PASS但两例都proof先于detector，没有early-result顺序覆盖；tb_d3_empty_native第二例FEdelay已1200→4000，新r11 empty_native_r3 session26497运行中，需确认实测第二例detector先于proof。13direct_cases_r3/keys_real_second_r2/metadata_final_r2/tracker_guards_r1的编译核心源未受本次两文件改动影响，可逐SHA核后复用；OSD检查编译了FSS/cache即使未实例化，也要新选绑定回执。
- 无子代理、无硬件动作、无推送。r11还需真实资源/严格原约束setup+hold审计、相机实际SYN锥串行I2C、最终SHA封包并复制BIT_FLASH；保护旧RL7/D2/只读R2。

# D3 执行中最新状态（2026-10-30，以下为过程历史）

- 最新14:15：r8布局后的真实最差路径是surface/edge_no→read_address，15逻辑级，SWNS-2.516ns；已核TD PID29204的父进程为本r8构建且无子进程后只终止该TD，r8/ABORT_REASON.json留证，未完成路由且无bit交付。不能当“完整routed失败”或PASS。
- 新r9 E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r9_20261030，session44480，704源/107依赖，seed4，全新SYN+PHY正在执行。包含tracker sourceFS检查pending/waiting，以及DUAL_STOP灰度地址两拍：phase2/5寄存row/column/zone，3/6算地址，8/9等RAM，10/11等sampled_q，再4/7取样；每个取样增加一拍，旧DUAL_STOP0完全不变。新d3_address_pipeline_pixels_r6六完整RGB/64目标主区逐位R27B对照PASS。r9目前与当前全部704生产源相同（后续以SHA核验为准）。
- keys_real_second_r2已经两项PASS：27按键检查、真实100MHz/100000000周期完整1秒。13项final_cases_r3、三UI、1024metadata已PASS。scripts/check_d3_observed_counter.py及docs/D3_OBSERVED_COUNTER_PROOF.json证明观察副本仅新增7只读输出/7assign，恢复后与R27B原文完全一致；另有每拍1197公开位对照。
- 原native_r1 session75400仍跑旧r8缓存，在第5源后已有真实双列事件；源在运行后更改了local_edge_surface_check，因此结束时原runner会报源hash变化，不选最终新缓存回归。只能作为被替代候选诊断，不能改runner绕过校验。最终native须指向r9冻结project而非活动源码，再新跑真实RAW/顶层/DDR/显示；可按新时序改动用足够帧数验证，不能用旧R27B PASS冒充。


- 用户已回复“执行”，持续做到两列识别/计数/停车和可审阅交付；不再询问同意，不烧录/操纵硬件，不开子代理。工作树/分支仍D:/CodexWork/FPGA_R22_Relay_20261027的codex/r27b-dual-count-and-stop-d3，尚未提交本轮文件。
- 资源路线已经改变：两套完整左站分别计数实际24361 Slice超限；共享两核仅综合25744（r4）/加R27B不可达分支保护25358（r5），收益不足，均拒绝交付。保留它们的冻结目录证据，生产.al已去掉parking_station_counter/pipeline/shared_counter/service四文件，不能继续把它们当当前实现。
- 当前生产：R27B classified_pocket_counter.v原文件SHA67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c未改；observed_classified_pocket_counter.v是其只增加只读snapshot/motion/radius/真实event坐标输出的副本，原状态转移完全相同。classified_count_pipeline新增OBSERVE_PARKING选择，双列默认观察副本、单核旧默认原件。global_empty_position_tracker仅关联已全局编号的EMPTY，每列32任务状态，共用一个小FSM；预测只用于关联/提示，position_new只给同ID/当前帧唯一实测EMPTY。主计数仍接原R27B四候选，算法/输入不扩区不改。pocket_relay_stop_v2新增DIRECT_GLOBAL_TRACK=1使用全局ID，不再本地重计数/签名比对；原150ms/有界重定位/完整1000ms/五空/新RUN/各列队列、共电机&互锁、四键SW3、V2无LED保留。
- FPGA资源证据：r6直接全局跟踪综合23096，实际物理映射21253/21216超37，未交付。r7固定候选mux/共享bank选择综合22947。r8复用现有UI数字转换器取消停车文字除法，综合22951，实际映射21015（776+20239）已装下，正在完整PHY；最终资源/时序以最终报告为准。
- 当前真实构建E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r8_20261030，704源/107硬件依赖，seed4，session35398（TD PID29204，13:58:35启动；最新处于opt_place/post-place normal nets routing，时序仍负，不能发布）。r8冻结后加了source_start时检查tracker pending/waiting_result的保护（原只检查phase）；所以r8即使通过也不等于当前最终源，须新r9冻结并全构建。其他生产文件目前没有后改。
- 当前最终源码的13项direct_final_cases_r3全部PASS：case0交错、1同时、2/3每列五连独立锁停+单清、4变速4+P+4、5暂停、6漏1帧、7漏7帧返回、8永久丢失、9错类别、10不清零连跑两轮530帧、11两列各四空不合并报警、alarm_control21项实际提取top motor逻辑（legacy控制器负例单位作用，不冒称双列端到端）。所有传送用真实main+站候选，无force位置/事件；每拍1197公开位与原R27B核对照，每个发布坐标与独立物理ID轨迹对照。负例8/9保留ID锁F6且无旧坐标完成。结果E:/2026FPGA/.codex_tmp/d3_direct_final_cases_r3_20261030/verification.json。
- 已有六完整RGB/64真实对象主区逐位与R27B对照PASS（d3_pixels_banked_cache_r5）；三完整UI栅格/双列计数ID列表/双黄窗/两列十进制状态/原子快照/三拍PASS（d3_osd_formatter_r1）。d3_metadata_proto_r1的1024实际top映射随机PASS，需核提取块仍literal并重跑最终夹具。旧shared/rawcore51628通过只属于被拒绝资源原型，不选最终功能证据。
- 正在跑native：session75400，vsimk PID2040（14:01:27启动），d3_native_r1_20261030。12源实际RAW10、100MHz处理/27FPS native cadence、真demosaic/WB/vendorERAM、AUTO_RELAY1且permit0、实际提取top元数据映射接DDR、逐像素完整显示。仅仿真计数/显示，不冒称RAW停车周期/光学召回。当前仅前两源已完成，未PASS；不可停止/复用原R27B旧PASS冒充本轮。scripts/relay_left_native_check.py新增--extra-rtl。
- keys_real_second_r2 session67063：tb_d3_keys已PASS27项单键/CDC/六SW3；tb_d3_real_second正在100MHz整100000000周期计时。之前keys_hold_r1第二个旧.*夹具缺新端口编译失败，已用V7对应夹具+external_hold0+DIRECT_GLOBAL_TRACK1修正，不是生产故障也不选旧失败为PASS。
- scripts/audit_dual_stop_d3.py已准备，以旧严格物理审计为基础，仍49bound/20Gray/9mailboxes/四键/V2/无LED，检查两个alarm FF到实际motor输出FF；未执行，需最终r9真正routed后运行，可能需适配层级名字但不能放松约束。还需只读导出实际SYN网表并做camera_cone两复位x126串行I2C；旧导出TCL参考d2_single_stop_second_lane_build_r4_20261029/export_camera.tcl。需要生成observer可复原字节证明、最终source/fixture冻结、Git blob审计、publisher、严格资源/时序通过后交付bit并核BIT_FLASH副本SHA。所有旧bit/只读R2不改。

# R27B 双列计数与停车合并（2026-10-30，最高优先级）

- 用户已明确确认：队友 R27B 双列计数实板成功，必须作为成功计数基线保留，不能归咎于 R27B。新任务是两列识别/独立计数/停车；一个电机协调两列，K1/K2/K3/K4、V2板载5V/无LED/完整1秒/各列五空报警保留。分支codex/r27b-dual-count-and-stop-d3，从0df23c84建；无子代理，无硬件动作。
- 交接ZIP SHA2a4dc51449708d797bcea40dc4b4c102e05042a2ce1836cde04d7d9b1cf3070c，解包E:/2026FPGA/.codex_tmp/r27b_dual_merge_handoff_20261030/R27B_DualColumn_Code_and_Handoff；2341载荷/680冻结源逐SHA通过。原附带AGENTS只是交接资料，不覆盖本工程规则。4个新回放在r27b_merge_analysis_replay_20261030：two_region_count、restart_epoch(123072)、empty_result_proof(202)、sparse_equivalence(14图)全部PASS。用户要求多分析R27B已有修复，必须携带R25稀疏扫描/队列预读、R26新epoch、R27 early-result/proof汇合、R27B平衡选择器，不能只移植双计数wrapper。
- 已确认并独立负例复现D2顶层错误：frame_view取[1038:783]而原计数在[886:631]，下列[1038:887]被当ID改写，且[782:631]152位未驱动；实测夹具下列y0=480变0，标签跑y80。证据r27b_merge_analysis_replay_20261030/metadata_negative/vsim.log，不能称修复PASS。此前ISP/DDR回归未覆盖实际顶层格式变换。R27B按ORIGINAL_META_WIDTH+bank*256显式映射可避免。新交付必须补顶层连通回归。
- 最新用户要求多分析R27B怎么解决消失/超时。本机追加11项原R27B恢复/排序/持续丢失/容量测试，合计15项PASS；docs/R27B_ANALYSIS_REPLAY_VERIFICATION.json逐项核实际编译源SHA/仿真完成。R27B LOCAL_RECOVERY可设置uncertainty_from后继续其他真实计数；不能用这种不确定编号直接停车。C6帧结果与F6队首位置新鲜度是两层条件，现有F6是150ms后有界重定位。主计数器仍与交接字节一致SHA67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c。
- 当前生产RTL已导入并开发D3原型，未出新bit。D2视频是RUN0，不可宣称已计数C6；密集超时仍需复现。详见docs/R27B_DUAL_STOP_MERGE_ANALYSIS.md。元数据1024随机、主区六RGB对照、265帧12对象/五次完整1秒传送已局部PASS，不能当整体交付。第三次综合probe_r3估算25976/21216 Slice*=122.44%、107ERAM/35DSP，未布局布线，拒绝交付；前两次3视频FIFO被临时RAM补齐挤入DRAM，第三次显式20x1024缓存银行已解决该溢出但计算逻辑仍过量。不可削功能/放松SDC。
- 只共享两个左站的资源优化原型：shared_parking_station_counter.v由scripts/generate_shared_station_counter.py生成，94份上下文存储银行化、397公开位51628选中时钟等价PASS；主R27B计数两核不共享不改。服务调度尚未实现/接入，也未加入.al。parking_station_pipeline新增EXTERNAL_COUNTER默认0与397bit响应适配，最近编辑未重跑。工作树含未完成原型，不可打包或称整体通过；下一步需冻结/集成/新帧预算/资源/严格时序。无后台构建或硬件动作。送料默认仍屏幕右→左（旧用户确认），R27B视频右向运动是计数成功证据，不等于停车方向改了。

# D2 保留单列停车并加第二条识别（2026-10-29，当前入口，用户纠正D1范围）

- 已交付D2：E:/2026FPGA/BIT_FLASH/R22_SingleStop_SecondRecognition_D2_20261029.bit，SHA1b2d3c1b0e279b53e8245fe8acd61db0ce6c69e37ae1ff3d9419fbab938803ae，与R4构建/发布原件一致。源码57793ece（生产44664cbe），分支codex/r22-single-stop-plus-second-recognition-d2，未推送。最终独立seed4，Slice19713/21216=92.92%、ERAM106/108、DSP30/40、PLL5/6，SWNS+.038/HWNS+.020/双TNS0。18项选定软件检查和原49bound/20Gray/9邮箱/四键SW3/V2/实际报警互锁审计PASS；R4相机303单元两复位×126完整串行I2C PASS。全部TD/ModelSim已结束，无硬件动作。
- 完整发布releases/r22_dual_stop_d2_20261029及相邻ZIP，ZIP SHAb7e8bf84267fb32149d012fb8a9d80417c9d3686eb635717bba9e1b6a2a30a59，1036载荷/636源/104硬件依赖；docs/R22_DUAL_STOP_D2_DELIVERY.json和GIT_AUDIT.json记录逐字节核验，1674 Git blobs含ZIP/源。旧RL7/D1/只读R2均保持。上方仍原384×160，下方480×168；用户只是问尺寸，不自动改几何。
- 下一步人验收RL7+D2实时相机、第一条单/三连完整1秒并继续、五空报警及K3解除、第二条多空但不混计数/队列/报警。K1新RUN/K2暂停继续/K3单清停止/K4停止，SW3上停下新RUN不变；右J2 pin1=V2高运行、板载5V、无LED。第二条只识别，队友只交双列计数，停车整合仍由本工程负责；106/108ERAM意味着后续接入须重新评估资源和共电机调度。无实板光学/任意高速/±1mm达标声明；不再启动额外构建。

- 最新续接：R4 seed4 完整构建通过，生产636源与R3逐SHA相同。Slice19713/21216=92.92%、ERAM106/DSP30/PLL5，SWNS+.038/HWNS+.020/双TNS0；原49bound/20Gray/9邮箱/四键SW3/V2无LED及实际报警互锁审计PASS。R3 seed3完整布线hold-.154/TNS-.203已拒绝，H1~H7 ECO试验未成功且未用于交付；最终bit只来自独立R4，无SDC放松。R4实际303单元相机SYN锥两复位×126笔串行I2C已PASS；18项软件检查均通过，五项R3旧回归用636源逐SHA和日志SHA复用，不冒称R4重跑。当前没有活动PHY任务或硬件动作。目标D2 bit尚待封包。

- 最高优先级r3（20:56起）：r2原17软件检查全过，但布线多轮setup约-.93/-.96/-.90ns，placed关键为candidate_region→high_worst最大值选择→distance比较→high_boxes ERAM使能13级。已核r2唯一父子PID并停止未完成构建，r2ABORT_REASON.json留存；不是routed失败验收。只在现有SCALE拍寄存high_free/high_worst/high_write_index，COMPARE用寄存值，SECOND_LANE=0仍走旧组合，不增加节拍。新d2_pixels_final_r4两项全PASS：原六RGB/48目标逐位等价，新增tb_d2_high_priority用18实际高阈值孔/12保留结果/满bank替换与拒绝/原RL7高阈值缓存逐位等价。新冻结d2_single_stop_second_lane_build_r3_20261029，seed3（前两次seed2），stage-timeout7200，636源/104依赖，全新构建/回归中；不改SYN/SDC约束来通过。publisher改选pixels_final_r4、ui_control_r4、rgb_final_r3、final_compat_r4、keys_compat_r1(编译6源未改)、native_r3、camera_r3、r3工程5旧回归，共18检查；是否完成以实际verification为准。活动构建session89975，RGB50841，RAW17503，UI+兼容67061；本记录之后新session以工具输出为准。r3新18项软件验证除camera_r3收尾均已PASS（RAW17503完成），当前准备提交r3源码；发布前必须核全部636Git blob。

- 最新r2：r1物理布线多轮SWNS停在-1.378ns，placed最差为灰度RAM-bank mux到legacy_ok的11级路径，助手已核唯一D2进程父子PID并停止该未完成构建；不是完整routed审计失败、更没有发布bit。r1冻结源/日志和ABORT_REASON.json保留。只对SECOND_LANE扩展模式加sampled_q一级寄存器及body/Sobel额外等待拍，原两区延迟不变，配对六RGB/48目标仍逐位等价PASS(d2_pixels_r3)。新冻结构建d2_single_stop_second_lane_build_r2_20261029运行中，其他检查正按新输入重跑；不得把r1资源/仿真回执当r2完整通过。用户问上下框为何一长一短，已解释原RL7右计数384×160、下方旧双ROI480×168、左黄窗另计；用户未要求统一尺寸，不改几何。

- 用户明确要求保留原第一条单列计数/编号/停车/1000ms/恢复/五空报警，再加一条识别；队友只研究双列计数，不负责停车。D1关闭整套计数停车属于范围误解，已向用户承认并纠正，不能再以D1纯识别作为当前交付。当前分支codex/r22-single-stop-plus-second-recognition-d2（从30d1a5a5开始），工作目录D:/CodexWork/FPGA_R22_Relay_20261027；无子代理，无实板动作。
- 当前SECOND_LANE=1,DUAL_RECOGNITION_ONLY=0；第一条右448..831×240..399计数、左64..447×240..399补件定位、黄72..232/中心152/触发184/完整1s及F15五空报警全保留；下方新增400..879×432..599独立识别。内部实际3区域，共享flood-fill/原完整mask，追加分段灰度缓存；原608bit只接第一条计数/定位，下方304bit独立，不能混入第一条队列/transport_occupied/报警。元数据1039bit，原887bit低位映射不动，新152bit位[1038:887]。原计数器/分类计数流水线/停车控制器/原ADC/原SDC/相机增益修复源保持。K1新RUN/K2暂停继续/K3单清停止/K4停止/SW3上停下新RUN，V2板载5V无LED。
- 生产冻结E:/2026FPGA/.codex_tmp/d2_single_stop_second_lane_build_r1_20261029，636源/104硬件依赖；当前完整PHY尚在运行，禁止改冻结源，尚不称最终资源/时序通过或新bit已交付。综合/早期物理报告仅参考，最终49bound/20Gray/9邮箱/四键SW3/V2报警互锁必须全部重新审计。scripts/audit_r22_relay.py新增--second-lane-d2，保留原全部检查；r2流水化后的综合资源为ERAM106/DSP30（r1曾为31DSP），按实际新映射核验，不放松时序。
- 已通过17项全新选定软件检查：d2_pixels_r2(六RGB/48实际P/E，与归档原RL7同输入的计数/定位608bits、occupied、trace一致)；ui_control_r2两项(完整两OSD/旧窗口状态报警+新增下框、21实际motor代码互锁)；rgb_r1(206RGB/原6IDs/3次完整10000000cycles=测试10MHz的1s/继续，第二条持续多空穴不混计数报警)；rgb_alarm_r1(75RGB/上方P+5E第五报警、下方独立识别)；first_compat_r2旧V7单穴/五空/OSD三项；keys_compat_r1旧键27检查+停车65断言两项；native_r1(七RAW/14显示/13088282精确像素，1039bit同槽/4views/WB取消，实例化计数停车但permit=0，不当RAW停车成功)；camera_r1(300单元实际相机锥2复位x126写入)；冻结工程regions/classified_counter/result_recorder_pipeline/empty_trace_abort/text_plane_prefetch五项。
- tests/dual_stop_d2；说明docs/R22_DUAL_STOP_D2_FIELD_GUIDE.md/INTERFACE.md明确三个区域和队友只交计数。d2_first_compat_r1遗漏include support、d2_pixels_r1把区外测试物放入左定位区属于夹具错误，独立日志保留，不算PASS；未因此更改生产判据。6份相对D1生产源修改（7份相对原RL7），frame/edge文件换行由LF变CRLF引起大diff，语义审阅使用--ignore-space-at-eol；冻结后不为换行重写。
- 目标独立名R22_SingleStop_SecondRecognition_D2_20261029.bit；发布脚本scripts/publish_dual_stop_d2.py需严格核17checks/原49约束/报警路径后才封包。是否交付/Git字节审计以docs/R22_DUAL_STOP_D2_DELIVERY.json/GIT_AUDIT.json实际回执为准，当前尚未封包。旧RL7 SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750、D1 SHAe9938418f0cc69790a583b401897657f4b44dff55e57cb361fcbeada1bad24cd、只读R2 SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f保持。所有新bit复制BIT_FLASH并核SHA。若PHY/时序失败，修具体资源/路径问题，不能再次关停车减功能来通过。

# D1 双区识别（2026-10-29，旧交付，已被用户纠正范围）

- 用户现在要求恢复原上下双ROI识别；双列计数等待队友代码，本轮不实现。当前分支codex/r22-dual-recognition-d1，起点a716eac，工作目录D:/CodexWork/FPGA_R22_Relay_20261027。无子代理，无烧录/接线/电机/继电器动作。
- 顶层DUAL_RECOGNITION_ONLY=1；上ROI[400,880)×[240,400)，下ROI[400,880)×[432,600)，1280×720处理像素；恢复原区域/缓存，R22现有检测开关及相机增益修复保留。每区内部4候选/显示2结果。当前不实例化计数/编号/停车/五连报警；旧RL7逻辑及bit保留，不能称本版自动补件仍启用。K1手动运行、K2暂停/运行、K3/K4停止；SW3上停、下沿运行；上电停，V2/板载5V/无LED，原ADC不改。
- 5份既有生产RTL修改+新增独立识别SDC，631份原源与RL7逐SHA不变。637冻结源/105硬件依赖构建E:/2026FPGA/.codex_tmp/dual_recognition_d1_build_r1_20261029已完成；Slice16299/21216=76.82%、ERAM100/108、DSP26/40、PLL5/6；SWNS+.107/HWNS+.020ns、双TNS0。识别SDC仅去掉未实例化count-live邮箱3约束，原SDC不改；严格46活动bound无忽略/20实际Gray/6手动邮箱组/四键SW3/V2无LED审计通过。
- 10项全新选定仿真通过：dual_d1_initial_r2两项（28按键断言+六RGB/32物理P/E）、osd_r3一项（两完整栅格/792字符）、native_r3一项（七RAW10源帧/14显示完整栅格/13088282逐像素/4views/WB取消）、camera_r1一项（实际302单元相机锥/2复位x126写入）、compat_r1旧键一项、osd_compat_r1旧OSD一项、冻结工程regions/text_plane_prefetch/empty_trace_abort三项。均有输入SHA回执，不当作实板/任意速度/光学召回验收。
- native早期首帧无效假设失败；同fixture对原RL7和D1均得到完整首帧，最终用例对全部7帧包括首帧执行相同完整字数/提交/像素验证。诊断失败不算PASS、不修改生产源绕过。测试tests/dual_recognition_d1；交接docs/R22_DUAL_RECOGNITION_D1_INTERFACE.md解释608bit候选及帧证明，端口不是计数事件，队友尚未接入。
- 目标独立发布R22_DualROI_Recognition_D1_20261029.bit，必须复制BIT_FLASH并核SHA。完整原件releases/r22_dual_recognition_d1_20261029及ZIP；实际是否交付/Git归档以docs/R22_DUAL_RECOGNITION_D1_DELIVERY.json和GIT_AUDIT.json为准。生产bit SHAe9938418f0cc69790a583b401897657f4b44dff55e57cb361fcbeada1bad24cd。已交付BIT_FLASH并与构建原件/发布原件核SHA一致；源码67538ef，未推送。990载荷ZIP SHAed8d10ea34da67442a51f2450b60b269218877d3dea202464747197c7b2c7997；归档提交766e1911已过HEAD逐字节审计：990载荷、清单、ZIP及637生产源共1629个Git blob核SHA通过；回执docs/R22_DUAL_RECOGNITION_D1_GIT_AUDIT.json。全部构建/仿真已结束，不另开构建。
- 旧RL7 SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750及只读R2 LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f不覆盖。下一步用户检查D1标识/实时画面、两条料带分别有件/空穴/一条空置以及K1/K2；双列计数与后续自动定位另行集成。

# RL7 已交付（2026-10-28，旧自动停车入口保留）

- 用户要求补件区稍左移、连续5个空穴报警停机。已交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit，SHA3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750，构建/发布原件/烧录副本一致。源码e037c9b（生产功能1d43470），分支codex/r22-left-shift-five-empty-v7，未推送。旧RL6/RL5/以太网R2保持。
- 窗口72..232、目标152、触发184（提前32），整体左移8px/宽160。FIVE_EMPTY_V7顶层1；按同RUN合法主计数序号累计EMPTY，PRESENT打断。第5个当拍锁存FF报警/送料关闭并禁止同拍弹队，保留待处理队列；顶部红字ALARM 5 EMPTY - MOTOR STOP - K3 CLEAR。K2/手动不能绕过；K3清零停止或明确K1/SW3新RUN才复位。保持单排、J2 pin1/V2高有效/板载5V、无LED和蜂鸣器新引脚。正常1~4空穴保持完整1秒，RL6一次500ms停机找回保留。
- E:/2026FPGA/.codex_tmp/r22_shift_alarm_v7_build_r1_20261028完成636源/104硬件依赖构建；5生产源修改、631源与RL6逐SHA相同。Slice18972/21216=89.42%、ERAM98/108、DSP30/40、PLL5/6；SWNS+.001ns/HWNS+.020ns/双TNS0，严格49最大延迟无忽略/20实际Gray/9邮箱/四键+SW3/V2无LED审计PASS。报警Q经实际alarm_stop网→电机注册LUT→V2输出同物理捕获单元已核；TD把该单元命名为station/counter/event_valid_reg_syn_3，不能只凭名字误认信号，证据physical_verification.json/alarm_interlock_packed_cell_proof。
- 全31项新选定检查PASS：final_units_r2的13、alarm_control_r2的1（21断言，实际顶层motor代码体逐字核对）、final_rgb_r3的2（206帧3保持+真实100MHz100000000周期1秒）、rgb_alarm_r1的1（75完整RGB帧P+5E、第5确认停机）、compat_r1的5、核心回归7、native_r1的1（12RAW/24精确显示，V7启用，未到停车线）、camera_gate_r1的1（实际305单元相机锥/2复位x126写入，非实物读回）。最终输入SHA逐项与冻结源/夹具一致；早期r1/r2夹具错误日志保留但不选PASS。
- 原件releases/r22_relay_shift_alarm_v7_20261028及相邻ZIP，1110载荷，ZIP SHA171f2e1004a973ba308d202fc0079b925c5840f37275fc69a41890802c22473c。docs/R22_SHIFT_ALARM_V7_DELIVERY.json回执；最终Git字节审计docs/R22_SHIFT_ALARM_V7_GIT_AUDIT.json以实际结果为准。BIT_FLASH同前缀_说明.md/_RELEASE.json包含操作/来源/资源。旧失败边界单独封存，不算新PASS。两段RL6现场视频及依据在docs/R22_V7_FIELD_ANALYSIS.md/.json，不能作为RL7实板验收。
- 所有TD/ModelSim工作已结束，无烧录/接线/电机动作，无子代理，不启动额外构建或自动跟进。下一步用户保持原接线，烧RL7确认T098/A020，先原普通/慢速三连，再4/5/6连和4空+有件+4空；4连继续、第5确认应报警，录上下两行后再K3清。新停点/五连报警/实物重复性待验收，无吸嘴握手/±1mm达标声明。主计数既有高速/弱RAW280漏检边界未修；不允许改编号/类别/上游gap保护假装通过。

# RL7 实施记录（以下为交付前过程，以本节以上结果为准）

- 用户新视频105ebf…为普通速度、930403…慢速，均RL6，最终S1F0Q00。普通速度2/3/4/11/16号保持X137/185/235/139/131，第三穴距右界240仅5px。用户要求补件区略左移、连续5空穴直接报警停机，已授权实施，无需再问确认。证据docs/R22_V7_FIELD_ANALYSIS.md/.json、docs/evidence/r22_rl6_shift_20261028（旧RL6实测，不能当RL7硬件通过）。
- 工作目录D:/CodexWork/FPGA_R22_Relay_20261027，分支codex/r22-left-shift-five-empty-v7，从1a82896起。生产只改5份：top/isp/relay_controller/dual_OSD/compact_OSD，主计数器/检测分类/ADC/SDC/相机源与RL6相同。FIVE_EMPTY_V7顶层默认1，叶模块默认0兼容。窗口72..232、目标152、提前32、触发184，整体左移8px/宽160，左ROI仍64..447留8px边。单排不恢复双ROI，原J2 pin1/V2高有效、板载5V、无LED。
- 五连报警按同RUN连续主计数编号的合法EMPTY事件累计；PRESENT打断，不按队列深度/图像帧数。第五个当拍锁存alarm_stop并fail15（上方S4 FF），保留队列含第五个、禁止同拍HOLD弹队。顶部红字ALARM 5 EMPTY - MOTOR STOP - K3 CLEAR。顶层实际motor_output再受!relay_alarm约束，K4后K2手动也不能绕过；K3清零停止或明确K1/SW3新RUN才重置报警和连续段。正常1~4穴仍逐个完整1秒，RL6一次500ms停机找回保留。
- 生产已冻结E:/2026FPGA/.codex_tmp/r22_shift_alarm_v7_build_r1_20261028（636源/104硬件依赖），SYN完成、PHY进行中，禁止修改冻结RTL。原生RAW V7/tol80/target152回放进行中，未到停车线，不混称RAW停车通过。相机实际305单元综合网表2复位x126串行写入已PASS。尚无新bit交付，旧RL6/RL5/只读R2保持。
- 最终拟选31项：final_units_r2的13项（31控制断言、移框/红字/两栅格、1~4连继续、5/8连在第5触发、回归/负例/变速）；alarm_control_r1的1项19断言（4+P+4/队列8不报，第5报，实际顶层motor寄存器代码体提取并逐字检查，K2/手动禁绕过、K3/新RUN、同拍HOLD冲突、错ID/RUN、暂停中第5）；RGB三连+实际100MHz1秒2项final_rgb_r3重跑中；RGB五连1项75完整帧已PASS；兼容5项+核心7项PASS；native1进行中；camera_gate1 PASS。r1真实秒夹具.*漏声明alarm_stop、r2夹具仍旧192触发，均为测试加载/激励错误；已改为输出声明及184/152，失败日志保留但不得当PASS。生产源未因此重构。
- scripts/publish_r22_shift_alarm_v7.py与audit_r22_relay.py --keys-v3 --adjacent-v6 --five-empty-v7准备中，严格49最大延迟/20Gray/9邮箱/四键+SW3/V2无LED外，新增alarm_latched到motor_output实际FF布线路径审计。5变动/631不变、全部636Git blob、31项冻结输入SHA、CRC/ZIP/发布payload及BIT_FLASH副本SHA必须核。拟名R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit；尚未发布。
- 继承弱RAW280/高速40pitch24step主计数失败/上游gap保护；高速失败是旧RL5/V6对照，不是本版新测或PASS，主计数/分类源未动。无吸嘴/实际补件/±1mm硬件验收。本轮仅文件/仿真/构建，没有烧录/接线/继电器/电机操作；无子代理，保留原未跟踪产物。

# RL6 交付记录（2026-10-28，以下为前版）

- 已生成独立交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V6_Adjacent_20261028.bit，SHA7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd，与实际构建/发布原件一致；源码ec53ab4（生产功能cc0d804），未推送。原件releases/r22_relay_adjacent_v6_20261028及相邻ZIP，ZIP SHAa79eeadf1bd20bdec9e09579af4e1ec0dc86a7c463efcbf591a9263102f60001，1086载荷/636源/104硬件依赖。docs/R22_ADJACENT_V6_DELIVERY.json为回执；BIT_FLASH同前缀_说明.md/_RELEASE.json含操作和资源来源。旧RL5/以太网R2保持。最终Git字节审计记录在docs/R22_ADJACENT_V6_GIT_AUDIT.json，是否通过以该回执为准。
- 当前分支codex/r22-adjacent-reacquire-v6，基线1972dea；工作目录D:/CodexWork/FPGA_R22_Relay_20261027。实施已获授权，不停在方案。新增8份生产源修改：停机交接下一队首、待处理EMPTY身份保留/停车提示限制、一次500ms电机关断重定位、同帧来源与候选/关联冻结诊断、RL6底部诊断和163bit显示邮箱。核心主计数、分类判据、相机增益修复、ADC/SDC原件保持。仍单排右数左补、窗口80..240/触发192/完整1000ms；无LED、V2高有效/板载5V。
- 生产冻结于E:/2026FPGA/.codex_tmp/r22_adjacent_v6_build_r1_20261028，636源/104硬件依赖；完整构建及严格审计完成，bit SHA7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd。Slice18672/21216=88.01%、ERAM98、DSP30、PLL5，SWNS+.001/HWNS+.020/双TNS0，49bound无忽略/20Gray/9邮箱/四键+SW3/V2无LED通过。不得改冻结源或已交付bit。目标独立名R22_RelayAuto_Left_V6_Adjacent_20261028.bit，不提前声称实板成功。
- 29项全新选定检查完成：12项final_units_r2（1/2/3/5/8连空穴、变速3/4/6/快10px帧、跨S2/S7连续7帧丢失后返回、持续缺失/错类别负例、23控制检查、2栅格106诊断字符），final_rgb2（RGB205帧3保持+163bit邮箱76次完整交付），final_second1（实际100MHz/100000000周期1秒），final_compat5，native1（V6/tol80、12RAW/24精确显示，未到停车线，不混称RAW停车通过），camera_gate1（实际307单元相机锥/2复位x126笔串行写入、非光学读回），7核心回归。全部输入SHA与冻结源一致；原r1修正前夹具不选最终证据。
- 额外高速压力40px穴距/突然24px帧出现主计数ID5类别顺序错误，第一次停车前，RL5与V6同输入同错误/同frame14/lead580；不是新停车逻辑引入，但不能声称任意高速。E:/2026FPGA/.codex_tmp/r22_v6_highspeed_boundary_20261028保存两版输入与失败日志，发布单独归档，绝不算通过；不放松编号/类别断言掩盖错误。
- scripts/publish_r22_adjacent_v6.py已核全部29项新选定检查/实际布线审计/636源码Git原始字节才发布，包含源码、报告、完整相机综合网表和旧拒绝负例/当前高速失败对照。docs/R22_ADJACENT_V6_FIELD_GUIDE.md包含S6/S7动作、底部RD解码、复测方法。原上游gap保护仍在，不允许用预测位置/错编号/错类别或跳过队首假装成功。
- 下一步用户保持原接线，烧RL6，先固定中低速空跑三连穴，拍完整上方RL6及底部RD；Q归零并继续送料才算连续成功。相邻穴在宽框内可连续停数秒但N逐个切换/Q递减；出现S7继续拍2秒，S4后拍3秒且不要先K3清诊断。无需用户自己解码。实物三连停车、不同速度重复性、光学画面及真实补件未验收，不声称±1mm。全部TD/ModelSim任务已结束，无额外构建/自动跟进。
- 只有本地文件/仿真/构建动作，没有烧录、接线、电机或继电器操作；无子代理。完成时须复制bit到E:/2026FPGA/BIT_FLASH并核SHA，写资源/来源，保持LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f。用户实测三连复现仍待进行。

# 最新三连空穴诊断（2026-10-28，以下为实施前分析记录）

- 新视频按上传序号：2a08…双连、a045…单穴、c6d4…三连，均RL5。单/双连最终S1F0Q00；三连2号约6.4sS3→7.4s队首3，3号7.5sS2/7.6sS3→8.6s队首4；4号8.8sS2X190、8.9s最后X145，9.1sS4F6/Q2/L6，余4和11号。用户说第二次不动，按编号实际前2/3均完成保持，卡在4号。用户已确认三连全程未操作/调速/碰料/遮挡/补件。
- 直接原因仍是150ms同ID位置未更新并锁定。145是最后测量且在80..240内；不能当故障时当前位置。队列容量32、本段只用4，右侧编号/入队已完成；不要把问题归为容量或继电器必须更换。
- 原始检测是否消失、四候选裁剪/±12预测保留失效、实际关联失败、上游gap阻止发布目前无法凭OSD唯一确定。先加同帧冻结诊断再针对性修。提议保留所有待处理身份、停车时限制旧速度预测漂移、增加下一队首交接（已在宽框内不盲目重启电机）、电机关闭时有界同ID重定位并重新完整保持；不得绕过上轮已失败的排序保护或用旧坐标完成。
- 本轮只有视频抽帧/源码读取/诊断文档；生产RTL未变，未启动构建、未生成新bit，旧RL5保留。证据E:/2026FPGA/.codex_tmp/r22_rl5_adjacent_field_20261028；持久选帧docs/evidence/r22_rl5_adjacent_20261028；完整分析docs/R22_RL5_ADJACENT_FIELD_ANALYSIS.md及JSON。下一步按用户后续指示实施诊断/相邻目标交接，当前不自动开始更大改造。

# 当前 RL5 跟踪/显示整理（2026-10-28，优先读取）

- 当前分支 codex/r22-brake-track-clean-ui，从 bcf29a4(RL4封存)开始。用户新视频8696…最后S4/F6，N004/Q02，最后有效X185在80..240内；PTS约5.333s S2→5.500s S4，未进入S3。用户确认未调速/碰料/补件；X185/V1不是故障时的新测量。
- 已复现并修复一个明确缺陷：STOP_POSITION左站不能按普通已计数轨迹规则提前回收当前query。四实际目标、同一漏检帧，旧RL4报F6；新源漏检1/2帧后同ID返回并完成三次完整1秒。持续缺失/不同类别仍F6，不增大150ms、不假造位置、不改控制器。
- 可见UI简化为右计数框+左黄80..240验收框+实际结果小框/分类；内部左ROI64..447/线256/目标160/触发192仍计算，只隐藏多余边线和特征十字。RELAY_CLEAN_UI=1生产默认，参数0保留旧显示，版本RL5。相机修复、按键、ADC/SDC、V2管脚无修改，仍单排，不恢复双排。
- 新用例tests/brake_track。r22_brake_faults_r2四例、clean_osd_r2、wide_r1四例、compat_r1五例和冻结工程七旧核心目前已PASS；原生RAW r22_brake_native_r1与完整TD r22_brake_clean_build_r1均已完成并PASS。门级相机启动r22_brake_camera_gate_r1已PASS 2复位x126笔。636源/104依赖已冻结，实际Slice18475/21216=87.08%、ERAM98/108、DSP30/40、PLL5/6；SWNS0.000/HWNS+.020ns、双TNS0。49最大延迟无忽略/20Gray/9邮箱/20bit命令/4键+SW3/V2无LED原审计PASS。bit SHA b88610ad095d5ee6b30444c542faa24bd65e21ed0c1f8ffc4a41484aa87c95ba，已封存并复制BIT_FLASH。不能称已过实板。
- 新现场证据/负对照/未解决压力失败在E:/2026FPGA/.codex_tmp/r22_rl4_f6_field_20261028，docs/R22_TRACKCLEAN_FIELD_ANALYSIS.json及FIELD_GUIDE.md记录。六目标候选压力场景还有上游未编号目标被裁剪产生gap_open从而抑制当前位置的边界；旧失败和修复后的该失败均保留，不算PASS，不宣称视频根因已完全复现或全部F6解决。旧弱RAW280边界不变。
- 已交付E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V5_TrackClean_20261028.bit，SHA b88610ad095d5ee6b30444c542faa24bd65e21ed0c1f8ffc4a41484aa87c95ba，与实际r1构建/发布原件相同；源码4fd5e86（功能07d95bd），未推送。scripts/publish_r22_trackclean.py已核23项全新选定检查+49最大延迟等原审计，完整release为releases/r22_relay_trackclean_v5_20261028及相邻ZIP，ZIP SHA4cef640f6dbd0745cc56e00924ad4dffcee29c06d529104f752c72559b75e194，1070载荷；全部1072个发布/ZIP索引路径及636源提交blob逐SHA核对通过，见docs/R22_TRACKCLEAN_GIT_AUDIT.json；不覆盖旧RL4/CamFix/V3/V2或只读R2。后续同速度同料带复测两穴，若仍F6采集左候选/排序，不能通过放松关联假装完成。
- 独立实验曾尝试跨上游gap发布实际队首位置并延长远端保留；虽六目标正例通过，删除上游目标的负例出现后续目标接错编号，因此已拒绝且未合入生产/bit，失败输入位于field_evidence/negative_and_boundary/rejected_station_gap_prototype。生产仍保留原gap保护。
- 本轮只有文件/仿真/构建操作，无烧录、继电器/电机或接线操作；无子代理。全部TD/ModelSim任务均已结束；不启动额外构建。

# R22 左补件继电器 V3 接续入口（2026-10-27，已交付）

## 当前宽窗口联调（2026-10-28，最新用户要求优先）

- 已交付RL4：E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V4_Wide_20261028.bit，SHA b5cc8c89b11da9895eb5406075ebcf76cd35f64c2f422a8cfe9e687e0add1e7b，与实际r1构建/发布原件相同；源码13724c3，分支codex/r22-wide-stop-window，未推送。
- r1构建/18项全新选定检查/真实布线审计均已结束并PASS：宽窗口65断言/7终点同RUN连续保持、真实双计数器变速582帧3保持+暂停继续+6SW3+单K3、宽框2完整栅格/颜色/94字符/3拍、生产100MHz整100000000周期1秒、5兼容检查、7旧核心回归、原生12 RAW/24精确显示、相机实际综合网表2复位x126笔串行写入。原生回放是默认tol8兼容性且未到停车线；宽tol80由专门控制/传送/显示测试验证，不混称原生RAW停车通过。
- 636冻结源/104硬件依赖，633源与CamFix相同；资源Slice18156/21216=85.58%、ERAM98/108、DSP30/40、PLL5/6；SWNS+.001ns/HWNS+.020ns/双TNS0。49最大延迟无忽略、20实际Gray、9邮箱、20bit命令、SW3/四键同步fanout、V2注册输出/无LED审计PASS。
- 完整原件releases/r22_relay_wide_v4_20261028及相邻ZIP；ZIP SHA2b99c5bdb238de6cffbbf2c0a29d3b10b3450c997c977c15ab484d54f78363df；987载荷、源码、实测截图/逐时状态图、所有新测试日志、布线报告、重构脚本已封存，BIT_FLASH同前缀_说明.md/_RELEASE.json。旧CamFix/V3/V2/以太网R2保持。
- 下一步用户以不同速度复测RL4，录像拍到至少两个空穴完整S1→S2→S3→S1，或出现F码后再拍3秒；先看宽框内停点能否连续处理，不以±1mm验收。若出现其他F码按现场原因处理，不能自动跳过错编号/丢目标装作成功。所有TD/ModelSim已结束；助手无实板/电机/烧录操作。

- 用户提供六段混合快慢速度视频，明确要求先尽量放宽补件范围，让多数情况停车1秒后继续下一穴；这项授权取代下文旧的“不放宽窗口”阶段限制。仍保持单排ROI，暂不恢复双ROI；宽窗口不宣称±1毫米精准补件已验收。
- 已逐帧抽取六段视频状态，末尾均S4/F8，按上传顺序停点X=131/137/145/169/139/121，均落在原152..168之外。第4段先在X157完成S3→S1，再在下一空穴X169报F8。不是因为一次完成后没有重新按键。
- 当前分支codex/r22-wide-stop-window，从0090662(含相机修复)开始。生产改动仅design_top_wrapper.v的默认RELAY_TOL_PX=80、传到显示的同名参数、classified_dual_page_osd.v和compact_inspector_osd.v；控制器/编号/分类/相机/引脚/SDC未改。
- 新验收窗口80..240（目标160±80），对比原±8宽10倍；保留触发192、提前32、稳定确认及完整1000ms保持，再弹出同一队首并继续。窗口边界距左检测边64/二次编号线256各16px，不能再扩大到检测边缘而丢失可靠定位。显示RL4及琥珀色虚线窗口；不是新增检测ROI。
- E:/2026FPGA/.codex_tmp/r22_wide_stop_field_20261028保存六视频SHA/元数据/每0.333秒状态图；范围覆盖已观测7个停点，不能称新版实板7/7已通过。先只处理已确认的F8窗口问题，保留错编号、图像中断、定位丢失等故障，不自动丢弃异常装作补件完成。
- 完整构建E:/2026FPGA/.codex_tmp/r22_wide_stop_build_r1_20261028已完成，冻结636源/104硬件依赖，TD/ModelSim软件操作；无烧录/电机/接线动作，无子代理。旧CamFix/V3/V2/以太网R2不覆盖。

## 当前黑图回归排查（2026-10-28，优先读取）

- 已交付独立修正版E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V3_CamFix_20261028.bit，SHA2c06e667cbf89039a63e9d788f5d1d07f72b195e23532ca1ae1d03336019677f；与实际r2构建/发布原件相同。源码提交701ea18，分支codex/r22-v3-camera-gain-fix，尚未推送。
- 完整r2构建已结束；严格49最大延迟/20实际Gray/9邮箱/20bit命令/SW3+四键同步fanout/V2输出/无LED审计全部PASS。Slice18171/21216=85.65%，ERAM98/108、DSP30/40、PLL5/6；SWNS+.002ns、HWNS+.020ns、TNS0。原V3/V2/只读R2保留。
- 发布原件releases/r22_relay_v3_camfix_20261028及相邻ZIP；ZIP SHA812de97fee80b7f65991cc391f859391cab2a73127c298d4bb63a3903b2be133。636源/104硬件依赖、986载荷、3项新相机检查+17项逐编译输入SHA复用检查均归档。只改一份生产源，其余635源不变；Slice打包数量不能独立证明功能删减，综合总单元旧49858→新49886（类型重映射/物理打包不同），不冒称整个综合网表除6单元外逐项相同。
- 下一步由用户先保持送料停止、不按K1确认实时画面更新，再测试运行键和停车；实板光学图像仍待确认。所有TD/ModelSim已结束，无硬件操作，不启动双ROI改造。

- 用户已同接线来回烧录确认：V2实时图像正常、V3仅OSD/ROI正常而相机底图黑；不能视为正常待机，CFG/FPS不是有效图像验收证据。
- 当前分支codex/r22-v3-camera-gain-fix，从119c276开始。仅生产源SC500GainTbl.v改为三个范围的同步译码，保持74有效表项/其余0/一拍延迟/原复位脚行为；tests/camera_gain_fix及scripts/check_camera_gain_fix.py新增真实串行总线检查。仍须实板确认图像。
- 第一次仅改case默认分支未解决综合网表错误，r1构建已停止并保留。完整构建E:/2026FPGA/.codex_tmp/r22_v3_camfix_build_r2_20261028已完成，冻结636源/104硬件依赖，635源逐SHA与V3一致。旧V3/V2/只读R2均不覆盖。
- 诊断E:/2026FPGA/.codex_tmp/v3_camera_black_20261028：旧V3实际综合网表相机锥回放曝光正确，但gain0338成为0000；已完成V2阳性对照(0338)及V3全部消费网驱动闭合检查，外部仅时钟/复位/SDA。修正r2实际综合网表305单元，两次复位的全部126笔串行写入均匹配正常V2，见r22_camfix_gate_r3_20261028；同一检查对旧V3在第125笔明确失败(0800而非0803)，见r22_camfix_old_v3_negative_r2_20261028。仅模拟ACK从机，不是传感器实物读回。
- 新RTL检查r22_camfix_rtl_20261028通过全部128地址x两种复位脚电平/相反地址顺序与原始表的等价性，以及两次复位x126完整I2C写入。独立小模块原case/default均正确0338，不能泛称所有ROM常量化都错。新检查初次gate运行因厂商Verilog模型在SV模式下缺timescale而加载失败；已分开编译并明确timescale，失败原件保留，未改期望结果。
- 既有RAW/17项测试未覆盖真实相机初始化串行总线，不能据其PASS判定此次黑图已解决；需补充启动I2C/实际综合网表验证和完整时序资源审计。本轮无烧录、电机或接线操作；保持单排布局/按键/引脚/停车参数。

## 最新用户决定（2026-10-28，优先于此前双ROI恢复建议）

- 用户明确：先由其把当前单排ROI跑稳定，再进行双ROI恢复；当前不启动双ROI改造或扩大检测布局。
- 当前阶段保持V3单排料道的右计数、左补件定位布局，集中验证识别/编号、按键暂停继续、精准停车、完整1秒保持和恢复；仍需实板数据，不提前宣称稳定或±1毫米已达标。
- 用户确认单排稳定后，再恢复原上下两块检测ROI并单独安排补件定位，重新评估缓存、资源和时序；不把当前布局误称为原双区功能全部保留。
- 本次仅记录阶段顺序，未修改RTL、按键、引脚、参数或任何已交付bit，也没有新仿真、构建、烧录或电机操作。下一步等待用户提供V3实测结果，再依据状态行、稳定X及速度分组分析。

## 约定

- 用户要求工程成功优先、先分析再修；人做实物操作/真值，助手做源码/仿真/构建/分析。本轮无实板/JTAG/Flash/电机动作，无子代理，不覆盖其他人的改动。
- 每个交付bit保留发布原件，额外复制E:/2026FPGA/BIT_FLASH并核SHA。只读R2 LATEST_READONLY.bit SHA30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f保持，不能因日期新而替换。旧R22/V1/V2都保留。
- 继电器板载5V、3.3V HIGH直触发，无NPN；右J2第1脚=V2，第11脚5V/第12脚GND。原ADC/SDC未改，集成版无LED。
- 原R22分类/编号/中文/Logo保持。用户最新明确把四键用于运行控制，所以自动版原曝光/增益/WB按键让位；默认曝光1092、增益40。无证据不把软件/像素/原生RAW/实板混作通过。

## 分支与交付

- 工作区D:/CodexWork/FPGA_R22_Relay_20261027，分支codex/r22-relay-controls-v3，源码提交a79ac7c，父V2 e51cb15，原R22a1cceaa。最后发布归档提交以git log为准；未推送。旧E盘R19/独立诊断不改。
- 正式bit E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V3_20261027.bit，SHA9ca7905cf147cfc6d8d770738b03416e2a43601b3b8a1315f46bbf43edfd267e，与release/实际r2构建相同。
- 完整原件releases/r22_relay_left_v3_20261027及相邻ZIP，ZIP SHAf154216670ae80643ed2f43467aac54fb875b89aa54e39b7106efdab4ff12329；636完整冻结源、928载荷逐SHA/ZIP CRC已核。BIT_FLASH同前缀_说明.md/_RELEASE.json/_BOUNDARY.json。docs/R22_RELAY_V3_DELIVERY.json/FINAL_AUDIT.json保存回执。全部928发布载荷、ZIP及636源码的Git索引字节已逐SHA核对，见docs/R22_RELAY_V3_GIT_AUDIT.json。
- TD r2 E:/2026FPGA/.codex_tmp/r22_relay_v3_build_r2_20261027，636源/104硬件依赖，TD6.2.168116 seed2；Slice18538/21216=87.38%，ERAM98/108、DSP30/40、PLL5/6；setup0.000/hold+.018/TNS0。49最大延迟/20实际Gray Q/9组邮箱/SW3+4键同步fanout/20bit命令/V2输出/无LED均实际审计PASS。ERAM比V2少1来自固定增益40的SC500GainTbl常量化，层级已对比，不是删识别缓存。

## 原因及当前行为

- 新现场视频1c37c718…共9s/270帧/30fps，SHA5d3609e76a87bc90b7889f9bf637b556d9d58ed222d26c531202d90e924b1bfd。3.2sS2F0X171、3.4s稳定X143、4.4sS4F8；目标160/窗口152..168，停偏17px，1200ms合格等待超时，未进S3。不同于V1F6丢位置。文档docs/R22_RELAY_V3_FIELD_ANALYSIS.json；视频状态序列图在release/field_evidence。
- K1单击新RUN/计数+自动送料，重新编号并重置旧队列；K3单击清零并停止；K4停止保留结果；SW3上停下新RUN，每轮无需K3+K4。原V2队列非空拒绝新RUN的FA限制仅在明确新RUN操作时解除，故障本身不丢旧队列。
- K2按用户选择暂停/继续当前自动流程，保留编号和队列；待机可手动电机启停。暂停仍采样/检查关联，冻结到站和停车等待，HOLD恢复后重新位置确认并完整1秒。按住键仅一次，释放才可重触发，上电按住不启动。
- 20bit{mode,17bitcommand}同一稳定邮箱避免RUN/许可不同步；注册V2输出；OSD版本RL3。右向左，主计数640/左站256/目标160/提前32/触发192/窗口±8px。首次K1须首穴在右约X800、左侧无未编号料，否则FC；继续原RUN用K2。
- 用户说速度可能调整。固定提前32仅根据此次视频的标定初值，不是速度自适应；组内固定速度，每个速度分组测5次。没有反向纠偏、吸嘴或补件完成握手；填料/遮挡会改变原E关联，先空跑停车/确认/保持/恢复。

## 最终验证及未决

- 17项选定实际PASS：final_unit5、final_closed4、final_native1、legacy7。路径均E:/2026FPGA/.codex_tmp/r22_relay_v3_final_*_20261027。27键检查、65控制检查、实际双计数器585帧/六SW3重开/保留队首暂停、处理RGB202帧3保持、V3和V2兼容两个100MHz100000000周期完整1秒。原生12RAW10帧/24精确显示栅格/4ID P2E2/到站前队列等待；RAW没到停车线，不能称RAW停车闭环。旧7回归实际从r2冻结工程运行，不拿V2旧数目充本版。
- 原R22弱RAW280孔漏检边界未修，报告随新发布；原始失败/逐位回放在V2完整发布保存。V3分类及主编号相关源逐SHA对比V2相同，不把失败算PASS。
- 尚需人实测：每个固定速度5次，完整RL3状态行、稳定X、S3→S1和停车后至少3秒；六SW3轮次、K3单清零、K2计数/队列保留；载带平面尺子标定像素/mm，再判±1mm。实板停车重复性/保持、板载5V负载和真实补料尚未正式验收。
- 当前全部TD/ModelSim结束、无硬件操作或自动跟进。下一步收新bit现场视频，按稳定X与速度标定advance，不放宽窗口掩盖停偏。发布为校准候选，不冒称工程实板完成。
- 原未跟踪calibration*.txt/compact*.hex/region_cadence*.pgm及scripts/__pycache__为产物，勿stage全部或删除。releases稀疏路径用git add --sparse；保留-text原始字节并核Git索引SHA。
