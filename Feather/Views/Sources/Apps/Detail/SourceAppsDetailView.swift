//
//  SourceAppsDetailView.swift
//  Feather
//
//  Created by samsam on 7/25/25.
//

import SwiftUI
import CoreData
import Combine
import AltSourceKit
import NimbleViews
import NukeUI

// MARK: - SourceAppsDetailView
struct SourceAppsDetailView: View {
    @FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]) private var availableCertificates: FetchedResults<CertificatePair>
    @AppStorage("Feather.installationMethod") private var installationMethod = 0
    @State private var showAMARYTInstall = false
    @State private var showCertificateAlert = false
    @State private var showCertificates = false
    @State private var libraryImportDownloadID: String?
    @State private var libraryImportComplete = false
    @State private var directInstallDownloadID: String?
    @State private var isDirectInstallSigning = false
    @State private var directInstallError: String?
    @State private var directInstallPreview: AnyApp?
	@ObservedObject var downloadManager = DownloadManager.shared
	@State private var _downloadProgress: Double = 0
	@State var cancellable: AnyCancellable? // Combine
	@State private var _isScreenshotPreviewPresented: Bool = false
	@State private var _selectedScreenshotIndex: Int = 0
	@State private var relatedApps: [AppsCatalogEntry] = []
	@State private var isLoadingRelatedApps = true
	
	var currentDownload: Download? {
		downloadManager.getDownload(by: app.currentUniqueId)
	}
	
	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App
	
	var body: some View {
		ScrollView {
			if #available(iOS 18, *) {
				_header().flexibleHeaderContent()
			} else if let bannerURL = app.bannerURL {
				LazyImage(url: bannerURL) { state in
					if let image = state.image {
						image.resizable().aspectRatio(contentMode: .fill)
					} else {
						standardHeader
					}
				}
				.frame(height: 210)
				.clipped()
			}
			
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 10) {
					if let iconURL = app.iconURL {
						LazyImage(url: iconURL) { state in
							if let image = state.image {
								image.appIconStyle(size: 111, isCircle: false)
							} else {
								standardIcon
							}
						}
					} else {
						standardIcon
					}

					VStack(alignment: .leading, spacing: 2) {
						Text(app.currentName)
							.font(.title2)
							.fontWeight(.semibold)
							.foregroundColor(.primary)
						Text(app.currentDescription ?? .localized("An awesome application"))
							.font(.subheadline)
							.foregroundColor(.secondary)
						
						Spacer()
						
						storeActions
					}
					.lineLimit(2)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				
				Divider()
				_infoPills(app: app)
				Divider()
                
				if let screenshotURLs = app.screenshotURLs {
					NBSection(.localized("Screenshots")) {
						_screenshots(screenshotURLs: screenshotURLs)
					}
                    
					Divider()
				}
				
				if
					let currentVer = app.currentVersion,
					let whatsNewDesc = app.currentAppVersion?.localizedDescription
				{
					NBSection(.localized("What's New")) {
						AppVersionInfo(
							version: currentVer,
							date: app.currentDate?.date,
							description: whatsNewDesc
						)
						if let versions = app.versions {
							NavigationLink(
								destination: VersionHistoryView(
									sourceURL: sourceURL,
									source: source,
									app: app,
									versions: versions
								)
									.navigationTitle(.localized("Version History"))
									.navigationBarTitleDisplayMode(.large)
							) {
								Text(.localized("Version History"))
							}
						}
					}
					
					Divider()
				}
				
				if let appDesc = app.localizedDescription {
					NBSection(.localized("Description")) {
						VStack(alignment: .leading, spacing: 2) {
							ExpandableText(text: appDesc, lineLimit: 3)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
					}
					
					Divider()
				}
                
				NBSection(.localized("Information")) {
					VStack(spacing: 12) {
						if let sourceName = source.name {
							_infoRow(title: .localized("Source"), value: sourceName)
						}
                        
						if let developer = app.developer {
							_infoRow(title: .localized("Developer"), value: developer)
						}
						
						if let size = app.size {
							_infoRow(title: .localized("Size"), value: size.formattedByteCount)
						}
						
						if let category = app.category {
							_infoRow(title: .localized("Category"), value: category.capitalized)
						}
						
						if let version = app.currentVersion {
							_infoRow(title: .localized("Version"), value: version)
						}
						
						if let date = app.currentDate?.date {
							_infoRow(title: .localized("Updated"), value: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
						}
						
						if let bundleId = app.id {
							_infoRow(title: .localized("Identifier"), value: bundleId)
						}
					}
				}
				
				if let appPermissions = app.appPermissions {
					NBSection(.localized("Permissions")) {
						Group {
							if let entitlements = appPermissions.entitlements {
								NBTitleWithSubtitleView(
									title: .localized("Entitlements"),
									subtitle: entitlements.map(\.name).joined(separator: "\n")
								)
							} else {
								Text(.localized("No Entitlements listed."))
									.font(.subheadline)
									.foregroundStyle(.secondary)
							}
							if let privacyItems = appPermissions.privacy {
								ForEach(privacyItems, id: \.self) { item in
									NBTitleWithSubtitleView(
										title: item.name,
										subtitle: item.usageDescription
									)
								}
							} else {
								Text(.localized("No Privacy Permissions listed."))
									.font(.subheadline)
									.foregroundStyle(.secondary)
							}
						}
						.padding()
						.background(
							RoundedRectangle(cornerRadius: 18, style: .continuous)
								.fill(Color(.quaternarySystemFill))
						)
					}
				}
				Divider()
                relatedAppsSection
			}
			.padding([.horizontal, .bottom])
			.padding(.top, {
				if #available(iOS 18, *) {
					8
				} else {
					0
				}
			}())
		}
		.flexibleHeaderScrollView()
		.shouldSetInset()
		.task(id: "\(sourceURL?.absoluteString ?? "")|\(app.currentUniqueId)") {
            relatedApps = []
            isLoadingRelatedApps = true
            let results = await RelatedApps.load(app: app, sourceURL: sourceURL, source: source)
            guard !Task.isCancelled else { return }
            relatedApps = results
            isLoadingRelatedApps = false
        }
		.toolbar {
			NBToolbarButton(
				systemImage: "square.and.arrow.up",
				placement: .topBarTrailing
			) {
				let sharedString = """
				\(app.currentName) - \(app.currentVersion ?? "0")
				\(app.currentDescription ?? .localized("An awesome application"))
				---
				\(source.website?.absoluteString ?? source.name ?? "")
				"""
				UIActivityViewController.show(activityItems: [sharedString])
			}
		}
		.fullScreenCover(isPresented: $_isScreenshotPreviewPresented) {
			if let screenshotURLs = app.screenshotURLs {
				ScreenshotPreviewView(
					screenshotURLs: screenshotURLs,
					initialIndex: _selectedScreenshotIndex
				)
			}
		}
	}
	

    @ViewBuilder
    private var relatedAppsSection: some View {
        // Do not render an empty shelf if all sources are unavailable offline.
        if isLoadingRelatedApps || !relatedApps.isEmpty {
            NBSection("تطبيقات ذات صلة") {
                if isLoadingRelatedApps {
                    ProgressView("جارٍ البحث عن تطبيقات مشابهة…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(relatedApps) { entry in
                            NavigationLink {
                                SourceAppsDetailView(sourceURL: entry.sourceURL, source: entry.source, app: entry.app)
                            } label: {
                                HStack(spacing: 12) {
                                    LazyImage(url: entry.app.iconURL) { state in
                                        if let image = state.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Image("App_Unknown").resizable().scaledToFit()
                                        }
                                    }
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.app.currentName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(entry.app.currentDescription ?? entry.category.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.forward")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(Color(uiColor: .secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 16))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func startDirectInstall() {
        guard let url = app.currentDownloadUrl else {
            directInstallError = "رابط تحميل التطبيق غير متوفر."
            return
        }
        let id = "FeatherDirectInstall_\(UUID().uuidString)"
        let download = downloadManager.startDownload(
            from: url,
            id: id,
            sourceProvenance: SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
        )
        download.directInstall = true
        directInstallDownloadID = download.id
    }

    private func signDirectInstall(importedUUID: String) {
        let request = NSFetchRequest<Imported>(entityName: "Imported")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "uuid == %@", importedUUID)
        guard let imported = try? Storage.shared.context.fetch(request).first else {
            directInstallError = "تعذر العثور على التطبيق بعد اكتمال التنزيل."
            return
        }
        let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        guard availableCertificates.indices.contains(selectedIndex) else {
            showCertificateAlert = true
            return
        }
        isDirectInstallSigning = true
        FR.signPackageFile(
            imported,
            using: OptionsManager.shared.options,
            icon: nil,
            certificate: availableCertificates[selectedIndex],
            onSigned: { signedUUID in
                let signedRequest = NSFetchRequest<Signed>(entityName: "Signed")
                signedRequest.fetchLimit = 1
                signedRequest.predicate = NSPredicate(format: "uuid == %@", signedUUID)
                if let signed = try? Storage.shared.context.fetch(signedRequest).first {
                    directInstallPreview = AnyApp(base: signed)
                } else {
                    directInstallError = "تم التوقيع لكن تعذر فتح واجهة التثبيت."
                }
            }
        ) { error in
            isDirectInstallSigning = false
            if let error { directInstallError = error.localizedDescription }
        }
    }

    private func importToLibrary() {
        guard let url = app.currentDownloadUrl else {
            directInstallError = "رابط تحميل التطبيق غير متوفر."
            return
        }
        libraryImportComplete = false
        let download = downloadManager.startDownload(
            from: url,
            id: app.currentUniqueId,
            sourceProvenance: SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
        )
        libraryImportDownloadID = download.id
    }

    private var storeActions: some View {
        HStack(spacing: 10) {
            Button {
                if installationMethod == DirectPolicy.method {
                    showAMARYTInstall = true
                } else if availableCertificates.isEmpty {
                    showCertificateAlert = true
                } else {
                    startDirectInstall()
                }
            } label: {
                if isDirectInstallSigning {
                    Label("جارٍ التوقيع…", systemImage: "checkmark.shield")
                } else if let id = directInstallDownloadID, downloadManager.getDownload(by: id) != nil {
                    Label("جارٍ التنزيل…", systemImage: "arrow.down.circle")
                } else {
                    Text("تثبيت")
                }
            }
            .disabled(isDirectInstallSigning || directInstallDownloadID != nil)
            .buttonStyle(.borderedProminent)
            Button {
                importToLibrary()
            } label: {
                if let id = libraryImportDownloadID,
                   let download = downloadManager.getDownload(by: id) {
                    VStack(spacing: 3) {
                        Text("جارٍ الاستيراد")
                        ProgressView(value: download.overallProgress)
                    }
                } else if libraryImportComplete {
                    Label("تمت الإضافة", systemImage: "checkmark")
                } else {
                    Text("استيراد إلى المكتبة")
                }
            }
            .disabled(libraryImportDownloadID != nil || libraryImportComplete)
            .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .alert("الشهادة مطلوبة", isPresented: $showCertificateAlert) {
            Button("إضافة شهادة") { showCertificates = true }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("يجب إضافة شهادة قبل تثبيت التطبيق.")
        }
        .alert("تعذر التثبيت", isPresented: Binding(
            get: { directInstallError != nil },
            set: { if !$0 { directInstallError = nil } }
        )) {
            Button("حسنًا", role: .cancel) { directInstallError = nil }
        } message: {
            Text(directInstallError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.libraryImportFinished"))) { notification in
            guard let downloadID = notification.object as? String,
                  downloadID == libraryImportDownloadID else { return }
            libraryImportDownloadID = nil
            if let error = notification.userInfo?["error"] as? String {
                directInstallError = error
            } else {
                libraryImportComplete = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.directInstallImported"))) { notification in
            guard let downloadID = notification.object as? String,
                  downloadID == directInstallDownloadID,
                  let uuid = notification.userInfo?["importedUUID"] as? String else { return }
            directInstallDownloadID = nil
            signDirectInstall(importedUUID: uuid)
        }
        .sheet(isPresented: $showAMARYTInstall) {
            DirectInstallView(input: .source(app.currentDownloadUrl, app.currentName, app.currentVersion, app.iconURL))
        }
        .sheet(item: $directInstallPreview) { app in
            InstallPreviewView(app: app.base, isSharing: app.archive)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCertificates) {
            NavigationStack {
                CertificatesView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("تم") { showCertificates = false }
                        }
                    }
            }
        }
    }

	var standardIcon: some View {
		Image("App_Unknown").appIconStyle(size: 111, isCircle: false)
	}
	
	var standardHeader: some View {
		Image("App_Unknown")
			.resizable()
			.aspectRatio(contentMode: .fill)
			.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
			.clipped()
	}
}

// MARK: - SourceAppsDetailView (Extension): Builders
extension SourceAppsDetailView {
	@available(iOS 18.0, *)
	@ViewBuilder
	private func _header() -> some View {
		ZStack {
			if let bannerURL = app.bannerURL {
				LazyImage(url: bannerURL) { state in
					if let image = state.image {
						image.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
							.clipped()
					} else {
						standardHeader
					}
				}
			} else if let iconURL = source.currentIconURL {
				LazyImage(url: iconURL) { state in
					if let image = state.image {
						image.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
							.clipped()
					} else {
						standardHeader
					}
				}
			} else {
				standardHeader
			}
			
			NBVariableBlurView()
				.rotationEffect(.degrees(-180))
				.overlay(
					LinearGradient(
						gradient: Gradient(colors: [
							Color.black.opacity(0.8),
							Color.black.opacity(0)
						]),
						startPoint: .top,
						endPoint: .bottom
					)
				)
		}
	}
	
	@ViewBuilder
	private func _infoPills(app: ASRepository.App) -> some View {
		let pillItems = _buildPills(from: app)
		HStack(spacing: 6) {
			ForEach(pillItems.indices, id: \.hashValue) { index in
				let pill = pillItems[index]
				NBPillView(
					title: pill.title,
					icon: pill.icon,
					color: pill.color,
					index: index,
					count: pillItems.count
				)
			}
		}
	}
	
	private func _buildPills(from app: ASRepository.App) -> [NBPillItem] {
		var pills: [NBPillItem] = []
		
		if let version = app.currentVersion {
			pills.append(NBPillItem(title: version, icon: "tag", color: Color.accentColor))
		}
		
		if let size = app.size {
			pills.append(NBPillItem(title: size.formattedByteCount, icon: "archivebox", color: .secondary))
		}
		
		return pills
	}
	
	@ViewBuilder
	private func _infoRow(title: String, value: String) -> some View {
		LabeledContent(title, value: value)
		Divider()
	}
	
	@ViewBuilder
	private func _screenshots(screenshotURLs: [URL]) -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(screenshotURLs.indices, id: \.self) { index in
					let url = screenshotURLs[index]
					LazyImage(url: url) { state in
						if let image = state.image {
							image
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(
									maxWidth: UIScreen.main.bounds.width - 32,
									maxHeight: 400
								)
								.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
								.overlay {
									RoundedRectangle(cornerRadius: 16, style: .continuous)
										.strokeBorder(.gray.opacity(0.3), lineWidth: 1)
								}
								.onTapGesture {
									_selectedScreenshotIndex = index
									_isScreenshotPreviewPresented = true
								}
						}
					}
				}
			}
			.padding(.horizontal)
			.compatScrollTargetLayout()
		}
		.compatScrollTargetBehavior()
		.padding(.horizontal, -16)
	}
}
