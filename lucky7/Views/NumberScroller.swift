import SwiftUI
import UIKit

struct NumberScroller: View {

    @Binding var selected: Int
    let range: ClosedRange<Int>
    var compact: Bool = false
    var wheelSize: CGFloat? = nil

    private var scrollerSize: CGFloat { wheelSize ?? (compact ? 84 : 92) }

    var body: some View {
        WheelNumberPicker(
            selection: $selected,
            range: range,
            diameter: scrollerSize
        )
        .frame(width: scrollerSize, height: scrollerSize)
        .contentShape(Circle())
    }
}

// MARK: - Font

private enum TimerFont {
    static func gothic(size: CGFloat) -> UIFont {
        UIFont(name: "SpecialGothicExpandedOne-Regular", size: size)
            ?? UIFont(name: "Special Gothic Expanded One", size: size)
            ?? .systemFont(ofSize: size, weight: .black)
    }
}

// MARK: - Circular Host

private final class CircularPickerHostView: UIView {

    let picker = UIPickerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .clear
        picker.backgroundColor = .clear
        picker.clipsToBounds = true
        addSubview(picker)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        picker.frame = bounds
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        guard bounds.contains(point) else { return nil }

        let radius = bounds.width / 2
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        guard (dx * dx + dy * dy) <= (radius * radius) else { return nil }

        let localPoint = convert(point, to: picker)
        return picker.hitTest(localPoint, with: event) ?? picker
    }
}

// MARK: - UIKit Wheel

private struct WheelNumberPicker: UIViewRepresentable {

    @Binding var selection: Int
    let range: ClosedRange<Int>
    let diameter: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CircularPickerHostView {
        let host = CircularPickerHostView(frame: .zero)
        host.picker.delegate = context.coordinator
        host.picker.dataSource = context.coordinator

        let row = context.coordinator.centeredRow(for: selection)
        host.picker.selectRow(row, inComponent: 0, animated: false)

        hidePickerSelectionLines(in: host.picker)
        context.coordinator.feedback.prepare()

        return host
    }

    func updateUIView(_ host: CircularPickerHostView, context: Context) {
        context.coordinator.parent = self

        let picker = host.picker
        let row = context.coordinator.centeredRow(for: selection)
        guard row >= 0, row < context.coordinator.totalRows else { return }

        if picker.selectedRow(inComponent: 0) != row {
            picker.selectRow(row, inComponent: 0, animated: false)
        }
    }

    private func hidePickerSelectionLines(in picker: UIPickerView) {
        DispatchQueue.main.async {
            picker.subviews.forEach { view in
                view.backgroundColor = .clear
                view.layer.borderWidth = 0
            }
        }
    }

    final class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        var parent: WheelNumberPicker
        let feedback = UISelectionFeedbackGenerator()
        private let repetitionCount = 80

        init(parent: WheelNumberPicker) {
            self.parent = parent
        }

        var valuesCount: Int {
            parent.range.count
        }

        var totalRows: Int {
            valuesCount * repetitionCount
        }

        func value(for row: Int) -> Int {
            let offset = row % valuesCount
            return parent.range.lowerBound + offset
        }

        func centeredRow(for value: Int) -> Int {
            let offset = value - parent.range.lowerBound
            let middle = totalRows / 2
            let base = middle - (middle % valuesCount)
            return base + offset
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            totalRows
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            parent.diameter * 0.26
        }

        func pickerView(
            _ pickerView: UIPickerView,
            viewForRow row: Int,
            forComponent component: Int,
            reusing view: UIView?
        ) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            let value = value(for: row)
            let isSelected = value == parent.selection

            let fontSize = isSelected
                ? parent.diameter * 0.35
                : parent.diameter * 0.16

            label.text = String(format: "%02d", value)
            label.textAlignment = .center
            label.font = TimerFont.gothic(size: fontSize)
            label.textColor = UIColor.white.withAlphaComponent(isSelected ? 1 : 0.18)
            label.backgroundColor = .clear

            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            feedback.selectionChanged()
            feedback.prepare()

            parent.selection = value(for: row)

            let centered = centeredRow(for: parent.selection)
            if row != centered {
                pickerView.selectRow(centered, inComponent: 0, animated: false)
            }

            let visibleRange = max(0, row - 2)...min(totalRows - 1, row + 2)
            for visibleRow in visibleRange {
                if let label = pickerView.view(forRow: visibleRow, forComponent: 0) as? UILabel {
                    let value = value(for: visibleRow)
                    let isSelected = value == parent.selection
                    let fontSize = isSelected
                        ? parent.diameter * 0.35
                        : parent.diameter * 0.16
                    label.text = String(format: "%02d", value)
                    label.font = TimerFont.gothic(size: fontSize)
                    label.textColor = UIColor.white.withAlphaComponent(isSelected ? 1 : 0.18)
                }
            }
        }
    }
}
