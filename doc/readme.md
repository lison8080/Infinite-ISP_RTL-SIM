# RTL 仿真 Testbench 说明（sim/tb）

本目录包含 `Infinite-ISP_RTL` 的主要 RTL 仿真测试平台（testbench）。这些 testbench 主要用于：

- **文件驱动仿真**：从二进制文件读取图像/向量数据，转换成视频流或测试激励。
- **模块级/系统级验证**：对 ISP/VIP 以及若干基础算法模块进行功能验证。
- **结果导出**：将 RTL 输出以二进制文件形式写回，便于与 Golden Model 或软件参考结果逐像素/逐帧对比。

## 1. 公共辅助模块（File <-> DVP）

多数视频类 testbench 会使用两个公共辅助模块：

- **`tb_file_to_dvp`**
  - **功能**：从二进制输入文件读取像素数据，按设定的行/场时序生成 DVP 风格信号（`pclk/href/vsync`）以及并行像素总线 `data`。
  - **输入**：`FILE` 参数指定的二进制文件（按像素顺序连续存放，每像素 `BITS/8` 字节）。
  - **输出**：
    - `pclk`：像素时钟（直接等于 `xclk`）。
    - `href`：行有效信号，表示当前 `data` 有效。
    - `vsync`：帧同步信号。
    - `data`：像素数据（当 `href==0` 时输出 0）。

- **`tb_dvp_to_file`**
  - **功能**：将 DVP 风格输出流在 `href==1` 时写入到二进制文件。
  - **写入字节序**：内部通过 `data[(c*8)+:8]` 逐字节写出，**先写低字节、再写高字节**。
  - **`vsync==1` 时 `fflush`**：用于在帧期间刷新缓冲区（方便仿真过程中观察输出文件增长）。

上述两个模块的定义位于：

- `fpga/vivado/isp_rtl/isp_rtl.srcs/sources_1/new/tb_dvp_helper.v`

## 2. 文件级说明

下文分别说明你标注的 6 个 testbench 文件：

- `tb_isp_dgain_update.v`
- `tb_isp_top.v`
- `tb_OSD.v`
- `tb_seq_simulation.sv`
- `tb_shift_div.v`
- `tb_vip_top.v`

### 2.1 `tb_isp_dgain_update.v`

- **测试对象（DUT）**：`isp_dgain_update`
- **目标**：验证数字增益（Digital Gain）索引更新逻辑是否能根据 AE 模块的反馈（`ae_response`）正确更新 `dgain_index`。
- **输入激励来源**：
  - `ae_response_vector.txt`：通过 `$readmemb` 读入的 2-bit AE 反馈序列。
- **输出/导出文件**：
  - `ae_feedback.bin`：按周期写出 `dgain_index`（扩展到 16bit 便于写文件）。
  - `ae_response_input.bin`：按周期写出“上一拍”的 `ae_response`（扩展到 16bit）。
- **使用方式**：
  - 将 `ae_response_vector.txt` 放在仿真工作目录（通常是仿真器生成的运行目录，如 xsim 目录）。
  - 运行仿真后，在工作目录中得到 `ae_feedback.bin` 与 `ae_response_input.bin`。

### 2.2 `tb_isp_top.v`

- **测试对象（DUT）**：`isp_top`
- **目标**：对 ISP 顶层进行文件驱动的整帧级仿真验证，支持 RAW Bayer 输入或 RGB 三通道输入（由 `rgb_inp_en` 选择）。
- **关键流程**：
  - `tb_file_to_dvp` 将输入文件转换为 DVP 流。
  - `isp_top` 对输入流进行 ISP 处理。
  - `tb_dvp_to_file` 将 ISP 输出再写回二进制文件。
- **常见输出**：
  - 主图像输出（YUV 或 RGB，取决于末端模块使能与 `generate` 选择）。
  - AWB 输出增益（`final_r_gain/final_b_gain`）按帧写文件。
  - AE 响应（`ae_response_debug`）/AE 偏度（`ae_result_skewness`）/DGain 索引（`dgain_index_out`）写文件。
- **可调点**：
  - `localparam`：图像尺寸、Bayer 格式、各模块 LUT 文件、算法参数。
  - 运行时 `*_en`：各模块旁路/使能（注意：与编译时 `USE_*` 宏的含义不同）。
  - 输入模式：`rgb_inp_en=0` 使用 RAW；`rgb_inp_en=1` 使用 R/G/B 三文件输入。

### 2.3 `tb_OSD.v`

- **测试对象（DUT）**：`vip_osd`
- **目标**：验证 OSD（On Screen Display，叠加显示）模块：
  - 在指定位置（`osd_x/osd_y`）叠加指定大小（`osd_w/osd_h`）的图形。
  - 支持前景色/背景色与透明度（`alpha`）混合。
- **输入激励**：
  - 通过 `tb_file_to_dvp` 分别读取 3 个文件作为 3 路像素通道输入。
  - 注意：该 testbench 中通道命名与实际连接（`in_data_r/g/b`）不完全一致，属于“为了喂数据而命名”的测试写法。
- **OSD RAM**：
  - 通过 `osd_lut` 产生每个地址的 RAM 写数据。
  - `osd_ram_wen` 在仿真开始阶段拉高一段时间，用于模拟一次性写入 OSD 图案。
- **输出文件**：`out_OSD.bin`（3 通道打包输出）。

### 2.4 `tb_seq_simulation.sv`

- **测试对象（DUT）**：`infinite_isp`（包含 ISP + VIP1 + VIP2 的系统级流水线）
- **目标**：验证“多帧连续输入”的系统级行为，典型用于观察：
  - AE/AWB 等跨帧算法是否能在连续帧上正确收敛。
  - ISP 与后级 VIP（如 RGBC/IRC/SCALE/OSD/YUV444->422）在连续帧下的时序/数据一致性。
- **输入文件命名规则**：
  - 期望当前仿真工作目录内存在 `XYZ_0.bin、XYZ_1.bin ...` 形式的文件。
  - 在本文件参数中 `IN_FILE` 只填写 `XYZ` 前缀，具体后缀由 `$sformatf(IN_FILE, "_%0d", i, ".bin")` 拼接得到。
- **输出文件**：
  - 输出同样按帧编号写成 `OUT_FILE_0.bin、OUT_FILE_1.bin ...`。
  - 另外也会导出 AWB/AE/DGain 的辅助结果文件（便于对比/回归）。

### 2.5 `tb_shift_div.v`

- **测试对象（DUT）**：`shift_div`
- **目标**：验证移位除法器（Shift Divider）在多组被除数/除数输入下的：
  - 商（quotient）
  - 余数（remainder）
  - `done` 完成时序
- **输入激励来源**：
  - `test_vector.txt`：文本文件，每行两个十进制数字（被除数、除数），通过 `$fscanf` 读入。
- **输出/导出文件**：
  - `fsm_dividend.bin / fsm_divisor.bin / fsm_quotient.bin / fsm_remainder.bin`：在 `done==1` 时写入对应结果（扩展到 64bit 写文件）。

### 2.6 `tb_vip_top.v`

- **测试对象（DUT）**：`vip_top`
- **目标**：单独验证 VIP 顶层（不包含 ISP 前端），支持组合使能如下典型模块：
  - 直方图均衡（HIST_EQU）
  - Sobel 边缘检测（SOBEL）
  - YUV->RGB（RGBC）
  - IRC/裁剪（IRC）
  - SCALE 缩放（SCALE）
  - OSD 叠加（OSD）
  - YUV444->422 格式转换（YUVConvFormat）
- **注意点**：
  - `USE_*` 为编译时宏，决定模块是否被实例化。
  - `*_EN` 为运行时使能，决定数据是否旁路。
- **输入输出**：
  - 输入通过 3 个文件生成 3 路像素通道（本文件中以 `in_y/in_u/in_v` 命名）。
  - 输出通过 `tb_dvp_to_file` 写到 `OUT_FILE`。

## 3. 常见仿真注意事项

- **文件路径**：这些 testbench 多数使用相对路径（如 `"xxx.bin"`）。请确保输入文件位于仿真器的当前工作目录。
- **像素位宽**：常见设置为 `BITS_FILE=16`（文件存储 16bit），内部处理位宽 `BITS=10/8`，必要时需要高位补 0 或截断。
- **帧级结果**：AWB/AE 等模块的输出通常在帧结束（`vsync` 边沿）或 `ae_done` 时刻写文件，因此仿真需要跑足够长时间。
