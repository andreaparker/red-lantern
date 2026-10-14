import Foundation

enum Schedule {
    static func contains(minute: Int, start: Int, end: Int) -> Bool {
        guard start != end else { return false }
        if start < end { return minute >= start && minute < end }
        return minute >= start || minute < end
    }

    static func isActive(_ settings: Settings, at date: Date = Date()) -> Bool {
        switch settings.schedule {
        case .manual: return true
        case .clock:
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return contains(minute: minute, start: settings.startMinute, end: settings.endMinute)
        case .sun:
            guard settings.locationSet else { return false }
            return solarElevation(at: date, settings: settings) < -0.833
        }
    }

    // Low-order solar coordinates for local sunset scheduling, calculated entirely offline.
    static func solarCoordinates(at date: Date) -> (declination: Double, equation: Double) {
        let days = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545
        let meanLongitude = (280.46 + 0.9856474 * days).truncatingRemainder(dividingBy: 360)
        let anomaly = radians(357.528 + 0.9856003 * days)
        let longitude = radians(meanLongitude + 1.915 * sin(anomaly) + 0.02 * sin(2 * anomaly))
        let obliquity = radians(23.439 - 0.0000004 * days)
        let declination = asin(sin(obliquity) * sin(longitude))
        return (declination, equationOfTime(longitude, obliquity: obliquity, mean: meanLongitude))
    }

    private static func equationOfTime(_ longitude: Double, obliquity: Double, mean: Double) -> Double {
        let ascension = atan2(cos(obliquity) * sin(longitude), cos(longitude)) * 180 / .pi
        let difference = (mean - ascension + 540).truncatingRemainder(dividingBy: 360) - 180
        return 4 * difference
    }

    static func solarElevation(at date: Date, settings: Settings) -> Double {
        let coordinates = solarCoordinates(at: date)
        let seconds = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)
        let minutes = seconds / 60 + coordinates.equation + 4 * settings.longitude
        let hourAngle = radians(minutes / 4 - 180)
        let latitude = radians(settings.latitude)
        let altitude = sin(latitude) * sin(coordinates.declination)
            + cos(latitude) * cos(coordinates.declination) * cos(hourAngle)
        return asin(min(1, max(-1, altitude))) * 180 / .pi
    }

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    static func nextEvent(_ settings: Settings, after date: Date) -> Date? {
        switch settings.schedule {
        case .manual: return nil
        case .clock: return nextClockEvent(settings, after: date)
        case .sun:
            guard settings.locationSet else { return nil }
            return nextSolarEvent(settings, after: date)
        }
    }

    private static func nextClockEvent(_ settings: Settings, after date: Date) -> Date? {
        guard settings.startMinute != settings.endMinute else { return nil }
        let events = [settings.startMinute, settings.endMinute].compactMap { minute in
            Calendar.current.nextDate(after: date,
                                      matching: DateComponents(hour: minute / 60, minute: minute % 60),
                                      matchingPolicy: .nextTime)
        }
        return events.min()
    }

    private static func nextSolarEvent(_ settings: Settings, after date: Date) -> Date {
        let active = isActive(settings, at: date)
        for interval in 1...96 {
            let candidate = date.addingTimeInterval(Double(interval) * 1800)
            if isActive(settings, at: candidate) != active {
                return refineSolarEvent(settings, range: candidate.addingTimeInterval(-1800)...candidate)
            }
        }
        return date.addingTimeInterval(12 * 3600)
    }

    private static func refineSolarEvent(_ settings: Settings, range: ClosedRange<Date>) -> Date {
        var lower = range.lowerBound
        var upper = range.upperBound
        let active = isActive(settings, at: lower)
        while upper.timeIntervalSince(lower) > 1 {
            let middle = lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
            if isActive(settings, at: middle) == active { lower = middle }
            else { upper = middle }
        }
        return upper.addingTimeInterval(1)
    }
}
