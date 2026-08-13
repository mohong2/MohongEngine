# 基准数据（交付物 5）

> 环境：Windows 10/11 本机，debug 构建（hxcpp MSVC，HXCPP_GC_BIG_BLOCKS）。
> 测试曲：mod "PE0.7.3重构)Daisuka-Desu" 的 Daisuka-Desu (hard)，163 BPM，谱面 1429 notes，约 160s。
> 帧时间来自 MemoryMonitor（stage ENTER_FRAME 采样）；渲染段来自 RenderOptimizer（preDraw→postDraw）。

## 1. after（全部修复，seek 模式，3 次重试，2026 实测）

| 快照 | 内存 | 峰值 | 缓存图 | 存活追踪 | 帧时间 p50/p95/p99 | 渲染段 p50/p95 | 可见精灵 | Note 池 |
|---|---|---|---|---|---|---|---|---|
| songEnd #1 | 408MB | 428MB | 86 | 23 | 4/5/9 ms | 1/1 ms | 34 | created=1429 borrowed=1429 returned=0 |
| songEnd #2 | 410MB | 498MB | 91 | 23 | 4/5/6 ms | 1/1 ms | 35 | created=2858 borrowed=2858 |
| songEnd #3 | 414MB | 503MB | 97 | 23 | 4/6/7 ms | 1/1 ms | 35 | created=4287 borrowed=4287 |

- 内存曲线：408→410→414 MB（每轮 +2~6MB，缓增）；峰值受 seek 帧 catch-up（一次性生成 1400+ overdue notes）影响冲高。
- 帧时间 p50≈4ms（≈250fps 上限区间），**不再被 60Hz 锁死**——P0-1 修复的直接证据。
- 池在 seek 模式下复用率为 0（seek 导致 overdue notes 全部生成+销毁），见 noseek 模式数据。

## 2. before / after（全曲模式，3 次重试）

（运行后回填）

## 3. 验收长跑（20 次重试 + 菜单往返）

（运行后回填）

## 4. GC / 卡顿观测

（运行后回填）
