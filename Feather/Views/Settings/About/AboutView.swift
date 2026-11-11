//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI

// MARK: - View
struct AboutView: View {
    private let accountURL = URL(string: "https://telegram.me/LLYDL")!
    private let channelURL = URL(string: "https://telegram.me/amaryt")!
    private let supportURL = URL(string: "https://telegram.me/ammaryt")!
    private let licenseURL = URL(string: "https://github.com/Amaryt1/Feather/blob/main/LICENSE")!

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerCard

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle(
                        "تواصل معي",
                        subtitle: "اختر الوجهة المناسبة، وسأكون سعيداً بالتواصل معك."
                    )

                    contactCard(
                        title: "حسابي",
                        detail: "@LLYDL",
                        description: "للتواصل الشخصي والاستفسارات",
                        symbol: "person.crop.circle.fill",
                        tint: Color(red: 0.25, green: 0.58, blue: 0.94),
                        destination: accountURL
                    )

                    contactCard(
                        title: "قناتي",
                        detail: "@amaryt",
                        description: "تابع الأخبار والتحديثات الجديدة",
                        symbol: "paperplane.fill",
                        tint: Color(red: 0.20, green: 0.68, blue: 0.83),
                        destination: channelURL
                    )

                    contactCard(
                        title: "مناقشة وحل المشاكل",
                        detail: "@ammaryt",
                        description: "للدعم ومناقشة المشاكل والاقتراحات",
                        symbol: "bubble.left.and.bubble.right.fill",
                        tint: Color(red: 0.38, green: 0.70, blue: 0.48),
                        destination: supportURL
                    )
                }

                licenseCard

                Text("شكراً لاستخدامك Feather ودعمك للمشروع.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("حول")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.28, blue: 0.62),
                            Color(red: 0.36, green: 0.43, blue: 0.82),
                            Color(red: 0.31, green: 0.57, blue: 0.79)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 170, height: 170)
                .offset(x: 105, y: -78)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .frame(width: 210, height: 210)
                .offset(x: -125, y: 90)

            VStack(spacing: 12) {
                FRAppIconView(size: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

                VStack(spacing: 5) {
                    Text("Feather")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("مساحة واحدة للتواصل والدعم")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))
                }

                HStack(spacing: 8) {
                    headerPill(title: "الإصدار \(Bundle.main.version)", symbol: "number")
                    headerPill(title: "المجتمع", symbol: "person.3.fill")
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 25)
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var licenseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("المصادر المفتوحة والتراخيص")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text("يحتفظ المشروع بإشعارات حقوق النشر والتراخيص الخاصة بالمصادر المفتوحة والمكتبات المستخدمة. يمكنك مراجعة نص الترخيص والتفاصيل من هنا.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: licenseURL) {
                HStack(spacing: 8) {
                    Text("عرض التراخيص وحقوق المصدر")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .background,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerPill(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.white.opacity(0.15), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func contactCard(
        title: String,
        detail: String,
        description: String,
        symbol: String,
        tint: Color,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 1)
                }

                Spacer(minLength: 5)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(9)
                    .background(Color.primary.opacity(0.045), in: Circle())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .background,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)، \(detail). \(description)")
    }
}
