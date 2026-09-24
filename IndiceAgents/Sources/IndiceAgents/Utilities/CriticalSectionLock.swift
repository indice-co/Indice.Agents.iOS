//
//  CriticalSectionLock.swift
//  IndiceAgents
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//


import Foundation

/// Just a wrapper over a lower level lock
/// - warning:
/// **NON RE-ENTRANT**
public final class CriticalSectionLock: @unchecked Sendable {
    
    private var lock = os_unfair_lock()
    
    public init() { }
    
    @inline(__always)
    public func withLock<R>(_ body: () throws -> R) rethrows -> R {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        return try body()
    }
}


public final class ReentrantSectionLock: @unchecked Sendable {
    private var lock = NSRecursiveLock()
    
    public init() { }
    
    @inline(__always)
    public func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        
        return try body()
    }
}
