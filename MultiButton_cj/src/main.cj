// MultiButton 演示与自测程序
package MultiButton_cj

// ============================================================
// 模拟 GPIO
// ============================================================

var mockGpioLevel: Int64 = 0

func mockReadGpio(_: Int64): Int64 {
    return mockGpioLevel
}

// ============================================================
// 事件记录回调类
// ============================================================

class EventRecorder <: BtnCallback {
    var counts: Array<Int64> = Array<Int64>(EVENT_COUNT, repeat: 0)

    public override func onEvent(btn: ButtonBase): Unit {
        let idx = eventIndex(btn.event)
        if (idx >= 0 && idx < EVENT_COUNT) {
            counts[idx] += 1
        }
    }

    public func countOf(event: ButtonEvent): Int64 {
        return counts[eventIndex(event)]
    }

    public func reset(): Unit {
        counts = Array<Int64>(EVENT_COUNT, repeat: 0)
    }
}

// ============================================================
// 测试辅助
// ============================================================

func pressButton(level: Int64): Unit {
    mockGpioLevel = level
}

func tickN(n: Int64): Unit {
    var i = 0
    while (i < n) {
        buttonTicks()
        i += 1
    }
}

// ============================================================
// 断言
// ============================================================

var passed: Int64 = 0
var failed: Int64 = 0

func assertEq(actual: Int64, expected: Int64, name: String): Unit {
    if (actual == expected) {
        println("  PASS: ${name}")
        passed += 1
    } else {
        println("  FAIL: ${name} (expected ${expected}, got ${actual})")
        failed += 1
    }
}

func assertTrue(condition: Bool, name: String): Unit {
    if (condition) {
        println("  PASS: ${name}")
        passed += 1
    } else {
        println("  FAIL: ${name}")
        failed += 1
    }
}

// ============================================================
// 测试用例
// ============================================================

func testSingleClick(): Unit {
    println("--- 测试：单击 ---")
    mockGpioLevel = 0

    let btn = ButtonBase(Some(mockReadGpio), 1, 1)
    let recorder = EventRecorder()
    buttonAttach(Some(btn), ButtonEvent.PRESS_DOWN, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.PRESS_UP, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.SINGLE_CLICK, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.DOUBLE_CLICK, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.LONG_PRESS_START, Some(recorder))
    buttonStart(Some(btn))

    // 按下 ~50ms
    pressButton(1)
    tickN(DEBOUNCE_TICKS + 10)

    // 释放，等待超时
    pressButton(0)
    tickN(DEBOUNCE_TICKS + SHORT_TICKS + 10)

    assertEq(recorder.countOf(ButtonEvent.PRESS_DOWN), 1, "PRESS_DOWN 触发")
    assertEq(recorder.countOf(ButtonEvent.PRESS_UP), 1, "PRESS_UP 触发")
    assertEq(recorder.countOf(ButtonEvent.SINGLE_CLICK), 1, "SINGLE_CLICK 触发")
    assertEq(recorder.countOf(ButtonEvent.DOUBLE_CLICK), 0, "DOUBLE_CLICK 未触发")
    assertEq(recorder.countOf(ButtonEvent.LONG_PRESS_START), 0, "LONG_PRESS_START 未触发")

    buttonStop(Some(btn))
}

func testDoubleClick(): Unit {
    println("--- 测试：双击 ---")
    mockGpioLevel = 0

    let btn = ButtonBase(Some(mockReadGpio), 1, 1)
    let recorder = EventRecorder()
    buttonAttach(Some(btn), ButtonEvent.PRESS_DOWN, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.DOUBLE_CLICK, Some(recorder))
    buttonStart(Some(btn))

    // 第一次点击
    pressButton(1)
    tickN(DEBOUNCE_TICKS + 10)
    pressButton(0)
    tickN(DEBOUNCE_TICKS + 5)

    // 第二次点击（在 SHORT_TICKS 内）
    pressButton(1)
    tickN(DEBOUNCE_TICKS + 10)
    pressButton(0)
    tickN(DEBOUNCE_TICKS + SHORT_TICKS + 10)

    assertEq(recorder.countOf(ButtonEvent.PRESS_DOWN), 2, "PRESS_DOWN 触发 2 次")
    assertEq(recorder.countOf(ButtonEvent.DOUBLE_CLICK), 1, "DOUBLE_CLICK 触发")

    buttonStop(Some(btn))
}

func testLongPress(): Unit {
    println("--- 测试：长按 ---")
    mockGpioLevel = 0

    let btn = ButtonBase(Some(mockReadGpio), 1, 2)
    let recorder = EventRecorder()
    buttonAttach(Some(btn), ButtonEvent.LONG_PRESS_START, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.LONG_PRESS_HOLD, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.PRESS_UP, Some(recorder))
    buttonStart(Some(btn))

    pressButton(1)
    tickN(DEBOUNCE_TICKS + LONG_TICKS + 20)

    assertTrue(recorder.countOf(ButtonEvent.LONG_PRESS_START) >= 1, "LONG_PRESS_START 触发")
    assertTrue(recorder.countOf(ButtonEvent.LONG_PRESS_HOLD) >= 1, "LONG_PRESS_HOLD 触发")

    // 释放
    pressButton(0)
    tickN(DEBOUNCE_TICKS + 10)
    assertEq(recorder.countOf(ButtonEvent.PRESS_UP), 1, "PRESS_UP 触发")

    buttonStop(Some(btn))
}

func testDebounce(): Unit {
    println("--- 测试：消抖 ---")
    mockGpioLevel = 0

    let btn = ButtonBase(Some(mockReadGpio), 1, 4)
    let recorder = EventRecorder()
    buttonAttach(Some(btn), ButtonEvent.PRESS_DOWN, Some(recorder))
    buttonAttach(Some(btn), ButtonEvent.SINGLE_CLICK, Some(recorder))
    buttonStart(Some(btn))

    // 快速翻转 GPIO（少于消抖阈值）
    var i = 0
    while (i < 20) {
        mockGpioLevel = i % 2
        tickN(1)
        i += 1
    }
    mockGpioLevel = 0
    tickN(10)

    assertEq(recorder.countOf(ButtonEvent.PRESS_DOWN), 0, "消抖过滤噪音")
    assertEq(recorder.countOf(ButtonEvent.SINGLE_CLICK), 0, "无单击事件")

    buttonStop(Some(btn))
}

func testNullSafety(): Unit {
    println("--- 测试：空指针安全 ---")
    buttonStop(None)
    buttonReset(None)
    buttonAttach(None, ButtonEvent.SINGLE_CLICK, None)
    buttonDetach(None, ButtonEvent.SINGLE_CLICK)

    let event = buttonGetEvent(None)
    let isNonePress = match (event) {
        case ButtonEvent.NONE_PRESS => true
        case _ => false
    }
    assertTrue(isNonePress, "buttonGetEvent(None) 返回 NONE_PRESS")

    assertEq(buttonGetRepeatCount(None), 0, "buttonGetRepeatCount(None) = 0")
    assertEq(buttonIsPressed(None), -1, "buttonIsPressed(None) = -1")
    assertEq(buttonStart(None), -2, "buttonStart(None) = -2")
}

// ============================================================
// 主函数
// ============================================================

main(): Int64 {
    println("MultiButton 仓颉版 自测程序")
    println("版本: ${getVersion()}")
    println("==============================\n")

    testSingleClick()
    testDoubleClick()
    testLongPress()
    testDebounce()
    testNullSafety()

    println("\n==============================")
    println("结果: ${passed} 通过, ${failed} 失败")
    return if (failed > 0) { 1 } else { 0 }
}
