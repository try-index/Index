//
//  AppLabel.swift
//  Data Inspector
//
//  Created by Axel Martinez on 26/11/24.
//

import SwiftUI

struct AppLabel: View {
    let appInfo: AppInfo
    
    var body: some View {
        Label {
            Text(appInfo.name)
        } icon: {
            if let icon = appInfo.icon {
                Image(nsImage: icon)
            }
        }
    }
}
