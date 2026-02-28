import plistlib
import sys

def add_background_location(plist_path):
    with open(plist_path, 'rb') as f:
        pl = plistlib.load(f)
    
    pl['NSLocationAlwaysAndWhenInUseUsageDescription'] = "We need your location in the background to continue navigating and alerting you of speed cameras."
    pl['UIBackgroundModes'] = ["location", "audio"]
    
    with open(plist_path, 'wb') as f:
        plistlib.dump(pl, f)

if __name__ == "__main__":
    add_background_location(sys.argv[1])
