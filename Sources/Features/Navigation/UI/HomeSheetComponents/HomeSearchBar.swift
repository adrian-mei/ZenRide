import SwiftUI
import CoreLocation

struct HomeSearchBar: View {
    @Binding var searchQuery: String
    @Binding var isSearching: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    var onProfileTap: () -> Void
    var onCancelSearch: () -> Void
    var onClearSearch: () -> Void
    var onSubmitSearch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .font(Theme.Typography.body)

                TextField("Search Destinations", text: $searchQuery)
                    .focused(isSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .onSubmit {
                        onSubmitSearch()
                    }

                if !searchQuery.isEmpty {
                    Button {
                        onClearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .frame(width: 36, height: 36)
                    }
                } else if !isSearchFocused.wrappedValue {
                    Image(systemName: "mic.fill")
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))

            if isSearchFocused.wrappedValue {
                Button("Cancel") {
                    onCancelSearch()
                }
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acWood)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button(action: onProfileTap) {
                    Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(Theme.Colors.acLeaf)
                    .background(Circle().fill(Theme.Colors.acCream))
                    .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                }
            }
        }
    }
}
