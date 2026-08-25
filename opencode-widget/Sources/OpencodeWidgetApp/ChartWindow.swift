import Foundation

enum ChartWindow {
    static let visibleHourCount = 168
    static let stepHours = 24

    static func range(endingAt newestHour: Date, offsetHours: Int) -> ClosedRange<Date> {
        let end = newestHour.addingTimeInterval(Double(-max(0, offsetHours) * 3_600))
        let start = end.addingTimeInterval(Double(-(visibleHourCount - 1) * 3_600))
        return start...end
    }

    static func maximumOffset(for count: Int) -> Int {
        max(0, count - visibleHourCount)
    }
}
