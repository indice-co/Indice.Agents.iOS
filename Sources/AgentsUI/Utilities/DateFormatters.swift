//
//  DateFormatters.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import Foundation

public struct ContextualDateFormat: FormatStyle {
    public typealias FormatInput  = Date
    public typealias FormatOutput = String
    
    
    let dateStyle: Date.FormatStyle.DateStyle
    let timeStyle: Date.FormatStyle.TimeStyle
    
    public init(dateStyle: Date.FormatStyle.DateStyle = .numeric, timeStyle: Date.FormatStyle.TimeStyle = .shortened) {
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }
    
    public func format(_ value: Date) -> String {
        if Calendar.autoupdatingCurrent.isDateInToday(value) {
            return String(localized: "Today")
        }
        
        if Calendar.autoupdatingCurrent.isDateInYesterday(value) {
            return String(localized: "Yesterday")
        }
        
        return value.formatted(date: dateStyle, time: timeStyle)
    }
}

extension FormatStyle where Self == ContextualDateFormat {
    static func contextual(date: Date.FormatStyle.DateStyle = .abbreviated, time: Date.FormatStyle.TimeStyle = .shortened) -> Self {
        ContextualDateFormat.init(dateStyle: date, timeStyle: time)
    }
}
