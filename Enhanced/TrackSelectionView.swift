//
//  TrackSelectionView.swift
//  rpd_9+LLM
//
//  Created by Chris on 11/19/25.
//


import SwiftUI
import AVFoundation

// MARK: - Track Selection View
struct TrackSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var selectedCategory: String = "Job Development"
    
    let categories = ["Job Development", "Personal Growth"]
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Choose Your Path")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Select a track to begin your personalized learning journey")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Category Selector
                        HStack(spacing: 15) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedCategory = category
                                    }
                                }) {
                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            selectedCategory == category ?
                                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                            LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedCategory == category ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Track Options
                        VStack(spacing: 20) {
                            ForEach(TrackType.allCases.filter { $0.category == selectedCategory }, id: \.self) { track in
                                TrackCard(track: track) {
                                    selectTrack(track)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Select Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        DatabaseManagerEnhanced.shared.logEvent(screen: "Track Selection", action: "cancelled")
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "Track Selection", action: "view_appeared")
            }
        }
    }
    
    func selectTrack(_ track: TrackType) {
        DatabaseManagerEnhanced.shared.saveUserTrack(trackType: track.rawValue)
        viewModel.loadTrackContent(trackType: track.rawValue)
        
        // Show success message
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isPresented = false
    }
}

// MARK: - Track Card
struct TrackCard: View {
    let track: TrackType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: track.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(getTrackDescription(track))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Track Features
                HStack(spacing: 20) {
                    FeatureTag(icon: "book.fill", text: "4+ Modules")
                    FeatureTag(icon: "star.fill", text: "250-400 pts")
                    FeatureTag(icon: "clock.fill", text: "20-60 min")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .blue.opacity(0.1), radius: 10)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    func getTrackDescription(_ track: TrackType) -> String {
        switch track {
        case .hvac:
            return "Learn HVAC installation, maintenance, and safety protocols"
        case .nursing:
            return "Master patient care, medical terminology, and clinical procedures"
        case .spiritual:
            return "Deepen your faith through Bible study and spiritual practices"
        case .mentalHealth:
            return "Build resilience through mindfulness and stress management"
        }
    }
}

struct FeatureTag: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.white.opacity(0.7))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - QR Code Scanner View
struct QRCodeScannerView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var scannedCode: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera View
                QRScannerViewController(scannedCode: $scannedCode, onScan: handleScan)
                    .ignoresSafeArea()
                
                // Overlay
                VStack {
                    Spacer()
                    
                    // Scan Frame
                    Rectangle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay(
                            VStack {
                                HStack {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: 30, height: 3)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: 30, height: 3)
                                }
                                Spacer()
                                HStack {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: 30, height: 3)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: 30, height: 3)
                                }
                            }
                            .padding(4)
                        )
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 12) {
                        Text("Position QR Code Within Frame")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("The code will scan automatically")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                }
                
                // Success Overlay
                if showSuccess {
                    ZStack {
                        Color.black.opacity(0.8)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                            
                            Text("Check-In Successful!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            let points = DatabaseManagerEnhanced.shared.calculateAutomatedPoints(taskType: "check_in")
                            Text("+\(points) points")
                                .font(.title3)
                                .foregroundColor(.yellow)
                        }
                        .padding(40)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSuccess = false
                                isPresented = false
                            }
                        }
                    }
                }
                
                // Error Overlay
                if showError {
                    VStack(spacing: 15) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Scan Failed")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            withAnimation {
                                showError = false
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()
                }
            }
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        DatabaseManagerEnhanced.shared.logEvent(screen: "QR Scanner", action: "cancelled")
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DatabaseManagerEnhanced.shared.logEvent(screen: "QR Scanner", action: "view_appeared")
            }
        }
    }
    
    func handleScan(_ code: String) {
        // Validate QR code (customize based on your QR code format)
        guard !code.isEmpty else {
            errorMessage = "Invalid QR code"
            withAnimation {
                showError = true
            }
            return
        }
        
        // Calculate points
        let points = DatabaseManagerEnhanced.shared.calculateAutomatedPoints(taskType: "check_in")
        
        // Save check-in
        DatabaseManagerEnhanced.shared.saveCheckIn(
            qrCodeData: code,
            location: "Location Name", // You can enhance this with actual location
            pointsEarned: points
        )
        
        // Update user points
        viewModel.user.pointsBalance += points
        
        // Show success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            showSuccess = true
        }
    }
}

// MARK: - QR Scanner View Controller
struct QRScannerViewController: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    var onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewControllerImpl {
        let controller = QRScannerViewControllerImpl()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewControllerImpl, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        var parent: QRScannerViewController
        
        init(_ parent: QRScannerViewController) {
            self.parent = parent
        }
        
        func didFindCode(_ code: String) {
            parent.scannedCode = code
            parent.onScan(code)
        }
    }
}

// MARK: - QR Scanner Delegate
protocol QRScannerDelegate: AnyObject {
    func didFindCode(_ code: String)
}

// MARK: - QR Scanner Implementation
class QRScannerViewControllerImpl: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerDelegate?
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var hasScanned = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get camera device")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Could not add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Could not add metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if hasScanned { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            hasScanned = true
            
            delegate?.didFindCode(stringValue)
        }
    }
}

// MARK: - Enhanced Home View with Track Selection
struct EnhancedHomeView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @State private var showTrackSelection = false
    @State private var showQRScanner = false
    @State private var currentTrack: TrackType?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.1, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Current Track Display
                        if let track = currentTrack {
                            CurrentTrackBanner(track: track) {
                                showTrackSelection = true
                            }
                        } else {
                            SelectTrackBanner {
                                showTrackSelection = true
                            }
                        }
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Quick Actions")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 15) {
                                QuickActionCard(
                                    title: "Check-In",
                                    icon: "qrcode",
                                    color: .green
                                ) {
                                    showQRScanner = true
                                }
                                
                                QuickActionCard(
                                    title: "Tasks",
                                    icon: "checklist",
                                    color: .blue,
                                    badge: viewModel.tasks.filter { !$0.isCompleted }.count
                                ) {
                                    selectedTab = 1
                                }
                                
                                QuickActionCard(
                                    title: "Points",
                                    icon: "star.fill",
                                    color: .yellow,
                                    value: "\(viewModel.user.pointsBalance)"
                                ) {
                                    selectedTab = 2
                                }
                                
                                QuickActionCard(
                                    title: "Streak",
                                    icon: "flame.fill",
                                    color: .orange,
                                    value: "\(viewModel.user.currentStreak)"
                                ) {
                                    selectedTab = 4
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Suggested Tasks
                        if currentTrack != nil {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Continue Learning")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.trackTasks.prefix(3), id: \.id) { task in
                                    GlassSuggestedTaskCard(
                                        title: task.title,
                                        description: task.description,
                                        points: task.points,
                                        icon: "book.fill"
                                    ) {
                                        DatabaseManagerEnhanced.shared.logEvent(
                                            screen: "Home",
                                            action: "button_tap",
                                            detail: task.title
                                        )
                                        selectedTab = 1
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showTrackSelection) {
                TrackSelectionView(viewModel: viewModel, isPresented: $showTrackSelection)
            }
            .sheet(isPresented: $showQRScanner) {
                QRCodeScannerView(viewModel: viewModel, isPresented: $showQRScanner)
            }
            .onAppear {
                loadCurrentTrack()
                DatabaseManagerEnhanced.shared.logEvent(screen: "Home", action: "view_appeared")
            }
        }
        .accentColor(.white)
    }
    
    func loadCurrentTrack() {
        if let trackString = DatabaseManagerEnhanced.shared.getUserSelectedTrack(),
           let track = TrackType(rawValue: trackString) {
            currentTrack = track
            viewModel.loadTrackContent(trackType: trackString)
        }
    }
}

// MARK: - Track Banners
struct CurrentTrackBanner: View {
    let track: TrackType
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Track")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Image(systemName: track.icon)
                        .foregroundColor(.blue)
                    Text(track.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            Button(action: action) {
                Text("Change")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
}

struct SelectTrackBanner: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text("Select Your Learning Track")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Choose from Job Development or Personal Growth")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Text("Get Started")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var badge: Int? = nil
    var value: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
                
                if let value = value {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}