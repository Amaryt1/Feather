//
//  CertificatesAddView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
    var onSaved: (() -> Void)? = nil
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	
	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
			Form {
				NBSection(.localized("Files")) {
					_importButton(.localized("Import Certificate File"), file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("Import Provisioning File"), file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("Password")) {
					SecureField(.localized("Enter Password"), text: $_p12Password)
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
				}
				
				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
            .storeScreen()
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						_acceptPickedFile(urls.first, expectedExtension: "p12")
						_isImportingP12Presenting = false
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						_acceptPickedFile(urls.first, expectedExtension: "mobileprovision")
						_isImportingMobileProvisionPresenting = false
					}
				)
				.ignoresSafeArea()
			}
		}
        .onDisappear {
            // Remove private-key staging files when the user leaves the
            // certificate form without saving them.
            if !_isImportingP12Presenting && !_isImportingMobileProvisionPresenting {
                _discardCopiedFile(_p12URL)
                _discardCopiedFile(_provisionURL)
            }
        }
	}
}

// MARK: - Extension: View
extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor(.accentColor)
		.animation(.easeInOut(duration: 0.3), value: file != nil)
	}
}

// MARK: - Extension: View (import)
extension CertificatesAddView {
    private var _temporaryCertificateDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FeatherCertificateImports", isDirectory: true)
    }

    private func _discardCopiedFile(_ url: URL?) {
        guard let url,
              url.deletingLastPathComponent().standardizedFileURL ==
                  _temporaryCertificateDirectory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func _acceptPickedFile(_ selected: URL?, expectedExtension: String) {
        guard let selected else { return }
        guard selected.pathExtension.lowercased() == expectedExtension else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: expectedExtension == "p12"
                    ? "اختر شهادة بامتداد .p12."
                    : "اختر ملف تزويد بامتداد .mobileprovision."
            )
            return
        }

        // Preserve an app-owned copy while the picker goes away. This also
        // works with temporary URLs provided by iCloud Drive and third-party
        // Files providers.
        let accessing = selected.startAccessingSecurityScopedResource()
        defer { if accessing { selected.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.createDirectory(
                at: _temporaryCertificateDirectory,
                withIntermediateDirectories: true
            )
            let copy = _temporaryCertificateDirectory.appendingPathComponent(
                UUID().uuidString + "." + expectedExtension
            )
            try FileManager.default.copyItem(at: selected, to: copy)

            if expectedExtension == "p12" {
                _discardCopiedFile(_p12URL)
                _p12URL = copy
            } else {
                _discardCopiedFile(_provisionURL)
                _provisionURL = copy
            }
        } catch {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: "تعذّر استيراد الملف: " + error.localizedDescription
            )
        }
    }

	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("Bad Password"),
				message: .localized("Please check the password and try again.")
			)
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { error in
            if let error {
                UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
                return
            }
            _discardCopiedFile(_p12URL)
            _discardCopiedFile(_provisionURL)
            onSaved?()
			dismiss()
		}
	}
}

