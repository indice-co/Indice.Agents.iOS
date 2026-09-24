//
//  SafariView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//


import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    
    let url: URL
    weak var delegate: SFSafariViewControllerDelegate? = nil
        
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.delegate = delegate
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        uiViewController.delegate = delegate
    }
}

class SafariViewDelegate: NSObject, SFSafariViewControllerDelegate {
    var onLoadFinished : ((Bool) -> ())? = nil
    var onRedirectLoad : ((URL)  -> ())? = nil
    
    func safariViewController(_ controller: SFSafariViewController, excludedActivityTypesFor URL: URL, title: String?) -> [UIActivity.ActivityType] {
        []
    }
    
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        onRedirectLoad?(URL)
    }
    
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        onLoadFinished?(didLoadSuccessfully)
    }
}
