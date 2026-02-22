import re

with open("Sources/AppMain.swift", "r") as f:
    content = f.read()

pattern = re.compile(r"RouteSelectionSheet\(destinationName: destinationName, onGo: \{\n\s*withAnimation\(\.spring\(response: 0.5, dampingFraction: 0.8\)\) \{\n\s*routeState = \.navigating\n\s*owlPolice\.simulateDrive\(along: routingService\.activeRoute\)\n\s*\}\n\s*\}, onCancel:", re.MULTILINE)

new_code = """RouteSelectionSheet(destinationName: destinationName, onDrive: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    owlPolice.isSimulating = false
                    // Real GPS updates handle progress
                }
            }, onSimulate: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    owlPolice.simulateDrive(along: routingService.activeRoute)
                }
            }, onCancel:"""

new_content = re.sub(pattern, new_code, content)

with open("Sources/AppMain.swift", "w") as f:
    f.write(new_content)
