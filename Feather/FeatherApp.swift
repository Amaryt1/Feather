//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showWelcome = true
	
	@State private var pendingLinks: [URL] = []
	
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject private var storage = Storage.shared
	
	var body: some Scene {
		WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-AMARYTCatalogPreview") {
                AMARYTCatalogPreviewView()
            } else {
                Group {
                    switch storage.state {
                    case .waiting, .loading:
                        ProgressView("جارٍ فتح المكتبة…").task { storage.load() }
                    case .failed(let message):
                        VStack(spacing: 16) {
                            Text(message).multilineTextAlignment(.center)
                            Button("إعادة المحاولة") { storage.load() }
                        }.padding()
                    case .ready:
                        storeContent
                    }
                }
                .onOpenURL { url in
                    if storage.state == .ready { _handleURL(url) } else { pendingLinks.append(url) }
                }
            }
        }
    }

    private var storeContent: some View {
            ZStack {
			VStack(spacing: 0) {
				if !downloadManager.manualDownloads.isEmpty {
				DownloadHeaderView(downloadManager: downloadManager)
					.transition(.move(edge: .top).combined(with: .opacity))
				}
				VariedTabbarView()
					.environment(\.managedObjectContext, storage.context)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
			.animation(.smooth, value: downloadManager.manualDownloads.description)
			.onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(
						title: "InvalidHostID",
						message: .localized("Your pairing file is invalid and is incompatible with your device, please import a valid pairing file.")
					)
				}
			}
                if showWelcome {
                    AMARYTWelcomeView().transition(.opacity).zIndex(1)
                }
            }
            .modifier(CardInstallHost())
            .modifier(StoreThemeHost())
            .task {
                Logger(subsystem: "Feather", category: "Startup").notice("store.root.appeared")
                appDelegate.startOptionalServices()
                let links = pendingLinks
                pendingLinks.removeAll()
                links.forEach(_handleURL)
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.45)) { showWelcome = false }
            }
    }


	private func _handleURL(_ url: URL) {
		if url.scheme == "feather" {
			/// feather://import-certificate?p12=<base64>&mobileprovision=<base64>&password=<base64>
			if url.host == "import-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
					let queryItems = components.queryItems
				else {
					return
				}
				
				func queryValue(_ name: String) -> String? {
					queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding
				}
				
				guard
					let p12Base64 = queryValue("p12"),
					let provisionBase64 = queryValue("mobileprovision"),
					let passwordBase64 = queryValue("password"),
					let passwordData = Data(base64Encoded: passwordBase64),
					let password = String(data: passwordData, encoding: .utf8)
				else {
					return
				}
				
				let generator = UINotificationFeedbackGenerator()
				generator.prepare()
				
				guard
					let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"),
					let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"),
					FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL)
				else {
					generator.notificationOccurred(.error)
					return
				}
				
				FR.handleCertificateFiles(
					p12URL: p12URL,
					provisionURL: provisionURL,
					p12Password: password
				) { error in
					if let error = error {
						UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
					} else {
						generator.notificationOccurred(.success)
					}
				}
				
				return
			}
			/// feather://export-certificate?callback_template=<template>
			/// ?callback_template=: This is how we callback to the application requesting the certificate, this will be a url scheme
			/// 	example: livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29
			/// 	decoded: livecontainer://certificate?cert=$(BASE64_CERT)&password=$(PASSWORD)
			/// $(BASE64_CERT) and $(PASSWORD) must be presenting in the callback template so we can replace them with the proper content
			if url.host == "export-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
				else {
					return
				}
				
				let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
				guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
				
				FR.exportCertificateAndOpenUrl(using: callbackTemplate)
			}
			/// feather://source/<url>
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			/// feather://install/<url.ipa>
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				UIAlertController.showAlertWithCancel(
					title: .localized("Install"),
					message: .localized("Do you want to download and install this file?") + "\n\n\(downloadURL)",
					actions: [
						UIAlertAction(title: .localized("Install"), style: .default) { _ in
							_ = DownloadManager.shared.startDownload(from: downloadURL)
						}
					]
				)
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { _ in }
				} else {
					FR.handlePackageFile(url) { _ in }
				}
				
				return
			}
		}
	}
}


private struct AMARYTWelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gold = Color(red: 1, green: 0.76, blue: 0.19)
    private let cyan = Color(red: 0.24, green: 0.79, blue: 1)

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.005, green: 0.008, blue: 0.035),
                            Color(red: 0.02, green: 0.025, blue: 0.10),
                            Color(red: 0.065, green: 0.025, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    Canvas { context, size in
                        // Deterministic star field, with individual twinkling phases.
                        for index in 0..<95 {
                            let x = CGFloat((index * 83 + 17) % 997) / 997 * size.width
                            let y = CGFloat((index * 137 + 71) % 991) / 991 * size.height
                            let pulse = reduceMotion ? 0.8 : 0.5 + 0.5 * sin(time * (1.1 + Double(index % 5) * 0.31) + Double(index) * 1.7)
                            let radius: CGFloat = index.isMultiple(of: 11) ? 1.8 : 0.8
                            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.18 + 0.78 * pulse)))
                        }

                        // Animated meteor trails that cross the scene.
                        if !reduceMotion {
                            for index in 0..<5 {
                                let progress = (time * (0.23 + Double(index) * 0.035) + Double(index) * 0.29)
                                    .truncatingRemainder(dividingBy: 1.0)
                                let x = CGFloat(progress) * (size.width + 240) - 120
                                let y = CGFloat((index * 29 + 12) % 85) / 100 * size.height
                                var trail = Path()
                                trail.move(to: CGPoint(x: x - 90, y: y - 42))
                                trail.addLine(to: CGPoint(x: x, y: y))
                                context.stroke(
                                    trail,
                                    with: .linearGradient(
                                        Gradient(colors: [.clear, index.isMultiple(of: 2) ? gold.opacity(0.7) : cyan.opacity(0.8), .white]),
                                        startPoint: CGPoint(x: x - 90, y: y - 42),
                                        endPoint: CGPoint(x: x, y: y)
                                    ),
                                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                                )
                                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                                             with: .color(.white))
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    // Wide, soft energy bands behind the brand.
                    Ellipse()
                        .stroke(cyan.opacity(0.28), lineWidth: 2)
                        .frame(width: side * 1.05, height: side * 0.29)
                        .blur(radius: 12)
                        .rotationEffect(.degrees(-20))
                        .offset(y: side * 0.10)
                    Ellipse()
                        .stroke(gold.opacity(0.48), lineWidth: 1.5)
                        .frame(width: side * 0.95, height: side * 0.24)
                        .rotationEffect(.degrees(-20))
                        .offset(y: side * 0.10)
                        .shadow(color: gold, radius: 15)

                    VStack(spacing: side * 0.035) {
                        ZStack {
                            Circle()
                                .fill(gold.opacity(0.15))
                                .frame(width: side * 0.42, height: side * 0.42)
                                .blur(radius: 42)

                            // A custom crescent outline, not an SF Symbol or image.
                            CrescentNeonShape()
                                .stroke(gold.opacity(0.20), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                .blur(radius: 18)
                            CrescentNeonShape()
                                .stroke(gold.opacity(0.55), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .blur(radius: 6)
                            CrescentNeonShape()
                                .stroke(
                                    LinearGradient(colors: [.white, gold, .orange],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 3.3, lineCap: .round)
                                )
                                .shadow(color: gold, radius: 13)
                        }
                        .frame(width: side * 0.38, height: side * 0.42)
                        .rotationEffect(.degrees(reduceMotion ? -12 : -12 + sin(time * 0.9) * 3))

                        Text("AMARYT")
                            .font(.system(size: min(side * 0.125, 68), weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .shadow(color: cyan.opacity(0.95), radius: 18)
                            .shadow(color: gold.opacity(0.65), radius: 30)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("S T O R E")
                            .font(.system(size: min(side * 0.051, 28), weight: .heavy, design: .rounded))
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.95), radius: 13)
                            .shadow(color: gold.opacity(0.6), radius: 25)

                        Capsule()
                            .fill(
                                LinearGradient(colors: [.clear, cyan, .white, gold, .clear],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: side * 0.64, height: 2)
                            .shadow(color: cyan, radius: 12)
                            .padding(.top, 6)

                        Text("WELCOME TO THE FUTURE")
                            .font(.system(size: min(side * 0.023, 13), weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AMARYT STORE، جاري فتح المتجر")
    }
}

private struct CrescentNeonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.42
        // Outer arc and inset arc join into a luminous crescent silhouette.
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(65), endAngle: .degrees(290), clockwise: false)
        let tip = CGPoint(x: center.x + radius * cos(65 * .pi / 180),
                          y: center.y + radius * sin(65 * .pi / 180))
        path.addQuadCurve(to: tip,
                          control: CGPoint(x: center.x - radius * 0.05, y: center.y - radius * 0.08))
        return path
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
        let files = FileManager.default
        if let domain = Bundle.main.bundleIdentifier {
            let existing = [files.archives, files.certificates, files.signed, files.unsigned]
                .contains { files.fileExists(atPath: $0.path) }
            FirstLaunchDefaults.apply(to: .standard, domain: domain, existingLibrary: existing)
        }
		_createPipeline()
		_createDocumentsDirectories()

		return true
	}
	
    private var startedServices = false
    func startOptionalServices() {
        guard !startedServices else { return }
        startedServices = true
        _ = HeartbeatManager.shared
        _addDefaultCertificates()
        // Do not clear the whole process temp directory while URLSession or an importer is using it.
        let cutoff = Date(timeIntervalSinceNow: -86400)
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let urls = (try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in urls {
                guard ["FeatherSigning_", "FeatherImport_"].contains(where: { url.lastPathComponent.hasPrefix($0) }),
                      let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      date < cutoff else { continue }
                try? fm.removeItem(at: url)
            }
        }
    }

	private func _createPipeline() {
		DataLoader.sharedUrlCache.diskCapacity = 0
		
		let pipeline = ImagePipeline {
			let dataLoader: DataLoader = {
				let config = URLSessionConfiguration.default
				config.urlCache = nil
				return DataLoader(configuration: config)
			}()
			let dataCache = try? DataCache(name: "thewonderofyou.Feather.datacache") // disk cache
			let imageCache = Nuke.ImageCache() // memory cache
			dataCache?.sizeLimit = 500 * 1024 * 1024
			imageCache.costLimit = 100 * 1024 * 1024
			$0.dataCache = dataCache
			$0.imageCache = imageCache
			$0.dataLoader = dataLoader
			$0.dataCachePolicy = .automatic
			$0.isStoringPreviewsInMemoryCache = false
		}
		
		ImagePipeline.shared = pipeline
	}
	
	private func _createDocumentsDirectories() {
		let fileManager = FileManager.default

		let directories: [URL] = [
			fileManager.archives,
			fileManager.certificates,
			fileManager.signed,
			fileManager.unsigned
		]
		
		for url in directories {
			try? fileManager.createDirectoryIfNeeded(at: url)
		}
	}
	
	private func _addDefaultCertificates() {
		guard
			UserDefaults.standard.bool(forKey: "feather.didImportDefaultCertificates") == false,
			let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
		else {
			return
		}
		
		do {
			let folderContents = try FileManager.default.contentsOfDirectory(
				at: signingAssetsURL,
				includingPropertiesForKeys: nil,
				options: .skipsHiddenFiles
			)
			
			for folderURL in folderContents {
				guard folderURL.hasDirectoryPath else { continue }
				
				let certName = folderURL.lastPathComponent
				
				let p12Url = folderURL.appendingPathComponent("cert.p12")
				let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
				let passwordUrl = folderURL.appendingPathComponent("cert.txt")
				
				guard
					FileManager.default.fileExists(atPath: p12Url.path),
					FileManager.default.fileExists(atPath: provisionUrl.path),
					FileManager.default.fileExists(atPath: passwordUrl.path)
				else {
					Logger.misc.warning("Skipping \(certName): missing required files")
					continue
				}
				
				let password = try String(contentsOf: passwordUrl, encoding: .utf8)
				
				FR.handleCertificateFiles(
					p12URL: p12Url,
					provisionURL: provisionUrl,
					p12Password: password,
					certificateName: certName,
					isDefault: true
				) { _ in
					
				}
			}
			UserDefaults.standard.set(true, forKey: "feather.didImportDefaultCertificates")
		} catch {
			Logger.misc.error("Failed to list signing-assets: \(error)")
		}
	}

}
