//
//  ErrorMapping.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//


import Foundation
import NetworkClient
import struct IdentityClient.ErrorResponse
import struct IdentityClient.ExtendedProblemDetails


func defaultErrorMap(_ error: Error) -> UIError {
    // if let signalRError = error as? SignalR.Error {
    //     return .signalRError(statusCode: nil, value: signalRError)
    // }
    
    guard let apiError = error as? NetworkClient.Error else {
        return .generic(message: error.localizedDescription)
    }

    if let identityError: ErrorResponse = apiError.getError() {
        return .identityError(
            statusCode: apiError.statusCode,
            value: identityError)
    }

    // if let signalRError: SignalR.Error = apiError.getError() {
    //     return .signalRError(
    //         statusCode: apiError.statusCode,
    //         value: signalRError)
    // }

    if let problemDetails: ExtendedProblemDetails = apiError.getError() {
        return .problemDetails(
            statusCode: apiError.statusCode,
            value: problemDetails)
    }

    // Fallback: Provide a description for the error
    return .generic(message: String(describing: apiError))
}

func defaultApiErrorMap(
    _ error: Error,
    onErrorResponse  : ((ErrorResponse) -> Bool)? = nil,
    onProblemDetails : ((ExtendedProblemDetails) -> Bool)? = nil,
    // onSignalRError   : ((SignalR.Error) -> Bool)? = nil,
    onGeneralAPIError: ((NetworkClient.Error) -> Bool)? = nil,
) -> Bool {
    // if let signalRError = error as? SignalR.Error, let onSignalRError {
    //     return onSignalRError(signalRError)
    // }
    
    guard let apiError = error as? NetworkClient.Error else {
        return false
    }

    if let identityError: ErrorResponse = apiError.getError(), let onErrorResponse {
        return onErrorResponse(identityError)
    }

    // if let signalRError: SignalR.Error = apiError.getError(), let onSignalRError {
    //     return onSignalRError(signalRError)
    // }

    if let problemDetails: ExtendedProblemDetails = apiError.getError(), let onProblemDetails {
        return onProblemDetails(problemDetails)
    }
    
    if let onGeneralAPIError {
        return onGeneralAPIError(apiError)
    }
    
    return false
}


extension UIError {
    
    static func generic(title: String? = nil, message: String, actions: [UIError.Action] = []) -> UIError {
        .init(title: title, message: message, actions: actions)
    }

    static func problemDetails(statusCode: Int?, value: ExtendedProblemDetails, actions: [UIError.Action] = []) -> UIError {
        .init(
            statusCode: statusCode,
            title: value.title,
            message: value.description,
            actions: [])
    }

    // static func signalRError(statusCode: Int?, value: SignalR.Error, actions: [UIError.Action] = []) -> UIError {
    //     .init(
    //         statusCode: statusCode,
    //         title: value.problemDetails?.title,
    //         message: value.problemDetails?.description ?? "",
    //         actions: actions)
    // }

    static func identityError(statusCode: Int?, value: ErrorResponse, actions: [UIError.Action] = []) -> UIError {
        .init(
            statusCode: statusCode,
            title: nil,
            message: value.description ?? value.error,
            actions: actions)
    }
}
