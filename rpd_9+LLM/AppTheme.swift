//
//  AppTheme.swift
//  rpd_9+LLM
//
//  Created by Assistant on 11/25/25.
//

import SwiftUI

/// App-wide color theme with custom color scheme
struct AppTheme {
    
    // MARK: - Color Palette
    
    /// Lightest shade - Off-white/Cream (Primary background)
    static let lightest = Color(red: 249/255, green: 248/255, blue: 246/255)
    static let background = lightest
    
    /// Light beige (Secondary background)
    static let light = Color(red: 239/255, green: 233/255, blue: 227/255)
    static let backgroundSecondary = light
    
    /// Medium beige (Tertiary background / Card backgrounds)
    static let medium = Color(red: 217/255, green: 207/255, blue: 199/255)
    static let backgroundTertiary = medium
    
    /// Warm tan/taupe (Accent / Buttons)
    static let dark = Color(red: 201/255, green: 181/255, blue: 156/255)
    static let accent = dark
    
    /// Black (Text / Icons)
    static let darkest = Color.black
    static let text = darkest
    
    // MARK: - Semantic Colors
    
    /// Primary text color (black)
    static let textPrimary = text
    
    /// Secondary text color (lighter black for less emphasis)
    static let textSecondary = Color.black.opacity(0.7)
    
    /// Tertiary text color (even lighter for captions)
    static let textTertiary = Color.black.opacity(0.5)
    
    /// Primary button background
    static let buttonPrimary = accent
    
    /// Secondary button background
    static let buttonSecondary = backgroundTertiary
    
    /// Card background
    static let cardBackground = backgroundSecondary
    
    /// Elevated card background
    static let cardBackgroundElevated = backgroundTertiary
    
    /// Divider color
    static let divider = Color.black.opacity(0.15)
    
    // MARK: - Status Colors (Using theme-appropriate shades)
    
    /// Success/completion color
    static let success = Color(red: 140/255, green: 160/255, blue: 130/255) // Muted sage green
    
    /// Warning color
    static let warning = Color(red: 210/255, green: 180/255, blue: 140/255) // Warm tan
    
    /// Error color
    static let error = Color(red: 180/255, green: 130/255, blue: 120/255) // Muted terracotta
    
    /// Info/accent color (using the main accent)
    static let info = accent
    
    // MARK: - Gradient Backgrounds
    
    /// Main app gradient (using theme colors)
    static let mainGradient = LinearGradient(
        colors: [background, backgroundSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Card gradient
    static let cardGradient = LinearGradient(
        colors: [backgroundSecondary, backgroundTertiary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent gradient (for special elements)
    static let accentGradient = LinearGradient(
        colors: [backgroundTertiary, accent],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Track-Specific Colors (Adjusted to theme)
    
    /// HVAC track color - warm orange-brown
    static let hvacColor = Color(red: 190/255, green: 160/255, blue: 130/255)
    
    /// Nursing track color - soft blue-grey
    static let nursingColor = Color(red: 170/255, green: 180/255, blue: 190/255)
    
    /// Spiritual track color - warm purple-grey
    static let spiritualColor = Color(red: 180/255, green: 170/255, blue: 180/255)
    
    /// Mental Health track color - muted green
    static let mentalHealthColor = Color(red: 170/255, green: 180/255, blue: 160/255)
    
    // MARK: - Spacing & Layout
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    struct Shadow {
        static let sm: CGFloat = 2
        static let md: CGFloat = 4
        static let lg: CGFloat = 8
    }
    
    // MARK: - Typography
    
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Apply standard card styling with theme colors
    func themedCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.md)
            .shadow(color: AppTheme.darkest.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    /// Apply elevated card styling
    func themedCardElevated(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.cardBackgroundElevated)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadow(color: AppTheme.darkest.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    /// Apply primary button styling
    func themedButtonPrimary() -> some View {
        self
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.lightest)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.darkest)
            .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    /// Apply secondary button styling
    func themedButtonSecondary() -> some View {
        self
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.medium)
            .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    /// Apply theme background
    func themedBackground() -> some View {
        self
            .background(AppTheme.background)
    }
    
    /// Apply gradient background
    func themedGradientBackground() -> some View {
        self
            .background(AppTheme.mainGradient)
    }
    
    /// Apply image background with overlay
    func imageBackground(_ imageName: String, opacity: Double = 0.3, blendMode: BlendMode = .normal) -> some View {
        self
            .background(
                ZStack {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(opacity)
                        .blendMode(blendMode)
                    
                    // Optional gradient overlay to ensure readability
                    AppTheme.mainGradient
                        .opacity(0.7)
                        .ignoresSafeArea()
                }
            )
    }
    
    /// Apply image background with custom gradient overlay
    func imageBackgroundWithGradient(_ imageName: String, imageOpacity: Double = 0.5, gradientOpacity: Double = 0.8) -> some View {
        self
            .background(
                ZStack {
                    // Background image
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(imageOpacity)
                    
                    // Theme gradient overlay for consistency and readability
                    AppTheme.mainGradient
                        .opacity(gradientOpacity)
                        .ignoresSafeArea()
                }
            )
    }
    
    /// Apply parallax image background
    func parallaxImageBackground(_ imageName: String, opacity: Double = 0.4) -> some View {
        self
            .background(
                GeometryReader { geometry in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(opacity)
                        .ignoresSafeArea()
                }
            )
            .background(AppTheme.mainGradient.ignoresSafeArea())
    }
    
    /// Apply glassomorphic effect to icons
    func glassIcon(size: CGFloat = 60, backgroundColor: Color = AppTheme.backgroundSecondary) -> some View {
        self
            .frame(width: size, height: size)
            .background(
                ZStack {
                    // Frosted glass background
                    backgroundColor
                        .opacity(0.4)
                    
                    // Light reflection on top
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    /// Apply glassomorphic effect to rectangular icons/cards
    func glassCard(cornerRadius: CGFloat = AppTheme.CornerRadius.md, backgroundColor: Color = AppTheme.backgroundSecondary) -> some View {
        self
            .background(
                ZStack {
                    // Frosted glass background
                    backgroundColor
                        .opacity(0.4)
                    
                    // Light reflection
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}


