import AppKit
import SwiftUI

/// Outer menu-bar panel corner radius (matches Chief of Staff panel).
enum MenuBarPanelMetrics {
    static let cornerRadius: CGFloat = 16
}

/// Vibrancy backdrop for the menu-bar panel.
struct GlassBackdrop: NSViewRepresentable {
    var cornerRadius: CGFloat = MenuBarPanelMetrics.cornerRadius

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        applyCornerRadius(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        applyCornerRadius(to: nsView)
    }

    private func applyCornerRadius(to view: NSVisualEffectView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }
}

/// Rounds the `MenuBarExtra` window. SwiftUI `clipShape` alone cannot round the AppKit window chrome.
struct MenuBarPanelWindowRounding: NSViewRepresentable {
    var cornerRadius: CGFloat = MenuBarPanelMetrics.cornerRadius

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleApply(from: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.shouldRetry(anchor: nsView) {
            coordinator.reset()
        }
        guard coordinator.needsApply(cornerRadius: cornerRadius, anchor: nsView) else { return }
        scheduleApply(from: nsView, coordinator: coordinator)
    }

    private func scheduleApply(from anchor: NSView, coordinator: Coordinator, attempt: Int = 0) {
        DispatchQueue.main.async {
            if let window = anchor.window, let contentView = window.contentView {
                let installed = Self.applyRounding(
                    cornerRadius: cornerRadius,
                    window: window,
                    contentView: contentView,
                    coordinator: coordinator
                )
                if installed { return }
            }
            guard attempt < 12 else {
                coordinator.markUnavailable()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                scheduleApply(from: anchor, coordinator: coordinator, attempt: attempt + 1)
            }
        }
    }

    @discardableResult
    private static func applyRounding(
        cornerRadius: CGFloat,
        window: NSWindow,
        contentView: NSView,
        coordinator: Coordinator
    ) -> Bool {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = .clear

        guard let shadowView = installShadow(on: contentView, cornerRadius: cornerRadius) else {
            return false
        }
        // Keep the shadow sibling behind contentView if SwiftUI reordered the hierarchy.
        if let parent = contentView.superview, shadowView.superview === parent {
            parent.addSubview(shadowView, positioned: .below, relativeTo: contentView)
        }

        coordinator.configuredWindow = window
        coordinator.configuredRadius = cornerRadius
        coordinator.shadowInstalled = true
        coordinator.gaveUp = false
        return true
    }

    @discardableResult
    private static func installShadow(on contentView: NSView, cornerRadius: CGFloat) -> NSView? {
        let identifier = "eithernet.panel.shadow"
        guard let parent = contentView.superview else { return nil }

        let shadowView: NSView
        if let existing = parent.subviews.first(where: { $0.identifier?.rawValue == identifier }) {
            shadowView = existing
            if shadowView.superview !== parent {
                parent.addSubview(shadowView, positioned: .below, relativeTo: contentView)
            }
        } else {
            let view = NSView(frame: .zero)
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.001).cgColor
            parent.addSubview(view, positioned: .below, relativeTo: contentView)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
            shadowView = view
        }

        shadowView.layer?.cornerRadius = cornerRadius
        shadowView.layer?.cornerCurve = .continuous
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.28
        shadowView.layer?.shadowRadius = 18
        shadowView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        shadowView.layer?.masksToBounds = false
        return shadowView
    }

    final class Coordinator {
        weak var configuredWindow: NSWindow?
        var configuredRadius: CGFloat = -1
        var shadowInstalled = false
        var gaveUp = false

        func reset() {
            configuredWindow = nil
            configuredRadius = -1
            shadowInstalled = false
            gaveUp = false
        }

        func markUnavailable() {
            gaveUp = true
        }

        func shouldRetry(anchor: NSView) -> Bool {
            gaveUp && anchor.window != nil
        }

        func needsApply(cornerRadius: CGFloat, anchor: NSView) -> Bool {
            if gaveUp { return false }
            guard let window = anchor.window else { return true }
            if !shadowInstalled { return true }
            return configuredWindow !== window || configuredRadius != cornerRadius
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                    )
            )
    }
}
