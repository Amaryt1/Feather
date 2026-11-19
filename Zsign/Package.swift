// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Zsign",
	platforms: [
		.iOS(.v12),
		.macOS(.v10_15),
		.tvOS(.v12),
		.watchOS(.v8),
		.custom("xros", versionString: "1.3")
	],
	products: [
		.library(
			name: "zsignc",
			targets: ["ZsignC"]
		),
		.library(
			name: "Zsign",
			targets: ["Zsign"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/krzyzanowskim/OpenSSL", from: "3.3.3001")
	],
	targets: [
		.target(
			name: "ZsignC",
			dependencies: [
				.product(name: "OpenSSL", package: "OpenSSL")
			],
			path: ".",
			exclude: [
				"Upstream/src/common/archive.cpp",
				"Upstream/src/zsign.cpp"
			],
			sources: [
				"Upstream/src/archo.cpp",
				"bundle.cpp",
				"Upstream/src/macho.cpp",
				"Upstream/src/openssl.cpp",
				"Upstream/swift/utils.mm",
				"Upstream/src/signing.cpp",
				"Upstream/swift/zsign.mm",
				"Upstream/src/common/base64.cpp",
				"Upstream/src/common/fs.cpp",
				"Upstream/src/common/json.cpp",
				"Upstream/src/common/log.cpp",
				"Upstream/src/common/sha.cpp",
				"Upstream/src/common/timer.cpp",
				"Upstream/src/common/util.cpp"
			],
			publicHeadersPath: "Upstream/src/include",
			cxxSettings: [
				.headerSearchPath("Upstream/src"),
				.headerSearchPath("Upstream/src/common"),
				.unsafeFlags(["-std=c++17"])
			],
			linkerSettings: [
				.linkedFramework("OpenSSL"),
			]
		),
		.target(
			name: "Zsign",
			dependencies: [
				"ZsignC"
			],
			path: "Upstream/swift",
			sources: [
				"zsign.swift"
			]
		)
	]
)
