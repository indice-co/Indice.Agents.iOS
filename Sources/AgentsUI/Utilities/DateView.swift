//
//  DateView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//


import SwiftUI

struct DateView: View {
    
    private let date: Date
    private let dateFormat: Date.FormatStyle.DateStyle
    private let timeFormat: Date.FormatStyle.TimeStyle
    
    init(
        _ date: Date,
        dateFormat: Date.FormatStyle.DateStyle = .abbreviated,
        timeFormat: Date.FormatStyle.TimeStyle = .standard
    ) {
        self.date = date
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
    }
    
    private var showDivider: Bool {
        dateFormat != .omitted && timeFormat != .omitted
    }
    
    var body: some View {
        HStack {
            if dateFormat != .omitted {
                Text(date.formatted(date: dateFormat, time: .omitted))
            }
            
            if showDivider { Divider() }
            
            if timeFormat != .omitted {
                Text(date.formatted(date: .omitted, time: timeFormat))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .font(.caption)
    }
}

#Preview {
    VStack(spacing: 16) {
        DateView(.now)
        DateView(.now, timeFormat: .shortened)
        DateView(.now, dateFormat: .omitted)
        DateView(.now, dateFormat: .omitted, timeFormat: .omitted)
    }
    .padding()
}
