import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColors.splashGradient

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 2)
                .offset(x: -120, y: -220)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: 140, y: 260)

            VStack(spacing: 20) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                    .scaleEffect(appeared ? 1 : 0.88)
                    .opacity(appeared ? 1 : 0)

                Text("CommonGround")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text("Volunteer management")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(appeared ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CommonGround")
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            onFinished()
        }
    }
}
