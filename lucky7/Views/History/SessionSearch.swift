//
//  SessionSearch.swift
//  lucky7
//

import SwiftUI
import SwiftData

struct SessionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var results: [Session] {
        guard !trimmedQuery.isEmpty else { return sessions }
        return sessions.filter { $0.matchesSearch(trimmedQuery) }
    }

    /// Real top safe-area inset. `proxy.safeAreaInsets` reads 0 inside the full-screen
    /// `.ignoresSafeArea()` canvas below, so read it from the key window instead — this is
    /// what keeps the bar clear of the status bar / Dynamic Island.
    private var safeTopInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top) ?? 47
    }

    var body: some View {
        // A full-screen GeometryReader with a FIXED frame is the reliable way to stop the
        // keyboard from shoving the search bar off the top: the canvas is locked to the whole
        // screen (it ignores ALL safe areas, keyboard included), so focusing the field can't
        // resize or offset the content. The top safe-area inset is re-added by hand so the bar
        // still sits below the status bar; results just scroll under the keyboard.
        ResponsiveReader { metrics in
            ZStack(alignment: .top) {
                Color("CanvasBlue")

                Image("PatternBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: metrics.width, height: metrics.height)
                    .clipped()

                // Tapping any empty area dismisses the keyboard.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { searchFocused = false }

                VStack(spacing: 0) {
                    searchBar(metrics: metrics)

                    if results.isEmpty {
                        noResults
                            .adaptiveReadableFrame(metrics, maxWidth: metrics.isPad ? 560 : nil)
                    } else {
                        feed(metrics: metrics)
                    }
                }
                .padding(.top, max(safeTopInset, metrics.safeArea.top))
            }
            .frame(width: metrics.width, height: metrics.height)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Small delay so the field is in the hierarchy (after the push) before focusing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                searchFocused = true
            }
        }
    }

    // MARK: - Search bar

    private func searchBar(metrics: ResponsiveMetrics) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)

                TextField("", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .fixedPlaceholder("Search by title or date", isEmpty: searchText.isEmpty, font: .system(size: 16, weight: .medium))
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel("Search sessions")
                    .accessibilityHint("Search by session title or date")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 2))
            )

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)        // bigger tap target, same glyph size
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close search")
            .accessibilityInputLabels(["close", "done"])
        }
        .adaptiveReadableFrame(metrics, maxWidth: metrics.isPad ? 720 : nil)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Results

    private func feed(metrics: ResponsiveMetrics) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(results) { session in
                    NavigationLink {
                        SessionAnalytics(sessionId: session.id)
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .adaptiveReadableFrame(metrics, maxWidth: metrics.prefersTwoColumns ? 900 : (metrics.isPad ? 720 : nil))
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, metrics.safeArea.bottom + 40)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - No results

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🙏")
                .font(.system(size: 64))
                .accessibilityDecorative()
            Text(trimmedQuery.isEmpty ? "No sessions yet" : "Sorry, no session found...")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(trimmedQuery.isEmpty
                 ? "Your focus sessions will show up here."
                 : "Try another keywords or date for the session you are looking for")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search matching

extension Session {
    /// Matches a query against the session title and several date spellings,
    /// so "May 31", "31", "may", "2026", "24 May" or "5/31" all find the right session.
    func matchesSearch(_ query: String) -> Bool {
        let title = self.title.isEmpty ? "Untitled Session" : self.title
        if title.localizedCaseInsensitiveContains(query) { return true }

        let formatter = DateFormatter()
        let dateFormats = ["MMMM d yyyy", "MMM d", "d MMMM yyyy", "M/d/yyyy", "yyyy-MM-dd", "EEEE", "MMMM", "yyyy"]
        for format in dateFormats {
            formatter.dateFormat = format
            if formatter.string(from: startTime).localizedCaseInsensitiveContains(query) {
                return true
            }
        }
        return false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionSearchView()
            .modelContainer(sampleMonitorContainer())
    }
}
