//
//  FRTitleWithSubtitleView.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import SwiftUI

public struct NBTitleWithSubtitleView: View {
    @Environment(\.storeAppearance) private var appearance
	private let _title: String
	private let _subtitle: String
	private var _linelimit: Int? = nil
	
	public init(title: String, subtitle: String, linelimit: Int? = nil) {
		self._title = title
		self._subtitle = subtitle
		self._linelimit = linelimit
	}
	
	public var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(_title)
				.font(.headline)
				.foregroundColor(appearance == .professional ? StoreTheme.ink : .primary)
                .lineLimit(_linelimit == 0 ? 2 : _linelimit)
			Text(_subtitle)
				.font(.subheadline)
				.foregroundColor(appearance == .professional ? StoreTheme.muted : .secondary)
                .lineLimit(_linelimit == 0 ? 2 : _linelimit)
		}
		.padding(.vertical, 2)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
