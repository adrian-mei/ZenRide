import re

with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'r') as f:
    content = f.read()

new_dedup = """                var finalResults = matchedRecents
                var seenCoordinates = Set<String>()
                
                // Keep track of coordinates we've already added (from recents)
                for r in matchedRecents {
                    let coordStr = "\\(String(format: "%.4f", r.placemark.coordinate.latitude)),\\(String(format: "%.4f", r.placemark.coordinate.longitude))"
                    seenCoordinates.insert(coordStr)
                }
                
                for item in sortedNetworkResults {
                    let coordStr = "\\(String(format: "%.4f", item.placemark.coordinate.latitude)),\\(String(format: "%.4f", item.placemark.coordinate.longitude))"
                    
                    // Don't deduplicate simply by name, as there can be multiple branches of a store.
                    // Deduplicate by approximate location to avoid showing the exact same physical place twice.
                    if !seenCoordinates.contains(coordStr) {
                        finalResults.append(item)
                        seenCoordinates.insert(coordStr)
                    }
                }"""

# Need to replace the final section inside search(for:)
content = re.sub(r'                var finalResults = matchedRecents\n                var seenNames = Set<String>\(\)\n                for r in matchedRecents \{\n                    seenNames\.insert\(\(r\.name \?\? ""\)\.lowercased\(\)\)\n                \}\n                \n                for item in sortedNetworkResults \{\n                    let name = \(item\.name \?\? ""\)\.lowercased\(\)\n                    if \!seenNames\.contains\(name\) \{\n                        finalResults\.append\(item\)\n                        seenNames\.insert\(name\)\n                    \}\n                \}', new_dedup, content)

with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'w') as f:
    f.write(content)
