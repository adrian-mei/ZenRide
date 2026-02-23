import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = "rider@zenride.app"
    @State private var name = "Zen Rider"
    @State private var subscription = "Pro Rider"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.cyan)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(white: 0.1))
                
                Section(header: Text("Subscription").foregroundColor(.white.opacity(0.6))) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscription)
                                .font(.headline)
                                .foregroundColor(.cyan)
                            Text("Active until Dec 2026")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button("Manage") {
                            // Action
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(white: 0.1))
                
                Section(header: Text("Account").foregroundColor(.white.opacity(0.6))) {
                    NavigationLink(destination: VoiceSettingsView()) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("GPS Voice")
                        }
                    }
                    .foregroundColor(.white)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("Edit Profile")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .foregroundColor(.white)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("Notifications")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .foregroundColor(.white)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("Privacy Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .foregroundColor(.white)
                }
                .listRowBackground(Color(white: 0.1))
                
                Section {
                    Button(action: {}) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color(white: 0.1))
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
