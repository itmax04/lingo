import Darwin
import Foundation

/// Память процесса (R-47, AC-15): `phys_footprint` — то же, что показывает `footprint` и монитор памяти.
public enum Memory {
    public static func physFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return kr == KERN_SUCCESS ? info.phys_footprint : 0
    }

    public static func mb(_ b: UInt64) -> Double { Double(b) / 1_048_576 }
}
