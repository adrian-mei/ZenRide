import re

with open("Sources/RouteSelectionSheet.swift", "r") as f:
    content = f.read()

header = """struct RouteSelectionSheet: View {
    let destinationName: String
    var onDrive: () -> Void
    var onSimulate: () -> Void
    var onCancel: () -> Void"""

content = re.sub(r"struct RouteSelectionSheet: View \{\n    let destinationName: String\n    var onGo: \(\) -> Void\n    var onCancel: \(\) -> Void", header, content)

actions = """            // Actions
            HStack(spacing: 16) {
                #if targetEnvironment(simulator)
                Button(action: {
                    timer?.invalidate()
                    onSimulate()
                }) {
                    Text("Simulate")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }
                #endif
                
                Button(action: {
                    timer?.invalidate()
                    onDrive()
                }) {
                    Text(countdown > 0 ? "GO (\(countdown)s)" : "GO")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }"""

content = re.sub(r"            // Actions\n            HStack\(spacing: 16\) \{\n.*?\n                Button\(action: \{\n                    timer\?\.invalidate\(\)\n                    onGo\(\)\n                \}\)", actions, content, flags=re.DOTALL)

content = content.replace("onGo()", "onDrive()")

with open("Sources/RouteSelectionSheet.swift", "w") as f:
    f.write(content)
