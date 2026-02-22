import yaml
import os

with open("project.yml", "r") as f:
    project = yaml.safe_load(f)

# Use manual signing and a generic identity that Xcode will try to fix on open
project["targets"]["ZenRide"]["settings"] = {
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "U79GV5TEWJ"
}

with open("project.yml", "w") as f:
    yaml.dump(project, f, sort_keys=False)
