import Foundation

let path = "Sources/AppMain.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// Fix the greedy Divider and layout overlap issue by constraining the width of the whole block
let searchStr = """
                            VStack(spacing: 0) {
                                if routeState == .navigating {
                                    Button(action: {}) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                } else {
                                    Button(action: {}) {
                                        Image(systemName: "map.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                }
                                
                                Button(action: {}) {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .foregroundColor(.primary)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
"""

let replaceStr = """
                            VStack(spacing: 0) {
                                if routeState == .navigating {
                                    Button(action: {}) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                } else {
                                    Button(action: {}) {
                                        Image(systemName: "map.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                }
                                
                                Button(action: {}) {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .frame(width: 48) // Strict constraint for layout issue
                            .foregroundColor(.primary)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
"""

content = content.replacingOccurrences(of: searchStr, with: replaceStr)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
