import SwiftUI

// MARK: - Design Tokens

enum AppRadius {
	static let card: CGFloat = 16
	static let control: CGFloat = 10
	static let field: CGFloat = 12
}

enum AppSpacing {
	static let tight: CGFloat = 8
	static let regular: CGFloat = 12
	static let relaxed: CGFloat = 16
	static let wide: CGFloat = 24
}

// MARK: - Glass Card (iOS 26 Liquid Glass with iOS 17 fallback)

struct GlassCardModifier: ViewModifier {
	var cornerRadius: CGFloat = AppRadius.card
	var fallbackFill: Color = Color("BackgroundCard")

	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content
				.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		} else {
			content
				.background(
					RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
						.fill(fallbackFill)
						.overlay(
							RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
								.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
						)
				)
		}
	}
}

extension View {
	func glassCard(cornerRadius: CGFloat = AppRadius.card, fallbackFill: Color = Color("BackgroundCard")) -> some View {
		modifier(GlassCardModifier(cornerRadius: cornerRadius, fallbackFill: fallbackFill))
	}
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
	var fullWidth: Bool = false
	@Environment(\.isEnabled) private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.body.weight(.semibold))
			.foregroundColor(.white)
			.padding(.horizontal, fullWidth ? 0 : 20)
			.frame(minHeight: 44)
			.frame(maxWidth: fullWidth ? .infinity : nil)
			.background(
				RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
					.fill(Color("AccentColor"))
					.opacity(configuration.isPressed ? 0.8 : 1)
			)
			.opacity(isEnabled ? 1 : 0.4)
	}
}

struct SubtleButtonStyle: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.body.weight(.medium))
			.padding(.horizontal, 14)
			.padding(.vertical, 8)
			.background(
				RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
					.fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
			)
			.opacity(isEnabled ? 1 : 0.4)
	}
}

// MARK: - Banner

struct BannerView: View {
	let message: String
	var actionTitle: String?
	let action: () -> Void

	var body: some View {
		HStack {
			Text(message)
				.font(.subheadline)
				.lineLimit(2)
			Spacer()
			if let actionTitle {
				Button(actionTitle, action: action)
					.font(.subheadline.weight(.semibold))
					.foregroundColor(Color("AccentColor"))
					.frame(minHeight: 44)
					.contentShape(Rectangle())
			}
		}
		.padding(.horizontal, AppSpacing.regular)
		.padding(.vertical, AppSpacing.tight)
		.glassCard(cornerRadius: AppRadius.control, fallbackFill: Color("BackgroundPrompt"))
	}
}

/**
 * Category Title
 *
 * Displays a title before the start of a list.
 */
struct CatTitle: View {
	var text: String

	init(_ text: String) {
		self.text = text
	}

	var body: some View {
		HStack {
			Text(text)
				.font(.subheadline.weight(.semibold))
				.opacity(0.7)
			Spacer()
		}
		.padding(.horizontal, AppSpacing.regular)
		.padding(.vertical, AppSpacing.tight)
	}
}

/**
 * Category List
 *
 * Displays a list of items. Acts as a container.
 * Use of `CatItem`s is recommended.
 */
struct CatList<Content: View>: View {
	var content: () -> Content

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	var body: some View {
		VStack(spacing: 0, content: content)
			.padding(.vertical, AppSpacing.tight)
			.glassCard(cornerRadius: 14, fallbackFill: Color("BackgroundTab"))
			.padding(.horizontal)
	}
}

/**
 * Category Item
 *
 * Displays a new item with a label in a list.
 * Should be used within `CatList`s.
 */
struct CatItem<Content: View>: View {
	var title: String
	var content: () -> Content

	init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.content = content
	}

	var body: some View {
		HStack {
			Text(title)
				.font(.body)
				.lineLimit(1)
			Spacer()
			content()
		}
		.padding(.horizontal, AppSpacing.regular)
		.padding(.vertical, 10)
	}
}

struct CatSlider: View {
	var title: String
	var value: Binding<Double>
	var range: ClosedRange<Double>
	var step: Double

	init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double) {
		self.title = title
		self.value = value
		self.range = range
		self.step = step
	}

	var body: some View {
		VStack(spacing: 6) {
			HStack {
				Text(title)
					.font(.body)
					.lineLimit(1)
				Spacer()
				Text(String(format: "%.1f", value.wrappedValue))
					.font(.subheadline)
					.monospacedDigit()
					.opacity(0.6)
			}
			Slider(value: value, in: range, step: step)
		}
		.padding(.horizontal, AppSpacing.regular)
		.padding(.vertical, 10)
	}
}

struct ConnectionLogPanel: View {
	@ObservedObject var log = ConnectionLog.shared

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			ForEach(Array(log.lines.suffix(14).enumerated()), id: \.offset) { _, line in
				Text(line)
					.font(.system(size: 10, design: .monospaced))
					.foregroundColor(.white.opacity(0.85))
					.lineLimit(2)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.padding(10)
		.frame(maxWidth: 640)
		.background(Color.black.opacity(0.55))
		.cornerRadius(8)
		.padding(.horizontal, 16)
		.padding(.top, 8)
	}
}

/**
 * Choice
 *
 * Used to depict a single choice with a given label and value.
 */
struct Choice<T: Hashable> {
	var label: String
	var value: T

	init(_ label: String, _ value: T) {
		self.label = label
		self.value = value
	}
}

/**
 * Segmented Picker
 *
 * Displays a segmented picker with a given list of choices.
 */
struct SegmentPicker<SelectionValue: Hashable>: View {
	var selection: Binding<SelectionValue>
	var options: [Choice<SelectionValue>]

	init(selection: Binding<SelectionValue>, options: [Choice<SelectionValue>]) {
		self.selection = selection
		self.options = options
	}

	var body: some View {
		Picker("", selection: selection) {
			ForEach(options.indices, id: \.self) { i in
				Text(options[i].label).tag(options[i].value)
			}
		}
		.pickerStyle(.segmented)
	}
}

/**
 * Multiple Choice Picker
 *
 * Displays a button that opens a menu to pick from a given list of choices.
 */
struct MultiPicker<SelectionValue: Hashable>: View {
	var selection: Binding<SelectionValue>
	var options: [Choice<SelectionValue>]

	init(selection: Binding<SelectionValue>, options: [Choice<SelectionValue>]) {
		self.selection = selection
		self.options = options
	}

	var body: some View {
		Picker("", selection: selection) {
			ForEach(options.indices, id: \.self) { i in
				Text(options[i].label).tag(options[i].value)
			}
		}
		.pickerStyle(.menu)
	}
}

struct ExUI_Previews: PreviewProvider {
	@State static var value1 = false
	@State static var value2 = true

	static var previews: some View {
		VStack {
			CatTitle("Category Title")
			CatList {
				CatItem("Category Item") {
					Toggle("", isOn: .constant(true))
						.frame(width: 80)
				}
			}
			CatTitle("Other Controls")
			CatList {
				CatItem("Segmented Picker") {
					SegmentPicker(selection: $value1, options:
					[
						Choice("False", false),
						Choice("True", true)
					])
					.frame(width: 180)
				}
				CatItem("Multiple Choice Picker") {
					MultiPicker(selection: $value2, options:
					[
						Choice("False", false),
						Choice("True", true)
					])
				}
			}
			Spacer()
		}
		.background(Rectangle().fill(Color("BackgroundGray")).edgesIgnoringSafeArea(.all))
		.foregroundColor(Color("Foreground"))
		.colorScheme(appScheme)
	}
}
