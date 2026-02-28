import re
import os

files_to_update = [
    'Sources/Features/Navigation/UI/CampCruiseSetupSheet.swift',
    'Sources/Features/Navigation/UI/CruiseSearchSheet.swift',
    'Sources/Features/Navigation/UI/QuestBuilderView.swift',
    'Sources/Features/Garage/UI/GarageView.swift'
]

for filepath in files_to_update:
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, 'r') as f:
        content = f.read()

    # If it already has savedRoutes or recentSearches being passed, skip to avoid double injecting
    if 'recentSearches: savedRoutes.recentSearches' in content:
        continue
        
    # Make sure we import environment object if missing (might be needed for CruiseSearchSheet)
    if 'savedRoutes' not in content and '@StateObject private var searcher' in content:
        content = re.sub(
            r'(@StateObject private var searcher = DestinationSearcher\(\))',
            r'@EnvironmentObject var savedRoutes: SavedRoutesStore\n    \1',
            content
        )

    # Update calls
    content = re.sub(
        r'searcher\.search\(for: ([^,]+), near: ([^\)]+)\)',
        r'searcher.search(for: \1, near: \2, recentSearches: savedRoutes.recentSearches)',
        content
    )

    with open(filepath, 'w') as f:
        f.write(content)
