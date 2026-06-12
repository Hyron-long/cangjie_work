// 按钮事件与状态枚举定义
package MultiButton_cj

// ============================================================
// 按钮事件类型（对应原 ButtonEvent 枚举）
// ============================================================

enum ButtonEvent {
    | PRESS_DOWN
    | PRESS_UP
    | PRESS_REPEAT
    | SINGLE_CLICK
    | DOUBLE_CLICK
    | LONG_PRESS_START
    | LONG_PRESS_HOLD
    | NONE_PRESS
}

// 事件总数（用于回调数组大小）
let EVENT_COUNT: Int64 = 8

// 将事件映射到数组索引
func eventIndex(event: ButtonEvent): Int64 {
    match (event) {
        case ButtonEvent.PRESS_DOWN => 0
        case ButtonEvent.PRESS_UP => 1
        case ButtonEvent.PRESS_REPEAT => 2
        case ButtonEvent.SINGLE_CLICK => 3
        case ButtonEvent.DOUBLE_CLICK => 4
        case ButtonEvent.LONG_PRESS_START => 5
        case ButtonEvent.LONG_PRESS_HOLD => 6
        case ButtonEvent.NONE_PRESS => 7
    }
}

// ============================================================
// 按钮状态机状态（对应原 ButtonState 枚举）
// ============================================================

enum ButtonState {
    | IDLE
    | PRESS
    | RELEASE
    | REPEAT
    | LONG_HOLD
}
