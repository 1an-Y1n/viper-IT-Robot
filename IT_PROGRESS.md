# LE IT 自动化进度 (DZ300-1757)

把 LE IT 测试模板 `Viper_LE-CAMP-00.04.006_IT_20261111.xlsx` 的每个测试项
变成 Robot Framework 自动化脚本。这份文件记录**逐项复核**的进度：每复核一项，
在这里写清楚「测试项的目的与内容 → 测试步骤 → 脚本怎么写的 → 实测有没有通过」。

| | |
| --- | --- |
| 模板 | `Viper_LE-CAMP-00.04.006_IT_20261111.xlsx` (Jira DZ300-1757) |
| 范围 | ASC / ALIGNMENT / CUST_FACING / PAB 四个表，130 个测试项 / 132 行（ASC-003 和 CF-054 在模板里各占两行；CHANGELIST 不在本次范围） |
| DUT | 现在用 `172.21.48.233`，序列号 `SCMLSA26200016`，HW `06.05`，SW `00.04.006`（2026-11-20 起） |
| 换过的 DUT | `172.21.48.230` / `SCMLSA2619005A` / HW 06.05 / SW 00.04.006（被别人占用）→ `172.21.48.226` / `SCMLSC25240006` / HW 04.0 / SW 00.04.006ER3（自己复位过两次）→ **`.233`**。模板是照着**正式版 00.04.006 + HW 06.05** 写的，现在这台正好对上 |
| 工程 | `3_camp/dz1757_autotest/robot_viper`（不入 git） |
| 工作流 | `AGENT.md`（逐项复核的步骤、生成器怎么用、实机怎么探、不能做的事） |
| 复核顺序 | 按模板 sheet 顺序：PAB → ALIGNMENT → ASC → CUST_FACING |

> ⚠️ **2026-11-20 的一个坑**：脚本走的是 `variables/dut_variables.robot` 里的
> `SSH_DUT_IT`（`.233`），而 tether 的目标在 **shell 的环境变量**里
> （`TETHER_DEVICE_HOST`）。这一轮 shell 里的这个变量还是 `.230`（`~/.bashrc`
> 里已经改成 `.233` 了，但 shell 是改之前起的，tether 的 daemon 也是改之前
> 起的、一直连着 `.230`）。结果是：**tether 看到的数和脚本看到的数不是同一台
> 机器**，害我把「文件里的值过不了重启」这个结论记到了 `.233` 头上（其实是在
> `.230` 上看到的，`.233` 那一轮根本没重启）。
> 每次用 tether 之前先确认目标：
> `tether --status` 或者在 shell 里 `echo $SSH_CONNECTION`（在设备上看），
> 不确定就用 `tether --once amp_admin@172.21.48.233 "cmd"` 显式指定。

## 参考资料

模板的每一条期望都指向 SERCOMM LE User Guide 的章节。这份 User Guide 已经抽成
markdown 在 `3_camp/okf-bundle`（`chapters/` 是按章切好的文档，`raw/` 是 PDF 原文，
`index.md` 是目录）。逐项复核时以它为权威依据，实机为最终事实。

| Sheet | User Guide 章节 |
| --- | --- |
| PAB | 6 Pre-Alignment Procedure（配置与 FreeRun）、12 gRPC（PAB 服务） |
| ALIGNMENT | 4 Legacy US Cal Error、5 Configurations For Different Lineups、7 Calibration Procedure、9 gNMI 数据模型（alignment 容器）、12 gRPC（Calibration 服务） |
| ASC | 8 Automatic Signal Conditioning、10 Other Useful Commands（ASC/AGC 配置） |
| CUST_FACING | 1 Basic Operation（LED/ICS）、2 Directory and Files、3 Comcast CLI、9 gNMI、11 Firmware Upgrade、12 gRPC、13 DS Tracker、14 SSH、15 FAQ |

## 每次跑的证据放在哪

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1119 -d result/run_20261119_1119 IT
```

`--variable VERSION:` 决定命令原始日志落在 `result/<VERSION>/<suite>/`，
`-d` 决定 Robot 自己的 output.xml / log.html / report.html 落在哪。
两者用同一个名字，就是一个自包含的目录，跑完的证据单独留一份。

命令日志**按次追加**（同一个 suite 跑两次，内容接在后面），
所以留档要靠上面这个独立的目录。

每个用例现在有自己��日志文件（`PAB-002-1_gnmi.log` 这种），
不再是一个 suite 一个大文件。做法见 `IT_CONVENTIONS.md` 的
「Where the logs go」。

## 已知的 User Guide 与实机不一致的地方

逐项对照时发现的，先记在这里，到对应条目时再确认：

- **「恢复出厂配置」自己会重启 DUT**：User Guide 10.3 只写了
  `FDX-AMP>$ restore factory config`，没说它会重启。实机实测：**它会把配置
  换成出厂数据并立刻重启 DUT**（命令发出后 15 s 内 SSH 就断了，约 40 s 后回来）。
  所以「恢复出厂 → 设管理 IP → 重启」这个顺序在实机上做不到——
  重启发生在设 IP 之前。详见下面的「恢复出厂与管理 IP」

- **AGC 配置项编号**：User Guide 第 10 章给的 `set_agc_config <Id>` 表是 13 项，
  其中 `6 = LEGACY_FLAG`、`7 = FDX_FLAG`、`9 = ACTIVE_AFE_TCP_MONITOR`、
  `12 = CLIPPING_GUARDRAIL`。但 DUT 上 `sc_cli get_agc_config` 打印的是 **18 个字段**，
  顺序也不同，按打印顺序数 `4 = Legacy enable`、`5 = Fdx enable`、
  `9 = NP Clipping Guardrail`。ASC-002 / ASC-003 用的是 DUT 的编号，
  到那两条时要确认用哪个为准

## 状态取值

| 状态 | 含义 |
| --- | --- |
| 未开始 | 还没有逐项复核过 |
| 已复核 | 已确认目的、步骤、脚本与实测结果 |
| 跳过 | 模板条目不自动化，理由写在条目里 |

## 恢复出厂与管理 IP（台子上的前置条件，实测）

PAB-016、CF-004、CF-015 这些条目都要「恢复出厂配置并重启」这一步，
它不在脚本里，是台子上的动作。这里记下 2026-11-19 在 `172.21.48.230`
上把这条流程走通时量到的东西。

**管理 IP 在哪、开机时从哪来**

- 配置存在 AMP 的 nonvol store 里，落在 `/mnt/sc_nonvol/ampapp_data.json`：
  `"management": {"interface": {"address", "gateway", "mode", "netmask"}}`
- 开机时 `/etc/network/interfaces` 里 eth0 是 `iface eth0 inet manual`，
  pre-up 钩子 `/usr/bin/scPortBringup.sh up eth0` 去读
  `sc_cli get_mgmt_port_config`，把地址/掩码/网关配到 eth0 上
  → **开机拿到的管理 IP 就是这个文件里的值**
- 改管理 IP 的命令：`mgmtip show | dhcp | static ip <ip> net-mask <mask> gateway <gw>`
  （User Guide 10.6）。它实际调 `sc_cli set_mgmt_port_config`，然后
  `systemctl restart sc_eth0` 让新地址立刻生效

**「配置文件有没有被改」——会，而且立刻就改**

`mgmtip static ...` 之后 `/mnt/sc_nonvol/ampapp_data.json` 被重写，
**同一秒内写了 4 次**（DUT journal 里 `sc-nonvol` 的
`WriteToFile: successfully wrote /mnt/sc_nonvol/ampapp_data.json (atomic, size=...)`），
不用等 60 s 的 debounce。写是原子写，文件不会写坏。

**「恢复出厂」会重启 DUT**

`restore factory config` → `/usr/bin/reset.sh RESET_FACTORY` →
`gnmic set /system-control/reset-control/reset = RESET_FACTORY`，
AMP 收到后把配置换成出厂数据并**自己重启 DUT**：
命令发出后 15 s 内 SSH 断开，约 40 s 后设备回来。
所以「恢复出厂 → 设管理 IP → 检查文件 → 重启」这个顺序做不到，
重启发生在设 IP 之前。

**那恢复出厂之后 IP 会不会变**

- 这台 DUT **不会变**：恢复出厂换上的出厂数据里就是 `172.21.48.230`，
  重启后照旧用这个地址，Robot 照旧连得上
- 出厂数据是这台机器自己的（台子出厂时烤进去的，
  见 `/mnt/nonvol_active/change_ip.sh`），**不是镜像里的默认值**：
  镜像里的 `/card0/amp/ampapp_data.json.default` 写的是 `192.168.2.103`
- 所以**没有烤过台子地址的机器**，恢复出厂后会变成 `192.168.2.103`，
  从台架上就连不上了。那种机器只能靠串口把地址改回来

**恢复出厂只能用一次（重要）**

源码 `libsc_cal.cpp` 的 `libsc_cal_factory_reset()` 做完恢复之后会
**把出厂文件删掉**：

```c
unlink("/mnt/sc_factory/rfboard_data.json.factory");
unlink("/mnt/sc_factory/ampapp_data.json.factory");
unlink("/mnt/sc_nonvol/calibrated_flag");
...
```

而恢复的来源正是那个 `/mnt/sc_factory/ampapp_data.json.factory`
（`ScNonVolData` 的三个路径：user=`/mnt/sc_nonvol/ampapp_data.json`、
factory=`/mnt/sc_factory/ampapp_data.json.factory`、
default=`/card0/amp/ampapp_data.json.default`）。

所以这台 DUT 恢复出厂之后，**那个出厂文件已经不在了**：
再执行一次 `restore factory config`，AMP 的配置**不会被换回出厂数据**
（`ResetFromFileName` 打不开文件就返回 false，store 保持原样），
但它仍然会删 `calibrated_flag`、删 syslog 备份、并重启。
要再恢复一次，**得让台子把出厂文件重新放回去**。

## 进度总表

### PAB（16 项，16 项有脚本）

| ID | 模块 | 脚本 | 用例 | 状态 |
| --- | --- | --- | --- | --- |
| PAB-001 | PAB \| Sercomm CLI | `IT/PAB/PAB-001/#PAB-001.robot` | 3 | 已复核（3/3 通过；第 3 条依赖台子的 eCM 状态） |
| PAB-002 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-002/#PAB-002.robot` | 2 | 已复核（2/2 通过） |
| PAB-003 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-003/#PAB-003.robot` | 1 | 已复核（1/1 通过） |
| PAB-004 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-004/#PAB-004.robot` | 1 | 已复核（1/1 通过） |
| PAB-005 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-005/#PAB-005.robot` | 1 | 已复核（1/1 通过） |
| PAB-006 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-006/#PAB-006.robot` | 1 | 已复核（1/1 通过） |
| PAB-007 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-007/#PAB-007.robot` | 1 | 已复核（1/1 通过） |
| PAB-008 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-008/#PAB-008.robot` | 1 | 已复核（1/1 通过） |
| PAB-009 | PAB \| GNMI Result (Container & Stage 1~7) | `IT/PAB/PAB-009/#PAB-009.robot` | 1 | 已复核（1/1 通过） |
| PAB-010 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-010/#PAB-010.robot` | 2 | 已复核（2/2 通过） |
| PAB-011 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-011/#PAB-011.robot` | 2 | 已复核（2/2 通过；修了两个真问题） |
| PAB-012 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-012/#PAB-012.robot` | 2 | 已复核（2/2 通过；恢复搬进了 Suite Teardown） |
| PAB-013 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-013/#PAB-013.robot` | 3 | 已复核（3/3 通过；改了脚本） |
| PAB-014 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-014/#PAB-014.robot` | 3 | 已复核（3/3 通过；去掉两处状态依赖的断言） |
| PAB-015 | PAB \| GRPC Configuration, Status & Control | `IT/PAB/PAB-015/#PAB-015.robot` | 3 | 已复核（3/3 通过，单跑） |
| PAB-016 | PAB \| FreeRun Boot-up | `IT/PAB/PAB-016/#PAB-016.robot` | 2 | 已复核（2/2 通过；跑在「恢复出厂 + 重启」之后的 DUT 上） |

### ALIGNMENT（15 项，13 项有脚本）

| ID | 模块 | 脚本 | 用例 | 状态 |
| --- | --- | --- | --- | --- |
| ALN-001 | Alignment \| Sercomm CLI Calibration | `IT/ALIGNMENT/ALN-001/#ALN-001.robot` | 3 | 已复核（3/3 通过；断言原来太松，是假通过，已收紧） |
| ALN-002 | Alignment \| FDX & Non-FDX Alignment | `IT/ALIGNMENT/ALN-002/#ALN-002.robot` | 12 | 历史 .233 运行报告 12/12；断言修改后待完整复测 |
| ALN-003 | Alignment \| FDX & Non-FDX Alignment | `IT/ALIGNMENT/ALN-003/#ALN-003.robot` | 12 | 历史运行报告 12/12；断言修改后待完整复测 |
| ALN-004 | Alignment \| FDX & Non-FDX Alignment | `IT/ALIGNMENT/ALN-004/#ALN-004.robot` | 16 | 历史运行有假通过；修复后 profile、RLSP、spectrum 定向实机通过，待完整复测 |
| ALN-007 | Alignment \| Legacy US Calibration Error Factory Compensation | `IT/ALIGNMENT/ALN-007/#ALN-007.robot` | 6 | 全项跳过：标定后需人工测量 RLSP，脚本尚不支持暂停等待；历史前 4 项实机通过 |
| ALN-008 | Alignment \| CLISH Calibration Modes | `IT/ALIGNMENT/ALN-008/#ALN-008.robot` | 4 | **已复核（.233 上 4/4 通过；断言原来太松，已收紧）** |
| ALN-009 | Alignment \| GNMI Alignment (DS1 / DS2 / DS3 / US) | `IT/ALIGNMENT/ALN-009/#ALN-009.robot` | 1 | 已复核（.233 上 1/1 通过；失败分支未实测） |
| ALN-010 | Alignment \| GNMI Alignment (DS1 / DS2 / DS3 / US) | `IT/ALIGNMENT/ALN-010/#ALN-010.robot` | 1 | 已复核（.233 上 1/1 通过；失败分支未实测） |
| ALN-011 | Alignment \| GNMI Alignment (DS1 / DS2 / DS3 / US) | `IT/ALIGNMENT/ALN-011/#ALN-011.robot` | 1 | 已复核（.233 上 1/1 通过；失败分支未实测） |
| ALN-012 | Alignment \| GNMI Alignment (DS1 / DS2 / DS3 / US) | `IT/ALIGNMENT/ALN-012/#ALN-012.robot` | 1 | 已复核（.233 上 1/1 通过；失败分支未实测） |
| ALN-013 | Alignment \| GNMI Alignment (DS1 / DS2 / DS3 / US) | `IT/ALIGNMENT/ALN-013/#ALN-013.robot` | 2 | 已复核（.233 上 2/2 通过；16 条 GET） |
| ALN-014 | Alignment \| GRPC Calibration Service | `IT/ALIGNMENT/ALN-014/#ALN-014.robot` | 4 | 已复核（.233 当前脚本完整运行 4/4 通过；人工调整和失败分支未实测） |
| ALN-015 | Alignment \| Calibration Control Flags | `IT/ALIGNMENT/ALN-015/#ALN-015.robot` | 4 | 已复核（按用户确认的 sc_cli 命令与 SET/GET 范围，.233 上 4/4 通过） |
| ALN-005 | Alignment \| FDX & Non-FDX Alignment | `IT/ALIGNMENT/ALN-005/#ALN-005.robot` | 17 | 历史运行有假通过；修复后 profile、RLSP、spectrum 定向实机通过，待完整复测 |
| ALN-006 | Alignment \| FDX & Non-FDX Alignment | `IT/ALIGNMENT/ALN-006/#ALN-006.robot` | 17 | 历史运行有假通过；修复后 profile、RLSP、spectrum 定向实机通过，待完整复测 |

### ASC（39 项，34 项有脚本）

| ID | 模块 | 脚本 | 用例 | 状态 |
| --- | --- | --- | --- | --- |
| ASC-001 | ASC \| CLI Configuration | `IT/ASC/ASC-001/#ASC-001.robot` | 1 | 已复核；.233 实机 1/1 通过，300 s 轮次、重启保持和恢复已验证 |
| ASC-002 | ASC \| CLI Configuration | `IT/ASC/ASC-002/#ASC-002.robot` | 2 | 未开始 |
| ASC-003 | ASC \| CLI Configuration | `IT/ASC/ASC-003/#ASC-003.robot` | 4 | 未开始 |
| ASC-004 | ASC \| OperationMode | `IT/ASC/ASC-004/#ASC-004.robot` | 1 | 已预留北口信号控制接口并跳过；未实测，待接入台架后验证 |
| ASC-005 | ASC \| OperationMode | `IT/ASC/ASC-005/#ASC-005.robot` | 1 | 已预留北口信号控制接口并跳过；未实测，待接入台架后验证 |
| ASC-006 | ASC \| OperationMode | `IT/ASC/ASC-006/#ASC-006.robot` | 2 | 未开始 |
| ASC-007 | ASC \| Config/Target Data save | `IT/ASC/ASC-007/#ASC-007.robot` | 1 | 已复核；.233 实机 1/1 通过，配置持久化、服务重启及恢复已验证 |
| ASC-008 | ASC \| Config/Target Data save | `IT/ASC/ASC-008/#ASC-008.robot` | 1 | 已复核；.233 实机 1/1 通过，完成自动标定并核对快照重启持久化 |
| ASC-009 | ASC \| Config/Target Data save | `IT/ASC/ASC-009/#ASC-009.robot` | 1 | 已复核；.233 实机 1/1 通过，核对快照转储字段及频谱 bin 数 |
| ASC-010 | ASC \| Config/Target Data clear | `IT/ASC/ASC-010/#ASC-010.robot` | 1 | 未开始 |
| ASC-011 | ASC \| Config/Target Data clear | `IT/ASC/ASC-011/#ASC-011.robot` | 1 | 未开始 |
| ASC-015 | ASC \| Algorithm flowchart | `IT/ASC/ASC-015/#ASC-015.robot` | 2 | 未开始 |
| ASC-016 | ASC \| Algorithm flowchart | `IT/ASC/ASC-016/#ASC-016.robot` | 1 | 未开始 |
| ASC-017 | ASC \| Interval | `IT/ASC/ASC-017/#ASC-017.robot` | 2 | 未开始 |
| ASC-018 | ASC \| Interval | `IT/ASC/ASC-018/#ASC-018.robot` | 2 | 未开始 |
| ASC-019 | ASC \| Interval | `IT/ASC/ASC-019/#ASC-019.robot` | 2 | 未开始 |
| ASC-020 | ASC \| Interval | `IT/ASC/ASC-020/#ASC-020.robot` | 1 | 已复核；.233 实机 1/1 通过，周期和关闭时遥测写入已验证 |
| ASC-021 | ASC \| Temperature compensation | `IT/ASC/ASC-021/#ASC-021.robot` | 1 | 未开始 |
| ASC-023 | ASC \| Telemetry | `IT/ASC/ASC-023/#ASC-023.robot` | 1 | 未开始 |
| ASC-026 | ASC \| Clipping Monitor | `IT/ASC/ASC-026/#ASC-026.robot` | 1 | 未开始 |
| ASC-027 | ASC \| Clipping Monitor | `IT/ASC/ASC-027/#ASC-027.robot` | 1 | 未开始 |
| ASC-028 | ASC \| Control & Status | `IT/ASC/ASC-028/#ASC-028.robot` | 1 | 已复核；.233 实机 1/1 通过，停止、恢复和禁用时拒绝均已验证 |
| ASC-029 | ASC \| Control & Status | `IT/ASC/ASC-029/#ASC-029.robot` | 1 | 已预留北口信号接口并跳过；未实测，待接入台架后验证 |
| ASC-030 | ASC \| Control & Status | `IT/ASC/ASC-030/#ASC-030.robot` | 1 | 已实现；.233 实测失败：轮次计数 1 → 1，不符合模板累加要求 |
| ASC-031 | ASC \| Gating | `IT/ASC/ASC-031/#ASC-031.robot` | 2 | 未开始 |
| ASC-032 | ASC \| Gating | `IT/ASC/ASC-032/#ASC-032.robot` | 2 | 未开始 |
| ASC-033 | ASC \| Gating | `IT/ASC/ASC-033/#ASC-033.robot` | 1 | 未开始 |
| ASC-034 | ASC \| Robustness | `IT/ASC/ASC-034/#ASC-034.robot` | 1 | 未开始 |
| ASC-035 | ASC \| Robustness | `IT/ASC/ASC-035/#ASC-035.robot` | 1 | 未开始 |
| ASC-036 | ASC \| Robustness | `IT/ASC/ASC-036/#ASC-036.robot` | 1 | 未开始 |
| ASC-037 | ASC \| Robustness | `IT/ASC/ASC-037/#ASC-037.robot` | 1 | 未开始 |
| ASC-038 | ASC \| GRPC Configuration Service | `IT/ASC/ASC-038/#ASC-038.robot` | 1 | 已复核；.233 实机 1/1 通过，gRPC 和 CLI 的全部配置字段及恢复已核对 |
| ASC-039 | ASC \| AGC with FDX Enablement (Workaround) | `IT/ASC/ASC-039/#ASC-039.robot` | 3 | 未开始 |
| ASC-012 | ASC \| Algorithm flowchart | — | — | 跳过（需要物理测试台，不自动化） |
| ASC-013 | ASC \| Algorithm flowchart | `IT/ASC/ASC-013/#ASC-013.robot` | 1 | 已预留北口信号接口并跳过；未实测，待接入台架后验证 |
| ASC-014 | ASC \| Algorithm flowchart | — | — | 跳过（需要物理测试台，不自动化） |
| ASC-022 | ASC \| Temperature compensation | — | — | 跳过（需要物理测试台，不自动化） |
| ASC-024 | ASC \| Simulation | — | — | 跳过（需要物理测试台，不自动化） |
| ASC-025 | ASC \| Simulation | — | — | 跳过（需要物理测试台，不自动化） |

### ASC-007 — ASC saves agc_data.json in nonvol（2026-11-23）

按模板设置 FreeRun、inputInterval 300、inputPowerTransientThreshold 0.2、
AGC ATT/EQ 阈值 0.5、rfboard 通知间隔 3600；核对文件、重启 sc-asc、
核对 PID 变化及重启后文件和 CLI 读回，并检查本次启动后的错误日志。
最终 `result/asc007_233_final_20261123/` 为 **1/1 通过**，PID 6191 → 7275，
启动后无 ERR 日志。

首次运行因 `systemctl show` 打开分页器而卡住，未执行服务重启；手工恢复
inputInterval 120、ATT 阈值 0.3 并核对文件。第二次重启及读回成功，但恢复时
AGC CLI 尚未异步刷新，导致失败；稍后独立核实 CLI 和文件均已恢复。已禁用
分页器，在恢复前重连并等待 CLI 和文件读回，最终重测通过。
测试后独立确认服务 active、NP DS enabled/Idle；模式 FreeRun、interval 120、
power threshold 0.5、ATT/EQ 0.3、通知间隔 86400，CLI 与文件一致。

### ASC-008 — ASC saves asc_calib_snapshot.json in nonvol（2026-11-23）

完整自动标定，验证四阶段顺序及成功；比较快照文件和 `show` 的 TCP、pilot、
13 项 RF 状态及五类频谱 bin 数，确认重启前后文件哈希一致，并再次比较
`show`。`result/asc008_233_retry_20261123/` 实机 **1/1 通过**；重启后
服务 active、FreeRun、NP DS enabled。

首次 `result/asc008_233_20261123/` 标定成功但在重启前失败：当前频谱为
Genesis、FDX 未启用，`fdx_path_gain_cal` 为 0 bins。设备源码允许无 FDX
频段时为空，脚本因此改为 FDX 未启用时允许零 bin、但仍核对文件与 CLI 一致；
FDX 启用时必须非空。该改动也应用于 ASC-009 的快照比较，本地模拟覆盖两种
状态；完整 FDX 状态的实机回归仍待执行。两次实测均重新标定，未恢复出厂。

### ASC-020 — Telemetry persist interval（2026-11-23）

设置间隔 60 s，重启服务并验证周期写入、再重启验证关闭时写入及日志，最后
恢复原值。`result/asc020_233_retry_20261123/` 实机 **1/1 通过**；
文件 mtime 分别为启动后 366 s、周期写入 427 s、关闭写入 432 s。
独立核对 CLI 与配置文件中的间隔均恢复为 86400 s，服务 active、NP DS enabled。
恢复后已排程的 60 s 周期可能再触发一次；设备源码在下次周期写入后按当前
配置重新设置定时器。

首次 `result/asc020_233_20261123/` 已验证周期及关闭写入，但恢复时服务的
10 分钟内最多启动三次限制被触发，服务进入 failed。已手动执行 systemd
reset-failed 并启动服务，核对配置恢复；脚本随后减少一次不必要的服务重启。
这是恢复服务，不是恢复出厂。

### ASC-028 — set_agc_control start/stop（2026-11-23）

等待 NP DS 运行后停止控制循环，检查四个 FSM 均 disabled/Idle，并持续观察
一个 NP DS 输入间隔加 5 秒；随后启动并验证四个 FSM 恢复、NP DS 重新运行。
设置 Disable 后验证 stop/start 都返回 failed，最后恢复原运行模式。
`result/asc028_233_20261123/` 实机 **1/1 通过**；独立核对服务 active、
FreeRun、inputInterval 120，四个 FSM 均 enabled/Idle。

### ASC-038 — ASC Configuration gRPC（2026-11-23）

保存全部 11 个字段，使用模板的完整配置执行 gRPC SET，分别通过 gRPC GET
和 CLI 核对每个字段；在 `FINALLY` 中通过 gRPC 恢复全部原始字段并再次核对。
`result/asc038_233_20261123/` 实机 **1/1 通过**。独立 CLI 核对原配置已恢复，
服务 active，NP DS enabled/Idle。本地模拟覆盖 gRPC 字段缺失、gRPC 和 CLI
读回不一致。

### ASC-030 — FSM status query（2026-11-23）

`result/asc030_233_20261123/` 实机 **失败**：NP DS 从 Idle 进入
PilotSample 并回到 Idle 后，`loop_count` 为 **1 → 1**，没有满足模板的
轮次累加要求。四个 FSM 的 enabled/disabled 状态及字段检查均通过，模式已
恢复 FreeRun，服务 active、NP DS enabled。

源码 `ScFsmManager.h` 的 `Start()` 每次清零计数，与模板“loop_count
accumululates”存在差异；当前按模板保留失败断言，未修改设备固件或将失败
计作通过。

### ASC-029 — ADU status（2026-11-23）

实现 Disable/Monitor 下 OFF、FreeRun 下 TRACKING、外部北口信号下降触发
ON_HOLD 及恢复后 TRACKING 的核对，并在退出时恢复信号和原模式。复用北口
信号接口，暂按 ASC-013 的相对标定基准 -6 dB；接口未接入，整项标记跳过，
仅做本地 dry-run，信号幅度与断言均未实机验证。

### ASC-009 — ASC dump the saved snapshot（2026-11-23）

在 `.233` 完整自动标定恢复后测试；校准四阶段均为 ALIGNED，校准标志为 false，
NP DS 控制循环启用。ASC-009 读取 `show`，将快照转储到唯一临时文件，并核对四项
TCP、pilot 表、13 项 RF 状态和五类频谱的 bin 数；无快照或字段不符即失败。
用 `jq -M` 在设备上解析并只返回摘要，避免传输约 3.3 MB 的完整文件；测试在
`FINALLY` 中删除自己创建的临时文件。
提取共享比较逻辑后，`result/asc009_233_genesis_20261123/` 在当前 Genesis
配置下再次 **1/1 通过**；FDX 开启状态的回归尚待可用台架。

首次运行 `result/asc009_233_20261123/` 因 `jq` 的终端颜色导致 JSON 解析失败；
禁用颜色后 `result/asc009_233_retry_20261123/` **1/1 通过**。本地模拟覆盖
正常数据、错误 bin 数、缺失 RF 字段及错误 pilot，并检查失败时临时文件清理。

### ASC-001 — ASC config sc_cli configuration（2026-11-23）

在 `.233` 自动标定恢复后测试；校准四阶段 ALIGNED，校准标志 false，ASC NP DS
启用。首次运行 `result/asc001_233_20261123/` 发现 NP DS 的 `loop_count` 每轮
重置，不能按累计值判断新轮次，已改为观察 FSM 运行及空闲状态。

第二次 `result/asc001_233_retry_20261123/` 在 300 秒定时器检查后重启；
旧的重连等待在关机前就返回，随后连接中断，自动恢复失败。设备上线后已用
独立命令恢复并核对 FreeRun、inputInterval=120、阈值=0.5、第三 pilot=1095000000
和日志级别 INFO；校准标志 false、NP DS enabled=true。已改为等待 boot ID
变化及服务就绪，恢复前也重试连接；本地模拟覆盖旧 boot ID 不能当作重启。
没有执行恢复出厂。

第三次 `result/asc001_233_bootid_20261123/` **1/1 通过**：检查了 pilot 改变、
300 秒定时轮次、真实重启后的四个字段保持及原配置恢复。测试后独立核对
FreeRun、inputInterval=120、阈值=0.5、第三 pilot=1095000000、日志级别 INFO，
校准标志 false，NP DS enabled=true。

### ASC-004 / ASC-005 — ASC FreeRun / Monitor（2026-11-23）

已预留北口信号变化及恢复接口 `IT ASC EXTERNAL - Set North Port Input Delta`
和 `IT ASC EXTERNAL - Restore North Port Signal`，未接入台架时明确失败。
用例标记为 `robot:skip`，不会执行套件初始化或设备操作。其余步骤编写了标定与
PAB 前置检查、FreeRun 状态和 ADU 检查、NP DS 轮次及 RF 衰减变化检查，并在
退出时恢复信号和原 operation mode。ASC-005 复用接口，检查 Monitor 模式下的
NP DS 决策日志和 RF 配置未变化，并恢复日志级别。两项仅做 dry-run；**未在实机
或接入仪表验证**。

### ASC-013 — NP DS FirstOutRange（2026-11-23）

复用北口信号控制接口，以相对标定基准 -6 dB 制造模板所需的输入变化；
检查本次日志中的 OutRange 处理和边界调整、ADU 的 ON_HOLD 与信号恢复后的
TRACKING，并恢复原模式和日志级别。接口未实现，整项标记跳过；仅本地 dry-run，
未在设备或外部仪表验证。

### CUST_FACING（60 项，60 项有脚本）

| ID | 模块 | 脚本 | 用例 | 状态 |
| --- | --- | --- | --- | --- |
| CF-001 | Sanity Check | `IT/CUST_FACING/CF-001/#CF-001.robot` | 1 | 未开始 |
| CF-002 | System & Basic Configuration | `IT/CUST_FACING/CF-002/#CF-002.robot` | 4 | 未开始 |
| CF-003 | System & Basic Configuration | `IT/CUST_FACING/CF-003/#CF-003.robot` | 2 | 未开始 |
| CF-004 | System & Basic Configuration | `IT/CUST_FACING/CF-004/#CF-004.robot` | 1 | 未开始 |
| CF-006 | System & Basic Configuration | `IT/CUST_FACING/CF-006/#CF-006.robot` | 1 | 未开始 |
| CF-007 | System & Basic Configuration | `IT/CUST_FACING/CF-007/#CF-007.robot` | 3 | 未开始 |
| CF-008 | Comcast CLI | `IT/CUST_FACING/CF-008/#CF-008.robot` | 2 | 未开始 |
| CF-009 | Comcast CLI | `IT/CUST_FACING/CF-009/#CF-009.robot` | 1 | 未开始 |
| CF-010 | Comcast CLI | `IT/CUST_FACING/CF-010/#CF-010.robot` | 1 | 未开始 |
| CF-011 | Comcast CLI | `IT/CUST_FACING/CF-011/#CF-011.robot` | 1 | 未开始 |
| CF-012 | Comcast CLI | `IT/CUST_FACING/CF-012/#CF-012.robot` | 1 | 未开始 |
| CF-013 | Comcast CLI | `IT/CUST_FACING/CF-013/#CF-013.robot` | 1 | 未开始 |
| CF-014 | Comcast CLI | `IT/CUST_FACING/CF-014/#CF-014.robot` | 2 | 未开始 |
| CF-015 | Comcast CLI | `IT/CUST_FACING/CF-015/#CF-015.robot` | 1 | 未开始 |
| CF-016 | Comcast CLI | `IT/CUST_FACING/CF-016/#CF-016.robot` | 3 | 未开始 |
| CF-017 | Sercomm CLI | `IT/CUST_FACING/CF-017/#CF-017.robot` | 4 | 未开始 |
| CF-018 | Sercomm CLI | `IT/CUST_FACING/CF-018/#CF-018.robot` | 5 | 未开始 |
| CF-019 | Sercomm CLI | `IT/CUST_FACING/CF-019/#CF-019.robot` | 1 | 未开始 |
| CF-020 | Sercomm CLI | `IT/CUST_FACING/CF-020/#CF-020.robot` | 1 | 未开始 |
| CF-021 | Sercomm CLI | `IT/CUST_FACING/CF-021/#CF-021.robot` | 1 | 未开始 |
| CF-022 | Sercomm CLI | `IT/CUST_FACING/CF-022/#CF-022.robot` | 2 | 未开始 |
| CF-023 | Sercomm CLI | `IT/CUST_FACING/CF-023/#CF-023.robot` | 1 | 未开始 |
| CF-024 | DS Output Spectrum Before and After FW Upgrade | `IT/CUST_FACING/CF-024/#CF-024.robot` | 1 | 未开始 |
| CF-025 | DS Output Spectrum Before and After FW Upgrade | `IT/CUST_FACING/CF-025/#CF-025.robot` | 2 | 未开始 |
| CF-026 | LED Tests | `IT/CUST_FACING/CF-026/#CF-026.robot` | 1 | 未开始 |
| CF-027 | LED Tests | `IT/CUST_FACING/CF-027/#CF-027.robot` | 1 | 未开始 |
| CF-028 | LED Tests | `IT/CUST_FACING/CF-028/#CF-028.robot` | 1 | 未开始 |
| CF-029 | LED Tests | `IT/CUST_FACING/CF-029/#CF-029.robot` | 1 | 未开始 |
| CF-030 | LED Tests | `IT/CUST_FACING/CF-030/#CF-030.robot` | 1 | 未开始 |
| CF-031 | LED Tests | `IT/CUST_FACING/CF-031/#CF-031.robot` | 1 | 未开始 |
| CF-032 | LED Tests | `IT/CUST_FACING/CF-032/#CF-032.robot` | 1 | 未开始 |
| CF-033 | LED Tests | `IT/CUST_FACING/CF-033/#CF-033.robot` | 1 | 未开始 |
| CF-034 | GNMI Tests | `IT/CUST_FACING/CF-034/#CF-034.robot` | 1 | 未开始 |
| CF-035 | GNMI Tests | `IT/CUST_FACING/CF-035/#CF-035.robot` | 1 | 未开始 |
| CF-036 | GNMI Tests | `IT/CUST_FACING/CF-036/#CF-036.robot` | 2 | 未开始 |
| CF-037 | GNMI Tests | `IT/CUST_FACING/CF-037/#CF-037.robot` | 2 | 未开始 |
| CF-038 | GNMI Tests | `IT/CUST_FACING/CF-038/#CF-038.robot` | 1 | 未开始 |
| CF-039 | GNMI Tests | `IT/CUST_FACING/CF-039/#CF-039.robot` | 1 | 未开始 |
| CF-040 | GNMI Tests | `IT/CUST_FACING/CF-040/#CF-040.robot` | 1 | 未开始 |
| CF-041 | GNMI Tests | `IT/CUST_FACING/CF-041/#CF-041.robot` | 1 | 未开始 |
| CF-042 | GNMI Tests | `IT/CUST_FACING/CF-042/#CF-042.robot` | 3 | 未开始 |
| CF-043 | GNMI Tests | `IT/CUST_FACING/CF-043/#CF-043.robot` | 2 | 未开始 |
| CF-044 | GNMI Tests | `IT/CUST_FACING/CF-044/#CF-044.robot` | 1 | 未开始 |
| CF-045 | GNMI Tests | `IT/CUST_FACING/CF-045/#CF-045.robot` | 1 | 未开始 |
| CF-046 | GNMI Tests | `IT/CUST_FACING/CF-046/#CF-046.robot` | 1 | 未开始 |
| CF-047 | GNMI Tests | `IT/CUST_FACING/CF-047/#CF-047.robot` | 1 | 未开始 |
| CF-048 | GNMI Tests | `IT/CUST_FACING/CF-048/#CF-048.robot` | 1 | 未开始 |
| CF-049 | GNMI Tests | `IT/CUST_FACING/CF-049/#CF-049.robot` | 1 | 未开始 |
| CF-050 | GNMI Tests | `IT/CUST_FACING/CF-050/#CF-050.robot` | 1 | 未开始 |
| CF-051 | GNMI Tests | `IT/CUST_FACING/CF-051/#CF-051.robot` | 2 | 未开始 |
| CF-052 | GNMI Tests | `IT/CUST_FACING/CF-052/#CF-052.robot` | 1 | 未开始 |
| CF-053 | GNMI Tests | `IT/CUST_FACING/CF-053/#CF-053.robot` | 2 | 未开始 |
| CF-054 | GRPC Tests | `IT/CUST_FACING/CF-054/#CF-054.robot` | 4 | 未开始 |
| CF-055 | GRPC Tests | `IT/CUST_FACING/CF-055/#CF-055.robot` | 2 | 未开始 |
| CF-056 | DS Tracker (Ch13) | `IT/CUST_FACING/CF-056/#CF-056.robot` | 3 | 未开始 |
| CF-057 | SSH (Ch14) | `IT/CUST_FACING/CF-057/#CF-057.robot` | 1 | 未开始 |
| CF-058 | SSH (Ch14) | `IT/CUST_FACING/CF-058/#CF-058.robot` | 1 | 未开始 |
| CF-059 | SSH (Ch14) | `IT/CUST_FACING/CF-059/#CF-059.robot` | 2 | 未开始 |
| CF-060 | SSH (Ch14) | `IT/CUST_FACING/CF-060/#CF-060.robot` | 1 | 未开始 |
| CF-061 | MSC (sc_msc_cli) | `IT/CUST_FACING/CF-061/#CF-061.robot` | 3 | 未开始 |


## 逐项记录

### PAB-001 — PAB | Sercomm CLI

**目的与内容**

验证 PAB（Pre-Alignment Balance，LE 放大器上电后的预均衡流程）的配置写入与读取
是否一致，以及 FreeRun 流程跑完后状态机是否停在期望的终态。
模板期望三条：① `set_pab_config` 被接受，`get_pab_config` 读回新值；
② `get_pab_status` 读出 `Enabled=Yes / Completed=Yes / eCM online=Yes /
Running Mode=FREERUN / Running Status=DONE / Current Stage=IDLE`；
③ 从 linux shell 读 eCM 状态为 `Operational`。
参考 User Guide 6.1 / 6.2。

**测试步骤**（脚本里的三条用例）

1. **PAB-001-1 预设 PAB 配置**
   - `sc_cli get_pab_config` 先读一次（留底）
   - `sc_cli set_pab_config 2 2.74 36.00 60 60 -21.78 6.00`
     （User Guide 6.1 推荐的 rx_adc_lna_mode=2 即 FREE_RUNNING、target TCP=36.00 dBmV）
   - 断言输出含 `Success`
   - 再 `sc_cli get_pab_config`，逐字段比对 7 个值
2. **PAB-001-2 触发 FreeRun 并检查状态**
   - `sc_cli pab_control stop` → `sc_cli pab_control free_run`
   - 轮询 `sc_cli get_pab_status`，直到 `Running Mode=FREERUN`、`Completed=Yes`、
     `Current Stage=IDLE` 三个字段同时成立（超时 300 s，间隔 10 s）
   - 再断言 `Enabled=Yes / Completed=Yes / eCM online=Yes / Running Mode=FREERUN /
     Running Status=DONE / Current Stage=IDLE`
3. **PAB-001-3 确认 eCM 在线**
   - 轮询 `sc_amphal_cli get_ecm_status` 直到输出含 `eCM status = Operational`
     （超时 180 s，间隔 10 s）

**脚本怎么写的**

- 文件：`IT/PAB/PAB-001/#PAB-001.robot`（这个 suite 是手写的，是全套 IT 的样板；
  其余条目由 `IT/_generator/sheet_*.py` 生成）
- 通道：`sc_cli` / `sc_amphal_cli` 走 **ROOT** SSH 会话（eAMP 的 linux shell，root），
  而不是模板里的 clish `debug` 视图——同一个二进制，但 root shell 不用每条命令先进
  出 `debug`，命令也更短
- 断言全部用公共关键字，失败时打印整段命令输出：
  - `IT COMMON - Run Dut Command And Return` — 发命令、剥掉回显与提示符、返回正文
  - `IT COMMON - Cli Field Should Equal` — 按标签取值并比对（不匹配时打印全文）
  - `IT COMMON - Wait For Dut Cli Fields` — 轮询直到多个标签同时到达期望值
  - `IT COMMON - Wait For Dut Command Contains` — 轮询直到输出包含某段文字
- 轮询而不是单次读：PAB 一轮约 40 s，且刚触发 free_run 时 `Running Status` 还是
  `DONE` 而阶段已是 `STAGE1`，所以等的是整个终态（模式/完成/阶段），不是状态字段本身
- 与模板的一处差异：eCM 状态用轮询而不是读一次。eCM 上电后会经历 range start，
  上一次全量跑时它就卡在 `RangeStart` 上导致这条失败

**User Guide 对照**（`3_camp/okf-bundle` = SERCOMM LE User Guide V24.1，
第 6 章 Pre-Alignment Procedure）

- 6.1 给出的推荐配置与脚本用的参数完全一致：
  `sc_cli set_pab_config 2 2.74 36.00 60 60 -21.78 6.00`，
  并说明 `rx_adc_lna_mode` 设成 Free Run 是推荐做法（2 = FREE_RUNNING）✓
- 6.1 的参数表只列了 5 个参数（mode / gain / target_tcp / online_interval /
  retry_interval），没有写 `RPD power threshold`(-21.78) 和
  `outlier threshold`(6.00)，但命令里带了这两个值、DUT 也读得出来、
  模板的期望输出里也有 → 脚本按 7 个字段断言 ✓
- 6.2 说明 PAB 默认就是 FreeRun，eCM 上线前会一直跑（PAB-016 的依据）✓
- User Guide 里**没有** `sc_cli pab_control` 和 `sc_cli pab_enable` 这两个命令，
  它们来自模板的 PAB-001 步骤和实测
- 一处实测修正：脚本原先多插了一步 `sc_cli pab_enable enable`，
  当时判断是「stop 之后 PAB 是 disabled，free_run 起不来」。
  实测证明这是错的——DUT 上 `pab_control stop` 之后状态仍是 `Enabled : Yes`，
  紧接着 `pab_control free_run` 就能起新的一轮。
  该步骤已从脚本里删掉，脚本现在与模板的 stop → free_run 完全一致。
  验证方法：从静止状态（`DONE/IDLE`）做 stop → free_run，10 s 一次轮询，
  一轮正常走完 `STAGE1 → STAGE2 → STAGE5 → STAGE6 → STAGE7 → DONE/IDLE`（约 60 s）；
  从半路打断（`STAGE2` 时 stop）再做 free_run，同样一轮走完，不受影响


**实测结果**

两次实跑，都在 `172.21.48.230` 上：

```
10:02 第一次（脚本里还有 pab_enable enable 那一步）
  PAB-001-1  Preset the PAB configuration .............. PASS
  PAB-001-2  Trigger PAB FreeRun and check the status ... PASS
  PAB-001-3  Verify the eCM is operational ............. PASS
  3 tests, 3 passed, 0 failed        （整个 suite 用时 57 s）

10:12 第二次（删掉 pab_enable enable 之后）
  PAB-001-1  Preset the PAB configuration .............. PASS
  PAB-001-2  Trigger PAB FreeRun and check the status ... PASS
  PAB-001-3  Verify the eCM is operational ............. FAIL
  3 tests, 2 passed, 1 failed
  失败原因：Command "sc_amphal_cli get_ecm_status" did not contain
            "eCM status = Operational" within 180s

10:33 第三次（当前脚本，eCM 恢复 Operational 之后）
  PAB-001-1  Preset the PAB configuration .............. PASS
  PAB-001-2  Trigger PAB FreeRun and check the status ... PASS
  PAB-001-3  Verify the eCM is operational ............. PASS
  3 tests, 3 passed, 0 failed
```

- PAB-001-1：`set_pab_config` 回 `Success: PAB configuration updated.`，
  读回 `rx adc lna mode : 2 (FREE_RUNNING)`、`rx adc lna gain : 2.74 dBmV`、
  `target tcp : 36.00 dBmV`、`online/retry interval : 60 sec`、
  `RPD power threshold : -21.78 dBmV`、`outlier threshold : 6.00`，7 个字段全中
- PAB-001-2：轮询序列证实等的是**新的一轮**，不是上一轮留下的旧状态——
  `free_run` 后先读到 `Completed=No, Loop count=0, Current Stage=STAGE1`
  （不满足条件，继续等），再 `Loop count=1, CONTINUE_DELAY, STAGE2 → STAGE5 →
  STAGE6 → STAGE7`，终态 `Completed=Yes, Running Mode=FREERUN,
  Running Status=DONE, Current Stage=IDLE, eCM online=Yes`
- PAB-001-3：第一次跑一次就读到 `eCM status = Operational`；
  第二次跑 180 s 里始终不是 Operational，事后查是 **DUT 的 eCM 掉回了 `RangeStart`**：
  10:02 是 Operational，10:12 已经变成 RangeStart，10:21:27~10:24:54 每 10 s 查了
  18 次都是 `RangeStart`，**10:28:21 又自己变回 Operational**。
  所以 eCM 不是卡死，是**在 RangeStart 和 Operational 之间来回切**，
  这一段至少 RangeStart 了 13 分钟。
  同时 PAB 自己的状态里 `eCM online : Yes` 一直是 Yes ——
  **PAB 的「eCM online」不等于 eCM 已经 ranging 完**，
  所以这两条期望不能互相代替，这是脚本要分开断言的原因
- 排除掉的猜测：**PAB 一轮不会把 eCM 打进 RangeStart**。
  两次对照：10:29:36 起每 6 s 采一次 eCM 状态、同时跑完整一轮 PAB
  （`STAGE1→STAGE2→STAGE4→STAGE5→STAGE6→STAGE7→IDLE`，到 10:31:43）；
  以及 10:34:48~10:38:43 每 5 s 采一次、跨过第三次跑的那一轮 PAB
  （这一轮结束在 10:35:16，之后又采了 3 分半钟）。两次 eCM 全程都是 Operational。
  所以 PAB-001-2 与 eCM 状态是两件独立的事
- **eCM 状态是怎么来的**（DUT 的 journal 里能看到状态机）：
  ```
  amphal:     received kRpcEventCmOperStateRangeStart event
  ampRfiMgr:  eCM status updated:0
  ampLedMgr:  state: Cm_RangeStart / description: Start Ranging
  sc_msc:     eCM operational pending - waiting 60 seconds for stability
  ampRfiMgr:  eCM status updated:1
  ampLedMgr:  received ECM_OPERATIONAL
  sc_msc:     eCM is stable operational (after 60 seconds)
  ```
  `sc_amphal_cli get_ecm_status` 报的就是 `eCM status updated:0/1` 这个值，
  所以它是 AMP 对 eCM 的上报，不是脚本自己推的。
  额外的坑：**AMP 立刻报 Operational，但 MSC 还要再等 60 s 才认它稳定**
  （`waiting 60 seconds for stability` → `stable operational (after 60 seconds)`），
  要「eCM 稳定可用」得按 MSC 那条算，不是按 amphal 那条
  PAB 的 stage 7 也是自己轮询 eCM：
  `Waiting 10000 ms to check eCM status...` → `eCM is operational during poll window`
  → `eCM is operational. Stopping PAB.`
- 没能独立佐证的部分：这台机器到 CM 的 `192.168.100.1:23` 不通，
  DUT 上也没有到 `192.168.100.0/24` 的路由（只有 `172.21.48.0/24` 和
  `172.31.255.0/24`），所以 eCM 状态只有 AMP 自己报的这一个来源，
  是什么让 eCM 重新 ranging 的还没查清（看起来是 eCM 自己发起的，AMP 只是收到事件）

**本次复核发现的偏差**

- 模板记录的日志里，刚 `free_run` 之后是 `Running Status: IDLE`，
  实机是 `Running Status: DONE`（阶段同样在 `STAGE1`）。
  终态一致，只是中间态的 `Running Status` 字段值不同。
  脚本等的是「模式/完成/阶段」这一组终态字段，所以不受影响。
- 脚本原先多插的 `sc_cli pab_enable enable` 是多余的，已删（见上面的 User Guide 对照）
- PAB-001-3 **取决于测试台状态**：eCM 在 RangeStart 时它必失败，
  eCM 是 Operational 时它必过。**决定：维持现状，如实失败**
  （时间线：10:02 ~ 11:00 之间是 Operational，11:19 又变回 RangeStart，
  这段时间内跑的 PAB-001-3 就失败。失败信息里现在直接带着实机的答案：
  `... within 180s. The last answer was:\n\neCM status = RangeStart`）
  不改超时、不判 SKIP——eCM 不在线是台子的事，报告里如实写出来。
  等待时间：`timeout=180`、每 `interval=10` 采一次，即最多 180 s、约 18 次采样。
  180 s 明显不够覆盖实测的 eCM RangeStart 时长（至少 13 分钟），
  但既然决定如实失败，就不动它
- 为了让「如实失败」真的可读，把公共关键字
  `IT COMMON - Wait For Dut Command Contains` 的失败信息改成带上最后一次的输出：
  ```
  Command "sc_amphal_cli get_ecm_status" did not contain "eCM status = Operational"
  within 180s. The last answer was:
  eCM status = RangeStart
  ```
  （关键字被 7 个 suite 用着，PAB-001-3 / ALN-002 / ALN-003 / ALN-004 / ALN-007 /
  ASC-035 / ASC-037 都受益。失败与通过的判定条件没有变）
- 顺带记一条：AMP 报 Operational 的那一刻，MSC 还要再等 60 s 才认它「稳定」。
  后面凡是等 eCM「可用了」的用例，要按 MSC 那 60 s 算余量


### PAB-010 — PAB | GRPC Configuration, Status & Control

**目的与内容**

用 gRPC（grpcurl）读 PAB 的配置，确认回答里有 `pabConfig` 这个对象，
而且它带着那 6 个字段：rxAdcLnaGain、pabTargetTcp、checkEcmOnlineInterval、
pabRetryInterval、rpdPwrdThreshold、outlierThreshold。
再拿 CLI 的 `sc_cli get_pab_config` 交叉核对一遍，确认**两个通道说的是同一件事**。
参考 User Guide 12.1.4.1。

**测试步骤**（脚本里的两条用例）

1. **PAB-010-1 gRPC 读配置**
   - `grpcurl -plaintext -import-path /etc/amp/proto/ -proto pab_config.proto
     -d '{}' 127.0.0.1:9338 gnoi.pab_config.v1.PabConfig/GetPabConfiguration`
   - 断言 `success.status = SUCCESS`
   - 断言 `pabConfig` 里 6 个字段的值
2. **PAB-010-2 和 CLI 交叉核对**
   - 再调一次 gRPC，再读一次 `sc_cli get_pab_config`
   - 逐个字段比对两个答案（数值比较）

**脚本怎么写的**

- 文件：`IT/PAB/PAB-010/#PAB-010.robot`（生成，`IT/_generator/sheet_pab.py`）
- 通道：grpcurl 跑在 **DUT 上**、打 DUT 自己的回环 gRPC 口 `127.0.0.1:9338`
  （`IT COMMON - Grpcurl And Return Json`）。因为 gRPC 服务不支持 server
  reflection，命令里必须带 `-import-path /etc/amp/proto/ -proto pab_config.proto`
- 走 **ROOT 会话**而不是 exec 通道：grpcurl 的 payload 是带双引号的 JSON，
  clish 会把命令包进 `sh -c "..."`，引号会被截断（见 `IT_CONVENTIONS.md`）
- 断言用公共关键字：`Grpc Should Succeed`（查 success.status）、
  `Grpc Get Field`（取一层字段）、`Grpc Number Should Equal`
  （**按数值**比，因为 gRPC 里 "36" 和 "36.0" 是同一个值但不是同一个字符串）
- 嵌套字段用 `${{['pabConfig', 'rxAdcLnaGain']}}` 这种写法传给关键字

**User Guide 对照**（第 12 章 gRPC，12.1.4.1）

- 章节号对得上：12.1.4.1 = GetPabConfiguration、12.1.4.2 = SetPabConfiguration、
  12.1.4.3 = GetPabStatus、12.1.4.4 = SetPabCommand（START / STOP / RESTART）
- 指南给的是命令，**「Expected Response」那一段在 PDF→markdown 的抽取里是空的**，
  所以回答的字段和值是以模板的参考日志为准的
- 指南的 SetPabConfiguration 例子里 `rpdPwrdThreshold` 是 **-27.78**，
  而模板的参考日志里 DUT 上是 **-21.78**（PAB-001 预设的值）——见下面的偏差

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-010-1  GET the PAB configuration over gRPC ............. PASS
PAB-010-2  Cross check the gRPC configuration with the CLI ... PASS
2 tests, 2 passed, 0 failed
```

实机回答（两个通道逐字段一致）：

```
grpcurl GetPabConfiguration                    sc_cli get_pab_config
  rxAdcLnaGain          : 2.74                    rx adc lna gain      : 2.74 dBmV
  pabTargetTcp          : 36                      target tcp           : 36.00 dBmV
  checkEcmOnlineInterval: 60                      online interval      : 60 sec
  pabRetryInterval      : 60                      retry interval       : 60 sec
  rpdPwrdThreshold      : -21.78                  RPD power threshold  : -21.78 dBmV
  outlierThreshold      : 6                       outlier threshold    : 6.00
```

和模板 PAB-010 的参考日志逐值一致。

**本次复核发现的偏差 / 要注意的地方**

- **CLI 有 7 个字段，gRPC 只有 6 个**：多出来的是 `rx adc lna mode`
  （2 = FREE_RUNNING），gRPC 的 `pabConfig` 里没有这个字段。
  所以交叉核对覆盖的是 6 个字段，lna mode 只有 CLI 那一侧能看（PAB-001 查过）
- **PAB-010-1 断言的是绝对值（rpdPwrdThreshold = -21.78），这是 PAB-001 预设的值**，
  出厂默认是 -27.78（User Guide 的 SetPabConfiguration 例子、
  模板 PAB-012/PAB-016 的日志都是 -27.78）。
  也就是说这条用例**依赖 PAB-001 先跑过**。
  按模板的编号顺序跑是成立的，而且 PAB-012 跑完会把原值恢复回去
  （PAB-012-3），所以整个 campaign 里这个依赖是稳的。
  模板对 PAB-010 的期望输出只要求「回答里有这 6 个字段」，
  绝对值是我们加严的——这一点记在这里，免得以后单独重跑 PAB-010 时看不懂


### PAB-011 — PAB | GRPC Configuration, Status & Control

**目的与内容**

用 gRPC（grpcurl）读 PAB 的状态，确认回答里有 `pabStatus` 这个对象，
而且它带着那 7 个字段：enabled、isCompleted、loopCount、ecmOnline、
runningMode、currentStage、runningStatus。
再拿 CLI 的 `sc_cli get_pab_status` 交叉核对，确认**两个通道说的是同一个状态**。
参考 User Guide 12.1.4.3。

**测试步骤**（脚本里的两条用例）

1. **PAB-011-1 gRPC 读状态**
   - 等到 PAB 跑完一轮（`pabStatus.isCompleted = true`），这是模板参考日志
     里的那个状态
   - 断言 `success.status = SUCCESS`
   - 断言 `pabStatus` 里那 7 个字段都在
2. **PAB-011-2 和 CLI 交叉核对**
   - 再调一次 gRPC，再读一次 `sc_cli get_pab_status`
   - 比对模式、阶段、运行状态三个枚举

**脚本怎么写的**

- 文件：`IT/PAB/PAB-011/#PAB-011.robot`（生成，`IT/_generator/sheet_pab.py`）
- 通道和 PAB-010 一样：grpcurl 跑在 DUT 上，打回环口 `127.0.0.1:9338`，走 ROOT 会话
- 等状态用新加的公共关键字
  `IT COMMON - Wait For Grpc Nested Field Value`（轮询一个 gRPC 调用，
  直到回答里某个嵌套字段到达期望值，失败信息里带最后一次的回答）
- 两个通道的枚举比对用新加的
  `IT COMMON - Grpc Enum Should Match Cli`（见下面的偏差 1）

**User Guide 对照**（12.1.4.3）

- 章节号对得上；指南这一节同样只有命令，**「Expected Response」在抽取里是空的**，
  字段和值以模板的参考日志为准
- 模板参考日志：`enabled: true, isCompleted: true, loopCount: 1, ecmOnline: true,
  runningMode: "ALIGN_PAB_MODE_FREERUN", currentStage: "ALIGN_PAB_STAGE_IDLE",
  runningStatus: "ALIGN_PAB_STATUS_DONE"` —— 实机在 PAB 跑完一轮后**逐字段一致**

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-011-1  GET the PAB status over gRPC ............... PASS
PAB-011-2  Cross check the gRPC status with the CLI .... PASS
2 tests, 2 passed, 0 failed
```

**本次复核发现两个问题，都修了**

1. **枚举比对在 PAB 跑起来的时候是错的（真 bug）**
   gRPC 给的是枚举全名，CLI 给的是短名，中间差一个下划线：
   ```
   gRPC: ALIGN_PAB_STAGE_2      CLI: STAGE2
   ```
   原来的写法是 `Should End With`，`"ALIGN_PAB_STAGE_2".endswith("STAGE2")` 是 **False**
   ——所以**交叉核对只在 PAB 空闲时才对**，PAB 一跑到一半就误报不匹配。
   模式（`ALIGN_PAB_MODE_FREERUN` vs `FREERUN`）和运行状态
   （`ALIGN_PAB_STATUS_CONTINUE_DELAY` vs `CONTINUE_DELAY`）不受影响，只有带数字的阶段中招。
   修法：新的 `IT COMMON - Grpc Enum Should Match Cli` 把两边都去掉下划线再比
2. **gRPC 的回答在 PAB 没跑完时没有 `isCompleted` 这个字段（DUT 行为）**
   protobuf 不把「值为 false 的布尔」写进回答，所以 PAB 正在跑的时候
   `isCompleted` 整个字段都不在：
   ```
   mid-round: {'enabled': True, 'loopCount': 1, 'ecmOnline': True,
               'runningMode': 'ALIGN_PAB_MODE_FREERUN',
               'currentStage': 'ALIGN_PAB_STAGE_2',
               'runningStatus': 'ALIGN_PAB_STATUS_CONTINUE_DELAY'}   ← 没有 isCompleted
   ```
   原来的脚本断言这个字段**存在**，于是 PAB 一跑到一半就失败。
   修法：先等 PAB 跑完一轮（`isCompleted = true`，也就是模板参考日志里的那个状态），
   再检查那 7 个字段

   **两个问题都是在「PAB 正在跑」的时候才暴露的**，
   所以修完之后特意做了一次验证：先 `sc_cli pab_control free_run` 触发一轮，
   紧接着跑 PAB-011（此刻 DUT 报 `Completed: No, Current Stage: STAGE1`）：
   ```
   PAB-011-1 ... PASS      （轮询 8 次，看着 PAB 走 STAGE2→STAGE5→STAGE6→STAGE7，
                             11:43:05 isCompleted 变 true，才检查那 7 个字段）
   PAB-011-2 ... PASS      （两边都是 IDLE / DONE）
   2 tests, 2 passed, 0 failed
   ```
   修之前同样情况下是 PAB-011-1 FAIL（`Field "isCompleted" not found`），
   PAB-011-2 也会因为阶段名不匹配而失败


### PAB-012 — PAB | GRPC Configuration, Status & Control

**目的与内容**

用 gRPC（grpcurl）**写** PAB 的配置，确认 SET 成功，再用 GET 把值读回来确认真的写进去了，
再拿 CLI 的 `sc_cli get_pab_config` 交叉核对。
模板期望：① grpcurl 命令跑成功；② SET / GET / `sc_cli get_pab_config`
三处的值一致。参考 User Guide 12.1.4.2。

**测试步骤**（两条用例，和模板一样是两步）

1. **PAB-012-1 SET**
   - 先 GET 一次，把**当前**的配置存下来（teardown 要用它恢复）
   - SET 新配置 `{"pabConfig": {"rxAdcLnaGain": 2.74, "pabTargetTcp": 36.0,
     "checkEcmOnlineInterval": 60, "pabRetryInterval": 60,
     "rpdPwrdThreshold": -27.78, "outlierThreshold": 6.0}}`
   - 断言 `success.status = SUCCESS`
2. **PAB-012-2 GET 回来核对**
   - GET 一次，6 个字段逐个比对（数值比较）
   - 再用 `sc_cli get_pab_config` 交叉核对 4 个字段
3. **（不是用例）Suite Teardown 把原值放回去**
   - teardown 里 SET 回存下来的原配置，再 GET 一次确认 `rpdPwrdThreshold` 回来了

**脚本怎么写的**

- 文件：`IT/PAB/PAB-012/#PAB-012.robot`（生成，`IT/_generator/sheet_pab.py`）
- 通道同 PAB-010：grpcurl 在 DUT 上、打回环口 `127.0.0.1:9338`，走 ROOT 会话
  （payload 是带双引号的 JSON，走 exec 通道会被 clish 的 `sh -c "..."` 截断）
- 当前配置放在 **suite 作用域**的 `${original}`（`VAR ... scope=SUITE`），
  恢复用的 payload 在 PAB-012-1 里算好存进 `${restore_payload}`（也是 suite 作用域），
  teardown 拿得到
- 恢复用新的公共关键字 `IT COMMON - Restore Grpc Configuration`：
  SET 回 payload → GET 回来 → 和 payload 里的值比。
  payload 是空的就跳过（没 SET 过没什么可恢复的）
- **生成器现在支持每个 suite 自己的 teardown**：`S(...)` 多了一个 `teardown=` 参数，
  写进去的正文会被放进那个 suite 的 `Suite Teardown` 关键字里
  （`IT/_generator/writer.py`）。目前只有 PAB-012 用

**User Guide 对照**（12.1.4.2）

- **脚本用的 payload 和指南的例子一字不差**：
  `rxAdcLnaGain 2.74, pabTargetTcp 36.0, checkEcmOnlineInterval 60,
  pabRetryInterval 60, rpdPwrdThreshold -27.78, outlierThreshold 6.0`
- 也和模板 PAB-012 的参考日志一致
- 指南这一节的「Expected Response」在抽取里同样是空的

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-012-1  SET the PAB configuration over gRPC ...................... PASS
PAB-012-2  GET the configuration back and check the new values ....... PASS
2 tests, 2 passed, 0 failed
```

实机：

```
SET 前 GET 出来：  rpdPwrdThreshold: -21.78
SET 的回答：       success.status = SUCCESS
                   message = "SetPabConfiguration completed successfully"
GET 回来：        rxAdcLnaGain 2.74, pabTargetTcp 36, checkEcmOnlineInterval 60,
                   pabRetryInterval 60, rpdPwrdThreshold -27.78, outlierThreshold 6
teardown 恢复：    SET 回 {"pabConfig": {..., "rpdPwrdThreshold": -21.78, ...}}
                   跑完之后 sc_cli get_pab_config → -21.78 ✓
```

**把恢复搬进 teardown 之后，验证过它真的更稳**：
把 PAB-012-2 的期望值故意改错，让它失败：

```
PAB-012-1 ... PASS
PAB-012-2 ... FAIL   （故意改错的）
跑完之后 DUT 上的配置：-21.78   ← teardown 照样恢复了
```

teardown 在 RF 里**用例失败也会跑**，只有进程被 kill 才不会
（那是任何做法都救不了的）。

**本次复核发现的偏差**

- **DUT 不会自己把配置恢复回去**：手工 SET 成 -27.78 之后，
  空转 3.5 分钟、再跑完整一轮 PAB，配置一直是 -27.78。
  也就是说 gRPC SET 出来的值会一直留着，
  **teardown 里那句恢复是唯一把它放回原值的东西**
- **恢复的是「跑这条用例之前的值」**，不是某个写死的值。
  所以整个 campaign 的基线是「上一次 PAB-001 设的那个值」；
  如果中途有人手工改了配置，teardown 会把它原样保留下来
  （这是恢复该有的行为，但要知道基线是可以被改的）

### PAB-013 — PAB | GRPC Configuration, Status & Control（Trigger PAB Control : START）

**目的与内容**

用 gRPC 触发 PAB 的 FreeRun 流程（`SetPabCommand` + `currentCommand: START`），
确认命令被接受，并且 **PAB 真的起了一轮新的均衡**。
模板期望：① `SetPabCommand` 回 `success.status = SUCCESS`；
② 命令前状态是 `Running Status: DONE / Current Stage: IDLE`，
命令后变成 `Running Status: CONTINUE_DELAY / Current Stage: STAGE1`。
参考 User Guide 12.1.4.4（Start）。

**测试步骤**（脚本里的三条用例）

1. **PAB-013-1 发 START**
   - **先发 STOP 把 PAB 强制停掉**，等模式真的变成 `STOP`
     （DUT 在下一个阶段边界才应用 STOP，所以要等）
   - 再发 `SetPabCommand` + `{"pabCommand": {"currentCommand": "START"}}`
   - 断言 `success.status = SUCCESS`
2. **PAB-013-2 检查命令之后的状态**
   - 等到阶段离开 IDLE（说明一轮真的开始了）
   - gRPC：`runningMode` = `ALIGN_PAB_MODE_FREERUN`、`currentStage` 不是 `ALIGN_PAB_STAGE_IDLE`
   - CLI：`Running Mode` = `FREERUN`、`Current Stage` 不是 `IDLE`、`Completed` = `No`
3. **PAB-013-3 等这一轮结束**
   - 等 `Running Status = CONTINUE_DELAY`（模板期望的「命令之后」状态）
   - 再等 `Running Mode=FREERUN / Completed=Yes / Current Stage=IDLE`
   - 断言 `Running Status = DONE`

**脚本怎么写的**

- 文件：`IT/PAB/PAB-013/#PAB-013.robot`（生成，`IT/_generator/sheet_pab.py`；
  PAB-013/014/015 是同一段生成器套出来的，命令分别是 START / STOP / RESTART）
- 通道同 PAB-010：grpcurl 在 DUT 上、打回环口 `127.0.0.1:9338`，走 ROOT 会话
- 新的公共关键字 `IT COMMON - Wait For Dut Cli Field Different`
  （轮询到某个字段**不再是**某个值——「阶段不再是 IDLE」这种「状态发生了」的场景）
- 等状态、断言都用公共关键字：`Wait For Dut Cli Field`、`Wait For Dut Cli Fields`、
  `Get Cli Field`、`Grpc Get Field`、`Grpc Should Succeed`

**User Guide 对照**（12.1.4.4 Start）

- 指南的 payload 和脚本一致：`{"pabCommand": {"currentCommand": "START"}}` ✓
- 章节号对得上（12.1.4.4 下面还有 Stop 和 Restart，正是 PAB-014 / PAB-015）

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-013-1  Send the START command over gRPC ..................... PASS
PAB-013-2  Check the PAB status after the START command ........ PASS
PAB-013-3  Wait for the PAB round to be over .................... PASS
3 tests, 3 passed, 0 failed
```

实机（START 之后 0.3 s 读到的那一份，正好是模板要的那一份）：

```
gRPC:  runningMode: ALIGN_PAB_MODE_FREERUN, currentStage: ALIGN_PAB_STAGE_1
CLI:   Completed : No | Running Mode : FREERUN | Current Stage : STAGE1
下一拍: Running Status : DONE（阶段 1 的时候）→ 之后 CONTINUE_DELAY
```

**最后定下来的顺序：先 STOP 再 START**

原来的写法是「等 PAB 自然静止（`Completed=Yes / DONE / IDLE`，最多 120 s）再发 START」。
改成**先发 STOP 强制停掉，等模式变成 STOP，再发 START**，理由有两条（都是实测出来的）：

1. **START 落在正在跑的一轮上不会重启那一轮**：
   ```
   一轮跑到 STAGE3 时发 START → 命令回 SUCCESS
   → Loop count 还是 1，阶段从 STAGE3 接着走到 STAGE6，那一轮并没有重来
   ```
   所以「等自然静止」这个前提是必要的，而 STOP 能**主动**把状态摆平，
   不依赖「上一轮会自己跑完」（PAB 在 eCM 没上线时会一轮一轮重试，等不到就超时）
2. **STOP 不是立刻生效的**：它在**下一个阶段边界**才应用
   （一轮跑到一半时发 STOP，状态里的 `Running Mode` 还会是 FREERUN 好几秒）。
   所以 STOP 和 START 之间必须等模式真的变成 `STOP`，
   否则 START 还是落在旧的那一轮上

顺带确认了一件事：**STOP 把模式置成 STOP 之后，START 会把它切回 FREERUN 并起新一轮**
（实测：`STOP → Running Mode: STOP / IDLE / Completed: Yes`，
`START → Running Mode: FREERUN / Completed: No / STAGE2`）。
所以 PAB-013-2 里「模式 = FREERUN」这条断言现在是有意义的
（不再是「本来就是 FREERUN」这种查不出变化的断言）。

**本次复核发现的问题（脚本改了）**

1. **原来的 PAB-013-2 证明不了任何事**。它只查了 `Running Mode`，
   而 PAB 本来就在 FREERUN 模式（出厂默认，User Guide 6.2），
   **命令前后这个值都一样**。所以原来那条用例，
   START 命令有没有真的起作用它都过。
   现在改成查「一轮真的开始了」：阶段离开 IDLE、`Completed=No`，
   两个通道都查
2. **命令之前必须等 PAB 静止**。DUT 在 eCM 没上线时会自己一轮一轮地重跑
   （retry_interval = 60 s），命令发出去的时候 PAB 很可能正在跑。
   实测：**在一轮跑到一半的时候发 START，命令回 SUCCESS，
   但那一轮并不会重来**（Loop count 还是 1，阶段从 STAGE3 接着走到 STAGE6）。
   所以要证明「START 起了一轮新的」，前提是发命令时 PAB 是静止的
3. **模板期望的「命令之后 = CONTINUE_DELAY + STAGE1」，这台 DUT 给不出来**。
   实测（2 s 一采）：
   ```
   轮次刚开始   Completed: No | Running Status: DONE      | Current Stage: STAGE1
   2 s 之后     Completed: No | Running Status: CONTINUE_DELAY | Current Stage: STAGE2
   ...
   轮次结束     Completed: Yes| Running Status: DONE      | Current Stage: IDLE
   ```
   也就是：**阶段 1 的 running status 还是 DONE**，CONTINUE_DELAY 是从阶段 2 才有的；
   而且 STAGE1 只存在约 2 s，钉不住它。
   脚本改成：查「阶段不是 IDLE」（轮次在跑）+ 另外等到 CONTINUE_DELAY 出现过
   （模板那个状态），这样两个都覆盖到，又不会 flaky
4. 中间还踩了两个自己的坑：
   - `Wait For Dut Cli Field` 返回的是**整段输出**不是字段值，
     我一开始直接拿它跟 "CONTINUE_DELAY" 比 → 失败
   - 「等 PAB 静止」的条件一开始带了 `Running Mode=FREERUN`，
     结果 PAB-015（RESTART）跟着 PAB-014（STOP）跑，
     PAB 停在 STOP 模式，那个条件永远不成立 → 300 s 超时。
     改成只看 `Completed=Yes / Running Status=DONE / Current Stage=IDLE`


### PAB-014 — PAB | GRPC Configuration, Status & Control（Trigger PAB Control : STOP）

**目的与内容**

用 gRPC 停掉**正在跑**的 PAB 均衡流程（`SetPabCommand` + `currentCommand: STOP`），
确认命令被接受、**那一轮被打断**、流程走到静止。
参考 User Guide 12.1.4.4（Stop）。

**测试步骤**（脚本里的三条用例）

1. **PAB-014-1 先起一轮，再发 STOP**
   - `SetPabCommand` + `{"pabCommand": {"currentCommand": "START"}}` 先起一轮
   - 等到阶段离开 IDLE（确认它**真的在跑**）
   - `SetPabCommand` + `{"pabCommand": {"currentCommand": "STOP"}}`
   - 断言 `success.status = SUCCESS`
2. **PAB-014-2 检查命令之后的状态**
   - 等模式变成 `STOP`（DUT 在下一个阶段边界才应用 STOP，所以要等）
   - CLI：`Running Mode` = `STOP`、`Current Stage` = `IDLE`
   - gRPC：`runningMode` = `ALIGN_PAB_MODE_STOP`、`currentStage` = `ALIGN_PAB_STAGE_IDLE`
3. **PAB-014-3 检查那一轮确实被打断**
   - `Current Stage` = `IDLE`、`Running Status` = `DONE`、
     **`Completed` = `No`**（被 STOP 打断的那一轮不算完成）

**脚本怎么写的**

- 文件：`IT/PAB/PAB-014/#PAB-014.robot`（生成，`IT/_generator/sheet_pab.py`；
  和 PAB-013/015 共用一段模板，按命令分三种分支）
- 通道同 PAB-013：grpcurl 在 DUT 上、打回环口 `127.0.0.1:9338`，走 ROOT 会话

**User Guide 对照**（12.1.4.4 Stop）

- 指南的 payload 和脚本一致：`{"pabCommand": {"currentCommand": "STOP"}}` ✓
- 模板对这条的**编号期望只有一条**：「SetPabCommand returns success.status = SUCCESS」，
  参考日志里 CLI 显示 `Running Mode : STOP / Running Status : DONE / Current Stage : IDLE`
  ——脚本查的就是这三样 ✓

**本次复核发现的问题（脚本改了）**

1. **原来的 PAB-014 是在 PAB 静止的时候发 STOP**，
   那样测的是「把一个已经停着的 PAB 再停一次」，**不是 STOP 的意义所在**。
   改成：**先 START 起一轮 → 等它真的在跑 → 再 STOP**。
   这样测的才是「把正在跑的 PAB 停下来」
2. **因为前提变了，原来那条「状态依赖」的断言反而变成确定的了**。
   实测：**一轮被 STOP 打断时，`Completed` 停在 `No`**（那一轮不算完成）：
   ```
   打断前:  Completed: No | Loop count: 1 | Running Mode: FREERUN | Running Status: CONTINUE_DELAY | Current Stage: STAGE4
   发 STOP: → success.status = SUCCESS
   打断后:  Completed: No | Loop count: 1 | Running Mode: STOP   | Running Status: DONE      | Current Stage: IDLE
   ```
   既然这一轮是这条用例自己起的，`Completed` = `No` 就是**固定的**，
   而且它正好是「那一轮被打断了」的证据 —— 所以改成断言它，
   而不是像之前那样把它去掉
3. **连带的：PAB-015 的前提条件要放宽**。
   PAB-014 走完，PAB 停在 `STOP / DONE / IDLE` 但 `Completed = No`（那一轮被打断了），
   而 PAB-015 原来要等 `Completed=Yes` 的「静止」——那个条件永远不成立，
   实测 PAB-015 直接 120 s 超时失败。
   改成只等 `Running Status=DONE / Current Stage=IDLE`（「流程没在做事」）
   实测也确认了 **RESTART 在这个状态下能用**：
   ```
   STOP / Completed: No → RESTART → success → FREERUN / CONTINUE_DELAY / STAGE2
   ```

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑（PAB-014 和 PAB-015 一起跑）：

```
PAB-014-1  Send the STOP command over gRPC .................. PASS
PAB-014-2  Check the PAB status after the STOP command ..... PASS
PAB-014-3  Check that the PAB is at rest .................... PASS
PAB-015-1  Send the RESTART command over gRPC ............... PASS
PAB-015-2  Check the PAB status after the RESTART command ... PASS
PAB-015-3  Wait for the PAB round to be over ................ PASS
6 tests, 6 passed, 0 failed
```

PAB-014-1 的实际时间线：

```
14:20:57.206  SetPabCommand START  → "SetPabCommand completed successfully"
14:20:57.592  Current Stage : STAGE1        ← 确认它在跑
14:20:57.721  SetPabCommand STOP   → "SetPabCommand completed successfully"
14:20:59.053  CLI : Completed: No | Running Mode: STOP | Running Status: DONE | Current Stage: IDLE
14:20:59.224  gRPC: runningMode: ALIGN_PAB_MODE_STOP, currentStage: ALIGN_PAB_STAGE_IDLE
```

### PAB-015 — PAB | GRPC Configuration, Status & Control（Trigger PAB Control : RESTART）

**目的与内容**

用 gRPC 让 PAB 重新开始一轮均衡（`SetPabCommand` + `currentCommand: RESTART`），
确认命令被接受、并且新的一轮真的起来了。
模板期望：「SetPabCommand returns success.status = SUCCESS」，
命令前 `Running Status: DONE / Current Stage: IDLE`，
命令后 `Running Status: CONTINUE_DELAY / Current Stage: STAGE1`
（User Guide 12.1.4.4 Restart）。

**测试步骤**（脚本里的三条用例）

1. **PAB-015-1 发 RESTART**
   - 等 PAB 静止（`Running Status=DONE / Current Stage=IDLE`，超时 120 s）
   - `SetPabCommand` + `{"pabCommand": {"currentCommand": "RESTART"}}`
   - 断言 `success.status = SUCCESS`
2. **PAB-015-2 检查命令之后的状态**
   - 等阶段离开 IDLE（新的一轮起来了）→ CLI：`Running Mode`=FREERUN、
     `Current Stage` 不是 IDLE、`Completed`=No；gRPC：`runningMode`=
     `ALIGN_PAB_MODE_FREERUN`、`currentStage` 不是 `ALIGN_PAB_STAGE_IDLE`
3. **PAB-015-3 等这一轮结束**
   - 等 `CONTINUE_DELAY` 出现过 → 等 `FREERUN / Completed=Yes / IDLE` → `DONE`

**脚本怎么写的**

- 文件：`IT/PAB/PAB-015/#PAB-015.robot`（生成，`IT/_generator/sheet_pab.py`；
  和 PAB-013/014 共用同一段模板，RESTART 是第三个分支）
- 通道同 PAB-013/014：grpcurl 在 DUT 上、打回环口 `127.0.0.1:9338`，走 ROOT 会话
- 「等 PAB 静止」的条件里**没有 `Completed`**：
  一轮被 STOP 打断过的那一轮不算完成（`Completed=No`），
  加上这个条件的话，单独跑 PAB-015 就会 120 s 超时（这个坑踩过一次）

**User Guide 对照**（12.1.4.4 Restart）

- 指南的 payload 和脚本一致：`{"pabCommand": {"currentCommand": "RESTART"}}` ✓

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上**单跑**：

```
PAB-015-1  Send the RESTART command over gRPC ............... PASS   0.5 s
PAB-015-2  Check the PAB status after the RESTART command ... PASS   0.4 s
PAB-015-3  Wait for the PAB round to be over ................ PASS  52.9 s
3 tests, 3 passed, 0 failed
```

（跑之前 PAB 是 `Completed: Yes / DONE / IDLE` 的静止态 → 前提条件直接满足；
52.9 s 全是 DUT 自己跑一轮的时间。）

**一个实测出来的结论（PAB-013/014/015 通用）**

三个控制命令落在**正在跑的一轮**上，行为是不一样的：

| 命令 | 落在正在跑的一轮上 |
| --- | --- |
| **START** | **命令回 SUCCESS，但没有效果**——那一轮接着跑完，不会重来 |
| **RESTART** | **有效果**——那一轮被拉回 stage 1 重跑 |
| **STOP** | **有效果**——那一轮被打断，回到 IDLE（`Completed` 停在 `No`） |

实测证据（START）：
```
发 START 之前:  ... Current Stage : STAGE3
发 START:       → success.status = SUCCESS
之后:           STAGE3 → STAGE5 → STAGE5 → STAGE6 ...   一直往前走，那一轮没有重来
```
实测证据（RESTART）：
```
发 RESTART 之前:  ... Current Stage : STAGE3
发 RESTART:       → success.status = SUCCESS
之后:             STAGE3 → STAGE2（= 回到 stage 1，阶段 1 只存在约 2 s，被采样间隔漏掉）→ STAGE4 → STAGE5 → STAGE6 → STAGE7
```

**Loop count 两种情况下都没变**（还是 1），
所以「那一轮被重启了」的标志不是 loop count，是**阶段往回退**。

**这条结论决定了三个用例的前提各不相同**：

| 用例 | 前提 | 为什么 |
| --- | --- | --- |
| PAB-013 (START) | 先 STOP，等模式变 STOP | START 落在运行中的一轮上是空操作，不先 STOP 的话断言证明不了任何事 |
| PAB-014 (STOP) | 先 START，等它在跑 | STOP 的意义就是停正在跑的 |
| PAB-015 (RESTART) | 等 PAB 静止 | 模板写的就是从静止态发 RESTART；RESTART 在运行中的 PAB 上也有效果 |



### PAB-016 — PAB | FreeRun Boot-up

**目的与内容**

验证**恢复出厂配置并重启之后**，PAB 会自己起来跑（不需要人工配置）：
开机自检之后 PAB 自动进入 FREERUN 模式，一直跑到 eCM 上线为止。
参考 User Guide 6.2（默认就是 FreeRun，eCM 上线前一直跑）和 10.3（恢复出厂配置）。

**测试步骤**（脚本里的两条用例）

1. **PAB-016-1 检查开机后的状态**
   - `sc_cli get_pab_status` → `Enabled` = Yes、`Running Mode` = FREERUN
   - 等 eCM 上线：`sc_amphal_cli get_ecm_status` 直到含 `eCM status = Operational`
     （超时 180 s，间隔 10 s）
2. **PAB-016-2 检查开机后的配置**
   - `sc_cli get_pab_config` → 配置必须是**出厂默认值**：
     `rx adc lna mode` = 3 (FIXED_GAIN)、gain = 2.74 dBmV、target tcp = 36.00 dBmV、
     online/retry interval = 60 sec、RPD power threshold = -27.78 dBmV、
     outlier threshold = 6.00

**脚本怎么写的**

- 文件：`IT/PAB/PAB-016/#PAB-016.robot`（生成，`IT/_generator/sheet_pab.py`）
- **「恢复出厂配置 + 重启」这一步不在脚本里**：它会把配置清掉再重启 DUT，
  是台子上的动作。按这个项目的约定（和 CF-021 等同一条），
  这一步是**写明的前置条件**，脚本自动做剩下能做的部分。
  已在 `IT/README.md` 的「The items that are not automated」里补上这条

**User Guide 对照**

- 10.3：`FDX-AMP>$ restore factory config` ✓（前置条件那一步）
- 6.2：「By default, PAB is set to FreeRun mode. In this mode, PAB starts
  automatically after LE bring-up is complete and continues until the eCM comes
  online.」—— 脚本查的两件事就是这句的两半 ✓
- 6.1 的参数表给出的**默认值**：`lna_gain mode` = **3**（2: FREE_RUNNING /
  3: FIXED_GAIN）、lna_gain 2.74db、target_tcp 36dbmV、Online_interval 60s、
  retry_interval 60s ✓
- 模板 PAB-016 的参考日志（恢复出厂之后）：
  ```
  PAB Status:
    Enabled : Yes | Completed : Yes | Loop count : 1 | eCM online : Yes
    Running Mode : FREERUN | Running Status : DONE | Current Stage : IDLE
  PAB Configuration:
    rx adc lna mode      : 3 (FIXED_GAIN)
    rx adc lna gain      : 2.74 dBmV
    target tcp           : 36.00 dBmV
    online interval      : 60 sec
    retry interval       : 60 sec
    RPD power threshold  : -27.78 dBmV
    outlier threshold    : 6.00
  ```

**本次复核发现的偏差（断言改了）**

- **原来的 PAB-016-2 断言 `rx adc lna mode` = 2 (FREE_RUNNING)，这是错的**。
  恢复出厂之后的值是 **3 (FIXED_GAIN)**——模板的参考日志和 User Guide 6.1
  的默认值表都是 3。
  而它之所以一直「过」，是因为**前面 PAB-001 把配置改成了 mode 2**
  （PAB-001 预设的就是 FreeRunning 的 LNA 模式）。
  也就是说这条用例在 campaign 里是个**假通过**：
  真正恢复了出厂配置的 DUT 上它反而会挂。
  现在改成按模板的参考日志逐个断言 7 个出厂默认值

**实测结果**

第一次跑（`2026-11-19`，`172.21.48.230`）：**2 条都失败，而且都是如实失败**

```
PAB-016-1 ... FAIL
   Command "sc_amphal_cli get_ecm_status" did not contain "eCM status = Operational"
   within 180s. The last answer was:
   eCM status = RangeStart
PAB-016-2 ... FAIL
   2 (FREE_RUNNING) != 3 (FIXED_GAIN)
```

- 第 1 条失败是那个已知的台子状态（eCM 在 RangeStart）
- 第 2 条失败是**前置条件没做**：这台 DUT 上 PAB-001 已经把配置改成 mode 2 了，
  它不是「恢复出厂 + 重启」的状态

**第二次跑：把前置条件真做了，2/2 通过**

先在台子上把前置条件走通（`restore factory config` → 等它自己重启回来 →
`mgmtip static ip 172.21.48.230 net-mask 255.255.255.0 gateway 172.21.48.254`
→ 再 `reset` 重启一次），然后才跑脚本：

```
PAB-016-1 ... PASS
PAB-016-2 ... PASS
2 tests, 2 passed, 0 failed
```

跑的时候 DUT 上的状态，和模板 PAB-016 的参考日志一模一样：

```
Enabled        : Yes        Running Mode : FREERUN
Completed      : Yes        eCM online   : Yes
eCM status = Operational
```

- 第 1 条现在能过，是因为**恢复出厂 + 重启之后 eCM 真的上线了**
  （之前那个 `RangeStart` 是这台 DUT 没重启留下的状态，重启一次就没了）
- 第 2 条现在能过，是因为配置真的回到出厂值了：
  `3 (FIXED_GAIN)` / 2.74 dBmV / 36.00 dBmV / 60 sec / 60 sec /
  -27.78 dBmV / 6.00 —— 7 个默认值逐个对上

**顺带量到的台子行为**（详见上面「恢复出厂与管理 IP」）

- `restore factory config` **自己会重启 DUT**（15 s 内 SSH 断，40 s 后回来），
  所以「恢复出厂 → 设 IP → 检查文件 → 重启」这个顺序在实机上做不到
- `mgmtip static ...` 之后配置文件**立刻就被改**（同一秒写 4 次，原子写），
  不用等 60 s
- 这台 DUT 恢复出厂之后管理 IP 还是 `172.21.48.230`（出厂数据是台子烤进去的，
  镜像里的默认值是 `192.168.2.103`），所以恢复出厂之后 Robot 照样连得上

**对整个 campaign 的影响**

PAB-016 只能在**恢复出厂配置并重启之后、别的用例还没动过配置之前**跑。
按编号顺序跑（先 PAB-001 后 PAB-016）是跑不出正确结果的——
PAB-001 一跑，配置就不是出厂的了。
所以 PAB-016 要么单独安排在一台刚恢复出厂的 DUT 上（或者 campaign 的最前面），
要么就带着这个已知失败交付、把前置条件写清楚。


### PAB-004 ~ PAB-009 — PAB | GNMI Result (Container & Stage 1~7)

**目的与内容**

和 PAB-003 同一件事，只是每次只读一个阶段：PAB-004 读 stage 2、
005 读 stage 3、006 读 stage 4、007 读 stage 5、008 读 stage 6、009 读 stage 7。
每个阶段的**信息完整、阶段自己报告成功**。
模板对每一条的要求都是「响应里要有的叶子」+「该阶段定义的所有叶子都在」。

**测试步骤**（每个 suite 一条用例，形状完全一样）

1. `gnmic ... get --path pab-result/stage-N`
2. 该阶段的叶子一个不少
3. `status` 必须是 `OK`

**脚本怎么写的**

六个 suite 都是 `IT/_generator/sheet_pab.py` 的 `_stage_suite()` 套出来的，
只有 path 和叶子清单不同：

| suite | stage | 叶子数 | User Guide 9.16.1 |
| --- | --- | --- | --- |
| PAB-004 | stage-2 | 9 | 一致 |
| PAB-005 | stage-3 | 5 | 一致 |
| PAB-006 | stage-4 | 7 | 一致 |
| PAB-007 | stage-5 | 13 | 一致 |
| PAB-008 | stage-6 | 9 | 一致 |
| PAB-009 | stage-7 | 3 | 一致 |

叶子清单和 User Guide 9.16.1 的表**逐个 stage 完全一致**
（和 PAB-002 一次性对过全部 58 个叶子）。

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上一次跑完：

```
PAB-004-1  GET the stage-2 result over gNMI .... PASS
PAB-005-1  GET the stage-3 result over gNMI .... PASS
PAB-006-1  GET the stage-4 result over gNMI .... PASS
PAB-007-1  GET the stage-5 result over gNMI .... PASS
PAB-008-1  GET the stage-6 result over gNMI .... PASS
PAB-009-1  GET the stage-7 result over gNMI .... PASS
6 tests, 6 passed, 0 failed
```

**本次复核发现的偏差**：没有。模板、User Guide 9.16.1、实机三方一致。


### PAB-002 — PAB | GNMI Result (Container & Stage 1~7)

**目的与内容**

一次 gNMI GET 把整个 `pab-result` 容器读出来，确认里面装的是 PAB 跑完之后的
**完整结果**（stage-1 到 stage-7 七个阶段各自的 payload），
供上层 API 一次拿到整个 payload 自己解析，不用分七次读。
模板期望：① gNMIc get 请求成功；② 响应里要有 stage-1 … stage-7；
③ 9.16.1 表里给每个 stage 定义的叶子都在。
参考 User Guide 9.16.1。

**测试步骤**（脚本里的两条用例）

1. **PAB-002-1 读整个容器**
   - `gnmic ... get --path pab-result`
   - 检查容器里有 `stage-1` … `stage-7` 七个
2. **PAB-002-2 逐个阶段检查叶子**
   - 再 GET 一次 `pab-result`
   - 对 7 个阶段逐个检查它的叶子一个不缺

**脚本怎么写的**

- 文件：`IT/PAB/PAB-002/#PAB-002.robot`（由 `IT/_generator/sheet_pab.py` 生成，
  叶子清单在那个文件的 `STAGE_LEAVES` 里）
- 通道：`IT COMMON - Gnmi Get And Return` → `GNMI_IT.Get And Return`，
  gnmic 在 DUT 上跑，打 DUT 的回环 gNMI 口 `127.0.0.1:9339`
- 答案结构是三层（`updates → values → <path>`），
  所以有 `IT COMMON - Gnmi Get Leaf Value` 把这三层索引收掉，
  取值交给 `lib/Viper/GnmiPath.py` 的 `Resolve`（selector 顺序无关）
- 断言只看**叶子名在不在**，不看值 —— 模板说的是
  "every leaf defined for stage 1..7 is present"
- 叶子清单用 JSON 数组存进 `VAR &{stage_leaves}`：
  Robot 的字典语法只能带字符串，列表只能这么传，
  `IT COMMON - Gnmi Stage Leaves Should Exist` 里再 `json.loads` 回来
- **前置条件**：容器里装的是上一次 PAB 跑出来的结果。
  实测 DUT 把每一步的结果落在 `/mnt/sc_nonvol/PAB/pab_stageN_result.json`，
  在 nonvol 里，所以**重启之后还在**；只有一台从没跑过 PAB 的机器才是空的。
  模板本身也写了前置条件「After performing a successful pre-alignment
  balancing procedure」，脚本不自己跑 PAB

**User Guide 对照**（第 9 章 Supported GNMI Data Model，9.16.1 的表）

- 指南里 `pab-result` 下每个 stage 的叶子，和脚本 `STAGE_LEAVES` 里的
  **逐个 stage 完全一致**：
  stage-1 12 个、stage-2 9 个、stage-3 5 个、stage-4 7 个、
  stage-5 13 个、stage-6 9 个、stage-7 3 个，共 58 个叶子
- 实机回的容器：7 个 stage 都在，58 个叶子**一个不缺、一个不多**
  （脚本把每阶段的叶子集合和指南的集合做集合比较过）

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-002-1  GET the whole PAB result container over gNMI ...... PASS
PAB-002-2  Check the leaves of every stage of the container .. PASS
2 tests, 2 passed, 0 failed
```

实机答案（`gnmic get --path pab-result`）：

```
stage-1: {"message": "Stage 1 completed successfully", "np-ds-att-after-lna": 14,
          "np-ds-att-before-lna": 20, "np-ds-att-between-lna": 13,
          "np-ds-inverse-eq": 0, "np-ds-vceq": 1.16, "rx-adc-lna-gain-db": 2.74,
          "status": "OK", "us-fdx-in-att": 31.5, ...}
stage-7: {"ecm-online": true, "message": "ECM operational - PAB complete",
          "status": "OK"}
```

**本次复核发现的偏差**：没有。模板、User Guide 9.16.1 和实机三方一致。


### PAB-003 — PAB | GNMI Result (Container & Stage 1~7)

**目的与内容**

读单个阶段的 PAB 结果（这里是 stage 1），确认这个阶段的**信息是完整的、是有定义的**：
12 个叶子一个不缺，且这一阶段自己报告成功。
模板期望：① gNMIc get 请求成功；② 响应里有这 12 个叶子
（status, message, rx-adc-lna-gain-db, np-ds-att-before-lna, np-ds-att-between-lna,
np-ds-att-after-lna, np-ds-inverse-eq, np-ds-vceq, us-fdx-in-att, us-fdx-out-att,
us-legacy-att-before-lna, us-legacy-att-after-lna）。
参考 User Guide 9.16.1。

**测试步骤**（脚本里的一条用例）

1. **PAB-003-1 GET stage-1**
   - `gnmic ... get --path pab-result/stage-1`
   - 12 个叶子一个不少
   - `status` 必须是 `OK`

**脚本怎么写的**

- 文件：`IT/PAB/PAB-003/#PAB-003.robot`
  （由 `IT/_generator/sheet_pab.py` 的 `_stage_suite()` 生成，
  PAB-003…PAB-009 都是同一个模板套出来的，只是 path 和叶子清单不同）
- 通道和 PAB-002 一样：`IT COMMON - Gnmi Get And Return`（gnmic 在 DUT 上跑，
  打回环口 `127.0.0.1:9339`）
- 叶子清单写成 Robot 的列表变量 `VAR @{leaves}    message    np-ds-att-after-lna ...`，
  断言走 `IT COMMON - Gnmi Leaves Should Exist` → `Gnmi Leaf Should Exist`
  （查的是叶子**名**在不在，不看值）
- 比 PAB-002 多一步：`Should Be Equal ${status}    OK`。
  模板的期望输出里只要求叶子齐全，**这一步是加严**——
  理由是模板对这一条的���置条件写的是
  「After performing a successful pre-alignment balancing procedure」，
  而 PAB-002 的参考日志里每个 stage 的 status 都是 `OK`。
  代价是：上次 PAB 跑失败时（status 不是 OK）这条会失败。
  这是有意的，不是误报

**User Guide 对照**（9.16.1）

- 指南里 stage 1 的 12 个叶子，与脚本 `STAGE_LEAVES["stage-1"]` 完全一致
- 指南这一节开头写「The following GNMIC commands may be performed using either
  CLISH or Linux Shell」——脚本走的是 Linux shell（ROOT 会话），是允许的

**实测结果**

`2026-11-19`，在 `172.21.48.230` 上实跑：

```
PAB-003-1  GET the stage-1 result over gNMI .... PASS
1 test, 1 passed, 0 failed
```

实机答案：

```json
"pab-result/stage-1": {
  "message": "Stage 1 completed successfully",
  "np-ds-att-after-lna": 14, "np-ds-att-before-lna": 20, "np-ds-att-between-lna": 13,
  "np-ds-inverse-eq": 0, "np-ds-vceq": 1.16, "rx-adc-lna-gain-db": 2.74,
  "status": "OK",
  "us-fdx-in-att": 31.5, "us-fdx-out-att": 31.5,
  "us-legacy-att-after-lna": 31.5, "us-legacy-att-before-lna": 8
}
```

**和模板参考日志逐值比对：12 个叶子的值全部一模一样**
（template 的 LOG FILE 列里那段 stage-1 与实机答案一致，
连 `us-legacy-att-before-lna: 8` 这种不整的值都对得上）。
即这台 DUT 复现出了和模板参考同一次 PAB 结果

**本次复核发现的偏差**：没有。模板、User Guide 9.16.1、实机三方一致。


## ALIGNMENT

### ALN-001 — ALIGNMENT | Sercomm CLI Calibration

**目的与内容**

用 Sercomm CLI 跑 **NAFE（North AFE）开环校准**，三个目标各跑一遍：
`NAFE_BO1`（第一块 NAFE）、`NAFE_BO2`（第二块）、`ALLNAFE`（两块一起），
每一条都要**不带错误地完成**。

NAFE 校准量的是北侧 AFE 的回退（backoff），属于**开环**校准：
不需要信号源、不需要人工动台子，DUT 自己测自己。
所以这一条**不是** BENCH 项（模板没标，User Guide 也没要求物理动作）。

参考 User Guide 3.5（命令表）和 7.2.2（校准流程的第 4 步）。

**测试步骤**（脚本里的三条用例，每条一个目标）

1. **ALN-001-1 校准第一块 NAFE**
   - `sc_cli calib_nafe NAFE_BO1`
   - 检查输出以 `calib_nafe success` 结尾，且输出里没有 `failed`
2. **ALN-001-2 校准第二块 NAFE**
   - `sc_cli calib_nafe NAFE_BO2`
   - 同上的检查
3. **ALN-001-3 两块一起校准**
   - `sc_cli calib_nafe ALLNAFE`
   - 同上的检查

**脚本怎么写的**

- 文件：`IT/ALIGNMENT/ALN-001/#ALN-001.robot`（生成，`IT/_generator/sheet_alignment.py`）
- 命令走 **ROOT 会话**（linux shell）里的 `sc_cli`，和模板里的
  `debug sc_cli calib_nafe ...` 是同一个可执行文件（clish 的 `debug` 视图
  最终也是调 `/usr/bin/sc_cli`）
- 超时 120 s（实测一条不到 1 s，模板参考日志里三次加起来约 19 s）

**User Guide 对照**

- 3.5 的命令表：`debug sc_cli calib_nafe ALLNAFE` → "Start NAFE alignment" ✓
- 7.2.2 第 4 步的完整写法是
  ```
  debug sc_rfboard_cli set_ignore_np_ds_calib_adj 1
  debug sc_cli calib_nafe ALLNAFE
  debug sc_rfboard_cli set_ignore_np_ds_calib_adj 0
  ```
  ——**模板这一条只要中间那步**，所以脚本不碰 `ignore_np_ds_calib_adj`
- 7.2.2 第 6 步：「Reboot is required to apply the NAFE calibration result.」
  → 校准结果要**下次重启**才生效，模板这一条不管重启
- 7.2.2 第 7 步：NAFE 校准之后要**再跑一次完整校准**
  → 见下面「跑完这台 DUT 变成什么样」

**实机答案（`172.21.48.230`，2026-11-19）**

`sc_cli calib_nafe` 的用法（实机打的）：

```
Usage: calib_nafe [NAFE_BO1|NAFE_BO2|ALLNAFE]
```

成功时的输出（NAFE_BO1，节选）：

```
resultMsg:{
transport_header { sequence_number: 6718  milliseconds_since_epoch: 6689734
  source_id: "NafeBackoff1 Op564121867"  correlation_tag: 2 }
result { success: true }
open_loop_calibration_event {
  stage: NafeBackoffStage1
  status: Completed
  event_description: "End of successful nafe_backoff_1 calibration stage 201"
  results { soc_temperature_celsius: 43.875
            nafe_backoff_open_loop_calibration_results_stage1 { } }
}
}
calib_nafe success
```

`ALLNAFE` 的输出里有**两段** resultMsg（NafeBackoff1 + NafeBackoff2），
最后同样是 `calib_nafe success`。

**本次复核发现的偏差（断言改了）**

- 原来断言是 `Should Contain    ${out}    success`——**太松，是假通过**：
  失败时 protobuf 打印里是 `success: false`，里面照样有 "success" 这个词，
  断言照样过。失败时 sc_cli 自己打的是
  `calib NAFE_BO1 failed (<rc>)` / `calib NAFE_BO2 failed (<rc>)`。
  现在改成两条：**必须出现 `calib_nafe success`**，
  **并且输出里不能有 `failed`**（依据：`sc_cli_api.c` 的 `sc_cli_api_calib_nafe`）
- 超时从 300 s 收到 120 s

**跑完这台 DUT 变成什么样（副作用）**

- `/tmp/calib/calib_nafeBackoff1_results.txt`、`calib_nafeBackoff2_results.txt`
  被写入（校准结果，JSON）
- `/tmp/nafe_calibrate_flag` 被 touch（NAFE_BO2 和 ALLNAFE 会）
  → 这个标记由**下一次完整校准的 POST_DS4** 阶段消费：
  它会把 US_LEGACY_ATT 的状态从板子上恢复回来，然后删掉标记
  （`ScCalibrationThread.cpp` 的 `ExecutePostDs4`）。
  也就是 User Guide 7.2.2 第 7 步说的「NAFE 校准之后要再跑一次完整校准」
- 校准结果要**下次重启**才生效（User Guide 7.2.2 第 6 步）
- 注意：`calib_req_config_flag` 现在是 `true`（ASC 的门闸），这一条不管它

**实测结果**

```
ALN-001-1  Calibrate the NAFE block 1 ....... PASS
ALN-001-2  Calibrate the NAFE block 2 ....... PASS
ALN-001-3  Calibrate both NAFE blocks ...... PASS
3 tests, 3 passed, 0 failed
```


### ALN-002 — ALIGNMENT | FDX & Non-FDX Alignment（Non-FDX: Down / Down / Down）

**目的与内容**

把 DUT 配成 **Non-FDX（下行/下行/下行）** 的形态，然后走一遍完整的
**Non-FDX 对齐流程**：ds-profile → legacy RLSP → spectrum allocation →
configuration-state → **重启** → PAB FreeRun（预对齐）→ 校准前的开关 →
`start-ds1` → `start-ds2` → `start-ds3` → `start-us` → 收尾。

参考 User Guide 5.1（不同 lineup 的配置）、7.1（校准前的设置）、
7.2.1（Non-FDX 的四个 stage）。

**测试步骤**（脚本里的 12 条用例）

1. **ALN-002-1 / -2 配 ds-profile（north / south）**
   `configure ds-profile <port>` → `name profile-3`、`start-freq 120000000`、
   `start-power 31.8`、`end-freq 1002000000`、`end-power 45.0`、
   `step-down 0 start-freq 1002000000`、`step-down 0 size-db 0.0` →
   `show configuration` → `commit` → `show configuration` → `exit`
2. **ALN-002-3 legacy RLSP**：`set_legacy_rlsp north|south 8`，再读回来
3. **ALN-002-4 spectrum allocation**：`configure spectrum` → ds 108~1218 MHz、
   us-legacy 5~85 MHz、us-extended 108~684 MHz、subband 0/1/2 ds → commit
4. **ALN-002-5 configuration-state**：`configuration-state MID_SPLIT`，
   再用 gNMI 读 `configuration-status` 和 `configuration-status/spectrum-state`
5. **ALN-002-6 重启 DUT**：clish 的 `reset`，然后等它回来
6. **ALN-002-7 重启后再读一次 spectrum-state**（模板的期望 5 写的是
   "after reboot"）
7. **ALN-002-8 PAB FreeRun**：`set_pab_config 2 2.74 36.00 60 60 -21.78 6.00` →
   `get_pab_config` → `pab_control stop` → `pab_control free_run` →
   等到 `Running Mode=FREERUN / Completed=Yes / Current Stage=IDLE` →
   `sc_amphal_cli get_ecm_status` = Operational
8. **ALN-002-9 校准前的开关**：`set_ignore_np_ds_calib_adj 0`、
   `set_auto_adj_legacy_vatt 1`、`set_station_mode with_cable_sim`
9. **ALN-002-10 对齐**：`configure alignment` → `start-ds1` → `start-ds2` →
   `start-ds3` → `start-us` → `show alignment-status` → `show alignment-action`
10. **ALN-002-11 JXP 倾角和 US DAC**：读 `get_legacy_up_jxp_tilt` →
    在 HAL 里跑 `/leap/np_dac_power_mode_set 0 0`（关掉 US DAC）→
    `set_attenuation 5 31.5`
11. **ALN-002-12 校准门闸**：`set_calib_req_config_flag false`

**脚本怎么写的**

- 文件：`IT/ALIGNMENT/ALN-002/#ALN-002.robot`（生成，
  `IT/_generator/sheet_alignment.py`），12 条用例
- 这一条是 **BENCH 项**：它把 DUT 改成一个完整的 Non-FDX 配置并且重启它
- 对齐的四个 stage 各给 **300 s**：实测 `start-ds1` 要 **19.7 s**
  （模板参考日志里也是 EQ IN 0.00 dB，说明台子的线缆模拟器已经在正确的衰减上，
  不需要人工动）
- 重启那一步：**`reset` 的回答可能被 SSH 断线吃掉**，所以命令用
  `Run Keyword And Ignore Error` 发出去不算失败，真正的判据是后面
  「等 DUT 回来」

**新增的公共设施（重启之后要用的）**

- `ViperSSH.Wait For Connection` / `ViperGnmi.Wait For Connection`：
  重启把会话打断，而 **paramiko 的 transport 察觉不到**（它还"活着"），
  下一条命令就在死掉的 channel 上跑，报的是 `exit status -1` 而不是连接错误。
  这两个 keyword 关掉重开，并且**带重试**：DUT 的 sshd 先接受 TCP 再能说 SSH，
  头几次会被对端重置
- `IT COMMON - Wait For Dut To Come Back`：三个会话（FDX / ROOT / gNMI）依次
  重建，然后**在 DUT 上跑一个 until 循环**，等 DUT 自己的 gNMI 服务器回答为止
  （AMP 的服务比 SSH 服务起来得晚）
- `IT COMMON - Run Dut Hal Command And Return`：进 HAL、跑命令、Ctrl-D 回来
  （见下面的「HAL 那一段」）
- 实测：重启到能连上，**157 s**（有一次量到 10 分钟，所以超时给到 900 s）

**User Guide 对照**

- 7.2.1 的四个 step 就是 `start-ds1` / `start-ds2` / `start-ds3` / `start-us` ✓
- 7.1：校准前 `set_ignore_np_ds_calib_adj 0`、`set_auto_adj_legacy_vatt 1` ✓
- 7.1：station mode 有 Normal 和 **with_cable_sim** 两种，实验室用线缆模拟器
  时用后者 ✓（模板也写了 `set_station_mode with_cable_sim`）
- 7.2.1 Step 5：`get_legacy_up_jxp_tilt` ✓
- 7.2.1 Step 6：`hal>/leap/np_dac_power_mode_set 0 0` 和
  `set_attenuation 5 31.5` —— **两步都做了**（一开始以为前半步做不了，
  是我判断错了，详见下面「HAL 那一段」）✓

**本次复核发现的偏差（改了四处）**

1. **原来的脚本根本没有重启**：模板的流程里 `reset` 在配置之后、PAB 之前，
   期望 5 还写着 "after reboot"。原脚本在设完 configuration-state 之后就
   直接去读 gNMI 了——那读的是**重启前**的状态。现在加了重启用例，
   并且在重启后再读一次 spectrum-state
2. **`Should Contain ${status} ALIGNED` 是假通过**：`UNALIGNED` 里就含着
   `ALIGNED` 这个词！DUT 一开始五个 stage 全是 `UNALIGNED`，这条断言照样过。
   现在逐个 stage 断言 `DS1:ALIGNED` / `DS2:ALIGNED` / `DS3:ALIGNED` /
   `US:ALIGNED`
3. **对齐 stage 的超时 15 s 不够**：实测 `start-ds1` 要 19.7 s，第一个版本
   就是因为 15 s 超时而**看起来失败**——但 DUT 那边其实已经 `DS1:ALIGNED` 了。
   现在给 300 s
4. 生成器里的 `\n` 写进了 Robot 文件，把一条用例拆成了两行，多出四个
   假用例（`${status}` not found）。改成同一行

**HAL 那一段（User Guide 7.2.1 Step 6 的前半步）**

一开始我写的是「这一步做不了」——**那个结论是错的**，原因不在 DUT，
在我用的探针工具。

- User Guide 上的写法是 `debug hal` → 出现 `hal>` 提示符 → 敲
  `/leap/np_dac_power_mode_set 0 0` → **Ctrl-D 退出**
- 实机：`debug hal` 之后 DUT 打印
  `Trying to connect... / Connected. / Press Ctrl-D to exit`，
  **然后就没有提示符了**。要**再敲一次回车**，`hal>` 才出来
  （这个回车就是提示符的钥匙，**不是**命令的一部分）
- 敲完命令它回 `Successfully set NP-DAC power mode`，Ctrl-D 之后回到
  `FDX-AMP>$`
- 我之前用 **tether** 去探，tether 的提示符正则只有 `[$#] $`，认不出
  `hal>`，而且超时时它会往通道里塞一个 `^C` —— 所以看起来像「挂住了」。
  **Robot 这边的 SSH 库本来就有 HAL 这一层**
  （`ViperSSH.LEVELS["HAL"]`，提示符 `hal> `，进去 `debug hal\n`，
  出来 `\x04`），而且 `_send_raw()` 里已经写了「等不到提示符就补一个换行」
  的逻辑（注释里就写着 `"debug hal"` 是这样的 shell）
- 所以新增了一个公共关键字
  `IT COMMON - Run Dut Hal Command And Return`：进 HAL → 跑命令 →
  用 Ctrl-D 回来 → 顺手把回车这个动作也做了

实机输出（`ALN-002-11` 的日志）：

```
/leap/np_dac_power_mode_set 0 0hal> /leap/np_dac_power_mode_set 0 0

Successfully set NP-DAC power mode

hal>
```

**顺带查清楚的一件事**：HAL 在 DUT 上并不是 eAMP 的程序，它是 Broadcom
的 CLI，AMP 通过 `/tmp/brcmhal.sock` 跟它说话。AMP 自己有一条一模一样的
路径（`palAmpPrivateAPI.c` 的 `palSetFdxUsDac()` 用
`cliwrapper_client -s /tmp/brcmhal.sock -c '...' -t 2000`），
但那个函数**在整个源码里没有被调用过**——所以 AMP 自己平时不会动这个 DAC。
脚本走的是 User Guide 的交互那条路。

**一次 DUT 自己重启了（不是脚本干的）**

09:29:47 跑完 HAL 之后 20 s 左右，DUT 从网络上消失了（ping 不通、ARP 表里
没有、22/9339/9338 都不通），09:30:47 回来。`/log/oops/oops.log` 说
`There was no panic in earlier run`，所以**不是 kernel panic**，
是一次干净的复位。

起因大概是我自己用 tether 探的时候留下的烂摊子：tether 的 `debug hal`
会话超时以后被塞了 `^C`，那个 HAL 客户端还挂在 socket 上，
后来又被我硬生生 kill 掉。第二次再跑同一个 HAL 用例（09:34:56）就**没有**
重启了，第三次（整条 ALN-002）也没有。
**结论：Robot 里的 HAL 流程本身是稳的，但用 tether 去手工驱动 `hal>`
会话会把这个 DUT 搞挂，别再这么探了。**

**实机答案（`172.21.48.230`，2026-11-19）**

对齐跑完之后：

```
DS1:ALIGNED
DS2:ALIGNED
DS3:ALIGNED
US:ALIGNED
NET:UNALIGNED          <- NET 对齐是别的条目
```

和模板参考日志的 `show alignment-status: DS1/DS2/DS3/US ALIGNED, NET UNALIGNED`
**一模一样**。

`start-ds1` 的实机输出：

```
Started DS1 alignment, please wait.
Operator action:
Please change the Analog Plugin (EQ IN) on the RF Board to increase slope by "0.00" dB
Completed DS1 alignment
```

**实测结果**

```
ALN-002-1  Configure the north port ds-profile ..... PASS
ALN-002-2  Configure the south port ds-profile ..... PASS
ALN-002-3  Set the legacy RLSP of both ports ........ PASS
ALN-002-4  Configure the spectrum allocation ....... PASS
ALN-002-5  Set the configuration state to MID_SPLIT  PASS
ALN-002-6  Reboot the DUT and wait for it to come .. PASS
ALN-002-7  Check the spectrum state after the reboot  PASS
ALN-002-8  Run the PAB FreeRun round ............... PASS
ALN-002-9  Allow the calibration to adjust the ..... PASS
ALN-002-10 Run the alignment stages ds1, ds2, ds3, us  PASS
ALN-002-11 Adjust the JXP tilt and the US DAC ....... PASS
ALN-002-12 Clear the calibration required flag ..... PASS
12 tests, 12 passed, 0 failed
```

**换 DUT：2026-11-20 从 .230 换到 .226**

.230 被别人占用了，开发改用 .226。台子上的环境变量也一起改了
（`~/.bashrc`：`TETHER_DEVICE_HOST` 和 `VIPER_DEVICE_IP` 都指向 .226）。
两台不是同一台机器：

| | .230（之前） | .226（现在） |
| --- | --- | --- |
| 序列号 | SCMLSA2619005A | SCMLSC25240006 |
| HW | 06.05 | **04.0** |
| SW | 00.04.006（正式版） | **00.04.006ER3**（ER 版） |
| MAC | a4:01:de:93:02:95 | 78:b3:9f:5c:a0:ef |

IT 模板是照着**正式版 00.04.006 + HW 06.05** 写的，所以在 .226 上的结果是
「参考」，不能当成正式版的结果。两台的路由一样（都没有到 CM 的
192.168.100.0/24），CM 同样不通。

**在 .226 上又抓到的两个坑**

1. **spectrum 的 `commit` 15 s 不够**：改了频段之后 commit 要真的把新的
   allocation 下到硬件上，clish 要等它做完才回提示符。实测 **21 s**。
   之前 15 s 超时 → 提示符没回来 → 下一条 `configuration-state MID_SPLIT`
   被塞进了**还在 spectrum 视图里**的会话 → 「Syntax error: Unknown
   command」→ 两条用例一起挂。现在 commit 给 **120 s**
   （不改频段时 commit 只要 8 s，所以 120 s 是给「真在改」的情况用的）
2. **eCM 上线要等**：eCM 不是一步到位的，它要走一串状态
   `RangeStart → StartDsAcquisition → StartUsAcquisition → RangeStart →
   Operational`。实测（.230，09:37:22 重启 → 09:42:43 Operational）：
   **重启之后 5m21s**，其中 PAB 结束（09:41:00）之后 4m43s；
   .226 上（10:02:18 重启 → 10:05:47 Operational）**3m29s**。
   原来等 180 s 不够（.226 上那条挂了），现在等 **600 s**。
   注意：**这跟 PAB-016 里那个「13 分钟」是两件事**——
   13 分钟是 .230 上 eCM 自己掉回 `RangeStart` 又自己回来的那次
   （见 PAB-016 那一节），那种情况等再久也不保证，按 PAB-016 的决定
   **如实失败**，不粉饰
3. **重启那条用例原来是假通过**（.226 第一轮跑出来才发现）：
   ALN-002-6 只做「发 `reset`（不看回答）+ 等 DUT 回来」，
   而当时 `reset` 被塞进了**还没退出的 spectrum 视图** →
   「Syntax error: Unknown command」→ **DUT 根本没重启**
   （`uptime` 当时还是「up 8 days」），但用例照样报 PASS。
   现在重启前后各读一次 `/proc/uptime`（开机以来的秒数），
   断言**之后必须比之前小**，否则算失败

**实测结果（两台机器）**

```
.230  12 tests, 12 passed, 0 failed      （带 HAL 那一步）
.226  12 tests, 12 passed, 0 failed      （带 HAL 那一步，commit 和 eCM 的超时修好之后）
.226  12 tests, 12 passed, 0 failed      （再加上「重启真的发生了」这条断言）
```

重启那条断言的实测值（.226，10:22）：

```
重启前 /proc/uptime = 1154.94 s
reset -> gNMI reset-control -> 重启
回来后 /proc/uptime = 105.35 s      （uptime 命令也说 "up 1 min"）
```

**跑完这台 DUT 变成什么样**


- DUT 现在是 **Non-FDX（Down/Down/Down）** 的配置：
  ds-profile profile-3 120~1002 MHz、spectrum 108~1218 MHz、
  us-extended 108~684 MHz、configuration-state = MID_SPLIT
- 四个 stage 都 ALIGNED，NET 还是 UNALIGNED
- `calib_req_config_flag` 被清成 `false`（ASC 的门闸开了）
- `station mode` = with_cable_sim
- US FDX out attenuation = 31.5 dB
- **US DAC 被关掉了**（`np_dac_power_mode_set 0 0`），这是 User Guide
  7.2.1 Step 6 要的：FDX 的 US 通路会干扰校准
- PAB 的配置被这一条改成了 mode 2 / target 36.00 / RPD -21.78
  （出厂值是 mode 3 / -27.78）


### ALN-003 ~ ALN-006 — 四个 lineup 的对齐流程（一次写完，没有全跑）

这一轮是按用户的决定做的：**03~06 的内容跟 02 差不多，代码写对就行，
不用都跑**（跑一轮要十几分钟：两次重启 + PAB + 四个 stage）。

**先查了 03~06 跟 02 到底差在哪**（模板的 row 5~9 + User Guide 5.2~5.5）：

| | ALN-002 | ALN-003 | ALN-004 | ALN-005 | ALN-006 |
| --- | --- | --- | --- | --- | --- |
| lineup | Non-FDX DDD | Non-FDX Legacy Mid-Split | Full FDX | Partial FDX 无 dummy DS | Partial FDX 有 dummy DS |
| ds-profile | profile-3 120~1002 MHz 31.8/45.0 | 同 ALN-002 | **profile-4 108~1218 MHz 32.0/53.0** | **profile-3 384~1098 MHz 36.0/46.4** | **profile-3 108~1098 MHz 31.8/46.4** |
| us-profile rlsp | 无 | 无 | **有（8.0）** | **有** | **有** |
| spectrum | us-ext 108~684, subband ds | **us-ext 0/0 + 删掉 3 个 subband + 预设 `Legacy_MidSplit_DS_1.2GHz`** | us-ext 108~684, **subband bidi** | us-ext 108~396, **subband us + freq-exclusion 383~396 MHz** | us-ext 108~396, **subband bidi + 同一个 freq-exclusion** |
| configuration-state | MID_SPLIT | MID_SPLIT | **FDX_FINE** | FDX_FINE | FDX_FINE |
| np_soc_target_tcp | 无 | 无 | **29** | **29** | **29** |
| 重启 | 1 次 | 1 次 | **2 次** | **2 次** | **2 次** |
| PAB 参数 | 2 / 36.00 / -21.78 | 同左 | **3 / 29 / -27.78** | 2 / 36.00 / -21.78 | 同左 |
| eCM 检查 | AMP 的 `sc_amphal_cli` | 同左 | **SNMP 问 CM（要 12）+ CM 控制台（人工）** | AMP 的 | AMP 的 |
| 校准 | `configure alignment` 的 start-ds1..us | 同左 | **AUTO 校准 + NAFE + 第二次手动** | **全手动 + NAFE + 第二次手动** | 同 ALN-005 |
| interference ratio | 无 | 无 | 0.0078125 | **3** | **3** |

**结论：03 跟 02 几乎一样；04/05/06 是另一条流程**（FDX 校准：`configure
calibration` → `start-calibration`，不是 `configure alignment`）。

**这一轮在代码里改掉 / 新写的东西**

1. **ALN-003 少了重启**——模板的 row 里 configuration-state 后面有
   `# Reboot`，原脚本没有。补上（`ALN-003-6`），后面也补了「重启后再读
   一次 spectrum-state」
2. **ALN-003 的 spectrum 少了 `us-extended-start-freq 0` /
   `us-extended-end-freq 0`**——模板和 User Guide 5.2 都有，补上
3. **ALN-004 少了两次重启**——模板 step 4（配完 spectrum + FDX_FINE +
   target TCP 之后）和 step 10（NAFE 输出 + target TCP 36 之后）各一次，
   原脚本都没有。补上
4. **ALN-004 少了 CM 的 SNMP 检查**——模板 step 7 要
   `snmpget -v2c -c public <CM> 1.3.6.1.2.1.10.127.1.2.2.1.1.2` 回答
   `INTEGER: 12`。**实机验证过**：DUT 上有 `/usr/bin/snmpget`，CM 的地址是
   `172.31.255.45`（DUT 的 priv0 网段），实测回 `INTEGER: 12` ✓
   （CM 控制台的 `show status` 是人工步骤，写在用例说明里了）
5. **ALN-005 / ALN-006 之前根本没有脚本**（表里写的是「跳过」），
   这一轮按模板写出来了，各 17 条用例
6. **AUTO 校准的断言太松**：原来只查 `STAGE_DS1` 出现在输出里。
   现在查四个 stage 的 `Progress:` 行、`Result: SUCCESS`，以及
   `show calibration-status` 里逐个 stage 的 `Status: ALIGNED`
   （**`STAGE_DS1, Status: ALIGNED` 这种写法才不会被 `NOT_ALIGNED` 骗到**）
7. **手动校准补了每个 stage 的 `Result: SUCCESS`**——模板的参考记录里
   第二次 pass 第一次跑是四个 stage 全 FAILED，原来的断言根本看不出来
8. **手动校准的端口状态用了模板的过滤**：`sc_cli get_north_port_status 0`
   的输出有 **32 kB**（1024 个预均衡系数），脚本里加了 `| grep tcp`，
   只留 `rx_adc_input_power_dbmv_tcp` 那一行
9. **抽了 5 个公共 helper**：`_us_profile_rlsp_case`、
   `_np_soc_target_tcp_case`、`_nafe_case`、`_manual_calibration_case`、
   `_cm_operational_case`，另外 `_spectrum_case` 加了可选的
   freq-exclusion
10. **新变量 `${CM_SNMP_ADDRESS}`**（CM 的地址，默认 172.31.255.45），
    在 `variables/dut_variables.robot` 和 `variables/sample/` 里都有

**实机验证过的命令**（不是照着模板抄的，是在 .226 上跑过的）

| 命令 | 实机回答 |
| --- | --- |
| `subband remove 0` | successfully deleted index 0 in local configuration |
| `subband 0 us` / `bidi` / `ds` | "subband-mode" is set from ds to us / bidi / ds |
| `add freq-exclusion 383000000 396000000 PASS_OTHER EXCLUDED` | successfully added frequency exclusion in local configuration |
| `us-extended-start-freq 0` | "us-extended-begin-hz" is set from 108000000 Hz to 0 Hz |
| `debug sc_cli set_spectrum_allocation Legacy_MidSplit_DS_1.2GHz` | 之后 `sc_cli get_spectrum_allocation` = Legacy_MidSplit_DS_1.2GHz，us-ext 0/0，subband 0 个 |
| `configure us-profile north` → `rlsp 8.0` | rlsp is set from 8.10 to 8.00 dBmV in local configuration |
| `configuration-state FDX_FINE` | Spectrum state set to: FDX_FINE |
| `sc_cli set_np_soc_target_tcp 29` | palSetNorthAfeInputTargetTcp success (value=29.000000 dBmV) |
| `sc_cli get_interference_ratio_based` | success (value=3.000000 db) |
| `sc_cli get_north_port_status 0 \| grep tcp` | rx_adc_input_power_dbmv_tcp = 33.116487 |
| `snmpget -v2c -c public 172.31.255.45 1.3.6.1.2.1.10.127.1.2.2.1.1.2` | SNMPv2-SMI::transmission.127.1.2.2.1.1.2 = INTEGER: 12 |
| `show calibration-status` | [0] Stage: STAGE_DS1, Status: ALIGNED（四行） |

**没有跑的**：`start-calibration`（AUTO 和 manual）本身。它的命令行语法
是从 clish 的定义文件确认的（`calibration.xml`：
`start-calibration [mode] [start_stage]`，mode = auto/semi-auto/manual，
stage = ds1/ds2/ds3/us1），输出格式也是从 `calibration.sh` 确认的
（每个 stage 一行 `Progress: STAGE_xxx`，最后 `Result: SUCCESS`）。
真跑一轮要几十分钟，而且台子上没有信号源，跑也是 FAIL。

**模板本身有个坑**：ALN-005 / ALN-006 的 row 在第二次 pass 的中间就断了
（`debug sc_cli get_north_port_status 0 \` 之后就没了），后面的
「清校准标志」在另一格里。第二次 pass 是照着第一次 pass 和 ALN-004 的
第二次 pass 重建的，用例说明里写了这一点。

**校验**：`robotcode analyze code` 151 files / 0 errors / 17 warnings / 27 hints
（跟之前一样的基线）；`robot --dryrun` 四个 suite 62 tests / 62 passed。


### ALN-003 — ALIGNMENT | FDX & Non-FDX Alignment（Non-FDX: Legacy Mid-Split）

**目的与内容**

跟 ALN-002 是同一条流程（ds-profile → RLSP → spectrum → configuration-state →
重启 → PAB FreeRun → 校准前的开关 → 四个 stage → JXP/US DAC → 清标志），
**只有 spectrum 那一步不一样**：Legacy Mid-Split 是 User Guide 5.2 里的
「Genesis mode」可选配置——上行扩展频段是 0/0，而且**没有 subband**。
User Guide 明说这一版有「subband 数量下限」的限制，所以要用预设来配：
`debug sc_cli set_spectrum_allocation Legacy_MidSplit_DS_1.2GHz`。

**测试步骤（12 条用例）**

1-2. north / south 的 ds-profile（profile-3，120~1002 MHz，31.8/45.0）
3. legacy RLSP = 8 dBmV（这一档是 Non-FDX，**没有 us-profile**）
4. **spectrum**：ds 108~1218 MHz、us-legacy 5~85 MHz、**us-extended 0/0** →
   **删掉 3 个 subband** → **删掉频段排除** → 上预设 → commit → 用
   `sc_cli get_spectrum_allocation` 读回来
5. configuration-state MID_SPLIT（gNMI 读两遍）
6. **重启**（模板里有的，原来脚本没有）
7. 重启后再读一次 spectrum-state
8. PAB FreeRun（2 / 36.00 / -21.78）+ eCM
9. 校准前的开关（ignore_np_ds_calib_adj 0、auto_adj_legacy_vatt 1、with_cable_sim）
10. 四个 stage（ds1/ds2/ds3/us）
11. JXP 倾角 + **HAL 里关 US DAC** + set_attenuation 5 31.5
12. 清校准标志

**脚本怎么写的**

`IT/ALIGNMENT/ALN-003/#ALN-003.robot`（生成，12 条用例，BENCH 项）。
除了 spectrum 那条，其余全是 ALN-002 已经跑通的代码。

**这一轮在实机上挖出来的东西（都是 .226 上量的）**

1. **模板的 ALN-003 少了「重启」**——模板 row 里 configuration-state 后面有
   `# Reboot`，原来脚本没有。补上了（ALN-003-6），后面也补了「重启后再读
   一次 spectrum-state」
2. **模板的 ALN-003 少了 `us-extended-start-freq 0` /
   `us-extended-end-freq 0`**——User Guide 5.2 有，脚本没有，补上
3. **频段排除会挡住 commit**（这条是最花时间的）：
   - `subband remove 0/1/2` 之后本地配置里没有 subband 了
   - 如果本地配置里**还有频段排除**，`commit` 回答
     **「failed to apply local configuration」**——AMP 不接受
     「没有 subband 但有排除」的 allocation
   - 把排除删掉之后，同样的配置 commit 回答 **「applied local configuration」** ✓
   - 上预设本身也会把 allocation 直接改掉（`sc_cli get_spectrum_allocation`
     立刻变成 Legacy_MidSplit_DS_1.2GHz，0 个 subband、0 个排除），
     但**存下来的配置**要靠 commit 才写进去——commit 失败的话，重启之后
     DUT 用的还是老的频段配置
   - 模板的期望 4 写的是「commit OK」，台子的记录也是「commit: applied」，
     所以脚本现在**先把频段排除删掉再 commit**
   - 删排除有个坑：**索引不会重排**。删掉 index 0 之后，剩下的那条还叫
     index 1，所以要按原索引 0..N-1 依次删（删 index 0 两次是删不干净的）
   - 新增公共关键字 `IT COMMON - Get Count After Label`：读 clish
     `show configuration` 里「Total frequency exclusions         N」那个 N
4. **断言收紧**：原来只查 `dsBeginHz` / `dsEndHz`，现在查
   `description: Legacy_MidSplit_DS_1.2GHz` + `usExtendedBeginHz: 0`
   （确认上的就是 Legacy Mid-Split，而不只是频段范围对）
5. **补上了 HAL 那一步**（关 US DAC），跟 ALN-002 一样

**实测结果**

```
ALN-003-4  Apply the Legacy Mid-Split spectrum allocation ..... PASS
```

（只跑了这一条：它是这一档里唯一有新命令的用例。日志：
`successfully deleted index 0/1/2` → `Total frequency exclusions 0` →
`applied local configuration` → `description: Legacy_MidSplit_DS_1.2GHz`）

其余 11 条用的都是 ALN-002 已经跑通的代码（ALN-002 整轮 12/12 通过）。

**跑完这台 DUT 变成什么样**

Legacy Mid-Split：ds 108~1218 MHz、us-legacy 5~85 MHz、**us-extended 0/0、
没有 subband、没有频段排除**，configuration-state = MID_SPLIT。

**一个不影响下一条、但要知道的点**

ALN-003 跑完（commit 成功）之后，clish 的 spectrum 视图里**还看得到 3 个
subband**（存下来的配置保留了它们的 mode，只是没有 exclusion、us-extended
是 0/0），实测下一条（ALN-002 的 spectrum 用例）照样能改 subband 的 mode、
commit 也回答「applied local configuration」✓。所以**条目之间不会互相搞坏**。

**没跑整轮的原因**：用户决定 03~06 不用都跑（每轮十几分钟：重启 + PAB +
四个 stage）。ALN-003 只跑了有新命令的那一条。


### ALN-004 — ALIGNMENT | FDX & Non-FDX Alignment（Full FDX）

**目的与内容**

**跟 ALN-002/003 完全不是一条流程**：ALN-002/003 走的是 `configure alignment`
（start-ds1/ds2/ds3/us），ALN-004 走的是 **FDX 校准**
（`configure calibration` → `start-calibration`）。

Full FDX lineup：ds-profile 用 **profile-4**（108~1218 MHz，32.0/53.0）、
**us-profile 的 rlsp 8.0**、spectrum 的三个 subband 都是 **bidi**、
configuration-state 是 **FDX_FINE**、初始 NP target TCP **29 dBmV**、
**重启两次**（配完之后一次、NAFE 之后一次）、**AUTO 校准** + NAFE +
第二次**手动** pass。User Guide 5.3 / 7.2.2。

**测试步骤（16 条用例，对应模板的 14 步）**

| # | 用例 | 模板步骤 |
| --- | --- | --- |
| 1-2 | north / south 的 ds-profile（profile-4，108~1218 MHz，32.0/53.0） | 1 |
| 3 | us-profile 的 rlsp 8.0（north/south）+ legacy rlsp | 2 |
| 4 | spectrum：us-extended 108~684，subband 0/1/2 **bidi** | 3 |
| 5 | configuration-state FDX_FINE（gNMI 读两遍） | 4 |
| 6 | np_soc_target_tcp 29 | 4 |
| 7 | **重启** + 等它回来（带「真的重启了」的断言） | 4 |
| 8 | 重启后再读一次 spectrum-state | 4 |
| 9 | PAB（**mode 3 / 29 / -27.78**）+ FreeRun + eCM | 5、6 |
| 10 | **CM 的 SNMP 检查**（要 INTEGER: 12） | 7 |
| 11 | **AUTO 校准**（四个 stage + Result: SUCCESS + 逐个 ALIGNED） | 8 |
| 12 | NAFE（ignore_np_ds_calib_adj 1 → calib_nafe ALLNAFE → 0） | 9 |
| 13 | interference_ratio_based 0.0078125 + np_soc_target_tcp 36 | 10 |
| 14 | **重启**（NAFE 的结果要重启才生效） | 10 |
| 15 | 第二次 pass：manual ds1/ds2 → AFE TCP - 0.2 → manual ds3/us1 | 11、12、13 |
| 16 | 清校准标志 | 14 |

**这一轮查出来的两个真 bug（都在 ALN-002/003 跑不出来，只有 ALN-004 才碰到）**

1. **PAB 的 LNA mode 名字写死了**。`_pab_case` 里断言
   `rx adc lna mode == "2 (FREE_RUNNING)"`，但 Full FDX 用的是 **mode 3 =
   FIXED_GAIN**（源码 `sc_cli_api.c`：`INVALID, FROZEN, FREE_RUNNING,
   FIXED_GAIN`；实机 `sc_cli get_pab_config` → `3 (FIXED_GAIN)`）。
   原来的断言会让 ALN-004 这一条**直接挂**。现在按 mode 取名字
2. **target TCP 是按字符串比的**。DUT 打印 `29.00 dBmV`，模板写的是
   `29` → 「29.00 dBmV != 29 dBmV」。改成按数字比
   （`IT COMMON - Cli Number Should Equal`），顺便把 lna gain 和
   RPD threshold 也查了

**这一轮补上的东西**

- **两次重启**（模板 step 4 和 step 10）→ 补上
- **CM 的 SNMP 检查**（模板 step 7）：DUT 上有 `/usr/bin/snmpget`，
  CM 的地址是 **172.31.255.45**（DUT 的 priv0 网段），实测回 `INTEGER: 12` ✓。
  CM 控制台的 `show status` 是**人工步骤**，
  写在用例说明里了
- **AUTO 校准的断言收紧**：四个 stage 的 `Progress:` 行 + `Result: SUCCESS`
  + `show calibration-status` 里逐个 `STAGE_DS1, Status: ALIGNED`
- **手动 pass 补了每个 stage 的 `Result: SUCCESS`**：台子的记录里
  「第二次 pass 第一次跑四个 stage 全 FAILED」，原来的断言看不出来
- **us-profile 的 rlsp 补了读回断言**（`rlsp 8.00 dBmV`）

**一个要拍板的矛盾（已定：按模板走 AUTO）**

User Guide 7.2.2 在 Step 1 和 Step 7 都挂着一条注：
「**04.005 版本上 FDX 校准有已知问题，不要用 AUTO，改走 Step 10 的
workaround（手动 ds1/ds2 → 读 AFE TCP → 设 target TCP → 手动 ds3/us1）**」。

而模板的 ALN-004 第 8 步就是 `start-calibration`（AUTO），台子的记录也是
AUTO 跑通了（`STAGE_DS1/DS2/DS3/US1 all ALIGNED`）；
模板的 ALN-005/006 则明写「**Do NOT use the AUTO mode**」。

**决定（2026-11-20，Ian Yin）：ALN-004 按模板走 AUTO，代码不改。**
ALN-005/006 保持全手动。用例说明里记着 UG 的那条注，所以以后看脚本的人
知道这是有意选的，不是漏看。

**第三个 bug：等一个状态的轮询会被一次慢回答打断**

`IT COMMON - Wait For Dut Command Contains` 这类轮询关键字原来用的是
`Run Dut Command And Return`——**一次回答超过 15 s，整轮等待就作废**，
哪怕这轮等待还有 600 s 的预算。实机就是这样挂的：`sc_amphal_cli
get_ecm_status` 在 eCM 正在 ranging 的时候会慢，有一次等了十几秒，
600 s 的等待就断在那里。

改成用新的 `IT COMMON - Run Dut Root Command And Return Buffer`
（超时也把拿到的 buffer 交出去），**所有轮询关键字都换过去了**
（Command Contains / Cli Field / Cli Fields / Command Match /
File / Json File / 拒绝重试那几条）。

**实测**

```
ALN-004-3   Set the RLSP of the us-profiles and of the legacy ports ..... PASS
ALN-004-9   Run the PAB FreeRun round ................................. PASS
```

**2026-11-20，`.233`（HW 06.05，正式版 00.04.006）上整轮 16/16 通过：**

```
16 tests, 16 passed, 0 failed
```

| # | 用例 | 结果 |
| --- | --- | --- |
| 1-2 | north / south 的 ds-profile（profile-4） | PASS |
| 3 | us-profile 的 rlsp + legacy rlsp | PASS |
| 4 | spectrum（subband bidi） | PASS |
| 5 | configuration-state FDX_FINE | PASS |
| 6 | np_soc_target_tcp 29 | PASS |
| 7 | 重启（带 uptime 前后对比） | PASS |
| 8 | 重启后再读 spectrum-state | PASS |
| 9 | PAB FreeRun（mode 3 / 29 / -27.78） | PASS |
| 10 | CM 的 SNMP（`INTEGER: 12`） | PASS |
| 11 | **AUTO 校准** | PASS |
| 12 | NAFE（ALLNAFE） | PASS |
| 13 | ratio 0.0078125 + target TCP 36 | PASS |
| 14 | 第二次重启 | PASS |
| 15 | **第二次 pass（手动 ds1/ds2 → ds3/us1）** | PASS |
| 16 | 清校准标志 | PASS |

AUTO 校准的实机输出（13:39:11 ~ 13:42:20，整轮 3 分钟）：

```
Progress: STAGE_DS1 - Downstream Calibration Stage 1
Progress: STAGE_DS2 - Downstream Calibration Stage 2
Progress: STAGE_DS3 - Downstream Calibration Stage 3
Progress: STAGE_US1 - Upstream Calibration Stage 1
Result: SUCCESS
  [0] Stage: STAGE_DS1, Status: ALIGNED
  [1] Stage: STAGE_DS2, Status: ALIGNED
  [2] Stage: STAGE_DS3, Status: ALIGNED
  [3] Stage: STAGE_US1, Status: ALIGNED
```

手动第二遍（13:45:06 ~ 13:47:21）：

```
Progress: STAGE_DS1 → Result: SUCCESS
Progress: STAGE_DS2 → Result: SUCCESS
rx_adc_input_power_dbmv_tcp = 35.964143      → target = 35.764143
Progress: STAGE_DS3 → Result: SUCCESS
Progress: STAGE_US1 → Result: SUCCESS
```

（台子的参考记录里 AFE 输入 TCP 是 35.421175 → target 35.22，同一个量级。）

**一个之前判断错的事**：我一直以为「台子上没有信号源，AUTO 校准跑不了」——
**不对**。clish 这条路（`start-calibration`）在台子上能跑完，四个 stage 全
ALIGNED；跑不了的是 gRPC 的 `HwInstallation/StartCalibration`（那条会报
`Alignment failed for stage:1`）。

（早先在 `.226` 上只跑了 ALN-004-3 和 ALN-004-9 两条，那两条也 PASS。）
```

ALN-004-9 跑通的那一轮：PAB（mode 3 / 29 / -27.78）写进去 → FreeRun 一轮
（Completed=Yes / DONE / IDLE）→ eCM 在 **12:01:48** 变成 `Operational`。
三个修复（mode 的名字、按数字比 target TCP、轮询不再被一次慢回答打断）
都验证过了。

（只跑了这两条：ALN-004-11 的 AUTO 校准在台子上没信号源，跑也是 FAIL，
所以没跑。）

**DUT 掉线：三次，两次是自复位，一次是丢包**

| 时间 | 现象 | 结论 |
| --- | --- | --- |
| 09:30 前后 | ping 不通、ARP 里没有、22/9339 不通；09:30:47 回来 | **自复位**（oops.log：不是 panic） |
| 11:31 ~ 11:55 | 同上，这次 24 分钟才回来；期间跑用例直接「Connect to DUT_IT_SSH time out 10」 | **自复位**（回来后 oops.log：不是 panic） |
| 13:05:07 | 监控报消失，15 s 后又通了 | **不是掉线**：uptime 1h10m37s，说明还是 11:55 那次启动的，**没重启**，只是一个 ping 丢了 |

两次自复位的共同点：**都是在动了 DUT 的「运行中配置」之后**
（09:29 是关 US DAC，11:31 是 PAB 换到 mode 3 = FIXED_GAIN / target 29）。

**但不是测试引起的**：11:55 DUT 回来之后，**同一个 PAB（mode 3 / 29 /
-27.78）在 11:57~12:01 又跑了一遍，一模一样，这次 eCM 变成 Operational，
DUT 好好地活着**。所以「PAB mode 3 会搞挂 DUT」这个猜测**不成立**。

结论：这台 DUT 会自己复位，两次都查不到 panic（`There was no panic in
earlier run`），复现不了。**当成台子的环境问题**，脚本这边不粉饰：
- 重启那一步用 `/proc/uptime` 前后对比，**真的重启了才算过**，
  免得「没重启」也报 PASS
- `run_it.sh` 跑之前先 ping DUT，不在就等 5 分钟，还不在就**直接退出**，
  而不是把一整轮打成红


### ALN-005 / ALN-006 — ALIGNMENT | Partial FDX（无 / 有 Dummy DS Energy）

**目的与内容**

Partial FDX 的两种形态，流程完全一样，差在 lineup 的参数：

| | ALN-005（无 dummy DS energy） | ALN-006（有 dummy DS energy） |
| --- | --- | --- |
| ds-profile | profile-3，**384000000 ~ 1098000000**，**36.0 / 46.4** | profile-3，**108000000 ~ 1098000000**，**31.8 / 46.4** |
| spectrum 的 subband | **us**（只有上行） | **bidi** |
| us-extended | **108000000 ~ 396000000** | **108000000 ~ 396000000** |
| 频段排除 | **383000000 ~ 396000000 PASS_OTHER EXCLUDED** | 同左 |

流程：ds-profile → us-profile rlsp → spectrum → FDX_FINE + target TCP 29 →
重启 → PAB FreeRun（2 / 36.00 / -21.78）+ eCM → 校准前的开关 →
**手动**校准第一遍 → JXP 倾角 → NAFE → ratio **3** + TCP 36 → 重启 →
**手动**校准第二遍 → 清校准标志。

两条共用一个生成函数（`_partial_fdx_suite`），17 条用例/条。
User Guide 5.5（无 dummy）/ 5.4（有 dummy）+ 7.1 + 7.2.2。

**跟 ALN-004 的三处行为差别**

1. **不用 AUTO**：模板明写「Do NOT use the AUTO mode」，走 User Guide 7.2.2
   Step 10 的 workaround（手动 ds1/ds2 → 读 AFE TCP → 设 target TCP →
   手动 ds3/us1）。ALN-004 按模板走 AUTO（已决定，见 ALN-004 那一节）
2. **interference ratio 是 3**（ALN-004 是 0.0078125）
3. **eCM 用 AMP 的 `sc_amphal_cli get_ecm_status` 查**（ALN-004 是 SNMP 问 CM）

**决定（2026-11-20，Ian Yin）：ALN-005 / ALN-006 不整轮跑。**

理由：004/005/006 是同一条 FDX 流程（骨架共用），ALN-005/006 跟别的条目的
差别只是 lineup 的参数，而这些参数都逐条在实机上验过了：

| ALN-005/006 特有的东西 | 在哪验过 |
| --- | --- |
| 整个 FDX 流程（两次重启、PAB、NAFE、ratio、手动 pass、清标志） | ALN-004（它的第二遍就是手动 pass） |
| 「校准前的开关」 | ALN-002（同一个 helper，12/12 过） |
| PAB 2 / 36.00 / -21.78 | ALN-002（12/12 过） |
| `subband 0/1/2 us` + 频段排除 383~396 MHz | ALN-005-4 在实机上跑过两遍，都 PASS（连「删旧排除」那段路也走到了） |
| `set_interference_ratio_based 3` | 实机读回 `3.000000 db` |
| us-profile 的 `rlsp 8.0` | 实机 |

只留一条尾巴：**lineup 的参数本身**（ds-profile 384 MHz / 36.0 dBmV、
spectrum 的 us-extended 108~396 + 排除）在这台正式版机器（.233）上再跑一遍
那两条便宜的用例确认一下。

**这一轮新增的代码（spectrum 那条）**

要**先把 DUT 上已有的频段排除删掉，再加模板的那一条**——因为排除的
**索引不重排**（删掉 index 0 之后剩下那条还叫 index 1），所以按原索引
0..N-1 删。新增公共关键字 `IT COMMON - Get Count After Label`
（读 clish `show configuration` 里「Total frequency exclusions         N」）。

**在 .233（HW 06.05，正式版）上补跑的 lineup 参数**

```
ALN-005-1  Configure the north port ds-profile ..................... PASS
ALN-005-2  Configure the south port ds-profile ..................... PASS
ALN-005-4  Configure the spectrum allocation ....................... PASS
ALN-005-8  Check the spectrum state after the reboot .............. PASS
```

（ds-profile 的 384 MHz / 36.0 dBmV、spectrum 的 us-extended 108~396 +
subband us + 频段排除 383~396，在正式版机器上都认。）

**实测**（ALN-005-4，在 .226 上跑了两遍）：

```
第一遍（DUT 上 0 条排除）
  Total frequency exclusions         0
  add freq-exclusion 383000000 396000000 PASS_OTHER EXCLUDED
  applied local configuration
  → subBand:0/1/2 mode "us"，Total frequency exclusions 1

第二遍（DUT 上已经有 1 条排除，删除那段路走到了）
  Total frequency exclusions         1
  remove freq-exclusion 0
  add freq-exclusion 383000000 396000000 PASS_OTHER EXCLUDED
  applied local configuration
  → Total frequency exclusions 1
```

**模板的一个坑**：ALN-005 / ALN-006 的 row 在第二次 pass 的中间就断了
（`debug sc_cli get_north_port_status 0 \` 之后没了），「清校准标志」在另一
格里。第二次 pass 是**照第一次 pass 和 ALN-004 的第二次 pass 重建**的，
用例说明里写了这一点。

### ALN-007 — ALIGNMENT | Legacy US Calibration Error Factory Compensation

**当前状态（2026-11-23）**：按用户要求，6 条用例均标记跳过；完整流程需要
标定后人工测量 RLSP，而当前脚本不能暂停等待。传入历史示例中的偏差也不会
解除跳过。历史通过记录只表明当时的脚本执行结果，不代表完成本轮仪表验证。

在 `.233` 上跑完。这一项原来是 4 条用例，断言太松，这次重写成 6 条。

**历史结果（跳过前）**：用例 6 需要台子上的人工测量，不给就报失败：

| 跑法 | 结果 |
| --- | --- |
| 不给偏差（`result/aln007_nomanual`） | 5/6，用例 6 报「需要人工测 RLSP」 |
| `--variable ALN007_MANUAL_DEVIATION:-0.5`（`result/aln007_manual`） | **6/6 通过**，offset 写成 14.5（跟 User Guide 的例子一样） |

**这一项在做什么**：User Guide 第 4 章（模板引的是 4 和 10.5）。eCM 上报的发射
功率比实际高约 15 dB，这个偏差要通过 legacy US 标定流程测出来，写进工厂文件
`/mnt/sc_factory/ecm_rfb_offset`，作为以后所有测量的补偿。模板的 5 条期望：

| # | 模板的期望 | 脚本怎么查 |
| --- | --- | --- |
| 1 | 上下限可读，上限能设成 50 dBmV | 用例 1 |
| 2 | eCM 是 Operational，US TXPWR 在 17.25~50 dBmV | 用例 4（从 alignment 日志里取实测值） |
| 3 | `calib_us_legacy` 成功 | 用例 3 |
| 4 | `get_legacy_up_jxp_tilt` 返回合理的 tilt | 用例 3 |
| 5 | offset = 默认 15 + 偏差 | 用例 2 + 用例 6 |

**6 条用例**：

1. `Read the eCM TX power limits` — 读上下限（**不写**，见下面第 1 点）→ 等 eCM
   到 Operational
2. `Set the eCM offset to the default 15` — 读文件里原来的值（teardown 要写回去）
   → 按 User Guide 写成 15 → 读回来核对
3. `Run the legacy US calibration` — 把 JXP tilt 设回 0（手册要求「0 dB
   attenuation JXP」）→ `configure alignment` → `debug sc_cli calib_us_legacy`
   → 查结果文件走的是哪条分支 → 读 JXP tilt
4. `Check the US TXPWR of the eCM` — 从 `journalctl -u sc_alignment` 里取
   `ecmTxPwrF1/F2` 和 `minEcmTxPower/maxEcmTxPower`，比窗口
5. `Measure the RLSP and compute the deviation` — 读南口的 target RLSP 和
   legacy RLSP，把 DUT 自己算出来的偏差打出来（给人工测量的数对一下）
6. `Write the compensated eCM offset` — **没有人工给的偏差就 Fail**；有的话写
   「15 + 偏差」，读回来核对；teardown 把文件写回原来的值

#### 实机结果（.233）

```
get_min_ecm_tx_power success (value=17.250000 dbmV)
get_max_ecm_tx_power success (value=52.750000 dbmV)   ← 出厂值，脚本不写它
eCM status = Operational
cat /mnt/sc_factory/ecm_rfb_offset → 13.5             ← 原值，teardown 写回它
（脚本按手册写成 15 → 读回来 15）
configure alignment → debug sc_cli calib_us_legacy:
    calib_us_legacy success
    Auto adjuest legacy upstream ATT by eCM Tx Power
sc_rfboard_cli get_legacy_up_jxp_tilt → 0（标定前，脚本先写回 0）
                                  → 3（标定后，算法算出来的）
journalctl -u sc_alignment:
    isCmOperational=1  ecmTxPwrF1=32.789700  ecmTxPwrF2=32.789700
    minEcmTxPower=17.250000  maxEcmTxPower=52.750000
sc_cli get_rlsp_all south:
    South Port rlsp: 8.000000 dBmv
    South Port legacy rlsp: 8.000000 dBmv
写回：15 + 0.0 = 15.0，teardown 写回 13.5
```

（`result/aln007_233i` 是最后一遍；前面几遍里 `maxEcmTxPower=50.000000` 是因为
旧版脚本把上限写成了 50，见下面第 1 点，已经写回 52.75。）

给上手工偏差（-0.5 dB）的那一遍：

```
The target RLSP is 8.0 dBmV and the RLSP of the calibration is 8.0 dBmV,
    the deviation of the DUT is 0.0 dB
The eCM offset goes from 15.0 to 14.5, the default 15.0 plus the deviation -0.5
（teardown 写回 13.5）
```

#### 五个跟模板/手册对不上的地方

1. **上限不改，保持出厂值**：这个上限不是代码里的常数，是 nonvol
   （`/alignment/max_ecm_tx_power_v2`），出厂写的是 **52.75**（代码里唯一的
   硬编码是给老 RF 板 hw<8.6 的兜底 `PPR4_DEFAULT_MAX_ECM_TX_POWER=32.25`，
   这台机器不走那条）。按「出厂值不动」的原则，**脚本不写这个上限**，只读、
   记日志，标定真正用的窗口从 alignment 日志里读回来。顺带一提：User Guide
   说「上限要在跑标定前调高」，但实机出厂值 52.75 比 50 高，设成 50 其实是
   调**低**；eCM 的 32.79 dBmV 在 (17.25, 52.75) 里也成立，所以这条上限不是
   eCM 算法的必要条件
2. **offset 按手册先设成 15，再写 15 + 偏差**：User Guide 第 4 章 Note 2 说
   「先把 `ecm_rfb_offset` 设成 15」（BCM 的 eCM 控制表报高约 15 dB，算法从
   eCM 报的功率里减掉这个 offset），Step 7 说「写 15 + 偏差」。所以脚本：
   **用例 2 先把文件写成 15**（原来的值 13.5 记下来，teardown 写回去），
   **用例 6 写 15 + 偏差**。文件里原来的 13.5 是这台机器以前补偿过的结果
   （模板备注也写了「pre-existing offset on this unit, not the default 15」）。
   注意 AMP 代码里这个文件的**缺省值是 -1.5**
   （`ScAscUtility::kDefaultEcmRfbOffsetDb`，sc-alignment 的
   `ReadEcmRfbOffset()` 用的也是 -1.5），那是「文件读不出来时」的兜底值，
   不是手册说的 15
3. **期望 2（US TXPWR 17.25~50）在手册里没有命令**，User Guide 那里还标着
   「(Need update)」。实机上有两处可以拿：
   - 标定结果文件走的是 **eCM 分支**（`Auto adjuest legacy upstream ATT by eCM
     Tx Power`）还是 **old method 回退分支**——只有 eCM 分支才说明 eCM 的功率
     在窗口里（`ScCalibrationThread.cpp` 的 `useEcmMethod` 条件）
   - alignment 日志里直接印着 `ecmTxPwrF1/F2` 和它用的 `min/max`
   脚本两条都用上：查结果文件的分支 + 比日志里的窗口
4. **RLSP 的测量是台子上的手工活**：手册第 4 章 Step 5 要在 US 跑满 100%
   利用率时用表测 SP_US_TP 的 RLSP。实机上 DUT 自己存着这两个数
   （`sc_cli get_rlsp_all south`：profile 的 RLSP = 目标值，legacy RLSP = 标定
   测到的值），这台机器上两个都是 8.0 → DUT 自己算的偏差是 **0.0**。
   但偏差为 0 的话，写回去的就是 15（跟默认值一样），**补偿等于没验**。
   所以按决定：**偏差必须人工给**——
   `--variable ALN007_MANUAL_DEVIATION:<偏差 dB>`，不给就用例 6 就 Fail，
   报「需要人工测 RLSP」。用例 5 仍然把 DUT 自己的两个 RLSP 和算出来的偏差
   打出来，给人工测量的数对一下
5. **补偿值可能过不了重启**（在 `.230` 上看到的，`.233` 没验证）：
   `.230` 重启过一次（内核 uptime 从 30 多分钟变成 189 s），**重启后约 3 分钟**
   （文件 mtime）有人把 `/mnt/sc_factory/ecm_rfb_offset` 写成了
   **`-1.5000000000`**，也就是 AMP 的缺省值。写这个值的程序没在源码树里找到
   （源码里只有三个 reader：sc-alignment、sc-agc、sc-asc）。`.233` 这一轮
   没重启（uptime 89 分钟），文件里的 13.5 一直都在，所以**这一项的补偿
   必须写在最后一次重启之后**，而且要确认写进去的值还在

#### 改紧的四处断言

| 原来 | 现在 | 为什么 |
| --- | --- | --- |
| `Should Contain ${calib} success` | `calib_us_legacy success` **且** 结果文件里有 `by eCM Tx Power` **且** 没有 `old method` | 原来的 `success` 会把 `calib_us_legacy failed, -1` 也算成通过；`old method` 是回退分支，说明 eCM 没在工作 |
| `Should Contain ${out} 15` | 读成数字，按手册写成 15，写完读回来核对是不是 15；原来的值记下来，teardown 写回去 | 原来是「读出来含 15」就算过，其实没做任何事 |
| `Should Contain ${jxp} get_legacy_up_jxp_tilt =` | 取数值，落在 0~6 dB（算法表 `gJxpDb` 的范围） | 原来只看有没有这行字 |
| （没有）| 新增：eCM 的 TXPWR 落在 min/max 窗口内 | 对应期望 2 |

6. **JXP tilt 要先归零**：标定会把算出来的 tilt 写到 RF 板
   （`libsc_rfboard_set_legacy_up_jxp_tilt`），所以第二次跑这一项时板上的
   tilt 已经是上一次的结果（这台机器上 3 或 4），eCM 路线就会去补偿一个并不
   存在的 JXP 衰减。User Guide 第 4 章 Step 3 要求的是「0 dB attenuation
   JXP」，所以脚本在标定前用 `sc_rfboard_cli set_legacy_up_jxp_tilt 0` 把它写回
   0，这一项才可以重复跑

#### 这一轮修的两个公共设施的坑

1. **`IT COMMON - Get Inline Field` 会跨行**：它原来用 `([^ ]+)` 取值，空格以外
   的都算，所以行尾的值会把**下一行**也吃进来（`get_legacy_up_jxp_tilt = 3`
   后面那行也被吃了）。现在先把换行换成空格再取值
2. **Robot 会吃掉不认识的转义**：cell 里的 `\s` 变成 `s`（资源文件开头就写了
   这条规矩）。所以正则一律用字符类（`[0-9]+`、`[.]`），不用 `\s`、`\.`

### ALN-008 — ALIGNMENT | CLISH Calibration Modes

在 `.233` 上跑完，**4/4 通过**（`result/aln008_233b`）。这一项原来是 3 条用例，
断言太松（只看 `show calibration-status` 里有没有那几个阶段名），这次重写成 4 条。

**这一项在做什么**：User Guide 第 4 章——clish 的标定命令有三种模式
（`start-calibration [auto|semi-auto|manual] [ds1|ds2|ds3|us1]`），外加
`show calibration-status`。模板的 4 条期望：

| # | 模板的期望 | 脚本怎么查 |
| --- | --- | --- |
| 1 | auto 把 DS1/DS2/DS3/US1 四个阶段跑到完 | 用例 1（四条 progress 行 + 顺序 + SUCCESS） |
| 2 | semi-auto <stage> 自己把剩下的阶段跑完 | 用例 2（四条 progress 行 + 顺序 + SUCCESS） |
| 3 | manual <stage> 只跑给的那个阶段 | 用例 3（每个阶段：自己的 progress 行在，别的不在） |
| 4 | calibration-status 和实际结果一致 | 用例 4（四个阶段 ALIGNED + 没有标定在跑） |

**命令其实是个 gRPC 的壳**：clish 的 `start-calibration` 走的是
`/usr/bin/calibration.sh`，它用 grpcurl 调 DUT 自己的 gRPC
`gnoi.calibration.v1.Calibration/StartCalibration`，再把回答翻译成：

```
 Progress: STAGE_DS1 - Downstream Calibration Stage 1
 Progress: STAGE_DS2 - Downstream Calibration Stage 2
 Progress: STAGE_DS3 - Downstream Calibration Stage 3
 Progress: STAGE_US1 - Upstream Calibration Stage 1
 Result: SUCCESS
 Message: Calibration completed successfully
```

失败的时候是 `Result: FAILURE` + `Message: Alignment failed for stage: N`。

**4 条用例**：auto / semi-auto ds1 / manual 四个阶段连着跑 / calibration-status。

#### 实机结果（.233）

| 命令 | 结果 | 用时 |
| --- | --- | --- |
| `start-calibration auto` | 四个阶段按顺序跑完，SUCCESS | 约 2 分钟 |
| `start-calibration semi-auto ds1` | 四个阶段按顺序跑完，SUCCESS | 约 2 分钟 |
| `start-calibration manual ds1` | 只有 STAGE_DS1，SUCCESS | 约 22 秒 |
| `start-calibration manual ds2/ds3/us1` | **只有自己那个阶段**，SUCCESS | 各 1 秒 / 46 秒 |
| `show calibration-status` | 四个阶段都 ALIGNED，Calibrating false | 1 秒 |

#### 三个跟模板/手册对不上的地方

1. **manual 模式必须连着跑**：单独跑一个不是 ds1 的阶段会失败——
   `Result: FAILURE / Message: Alignment failed for stage: 2`，而且**是在
   `show calibration-status` 显示四个阶段都 ALIGNED 的情况下**失败。实测：
   - auto 跑完 → `manual ds2` → **失败**（连着两次都是）
   - `manual ds1` → `manual ds2` → **成功**，再 `manual ds2` → 还是成功
   也就是说：**manual 模式是一个链**，ds1 → ds2 → ds3 → us1 挨着跑才行，
   中间隔了别的标定（auto / semi-auto）就不行了。这跟 User Guide 10.13.2 /
   10.13.3 的 WARNING（「阶段是顺序依赖的，前面阶段没成功完成就不要从后面的
   阶段开始」）方向一致，但手册说的是「完成」而不是「刚才在 manual 模式里
   跑过」，所以**要么是实现比手册严，要么是手册漏了这条**。
   模板的 procedure 写的正是 `manual ds1 / ds2 / ds3 / us1` 挨着跑，跟实机对得上。
2. **失败消息里的阶段编号跟别处不一样**：`Alignment failed for stage: N` 里的
   N 是标定服务自己的编号（**US1=0, DS1=1, DS2=2, DS3=3**），而 alignment
   日志里是 DS1=1, DS2=2, DS3=3, **US1=5**。脚本按标定服务的编号断言。
3. **失败的时候 alignment 日志里能看到它是怎么失败的**：阶段刚开始 0.2~0.7 秒
   就收到 `Received calibration abort: stage=N`，而成功的时候阶段跑完会有
   `Received calibration result: result_type=N`。所以失败时阶段**根本没跑完**。

#### 改紧的断言

| 原来 | 现在 |
| --- | --- |
| `Should Contain ${status} STAGE_DS1`（只看状态里有阶段名） | 直接查命令的输出：四个阶段的 progress 行都在、**顺序也对**、Result 是 SUCCESS |
| （没有）| manual 模式：断言**只有**自己那个阶段的 progress 行，别的一行都没有（这是期望 3 的核心） |
| （没有）| manual 的每个阶段都断言 Result 是 SUCCESS；失败时把「它放弃的是哪个阶段」写进失败消息 |
| `Should Contain ${status} STAGE_US1` | `Stage: STAGE_US1, Status: ALIGNED`（整行）+ `Calibrating false` |

#### 这一轮加的三个公共 keyword

- `IT COMMON - Get Text After Label` —— 读「标签 + 空格（可选冒号）+ 值」的形式
  （`Calibrating                 false`、`Result: SUCCESS`）
- `IT COMMON - Progress Line Order` —— 检查几个 progress 行的先后顺序
- `IT COMMON - Check Calibration Result` —— 检查标定命令的结果行；失败时把
  「它放弃的是哪个阶段」写进失败消息

### 这一轮改的两个公共设施（DUT 会掐断 SSH 会话）

`.233` 上跑 ALN-004 的时候，**SSH 会话在用例中途被 DUT 掐断**（EOF），
库能重连，但**正在跑的那条命令**就挂了（报「Timeout reached while waiting
for prompt」）。查下来的机制：

1. **DUT 的时钟会跳**：重启后从 1970-01-01 开始，之后跳到真实时间。
   而 `amp_admin` 的密码修改时间是个真实日期，**时钟落后于它时 PAM 会拒绝
   登录**：`pam_unix(sshd:account): account amp_admin has password changed in
   future` → 登录报 `Authentication failed`，持续一两分钟，时钟追上就好。
   同一段时间里也会出现 `Connection reset by peer`（sshd 先接受 TCP 再重置）
2. **AMP 没有崩**：所有 AMP 服务 `NRestarts=0`，DUT 也没重启（uptime 一直在
   走）。掉的是 SSH 会话，不是 AMP 进程。

改了两处（`lib/Viper/ViperSSH.py`、`lib/Viper/ViperGnmi.py`）：

1. **connect 重试 ~2 分钟**（6 次 × 20 s）：以前一次失败就整条 suite 挂在
   setup 上（`Parent suite setup failed`）。覆盖 PAM 拒绝登录的那一两分钟
2. **命令重试一次**：会话在命令执行途中被掐断时，重建会话并把那条命令再发
   一次（人也是这么干的）。**`reset` 不重发**——重发会重启两次

ALN-005-4 在这两处改之前连挂三次（第一次是 setup 连不上，后面两次是会话
被掐断），改完之后 4/4 通过。

### ALN-009 — ALIGNMENT | gNMI DS1 Alignment

**目的与模板**：通过 gNMI SET 触发 DS1，订阅
`amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]/alignment-status`，
成功时依次收到 `ALIGN_STATUS_IN_PROGRESS` 和 `ALIGN_STATUS_ALIGNED`；
模板还要求失败时报告 `ALIGN_STATUS_FAILURE`。

**实机测试（2026-11-23，.233，HW 06.05 / SW 00.04.006）**：

1. 测试前五个 stage 均无 IN_PROGRESS；DS1、DS2、DS3、US 均为 ALIGNED，
   NETWORK 为 UNALIGNED。
2. 先订阅并收到 `sync-response: true`，SET DS1 的响应包含目标路径和
   `operation: UPDATE`。
3. 订阅收到 IN_PROGRESS，再收到 ALIGNED，两次通知相隔约 16 秒。
4. DS1 触发后 DS2、DS3、US 变为 UNALIGNED，并未自动完成。用户决定不做
   额外自动标定，测试结束时保留此状态。与旧的自动串行记录不同，原因未确认。

**脚本和结果**：`IT/_generator/sheet_alignment.py` 生成 ALN-009，新增
`ViperGnmi` 的 ON_CHANGE 订阅、同步和读取功能。用例断言同步、SET 响应的
operation 和路径、订阅状态顺序；FAILURE 不会被当作通过。失败状态本次没有
人为制造，模板的失败场景尚未实测。订阅在 teardown 关闭，实机检查没有遗留
订阅进程。

`.233` 上 Robot **1/1 通过**，证据在
`result/aln009_233_20261123/`。本地单元测试 3/3 通过；全树 dry run 通过，
静态分析仍为 151 文件、0 errors、17 warnings、27 hints（与基线一致）。
DUT 自身时间是 1970 年，订阅时间仅用于计算间隔，不代表实际日期。

### ALN-009 ~ ALN-013 — gNMI Alignment 批次复核

**目的与步骤**：009~012 分别对 DS1、DS2、DS3、US 启动同步后的
ON_CHANGE 订阅、SET 对应 stage，验证 SET 响应路径和 UPDATE，再验证
IN_PROGRESS 后最终 ALIGNED。后续 stage 在 SET 前检查前序 stage 已
ALIGNED；失败状态不能作为通过。013 GET 根容器及五个 stage 的容器、
状态和更新时间，共 16 条路径；检查五种类型恰好各一项、状态枚举、
容器与叶值一致、非空时间为 ISO 时间，ALIGNED 不允许空时间。

**2026-11-23 .233 实机结果**（最终批次
`result/aln009_013_233_20261123b`，6/6 通过）：

| 项 | SET 后订阅结果 | IN_PROGRESS 到 ALIGNED | Robot 用例总耗时 |
| --- | --- | --- | --- |
| ALN-009 DS1 | IN_PROGRESS → ALIGNED | 约 15.9 s | 19.1 s |
| ALN-010 DS2 | IN_PROGRESS → ALIGNED | 约 5.9 s | 9.2 s |
| ALN-011 DS3 | 多次 IN_PROGRESS → ALIGNED | 约 46.2 s | 50.6 s |
| ALN-012 US | IN_PROGRESS → ALIGNED | 约 46.6 s | 51.0 s |
| ALN-013 | 16 条 GET 全部通过；NETWORK 时间为空 | — | 0.8 s + 9.4 s |

首次批次 `result/aln009_013_233_20261123` 中，009/010 通过，011
收到第二条 IN_PROGRESS 时旧断言错误地当成终态并失败；启用的
`--exitonfailure` 阻止了后续 SET。修正后允许重复 IN_PROGRESS，并使用
总计 300 秒的截止时间等待 ALIGNED；FAILURE 和其他状态立即失败。
本地模拟测试覆盖了重复 IN_PROGRESS 和 FAILURE；**没有在设备上制造失败**。

**测试后的设备状态**：DS1、DS2、DS3、US 均为 ALIGNED，NETWORK 为
UNALIGNED；测试依次执行了实际标定，标定数据可能已变化。设备时间仍为
1970 年，表中的阶段间隔来自通知时间差。全树 dry run 325/325，通过；相关本地自动测试 8/8 通过，覆盖重复状态、
失败状态、类型重复和非法时间；静态分析仍为 151 文件、0 errors、
17 warnings、27 hints。

### ALN-014 — gRPC Calibration Service

**目的与步骤**：通过 `Calibration.StartCalibration` 分别执行 AUTO、
SEMI_AUTO（从 DS1）和 MANUAL（仅 DS1），验证流中的阶段顺序及最终
SUCCESS；SEMI_AUTO 若返回有效的人工调整，则验证调整对应当前阶段并
停止后续自动校准。`GetCalibrationStatus` 校验 success、四个阶段的状态
和返回的人工调整数据。该项会实际标定并可能改变标定数据。

**2026-11-23 .233（UNIFIED_LE，00.04.006）实机**：

| 模式 | 结果 | 用时 |
| --- | --- | --- |
| AUTO | DS1 → DS2 → DS3 → US1，SUCCESS | 118.9 s |
| SEMI_AUTO DS1 | DS1 → DS2 → DS3 → US1，SUCCESS；没有人工调整 | 115.9 s |
| MANUAL DS1 | 仅 DS1，SUCCESS | 16.6 s |
| GetCalibrationStatus | SUCCESS，四个阶段及状态有效 | 0.2 s |

首次运行 `result/aln014_233_20261123_141043/` 中 AUTO、SEMI_AUTO 和
状态通过，但保护条件错误地把 `default=False` 作为非空字符串，导致
MANUAL 被跳过。修正并添加真假两种保护条件测试后，仅补跑 MANUAL 和
状态，均通过：`result/aln014_manual_233_20261123_141547/`。因此是
**四项分两次通过**，不是一次完整运行 4/4。

之后加强了保护条件：AUTO 或 SEMI_AUTO 尚未成功完成、发生异常或需要
人工调整时，不会继续启动后续校准。最终脚本的保护逻辑通过本地模拟
测试，未再重复 AUTO/SEMI_AUTO 的实机写入。人工调整分支和失败分支未在
设备上制造；其流解析、失败拒绝和后续校准保护已用本地模拟测试。
日志可能包含设备登录信息，分享前需脱敏。

**当前脚本完整实机复测**：`result/aln014_233_full_20261123_142331/`
4/4 通过；AUTO 116.3 s、SEMI_AUTO 118.3 s、MANUAL DS1 16.4 s、
状态查询 0.2 s。SEMI_AUTO 完整运行并成功，未触发人工调整。失败和
人工调整分支仍未实机覆盖。

**测试后的设备状态**：独立查询显示 DS1 ALIGNED，DS2、DS3、US1
UNALIGNED；MANUAL DS1 导致后续阶段失效，可能改变了标定数据。没有
额外执行标定恢复。全树 dry run 327/327；本地相关单元测试 19/19；
RobotCode 151 文件、0 errors、17 warnings、27 hints。

### ALN-015 — Calibration Control Flags

**目的与步骤**：核对四个 RF board 标志、station mode、NAFE ratio 和
single-mode gain delta 的 set/get。模板预期提到 gain delta 对 legacy RLSP
精度的影响，但操作步骤没有给出验证方法或判定标准；按用户要求本套件只
验证 set/get，不验证该影响。逐项保存原值、写入和读回，失败时也在
FINALLY 中恢复并核对；这些全局设置测试期间不应并发标定或由其他人修改。

**2026-11-23 .233（UNIFIED_LE，00.04.006）实机**：
`result/aln015_233_20261123_135618/` 中 4 通过、2 跳过，Robot 将
含跳过用例的 suite 显示为 PASS，**不等于模板全部通过**。

| 操作 | 测试与恢复结果 | 耗时 |
| --- | --- | --- |
| RF board 四个标志 | 四项写 1 并读回；ignore NP DS 额外写 0；逐项恢复成功 | 2.76 s |
| station mode | with_cable_sim、normal 均读回，恢复原值 normal | 0.88 s |
| NAFE ratio | 写 3 并读回，恢复精确值 0.0078125 | 0.91 s |
| gain delta（`sc_cli` 替代命令） | 写 1 并读回，恢复精确值 2.5247283426016978 | 0.89 s |
| gain delta（模板的 `sc_rfboard_cli`） | 命令不在 usage 中，跳过，未执行 SET | 0.13 s |
| gain delta 对 legacy RLSP 精度的影响 | 原运行中占位用例跳过；现按用户要求删除，未验证 | — |

模板的 RF board 命令检查后来补充了对 set/get 均不在 usage 的断言，
只读复测为 SKIP，结果在 `result/aln015_command_233_20261123_135719/`。
原运行的第 6 个占位用例后来删除；随后按用户决定去掉模板 RF board
命令的检查，gain delta 改以 `sc_cli` set/get 为测试范围。
模板及 User Guide 10.12 使用 `sc_rfboard_cli`，实际版本支持的替代命令
是 `sc_cli`，不能以替代命令通过代替模板命令通过。

测试前后独立核对四个标志分别为 1、0、0、0，station mode 为 normal，
两个浮点数与上表一致；nonvol 文件中 ratio、gain delta 和 station mode
也已确认恢复。CLI 浮点 GET 仅显示六位小数，因此脚本用设备的
`libsc_nonvol_get_number` 读取运行态双精度原值并精确核对恢复；依赖 DUT
的 Python 和 `/usr/lib/libsc_cfg.so.1`。异常时恢复失败会导致测试失败，
但进程被强制终止或连接中断无法保证恢复，应人工复核。

本地相关单元测试 11/11 通过，包括 SET 失败后恢复和恢复失败的模拟；
全树 dry run 328/328，RobotCode 151 文件、0 errors、17 warnings、
27 hints。测试结果日志可能包含设备登录信息，分享前需脱敏。

**先前 5 用例脚本实机复测**：`result/aln015_233_full_20261123_142819/`
为 4 通过、1 跳过；跳过的是模板指定但设备不支持的 RF board gain
delta 命令。测试前后独立核对四个标志为 1、0、0、0，station mode 为
normal，ratio 为 0.0078125，gain delta 为 2.5508488016673958，均恢复
至 ALN-015 测试前的值。该 gain delta 与之前实测记录的
2.5247283426016978 不同；本次是在 ALN-014 实际标定之后读取的，
ALN-015 的恢复以其测试前值为准。等待 nonvol 写入后也核对了文件中的
ratio、gain delta 和 station mode；`jq` 显示的 gain delta 尾数四舍五入
为 2.550848801667396，与运行态值是同一个 IEEE-754 双精度数。

**按用户决定改用 sc_cli 后的实机复测**：当前脚本删除了 RF board
gain delta 命令检查，使用 `sc_cli set_single_mode_gain_delta` 和
`sc_cli get_single_mode_gain_delta`。`result/aln015_sc_cli_233_20261123_143818/`
4/4 通过、无跳过；四个标志、station mode、ratio 和 gain delta
经独立查询均恢复到测试前值，nonvol 文件中的 station mode、ratio 和
gain delta 也已核对。全树 dry run 326/326，RobotCode
151 文件、0 errors、17 warnings、27 hints。测试范围为 SET/GET，
不包含 legacy RLSP 精度测量。

### ALIGNMENT 全量实机运行和脚本复核（2026-11-23）

用户确认 `.233` 可重启并重新配置，台架条件就绪；ALN-007 的人工
RLSP 测量和用例 6 按用户要求不执行。本轮其余 **100 个用例最终均被
Robot 报为通过**，但不能称为 101/101 全部通过；进一步检查命令日志
发现其中存在假通过，详见下方。

| 结果目录 | 范围和结果 |
| --- | --- |
| `result/alignment_001_006_233_20261123_144518/` | 001～004 共 43/43、005 前 15 项通过；005-16 执行约 13 s 后收到中断信号，输出误报等待 prompt 超时；exit-on-failure 阻止后续写入，006 的 17 项被标为失败但并未执行 |
| `result/alignment_005_resume_006_233_20261123_152924/` | 005 的 16～17 项 2/2 通过；006 全部 17/17 通过 |
| `result/alignment_007_no_manual_233_20261123_154427/` | 007 前 5 项 5/5 通过；第 6 项未选择、未执行 |
| `result/alignment_008_015_233_20261123_154506/` | 008～015 共 18/18 通过 |

测试后独立查询：DS1 ALIGNED、DS2/DS3/US1 UNALIGNED，eCM Operational，
工厂 offset 恢复为 13.5；lineup 和校准数据按测试流程已被更改，没有
额外执行标定恢复。日志可能含设备登录信息，分享前需脱敏。

**当时复核的问题**（修复状态见后续记录）：

1. `_ds_profile_case` 用 DS end frequency 作为 step-down start frequency。
   004 模板要求 1002000000，脚本写 1218000000；005/006 模板要求
   1002000000，脚本写 1098000000。用例也未核对 step-down 值。
2. 007 的原始 offset 正则不包含负号，`-1.5` 会被读成 `1.5` 并在 teardown
   写回；teardown 虽读取但不断言恢复值。本次原值是正数 13.5，已核对恢复。
3. 002～006 的 DS profile 和 spectrum 测试只断言少数频率/文本，未核对
   profile 功率、扩展上行范围及各 subband 模式等关键配置，可能假通过。
4. 002/003 的各阶段启动命令输出未断言，仅检查最终状态；旧状态已
   ALIGNED 时即使命令失败也可能通过。004～006 的 legacy RLSP SET 也
   未检查返回或读回。
5. 004～006 的 NAFE 用例将 ignore NP DS 标志置 1 后，若校准或断言失败，
   不会执行后续置 0 的步骤，可能把设备留在错误状态。

**进一步核对实机命令日志**：004-4、005-4、006-4 的三条 subband 设置
均返回 `path not found`、`failed to set`，各次 `commit` 均返回
`failed to apply local configuration`，之后 `show configuration` 的
本地配置均显示 `Total subbands 0`。但测试只检查少量频率字符串，三项
均被 Robot 标为 PASS，不能视为配置成功。003 的日志此前显示删除了三个
subband，004 开始时相应条目不存在；需要进一步确认正确的创建和提交
流程，不能仅凭本地配置推断设备最终运行态。

004～006 的 north 和 south profile 日志中，提交后的 step-index 0
频率与脚本所设值一致，但与模板的 1002000000 不一致。004～006 的
NAFE 日志均显示 `calib_nafe success`，并读回 ignore 标志为 0；上述
NAFE 恢复问题是失败路径风险，不是本轮发生的失败。

### ALIGNMENT 复核问题修复（2026-11-23）

- 002～006 的南北 DS profile 使用模板的 step-down 1002000000 Hz，
  并核对名称、起止频率、起止功率、step-down 频率和大小及 commit。
- 002/004～006 的 spectrum 核对六个频率、三个 subband、所需的
  exclusion 字段及 commit 返回；003 的 spectrum 增加 commit 断言。
  004～006 的 FDX 和 legacy RLSP 均核对 commit/SET 和两个端口读回。
  配置失败时同一 suite 的后续依赖步骤跳过，避免在错误 lineup 上标定。
- 007 原始 offset 改为保留完整字符串、校验有限数，并在 suite teardown
  写回后校验；本地模拟覆盖负数和恢复失败。NAFE 的 ignore 标志增加
  `FINALLY` 恢复及读回检查。002/003 的各 alignment 启动命令增加
  完成结果检查。
- 修复后 `.robot` 从生成器重新生成；本地单元测试 25/25，全树 dry run
  326/326，RobotCode 151 文件、0 errors、17 warnings、27 hints。

**Spectrum 台架前置条件及修复**：此前只读查询 `.233` 的运行态是
`Legacy_MidSplit_DS_1.2GHz`，扩展上行 0/0、subband 数量 0，而非之前
误述的 ALN-006 spectrum。003 本身会删除三个 subband；手册不推荐
`subband add`。用户明确选择允许使用该命令；手动探测三次添加后本地
配置显示索引 0/1/2，探测未 commit。002/004～006 脚本现会按缺少的
数量添加，添加前检查已有索引、拒绝超过三个且不删除多余条目；设置
后在 commit 前及之后检查各字段，任何失败都会阻止后续依赖步骤。

**修复后定向实机验证**：

- `result/alignment_profile_rlsp_fix_233_20261123/`：004～006 的南北
  profile 和 RLSP 共 9/9 通过；包含 step-down 1002000000 Hz、功率、
  profile 频率及两个端口 legacy RLSP 的读回检查。测试改变了 profile
  和 RLSP，最后保留 006 的 profile；未重启或执行标定。
- `result/alignment_spectrum_guard_233_20261123/`：只运行 004-4，按预期
  报 FAIL（当前 subband 数量为 0）；实际只读了 `show configuration`，
  已退出 spectrum view，未发送设置或 commit。随后独立查询运行态仍为
  `Legacy_MidSplit_DS_1.2GHz`，subband 数量 0。这是前置条件检查的
  预期失败，不是 spectrum 配置成功；该记录产生于用户批准添加之前。
- `result/alignment_spectrum_add_233_20261123/`：004-4、005-4、006-4
  依次 3/3 通过。004 从 0 条开始实际添加三条 `bidi`，三个测试的
  SET、commit 以及 commit 前后的本地字段检查均通过。测试后独立查询
  运行态为 006 的 108～396 MHz 扩展上行、3 个 subband
  `[1,1,1]`、383～396 MHz 排除（DS PASS_OTHER / US EXCLUDED）。
  此次没有重启或运行标定；需要完整重跑才能判定整个 ALIGNMENT。

### ALN-007 标定日志关联修复（2026-11-23）

007-3 在启动 legacy US 标定前记录 journald cursor，成功后立即读取该
cursor 之后的 `sc_alignment` JSON 日志，要求恰好一条 `ExecutePostUs1`
的 eCM 数据记录，并保存给 007-4。007-4 断言 `isCmOperational=1`，
再检查同一条记录的功率窗口；缺少、重复或无法解析日志、标定失败、
没有执行 007-3 等均不能通过。运行时仍要求台架上没有并发标定。

首次定向实机运行 `result/aln007_journal_fix_233_20261123/` 中，设备
在交互终端为 JSON 加了颜色，007-3 正确报错，007-4 被 exit-on-failure
阻止；offset 已恢复。加入 `SYSTEMD_COLORS=0` 后，
`result/aln007_journal_fix_retry_233_20261123/` 的 007-1～4 **4/4
通过**。本次记录 `isCmOperational=1`，两路 TX power 均为
29.9794 dBmV，窗口为 17.25～52.75 dBmV。实测后独立核对 offset
13.5、eCM Operational、JXP tilt 3（测试前也是 3）；实际标定可能改变
其他标定数据。没有执行需要人工偏差的 007-6。

本地 26/26 通过，覆盖旧日志、非 Operational、多条日志、无效 cursor、
日志读取和标定失败；全树 dry run 326/326，RobotCode 151 文件、
0 errors、17 warnings、27 hints。
