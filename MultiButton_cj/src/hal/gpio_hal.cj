// HAL 抽象接口
package MultiButton_cj.hal

interface GpioReader {
    func readLevel(pin: Int64): Int64
}
