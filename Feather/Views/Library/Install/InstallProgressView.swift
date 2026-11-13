//
//  InstallProgressView.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import SwiftUI
import IDeviceSwift

struct InstallProgressView: View {
	@State private var _isPulsing = false
	
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	var body: some View {
		VStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(Color.accentColor.opacity(0.10))
					.frame(width: 92, height: 92)
					.blur(radius: 12)
					.scaleEffect(_isPulsing ? 1.18 : 0.92)
					.animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: _isPulsing)

				Circle()
					.stroke(Color.accentColor.opacity(0.14), lineWidth: 3)
					.frame(width: 76, height: 76)

				Circle()
					.trim(from: 0, to: max(0.025, min(viewModel.overallProgress, 1)))
					.stroke(
						AngularGradient(colors: [.cyan, Color.accentColor, .purple, .cyan], center: .center),
						style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
					)
					.rotationEffect(.degrees(-90))
					.frame(width: 76, height: 76)
					.animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.overallProgress)

			_appIcon()
				.scaleEffect(_isPulsing && !viewModel.isCompleted ? 0.91 : 0.86)
				.animation(.spring(response: 0.48, dampingFraction: 0.68), value: viewModel.isCompleted)
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
			.onAppear { _isPulsing = true }
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
				.animation(.smooth, value: viewModel.overallProgress)
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
