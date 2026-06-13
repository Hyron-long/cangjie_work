# MultiButton 仓颉语言移植

> **源项目地址：** [https://github.com/0x1abin/MultiButton.git](https://github.com/0x1abin/MultiButton.git)
>
> **Cangjie Language Port of [0x1abin/MultiButton](https://github.com/0x1abin/MultiButton)**  
> 一个紧凑灵活的嵌入式多按钮事件驱动库，基于有限状态机实现按键消抖与多种事件检测。

## 1. 项目介绍

MultiButton 是一个嵌入式按钮状态机库，原生使用 C 语言编写。本项目将其完整移植到**仓颉（Cangjie）编程语言**，在保持核心行为 100% 一致的前提下，利用仓颉的类型系统实现了更强的空安全与类型安全。

### 核心特性

- **事件驱动**：支持 7 种按钮事件（按下、释放、单击、双击、长按开始、长按保持、连击）
- **状态机架构**：5 状态有限状态机（IDLE → PRESS → RELEASE → REPEAT → LONG_HOLD）
- **硬件消抖**：可配置的消抖采样深度，过滤 GPIO 噪声
- **多按钮支持**：基于链表管理，支持无限数量按钮同时工作
- **类型安全**：仓颉的 `Option<T>` 替代 C 语言的空指针，编译期消除 NPE
- **接口回调**：基于 `interface` 的事件回调机制，比 C 函数指针更安全灵活

### 状态机

```
                         +-- 超长按 --> [LONG_HOLD]
                         |                  |
 [IDLE] -- 按下 --> [PRESS]              释放
    ^                  |                    |
    |              释放                     |
    |                  v                    |
    |             [RELEASE] <--------------+
    |             |       ^
    |       超时   |       | 快速再按
    |             |       |
    +-------------+   [REPEAT] -- 按住过久 --> [PRESS]
```

## 2. 项目结构

```
MultiButton_cj/
├── README.md                      # 项目说明（本文件）
├── 仓颉语言移植指南.md              # 完整移植指南与设计文档
├── cjpm.toml                      # 仓颉包管理配置
├── src/
│   ├── main.cj                    # 程序入口 + 自测程序（16项测试）
│   ├── lib.cj                     # 库入口
│   ├── button_config.cj           # 可配置常量（消抖、超时阈值等）
│   ├── button_types.cj            # 事件枚举 / 状态枚举定义
│   ├── multi_button.cj            # 核心实现（ButtonBase 类、状态机、公有 API）
│   └── hal/
│       └── gpio_hal.cj            # HAL 抽象接口（GpioReader）
├── test/
│   └── test_button.cj             # 单元测试（待扩展）
└── examples/
    ├── basic_example.cj           # 回调模式示例（待扩展）
    ├── poll_example.cj            # 轮询模式示例（待扩展）
    └── advanced_example.cj        # 高级多按钮示例（待扩展）
```

## 3. 接口说明

### 3.1 配置常量 (`button_config.cj`)

| 常量 | 值 | 说明 |
|-----|----|------|
| `TICKS_INTERVAL` | `5` | 定时器中断间隔（毫秒） |
| `DEBOUNCE_TICKS` | `3` | 消抖采样深度（最大 7） |
| `SHORT_TICKS` | `60` | 短按超时阈值（tick 数， = 300ms / 5ms） |
| `LONG_TICKS` | `200` | 长按触发阈值（tick 数， = 1000ms / 5ms） |
| `PRESS_REPEAT_MAX_NUM` | `15` | 最大连击计数 |

### 3.2 事件类型 (`button_types.cj`)

```cangjie
enum ButtonEvent {
    | PRESS_DOWN       // 按钮按下
    | PRESS_UP         // 按钮释放
    | PRESS_REPEAT     // 重复按下（连击）
    | SINGLE_CLICK     // 单击（超时确认后）
    | DOUBLE_CLICK     // 双击（超时确认后）
    | LONG_PRESS_START // 长按开始（仅触发一次）
    | LONG_PRESS_HOLD  // 长按保持（每个 tick 触发）
    | NONE_PRESS       // 无事件
}
```

### 3.3 状态类型 (`button_types.cj`)

```cangjie
enum ButtonState {
    | IDLE       // 空闲
    | PRESS      // 按下
    | RELEASE    // 释放（等待超时）
    | REPEAT     // 重复按下
    | LONG_HOLD  // 长按保持
}
```

### 3.4 BtnCallback 接口 (`multi_button.cj`)

```cangjie
interface BtnCallback {
    func onEvent(btn: ButtonBase): Unit
}
```

实现此接口以接收按钮事件回调。`btn` 参数包含当前按钮的完整状态（`event`、`repeat`、`buttonId` 等）。

### 3.5 ButtonBase 类 (`multi_button.cj`)

| 属性 | 类型 | 说明 |
|-----|------|------|
| `buttonId` | `Int64` | 按钮唯一标识 |
| `state` | `ButtonState` | 当前状态机状态 |
| `event` | `ButtonEvent` | 最近触发的事件 |
| `ticks` | `Int64` | tick 计数器（最大 65535） |
| `repeat` | `Int64` | 连击计数器（0-15） |
| `debounceCnt` | `Int64` | 消抖计数器（0-7） |
| `activeLevel` | `Int64` | 有效电平（0 = 低有效，1 = 高有效） |
| `buttonLevel` | `Int64` | 当前按键电平 |
| `callbacks` | `Array<Option<BtnCallback>>` | 事件回调数组 |

### 3.6 公有 API

| 函数 | 签名 | 说明 |
|-----|------|------|
| `buttonStart` | `(handle: Option<ButtonBase>) -> Int64` | 激活按钮。返回 0 = 成功，-1 = 已存在，-2 = 无效参数 |
| `buttonStop` | `(handle: Option<ButtonBase>) -> Unit` | 停用按钮，从活跃列表移除 |
| `buttonTicks` | `() -> Unit` | 驱动所有活跃按钮（每个 tick 调用一次，通常 5ms） |
| `buttonAttach` | `(handle, event, callback) -> Unit` | 注册事件回调 |
| `buttonDetach` | `(handle, event) -> Unit` | 移除事件回调 |
| `buttonGetEvent` | `(handle) -> ButtonEvent` | 获取当前事件 |
| `buttonGetRepeatCount` | `(handle) -> Int64` | 获取连击计数 |
| `buttonReset` | `(handle) -> Unit` | 重置按钮到空闲状态 |
| `buttonIsPressed` | `(handle) -> Int64` | 检查是否按下。返回 1 = 按下，0 = 未按，-1 = 错误 |

### 3.7 GpioReader 接口 (`hal/gpio_hal.cj`)

```cangjie
interface GpioReader {
    func readLevel(pin: Int64): Int64
}
```

嵌入式平台需实现此接口以对接具体的 GPIO 硬件。

### 3.8 GPIO 读取函数类型 (`multi_button.cj`)

```cangjie
type GpioReadFunc = (Int64) -> Int64
```

用于桌面测试/模拟环境的轻量级 GPIO 读取函数类型，参数为 `buttonId`，返回 0 或 1。

## 4. 使用说明

### 4.1 环境要求

- 仓颉工具链 ≥ 1.0.5（`cjc`、`cjpm`）
- macOS / Linux（桌面测试）
- 嵌入式目标平台（ARM MCU 等，需 HAL 适配）

### 4.2 构建与运行

```bash
# 进入项目目录
cd MultiButton_cj

# 编译
cjpm build

# 运行自测程序
cjpm run
```

### 4.3 基本使用流程

```
1. 定义 GPIO 读取函数
       ↓
2. 创建 ButtonBase 实例
       ↓
3. 实现 BtnCallback 接口
       ↓
4. 用 buttonAttach() 注册回调
       ↓
5. 用 buttonStart() 激活按钮
       ↓
6. 在定时器中断中周期性调用 buttonTicks()
       ↓
7. 用 buttonStop() 停用按钮
```

## 5. 功能示例

### 5.1 回调模式（完整示例）

```cangjie
package MultiButton_cj

// ---- GPIO 模拟 ----
var btnPin: Int64 = 0

func readGpio(_: Int64): Int64 {
    return btnPin
}

// ---- 回调实现 ----
class MyCallback <: BtnCallback {
    public override func onEvent(btn: ButtonBase): Unit {
        match (btn.event) {
            case ButtonEvent.PRESS_DOWN => println("按下")
            case ButtonEvent.PRESS_UP => println("释放")
            case ButtonEvent.SINGLE_CLICK => println("单击")
            case ButtonEvent.DOUBLE_CLICK => println("双击")
            case ButtonEvent.LONG_PRESS_START => println("长按开始")
            case ButtonEvent.LONG_PRESS_HOLD => println("长按持续...")
            case ButtonEvent.PRESS_REPEAT =>
                println("连击 x${buttonGetRepeatCount(Some(btn))}")
            case _ => {}
        }
    }
}

// ---- 主程序 ----
main(): Int64 {
    // 1. 创建按钮（高电平有效，ID=1）
    let btn = ButtonBase(Some(readGpio), 1, 1)

    // 2. 创建回调并注册
    let cb = MyCallback()
    let events = [
        ButtonEvent.PRESS_DOWN, ButtonEvent.PRESS_UP,
        ButtonEvent.SINGLE_CLICK, ButtonEvent.DOUBLE_CLICK,
        ButtonEvent.LONG_PRESS_START, ButtonEvent.LONG_PRESS_HOLD,
        ButtonEvent.PRESS_REPEAT
    ]
    for (ev in events) {
        buttonAttach(Some(btn), ev, Some(cb))
    }

    // 3. 激活按钮
    buttonStart(Some(btn))

    // 4. 模拟操作序列（嵌入式环境替换为 5ms 定时器中断）
    // ---- 单击 ----
    btnPin = 1
    doTicks(DEBOUNCE_TICKS + 10)  // 按下
    btnPin = 0
    doTicks(DEBOUNCE_TICKS + SHORT_TICKS + 10)  // 释放

    // ---- 双击 ----
    btnPin = 1
    doTicks(DEBOUNCE_TICKS + 8)
    btnPin = 0
    doTicks(DEBOUNCE_TICKS + 3)
    btnPin = 1
    doTicks(DEBOUNCE_TICKS + 8)
    btnPin = 0
    doTicks(DEBOUNCE_TICKS + SHORT_TICKS + 10)

    // ---- 长按 ----
    btnPin = 1
    doTicks(DEBOUNCE_TICKS + LONG_TICKS + 30)
    btnPin = 0
    doTicks(DEBOUNCE_TICKS + 10)

    // 5. 停用
    buttonStop(Some(btn))
    return 0
}

func doTicks(n: Int64): Unit {
    var i = 0
    while (i < n) {
        buttonTicks()
        i += 1
    }
}
```

### 5.2 轮询模式

不注册回调，直接在主循环中轮询事件：

```cangjie
main(): Int64 {
    let btn = ButtonBase(Some(readGpio), 1, 1)
    buttonStart(Some(btn))

    var lastEvent = ButtonEvent.NONE_PRESS
    while (true) {
        buttonTicks()

        let current = buttonGetEvent(Some(btn))
        match (current) {
            case e if (e != lastEvent && e != ButtonEvent.NONE_PRESS) => {
                // 处理事件...
                lastEvent = e
            }
            case _ => {}
        }

        // sleep(5)  // 5ms 周期
    }
    return 0
}
```

### 5.3 多按钮管理

```cangjie
let btn1 = ButtonBase(Some(readGpio1), 0, 1)  // ID=1, 低电平有效
let btn2 = ButtonBase(Some(readGpio2), 0, 2)  // ID=2, 低电平有效
let btn3 = ButtonBase(Some(readGpio3), 1, 3)  // ID=3, 高电平有效

buttonAttach(Some(btn1), ButtonEvent.SINGLE_CLICK, Some(cb1))
buttonAttach(Some(btn2), ButtonEvent.DOUBLE_CLICK, Some(cb2))
buttonAttach(Some(btn3), ButtonEvent.LONG_PRESS_START, Some(cb3))

buttonStart(Some(btn1))
buttonStart(Some(btn2))
buttonStart(Some(btn3))

// 在 5ms 定时器中断中：
// buttonTicks()  // 一次调用驱动所有活跃按钮
```

### 5.4 嵌入式平台适配

```cangjie
// 实现 GpioReader 接口对接硬件
class Stm32Gpio <: MultiButton_cj.hal.GpioReader {
    public func readLevel(pin: Int64): Int64 {
        // return HAL_GPIO_ReadPin(gpioPort, gpioPin) as Int64
        return 0
    }
}

// 在 5ms SysTick 中断服务函数中调用：
// MultiButton_cj.buttonTicks()
```

## 6. 移植对照

| 原 C API | 仓颉 API | 变化 |
|---------|---------|------|
| `button_init(&btn, fn, 0, 1)` | `ButtonBase(pinLevel, activeLevel, buttonId)` | 构造函数替代 |
| `button_attach(&btn, EV, cb, NULL)` | `buttonAttach(Some(btn), EV, Some(cb))` | Option 替代空指针 |
| `button_start(&btn)` | `buttonStart(Some(btn))` | 传引用不传指针 |
| `button_ticks()` | `buttonTicks()` | 命名风格统一 |
| `handle->event` | `btn.event` | 点访问替代箭头 |
| `NULL` 检查 | `None` 模式匹配 | 编译期安全检查 |

## 7. 许可

MIT License — 与原项目保持一致。
