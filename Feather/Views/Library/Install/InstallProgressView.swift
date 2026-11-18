//
//  InstallProgressView.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift

struct InstallProgressView: View {
	@Environment(\.storeMotion) private var motion
	
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	var body: some View {
		VStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(Color.accentColor.opacity(0.10))
					.frame(width: 92, height: 92)
					.blur(radius: 12)

                StoreProgressRing(viewModel.overallProgress)
                    .frame(width: 76, height: 76)

			_appIcon()
				.scaleEffect(viewModel.isCompleted ? 0.92 : 0.86)
				.animation(motion ? StoreTheme.feedback : nil, value: viewModel.isCompleted)
				.overlay(alignment: .bottomTrailing) {
					Image(systemName: viewModel.isCompleted ? "checkmark" : "arrow.down")
						.font(.system(size: 10, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: 23, height: 23)
						.background(viewModel.isCompleted ? Color.green : Color.accentColor, in: Circle())
						.overlay(Circle().stroke(.background, lineWidth: 2))
						.offset(x: 3, y: 3)
				}
			}
			.frame(width: 100, height: 100)
		}
	}
	
	@ViewBuilder
	private func _appIcon() -> some View {
		ZStack {
			FRAppIconView(app: app)
				.opacity(0.2)
				.frame(width: 54, height: 54)
				.foregroundStyle(Color.black)
			
			FRAppIconView(app: app)
				.frame(width: 54, height: 54)
				.mask(
					ZStack {
						Circle().strokeBorder(Color.white, lineWidth: 4.5)
						PieShape(progress: viewModel.overallProgress)
							.scaleEffect(viewModel.isCompleted ? 2.2 : 1)
							.animation(.smooth, value: viewModel.isCompleted)
					}
				)
				.animation(motion ? StoreTheme.feedback : nil, value: viewModel.overallProgress)
		}
	}
	
	struct PieShape: Shape {
		var progress: Double
		
		func path(in rect: CGRect) -> Path {
			var path = Path()
			let center = CGPoint(x: rect.midX, y: rect.midY)
			let radius = min(rect.width, rect.height) / 2
			let startAngle = Angle(degrees: -90)
			let endAngle = Angle(degrees: -90 + progress * 360)
			
			path.move(to: center)
			path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
			path.closeSubpath()
			
			return path
		}
		
		var animatableData: Double {
			get { progress }
			set { progress = newValue }
		}
	}
}
