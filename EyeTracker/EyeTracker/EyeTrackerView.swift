//
//  EyeTrackerView.swift
//  EyeTracker
//
//  Created by Ravi Tripathi on 17/01/21.
//

import SwiftUI

struct EyeTrackerView: View {
    let itemArray = Array(0...100)
    var body: some View {
        List {
            ForEach(Array(itemArray.enumerated()), id: \.element) { index, element in
                Text("Item number \(index)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EyeTrackerView()
    }
}
