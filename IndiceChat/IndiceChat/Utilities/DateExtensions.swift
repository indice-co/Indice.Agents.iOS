//
//  DateExtensions.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//


import Foundation

extension Date {
    // Just a more "context"-ed value wrapper.
    static var timestamp: TimeInterval {
        Date.timeIntervalSinceReferenceDate
    }
    
    func component(_ component: Calendar.Component, using calendar: Calendar = Calendar.usingDefault) -> Int {
        calendar.component(component, from: self)
    }
    
    func removingTimeStamp() -> Date {
        self.keeping([.calendar, .year, .month, .day])
    }
    
    func keeping(_ components: Set<Calendar.Component>) -> Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents(components, from: self)) else {
            fatalError("Failed to strip time from Date object")
        }
        
        return date
    }

    func reduced(by duration: Duration) -> Date {
        self.advanced(by: TimeInterval(duration.components.seconds * -1))
    }
    
    func advanced(by duration: Duration) -> Date {
        self.advanced(by: TimeInterval(duration.components.seconds))
    }
    
    func advanced(_ component: Calendar.Component, by value: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: component, value: value, to: self)!
    }
    
    var monthRange: DateInterval {
        Calendar.current.dateInterval(of: .month, for: self)!
    }
    
    var endOfMonth   : Date { monthRange.end   }
    var startOfMonth : Date { monthRange.start }
    
    var monthDayCount: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 0
    }
    
    var weekDayName: String {
        let index = Calendar.usingDefault.component(.weekday, from: self)
        return Calendar.usingDefault.weekdaySymbols[index - 1]
    }
    
    func upThrough(_ offset: Duration) -> ClosedRange<Date> {
        self...(self.advanced(by: offset))
    }
}


struct Month {
    var name: String
    var shortName: String
    var index: Int
    var start: Date
    var end: Date
}



func dateIntervalForMonthIndex(_ monthIndex: Int, in year: Int, calendar: Calendar = .current) -> DateInterval? {
    var components = DateComponents(year: year, month: monthIndex, day: 1)
    
    guard let startDate = calendar.date(from: components),
          let monthRange = calendar.range(of: .day, in: .month, for: startDate) else {
        return nil
    }
    
    components.day = monthRange.count
    guard let endDate = calendar.date(from: components) else {
        return nil
    }
    
    // `endDate` is the last day at midnight, add a day to cover the full day
    return DateInterval(start: startDate, end: calendar.date(byAdding: .day, value: 1, to: endDate)!)
}
 

extension Calendar {
    
    func month(index: Int) -> DateInterval {
        let components = DateComponents(year: currentYear, month: index, day: 1)
        let date = self.date(from: components)!
        
        return date.monthRange
    }
    
    static var usingDefault: Calendar {
        .autoupdatingCurrent
    }
    
    func isDateInCurrentYear(_ date: Date) -> Bool {
        self.year(of: date) == self.currentYear
    }
    
    var currentYear: Int {
        self.component(.year, from: .now)
    }
    
    func year(of date: Date) -> Int {
        self.component(.year, from: date)
    }
    
    func month(of date: Date) -> Int {
        self.component(.month, from: date)
    }
    
    func date(bySettingComponentValues items: [(component: Calendar.Component, value: Int)], on origin: Date) -> Date {
        var date = origin
        
        for item in items {
            date = self.date(
                bySetting: item.component,
                value: item.value,
                of: date) ?? date
        }
        
        return date
    }
}


struct Timestamp: Equatable, Hashable, Identifiable {
    var id: TimeInterval { value }
    let value: TimeInterval
    
    private init(value: TimeInterval) {
        self.value = value
    }
    
    public static func now() -> Timestamp {
        Timestamp(value: Date.timestamp)
    }
    
}
