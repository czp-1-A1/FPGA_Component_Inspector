# R50 后续路径分析：仅只读诊断，尚未实施

当前代码提交 `38408179`，34项精确源检查通过。R50完整布线仍在运行；本记录不授权或启动下一轮，不改变显示、算法、时钟、约束或硬件。

## 已确认的布局线索

R50的100MHz首条placed路径为FSS `ramread16_syn_111.clkb → reason_bank_reg[47]`，10级，数据路径9.431ns，setup余量0.349ns。来源是R50保存的place报告，**不是实际route失败端点**。

实际SYN网表中，该RAM实例连接`mask_wa`、`mask_wd`、`mem_addr`，注释指向`frame_shape_search.v`第163行的mask读口，`REGMODE_B=NOREG`。它属于捕获的前景／暗参考mask，不是可以随意删除的显示缓存。

原代码的参考检查存在如下组合关系：

```text
mask RAM高4位 + ref_mask
    → dark_word（4个有效像素的popcount，0..4）
    → right_dark + dark_word
    → 与ref_min比较
    → reason_bank[ref_index][3]写回
```

对应源码位置：`dark_word`和`background_reference_ok`在参考采样组合逻辑中；最后一次`REF_CHECK`在保留有件识别时写入质量原因位。不能把它描述成识别核心已经出错。

## 下一步可验证的方向

优先研究在**现有REF_WAIT**计算`dark_word=0..4`时各自的比较结果，再在REF_CHECK用新RAM实际读出的`dark_word`选择结果。`right_dark`、`ref_min`和相应控制参数在REF_WAIT到REF_CHECK之间保持不变，而当前像素字只在读口完成后使用。

这能尝试将累加／宽比较移出RAM输出到原因写回的路径。必须保留原有表达式的位宽、无符号扩展和溢出语义，不能直接把9位和32位上下文中的相同加法合并。不得在读取沿使用上一地址的mask或`dark_word`。先做局部边界、原FSS逐像素／逐候选对照，再测实际资源及布局，才决定是否完整布线。

此方向还可能影响EMPTY的context比较，不能仅修有件原因位后就宣称整个FSS路径已解决。新增准备寄存器也可能增加Slice；R47的负收益已经证明，必须实测。当前非法布线首先是拥挤现象，尚不能证明修这条placed路径就能消除全部冲突。

## 已排除的直觉优化

- 实际SYN网表的两列5组状态标志（valid/used/armed/quarantine/cross_pending）共320个FF，`CEMUX`已经全部为常开1。不能再把“取消这些FF的时钟使能”算作新收益。
- `global_empty_position_tracker`已经使用一套FSM串行扫描两列，包含READ/LOAD/SCAN/WRITE和两组32记录。不能再把“双列定位比较器共享”当作尚未实施的大幅节省。
- mask高4位是`灰度<=FOREGROUND`，低4位是`灰度>=FOREGROUND`，阈值相等时两者同时为1；访问标记又允许清除低位。因此不能直接把每像素两位改成三态编码，或把`<=`改成`<`来换资源，这会改变参考／识别语义。

以上是后续分析线索，没有新RTL、SYN、seed、策略或约束试验，也没有删任何显示模式。
