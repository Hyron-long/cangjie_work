// MultiButton 核心实现
package MultiButton_cj
import std.collection.*

// ============================================================
// 事件回调接口
// ============================================================

interface BtnCallback {
    func onEvent(btn: ButtonBase): Unit
}

// ============================================================
// HAL GPIO 读取函数类型
// ============================================================

type GpioReadFunc = (Int64) -> Int64

// ============================================================
// ButtonBase — 基类
// ============================================================

open class ButtonBase {
    var ticks: Int64 = 0
    var repeat: Int64 = 0
    var event: ButtonEvent = ButtonEvent.NONE_PRESS
    var state: ButtonState = ButtonState.IDLE
    var debounceCnt: Int64 = 0
    var activeLevel: Int64 = 0
    var buttonLevel: Int64 = 0
    var buttonId: Int64 = 0
    var halButtonLevel: Option<GpioReadFunc> = None
    var next: Option<ButtonBase> = None

    init(
        pinLevel: Option<GpioReadFunc>,
        activeLevel: Int64,
        buttonId: Int64
    ) {
        this.buttonLevel = if (activeLevel == 0) { 1 } else { 0 }
        this.halButtonLevel = pinLevel
        this.activeLevel = activeLevel
        this.buttonId = buttonId
        this.state = ButtonState.IDLE
        this.event = ButtonEvent.NONE_PRESS
        this.callbacks = Array<Option<BtnCallback>>(EVENT_COUNT, { _ => None })
    }

    var callbacks: Array<Option<BtnCallback>>

    public func reset(): Unit {
        this.state = ButtonState.IDLE
        this.ticks = 0
        this.repeat = 0
        this.event = ButtonEvent.NONE_PRESS
        this.debounceCnt = 0
    }
}

// ============================================================
// 按钮链表管理
// ============================================================

var activeButtons: ArrayList<ButtonBase> = ArrayList<ButtonBase>()

// ============================================================
// 内部辅助函数
// ============================================================

func readButtonLevel(handle: ButtonBase): Int64 {
    match (handle.halButtonLevel) {
        case Some(fn) => fn(handle.buttonId)
        case None => 0
    }
}

func fireCallback(handle: ButtonBase, event: ButtonEvent): Unit {
    let idx = eventIndex(event)
    if (idx >= 0 && idx < handle.callbacks.size) {
        match (handle.callbacks[idx]) {
            case Some(cb) => cb.onEvent(handle)
            case None => return
        }
    }
}

func isStateIdle(state: ButtonState): Bool {
    match (state) {
        case ButtonState.IDLE => true
        case _ => false
    }
}

// ============================================================
// 状态机处理器
// ============================================================

func handleIdleState(handle: ButtonBase): Unit {
    if (handle.buttonLevel == handle.activeLevel) {
        handle.event = ButtonEvent.PRESS_DOWN
        fireCallback(handle, ButtonEvent.PRESS_DOWN)
        handle.ticks = 0
        handle.repeat = 1
        handle.state = ButtonState.PRESS
    } else {
        handle.event = ButtonEvent.NONE_PRESS
    }
}

func handlePressState(handle: ButtonBase): Unit {
    if (handle.buttonLevel != handle.activeLevel) {
        handle.event = ButtonEvent.PRESS_UP
        fireCallback(handle, ButtonEvent.PRESS_UP)
        handle.ticks = 0
        handle.state = ButtonState.RELEASE
    } else if (handle.ticks > LONG_TICKS) {
        handle.event = ButtonEvent.LONG_PRESS_START
        fireCallback(handle, ButtonEvent.LONG_PRESS_START)
        handle.state = ButtonState.LONG_HOLD
    }
}

func handleReleaseState(handle: ButtonBase): Unit {
    if (handle.buttonLevel == handle.activeLevel) {
        handle.event = ButtonEvent.PRESS_DOWN
        fireCallback(handle, ButtonEvent.PRESS_DOWN)
        if (handle.repeat < PRESS_REPEAT_MAX_NUM) {
            handle.repeat += 1
        }
        handle.event = ButtonEvent.PRESS_REPEAT
        fireCallback(handle, ButtonEvent.PRESS_REPEAT)
        handle.ticks = 0
        handle.state = ButtonState.REPEAT
    } else if (handle.ticks > SHORT_TICKS) {
        if (handle.repeat == 1) {
            handle.event = ButtonEvent.SINGLE_CLICK
            fireCallback(handle, ButtonEvent.SINGLE_CLICK)
        } else if (handle.repeat == 2) {
            handle.event = ButtonEvent.DOUBLE_CLICK
            fireCallback(handle, ButtonEvent.DOUBLE_CLICK)
        }
        handle.state = ButtonState.IDLE
    }
}

func handleRepeatState(handle: ButtonBase): Unit {
    if (handle.buttonLevel != handle.activeLevel) {
        handle.event = ButtonEvent.PRESS_UP
        fireCallback(handle, ButtonEvent.PRESS_UP)
        if (handle.ticks < SHORT_TICKS) {
            handle.ticks = 0
            handle.state = ButtonState.RELEASE
        } else {
            handle.state = ButtonState.IDLE
        }
    } else if (handle.ticks > SHORT_TICKS) {
        handle.ticks = 0
        handle.repeat = 0
        handle.state = ButtonState.PRESS
    }
}

func handleLongHoldState(handle: ButtonBase): Unit {
    if (handle.buttonLevel == handle.activeLevel) {
        handle.event = ButtonEvent.LONG_PRESS_HOLD
        fireCallback(handle, ButtonEvent.LONG_PRESS_HOLD)
    } else {
        handle.event = ButtonEvent.PRESS_UP
        fireCallback(handle, ButtonEvent.PRESS_UP)
        handle.state = ButtonState.IDLE
    }
}

func handleButton(handle: ButtonBase): Unit {
    let readGpioLevel = readButtonLevel(handle)

    if (!isStateIdle(handle.state)) {
        if (handle.ticks < 65535) {
            handle.ticks += 1
        }
    }

    if (readGpioLevel != handle.buttonLevel) {
        handle.debounceCnt += 1
        if (handle.debounceCnt >= DEBOUNCE_TICKS) {
            handle.buttonLevel = readGpioLevel
            handle.debounceCnt = 0
        }
    } else {
        handle.debounceCnt = 0
    }

    match (handle.state) {
        case ButtonState.IDLE => handleIdleState(handle)
        case ButtonState.PRESS => handlePressState(handle)
        case ButtonState.RELEASE => handleReleaseState(handle)
        case ButtonState.REPEAT => handleRepeatState(handle)
        case ButtonState.LONG_HOLD => handleLongHoldState(handle)
    }
}

// ============================================================
// 公有 API 辅助函数
// ============================================================

func addToActiveList(btn: ButtonBase): Int64 {
    for (existing in activeButtons) {
        if (existing.buttonId == btn.buttonId) {
            return -1
        }
    }
    activeButtons.add(btn)
    return 0
}

func removeFromActiveList(btn: ButtonBase): Unit {
    var idx = 0
    while (idx < activeButtons.size) {
        if (activeButtons[idx].buttonId == btn.buttonId) {
            activeButtons.remove(at: idx)
            btn.next = None
            return
        }
        idx += 1
    }
}

func storeCallback(btn: ButtonBase, event: ButtonEvent, callback: Option<BtnCallback>): Unit {
    let idx = eventIndex(event)
    if (idx >= 0 && idx < EVENT_COUNT) {
        btn.callbacks[idx] = callback
    }
}

func clearCallback(btn: ButtonBase, event: ButtonEvent): Unit {
    let idx = eventIndex(event)
    if (idx >= 0 && idx < EVENT_COUNT) {
        btn.callbacks[idx] = None
    }
}

// ============================================================
// 公有 API
// ============================================================

func buttonStart(handle: Option<ButtonBase>): Int64 {
    match (handle) {
        case Some(btn) => addToActiveList(btn)
        case None => -2
    }
}

func buttonStop(handle: Option<ButtonBase>): Unit {
    match (handle) {
        case Some(btn) => removeFromActiveList(btn)
        case None => return
    }
}

func buttonTicks(): Unit {
    for (btn in activeButtons) {
        handleButton(btn)
    }
}

func buttonAttach(handle: Option<ButtonBase>, event: ButtonEvent, callback: Option<BtnCallback>): Unit {
    match (handle) {
        case Some(btn) => storeCallback(btn, event, callback)
        case None => return
    }
}

func buttonDetach(handle: Option<ButtonBase>, event: ButtonEvent): Unit {
    match (handle) {
        case Some(btn) => clearCallback(btn, event)
        case None => return
    }
}

func buttonGetEvent(handle: Option<ButtonBase>): ButtonEvent {
    match (handle) {
        case Some(btn) => btn.event
        case None => ButtonEvent.NONE_PRESS
    }
}

func buttonGetRepeatCount(handle: Option<ButtonBase>): Int64 {
    match (handle) {
        case Some(btn) => btn.repeat
        case None => 0
    }
}

func buttonReset(handle: Option<ButtonBase>): Unit {
    match (handle) {
        case Some(btn) => btn.reset()
        case None => return
    }
}

func buttonIsPressed(handle: Option<ButtonBase>): Int64 {
    match (handle) {
        case Some(btn) => if (btn.buttonLevel == btn.activeLevel) { 1 } else { 0 }
        case None => -1
    }
}
