import sys

content = open('Sources/Features/Experiences/UI/ExperienceDetailView.swift').read()

# Make the map full width and a bit more prominent
content = content.replace('.frame(height: 250)\n                .clipShape(RoundedRectangle(cornerRadius: 16))\n                .padding()', '.frame(height: 250)')

# Use Theme.Colors.acCream for list background to match the rest of the app's aesthetic
content = content.replace('.listStyle(.plain)', '.listStyle(.insetGrouped)\n                .scrollContentBackground(.hidden)\n                .background(Theme.Colors.acField)')

# Update the map section to include a shadow and better styling
content = content.replace('// Map Section', '''// Map Section
                ZStack(alignment: .bottom) {''')

content = content.replace('.frame(height: 250)', '''.frame(height: 250)
                    
                    // Gradient overlay to blend map into content
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, Theme.Colors.acField.opacity(0.8), Theme.Colors.acField]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }''')

# Update the header in the list
old_header = '''                    } header: {
                        HStack {
                            Text("Stops")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(Theme.Colors.acWood)
                            Spacer()
                            if isCustomized {
                                Button("Save Order") {
                                    saveCustomOrder()
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.acLeaf)
                            }
                        }
                    }'''
new_header = '''                    } header: {
                        HStack {
                            Text("Destinations")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .textCase(None)
                            
                            Spacer()
                            
                            if isCustomized {
                                Button {
                                    withAnimation {
                                        saveCustomOrder()
                                    }
                                } label: {
                                    Text("Save Order")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.Colors.acLeaf)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 8)
                    }'''
content = content.replace(old_header, new_header)

# Make the bottom button stick better to the bottom and have a shadow
old_bottom = '''                // Bottom Button
                Button {
                    startExperience(from: 0)
                } label: {
                    Text("Start Full Experience")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.acLeaf)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()'''

new_bottom = '''                // Bottom Button
                VStack {
                    Button {
                        startExperience(from: 0)
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Start Full Experience")
                        }
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.acLeaf)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Theme.Colors.acLeaf.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Theme.Colors.acField)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)'''
content = content.replace(old_bottom, new_bottom)

# Add spacing in the main VStack
content = content.replace('VStack(spacing: 0) {', 'VStack(spacing: 0) {')

# Improve the list row appearance
old_row = '''                                HStack(alignment: .top) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.Colors.acWood)
                                            .frame(width: 24, height: 24)
                                        Text("\\(index + 1)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stop.name)
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.Colors.acTextDark)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Text(stop.description)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.Colors.acTextMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Start") {
                                        startExperience(from: index)
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.Colors.acWood)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                }'''

new_row = '''                                HStack(alignment: .top, spacing: 16) {
                                    // Number Badge
                                    ZStack {
                                        Circle()
                                            .fill(Theme.Colors.acCream)
                                            .frame(width: 32, height: 32)
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        Text("\\(index + 1)")
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.Colors.acWood)
                                    }
                                    .padding(.top, 2)
                                    
                                    // Content
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(stop.name)
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.Colors.acTextDark)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Text(stop.description)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.Colors.acTextMuted)
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.bottom, 4)
                                        
                                        // Start Button
                                        Button {
                                            startExperience(from: index)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 10))
                                                Text("Start Here")
                                            }
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.Colors.acWood.opacity(0.1))
                                            .foregroundColor(Theme.Colors.acWood)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Spacer(minLength: 0)
                                }'''
content = content.replace(old_row, new_row)
content = content.replace('.listRowBackground(Theme.Colors.acCream)', '')
content = content.replace('} header: {', '}\n                        .listRowBackground(Theme.Colors.acCream)\n                        .listRowSeparator(.hidden)\n                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))\n                    } header: {')

# Adjust padding and corner radius on row content
content = content.replace('.padding(.vertical, 4)', '.padding(.vertical, 8)')

# Add description
content = content.replace('                    Section {', '''                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(experience.subtitle)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .fixedSize(horizontal: false, vertical: true)
                                
                            Text(experience.description)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                                
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                    Text("\\(experience.durationMinutes) min")
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                    Text(experience.city)
                                }
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acWood)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                    }
                    
                    Section {''')

open('Sources/Features/Experiences/UI/ExperienceDetailView.swift', 'w').write(content)
