// 配置常量 - 对应原 multi_button.h 中的 #define 宏
package MultiButton_cj

// ============================================================
// 可配置常量（可根据需要修改）
// ============================================================

/** 定时器中断间隔（毫秒），默认 5ms */
let TICKS_INTERVAL: Int64 = 5

/** 消抖采样深度（最大值 7，对应原 3-bit 位域限制） */
let DEBOUNCE_TICKS: Int64 = 3
let _MAX_DEBOUNCE_TICKS: Int64 = 7

/** 短按超时阈值（毫秒 → tick 数） */
let SHORT_TICKS: Int64 = 300 / TICKS_INTERVAL

/** 长按触发阈值（毫秒 → tick 数） */
let LONG_TICKS: Int64 = 1000 / TICKS_INTERVAL

/** 最大连击计数 */
let PRESS_REPEAT_MAX_NUM: Int64 = 15

// ============================================================
// 版本信息
// ============================================================

let VERSION_MAJOR: Int64 = 2
let VERSION_MINOR: Int64 = 0
let VERSION_PATCH: Int64 = 0

func getVersion(): String {
    return "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
}
