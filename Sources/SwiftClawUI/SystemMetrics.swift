import Foundation
import Darwin
import SwiftUI

/// Polls RAM and CPU usage via Mach host APIs every 2 seconds.
@Observable
@MainActor
public final class SystemMetricsMonitor {

    public var ramUsed: Double = 0    // GB
    public var ramTotal: Double = 0   // GB
    public var cpuPercent: Double = 0 // 0–100

    private var timer: Timer?

    private var prevCPUInfo: processor_info_array_t? = nil
    private var prevCPUInfoCount: mach_msg_type_number_t = 0

    public init() {
        ramTotal = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    }

    public var formattedRAM: String {
        String(format: "RAM %.1f/%.0f GB", ramUsed, ramTotal)
    }

    public var formattedCPU: String {
        "\(Int(cpuPercent))%"
    }

    public func start(interval: TimeInterval = 2.0) {
        updateMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func updateMetrics() {
        updateRAM()
        updateCPU()
    }

    private func updateRAM() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let pageSize = Double(sysconf(_SC_PAGESIZE))
        let usedPages = Double(stats.active_count)
                      + Double(stats.wire_count)
                      + Double(stats.compressor_page_count)
        ramUsed = usedPages * pageSize / 1_073_741_824
    }

    private func updateCPU() {
        var cpuInfo: processor_info_array_t? = nil
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfo, &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        let stride = Int(CPU_STATE_MAX)
        var busyTicks: Double = 0
        var totalTicks: Double = 0

        if let prev = prevCPUInfo {
            for i in 0..<Int(numCPUs) {
                let base = i * stride
                let deltaUser   = Double(info[base + Int(CPU_STATE_USER)])   - Double(prev[base + Int(CPU_STATE_USER)])
                let deltaSystem = Double(info[base + Int(CPU_STATE_SYSTEM)]) - Double(prev[base + Int(CPU_STATE_SYSTEM)])
                let deltaNice   = Double(info[base + Int(CPU_STATE_NICE)])   - Double(prev[base + Int(CPU_STATE_NICE)])
                let deltaIdle   = Double(info[base + Int(CPU_STATE_IDLE)])   - Double(prev[base + Int(CPU_STATE_IDLE)])
                let delta = deltaUser + deltaSystem + deltaNice + deltaIdle
                if delta > 0 {
                    busyTicks  += deltaUser + deltaSystem + deltaNice
                    totalTicks += delta
                }
            }
        }

        // Free previous allocation
        if let prev = prevCPUInfo {
            let size = vm_size_t(prevCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), size)
        }

        prevCPUInfo      = info
        prevCPUInfoCount = numCPUInfo

        if totalTicks > 0 {
            cpuPercent = (busyTicks / totalTicks) * 100
        }
    }
}
