import UIKit
import Social
import Vision
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "👑 Deck Tracker"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Scanning screenshot..."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let openAppButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open in Deck Tracker", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.37, green: 0.45, blue: 0.89, alpha: 1)
        button.layer.cornerRadius = 12
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.setTitleColor(.white.withAlphaComponent(0.8), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var extractedText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedImage()
        
        openAppButton.addTarget(self, action: #selector(openMainApp), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(openAppButton)
        containerView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            openAppButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 24),
            openAppButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            openAppButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            openAppButton.heightAnchor.constraint(equalToConstant: 50),
            
            cancelButton.topAnchor.constraint(equalTo: openAppButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        activityIndicator.startAnimating()
    }
    
    private func processSharedImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("No image found")
            return
        }
        
        // Check for image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.showError("Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    var image: UIImage?
                    
                    if let url = item as? URL {
                        image = UIImage(contentsOfFile: url.path)
                    } else if let imageData = item as? Data {
                        image = UIImage(data: imageData)
                    } else if let img = item as? UIImage {
                        image = img
                    }
                    
                    if let image = image {
                        self?.performOCR(on: image)
                    } else {
                        self?.showError("Could not process image")
                    }
                }
            }
        } else {
            showError("Please share an image")
        }
    }
    
    private func performOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else {
            showError("Invalid image format")
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("OCR failed: \(error.localizedDescription)")
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                
                if text.isEmpty {
                    self?.showError("No text found in image")
                } else {
                    self?.extractedText = text
                    self?.showSuccess(text: text)
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.showError("OCR error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showSuccess(text: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        // Save to shared container for main app
        saveTextToSharedContainer(text)
        
        let preview = text.prefix(100) + (text.count > 100 ? "..." : "")
        statusLabel.text = "✅ Found player name:\n\n\(preview)"
        openAppButton.isHidden = false
    }
    
    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = "❌ \(message)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.cancelShare()
        }
    }
    
    private func saveTextToSharedContainer(_ text: String) {
        // CHANGE THIS to your app group: group.com.dean.decktracker
        if let sharedDefaults = UserDefaults(suiteName: "group.com.dean.decktracker") {
            sharedDefaults.set(text, forKey: "lastScannedText")
            sharedDefaults.set(Date(), forKey: "lastScanDate")
            sharedDefaults.synchronize()
        }
    }
    
    @objc private func openMainApp() {
        // Save to shared defaults first
        saveTextToSharedContainer(extractedText)
        
        // Open main app with custom URL scheme
        if let encoded = extractedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "decktracker://scanned?text=\(encoded)") {
            
            // Method 1: Try to open URL directly
            var responder: UIResponder? = self
            while let currentResponder = responder {
                if let application = currentResponder as? UIApplication {
                    application.perform(#selector(UIApplication.openURL(_:)), with: url)
                    break
                }
                responder = currentResponder.next
            }
            
            // Method 2: Complete extension and let system handle it
            extensionContext?.completeRequest(returningItems: nil) { _ in
                self.openURLInSystemContext(url)
            }
        } else {
            // Fallback: just close and save to shared defaults
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func openURLInSystemContext(_ url: URL) {
        // This uses the system context to open URLs
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = currentResponder.next
        }
    }
    
    @objc private func cancelShare() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
