//
//  AboutView.swift
//  Feather
//
//  Custom community About screen.
//

import SwiftUI
import UIKit

struct AboutView: View {
    private let links: [AboutSocialLink] = [
        .init(
            title: "حسابي",
            subtitle: "تابعني وتواصل معي مباشرة",
            symbol: "person.crop.circle.fill",
            url: "https://telegram.me/LLYDL",
            tint: Color(red: 0.20, green: 0.62, blue: 0.88)
        ),
        .init(
            title: "قناتي",
            subtitle: "تابع آخر الأخبار والتحديثات",
            symbol: "megaphone.fill",
            url: "https://telegram.me/amaryt",
            tint: Color(red: 0.36, green: 0.48, blue: 0.92)
        ),
        .init(
            title: "مناقشة وحل المشاكل",
            subtitle: "للدعم الفني والإبلاغ عن المشاكل",
            symbol: "message.fill",
            url: "https://telegram.me/ammaryt",
            tint: Color(red: 0.20, green: 0.68, blue: 0.53)
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("تواصل معي", subtitle: "اختر الوجهة المناسبة لك")
                    VStack(spacing: 10) {
                        ForEach(links) { item in
                            AboutSocialLinkRow(item: item)
                        }
                    }
                }

                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 34)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("حول")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.22), Color.purple.opacity(0.13)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)

                FRAppIconView(size: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
            }

            VStack(spacing: 5) {
                Text("Feather")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("مساحة التواصل والدعم")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("الإصدار \(Bundle.main.version)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.11), in: Capsule())
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
                }
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
            Text("شكراً لاستخدامك Feather")
                .foregroundStyle(.secondary)
        }
        .font(.footnote.weight(.medium))
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

private struct AboutSocialLink: Identifiable {
    let title: String
    let subtitle: String
    let symbol: String
    let url: String
    let tint: Color

    var id: String { url }
}

private struct AboutSocialLinkRow: View {
    let item: AboutSocialLink

    var body: some View {
        Link(destination: URL(string: item.url)!) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(item.tint.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(9)
                    .background(Color.primary.opacity(0.045), in: Circle())
            }
            .padding(13)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("يفتح رابط تيليجرام")
    }
}
