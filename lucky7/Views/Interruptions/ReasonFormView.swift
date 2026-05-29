import SwiftUI

struct ReasonFormView: View {
    let appName: String
    @State private var reason: String = ""
    let onSubmit: (String) -> Void
    let onSkip: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color("CanvasRed").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                Image("ReasonFormHeader")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 140)
                    .padding(.horizontal, 60)
                    .zIndex(2)
                    .offset(y: 40)

                reasonCard
                    .zIndex(1)

                buttons
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onTapGesture { fieldFocused = false }
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reason")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 28))
                .foregroundStyle(Color("CanvasRed"))
                .padding(.top, 24)

            ZStack(alignment: .topLeading) {
                if reason.isEmpty {
                    Text("I open this because….")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $reason)
                    .scrollContentBackground(.hidden)
                    .focused($fieldFocused)
                    .frame(minHeight: 200)
            }
            .font(.body)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(.white)
        )
    }

    private var buttons: some View {
        VStack(spacing: 4) {
            Button {
                onSubmit(reason)
            } label: {
                Text("SUBMIT")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.black, in: Capsule())
            }
            Button(action: onSkip) {
                Text("SKIP")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
            }
        }
    }
}

#Preview {
    ReasonFormView(
        appName: "YouTube",
        onSubmit: { _ in },
        onSkip: {}
    )
}
