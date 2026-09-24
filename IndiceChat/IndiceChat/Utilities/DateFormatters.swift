//
//  DateFormatters.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import Foundation

struct ContextualDateFormat: FormatStyle {
    typealias FormatInput  = Date
    typealias FormatOutput = String
    
    
    var dateStyle: Date.FormatStyle.DateStyle = .numeric
    var timeStyle: Date.FormatStyle.TimeStyle = .shortened
    
    func format(_ value: Date) -> String {
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
