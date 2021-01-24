//
//  EyeTrackerView.swift
//  EyeTracker
//
//  Created by Ravi Tripathi on 17/01/21.
//

import SwiftUI
import ARKit
import UIKit

public struct EyeTrackerView: View {
    let itemArray = Array(0...100)
    private let session = ARSession()
    @StateObject private var delegate: ARTrackingDelegate = {
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 40.0, height: 40.0)))
        view.backgroundColor = .red
        view.accessibilityIdentifier = "brr"
        return ARTrackingDelegate(withView: view)
    }()
    private let config: ARFaceTrackingConfiguration = {
        let cnf = ARFaceTrackingConfiguration()
        cnf.maximumNumberOfTrackedFaces = 1
        return cnf
    }()
    private let sessionQueue = DispatchQueue(label: "Arcadia.arsession.queue",
                                             qos: .userInteractive,
                                             attributes: [],
                                             autoreleaseFrequency: .workItem)
    public init() {
        
    }
    @State private var lastRow: Int = 0
    public var body: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                List {
                    ForEach(Array(itemArray.enumerated()), id: \.element) { index, element in
                        Text("Item number \(index)")
                            .onAppear { self.lastRow = index }
                    }
                }.onReceive(delegate.$direction) { action in
                    withAnimation {
                        switch action {
                        case .top:
                            
                            scrollProxy.scrollTo(lastRow + 1, anchor: .top)
                        case .bottom:
                            scrollProxy.scrollTo(lastRow + 1, anchor: .top)
                        case .none:
                            break
                        }
                        
                    }
                }
            }
        }.onAppear {
            delegate.targetView.center = UIApplication.shared.windows.first?.center ?? .zero
            UIApplication.shared.windows.first?.addSubview(delegate.targetView)
            session.delegate = self.delegate
            session.delegateQueue = sessionQueue
            session.run(config, options: [])
        }.onDisappear {
            session.pause()
            delegate.targetView.removeFromSuperview()
            session.delegate = nil
            session.delegateQueue = nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EyeTrackerView()
    }
}

class ARTrackingDelegate: NSObject, ARSessionDelegate, ObservableObject {
    
    enum Action {
        case bottom
        case top
    }
    @Published var direction: Action? = nil
    
    public var targetView: UIView
    var shouldDrag: Bool = false
    let label: UILabel = {
       let l = UILabel()
        l.backgroundColor = UIColor.white
        l.textColor = UIColor.black
//        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
       return l
    }()
    init(withView view: UIView) {
        targetView = view
        super.init()
        if let window = UIApplication.shared.windows.first {
            window.addSubview(label)
            label.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 10.0).isActive = true
            label.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -10.0).isActive = true
            label.topAnchor.constraint(equalTo: window.topAnchor, constant: 20.0).isActive = true
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            self.label.isHidden = false
            switch camera.trackingState {
            case .notAvailable:
                self.label.text = "Tracking not available"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.label.text = "Initializing. Wait."
                case .excessiveMotion:
                    self.label.text = "Excessive Motion"
                case .insufficientFeatures:
                    self.label.text = "Insufficient Features"
                case .relocalizing:
                    self.label.text = "Relocalization changes"
                @unknown default:
                    self.label.text = "New Entry in enum!"
                }
            case .normal:
                self.label.text = "Tracking normal"
                self.label.isHidden = true
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        DispatchQueue.main.async {
            
            let point = self.getNormalizedPoint(session: session, didUpdate: anchors)
            UIView.animate(withDuration: 0.1, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
//                print(point)
                self.targetView.frame = CGRect(x: point.x, y: point.y, width: 40.0, height: 40.0)
                if self.shouldDrag {
                    self.direction = .bottom
                    self.targetView.backgroundColor = .green
                } else {
                    self.targetView.backgroundColor = .red
                }
//                self.targetView.transform = transform
            })
        }
    }
    
    func getNormalizedPoint(session: ARSession, didUpdate anchors: [ARAnchor]) -> CGPoint {
        let faceAnchors = anchors.compactMap { $0 as? ARFaceAnchor }

        guard !faceAnchors.isEmpty,
            let camera = session.currentFrame?.camera
            else {
            return CGPoint.zero}
        
        // Calculate face points to project to screen
//        targetView.bounds.size
        let projectionMatrix = camera.projectionMatrix(for: .portrait, viewportSize: UIScreen.main.bounds.size, zNear: 0.001, zFar: 1000)  // A transform matrix appropriate for rendering 3D content to match the image captured by the camera
        let viewMatrix = camera.viewMatrix(for: .portrait)        // Returns a transform matrix for converting from world space to camera space.

        let projectionViewMatrix = simd_mul(projectionMatrix, viewMatrix)
        var points = [CGPoint]()
        for faceAnchor in faceAnchors  {
            let tongueOut = (faceAnchor.blendShapes[.tongueOut] as? Float) ?? 0.0
            shouldDrag = tongueOut > 0.3
            let modelMatrix = faceAnchor.transform                  //  Describes the face’s current position and orientation in world coordinates; that is, in a coordinate space relative to that specified by the worldAlignment property of the session configuration. Use this transform matrix to position virtual content you want to “attach” to the face in your AR scene.
            let mvpMatrix = simd_mul(projectionViewMatrix, modelMatrix)

            // Calculate points

            points = faceAnchor.geometry.vertices.compactMap({ (vertex) -> CGPoint? in

                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)

                let normalizedImageCoordinates = simd_mul(mvpMatrix, vertex4)

                return CGPoint(x: CGFloat(normalizedImageCoordinates.x ),
                               y: CGFloat(normalizedImageCoordinates.y ))
            })
        }
//        var str = "Point: "
//        for point in points {
//            str.append(", \(point)")
//        }
//        print(str)
        let point = points.first ?? .zero
//        let screenWidth = UIScreen.main.bounds.width
//        let screenHeight = UIScreen.main.bounds.height
//        let newP = CGPoint(x: (point.x*screenWidth)+100.0, y: -(point.y*screenHeight)+100.0)
        let windowCenterX = UIApplication.shared.windows.first?.center.x ?? 0.0
        let windowCenterY = UIApplication.shared.windows.first?.center.y ?? 0.0
        let computedY = -(point.y*3000.0) + windowCenterY
        print("Computed: \(computedY)")
        return CGPoint(x: point.x*1000.0 + windowCenterX, y: computedY)
    }
    
    
//    x - min
//f(x) = ---------
//     max - min
//    (b-a)(x - min)
//f(x) = --------------  + a
//       max - min
}
