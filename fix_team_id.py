import yaml
import os

with open("project.yml", "r") as f:
    project = yaml.safe_load(f)

# Remove the hardcoded development team so Xcode doesn't complain
if "settings" in project["targets"]["ZenRide"] and "DEVELOPMENT_TEAM" in project["targets"]["ZenRide"]["settings"]:
    del project["targets"]["ZenRide"]["settings"]["DEVELOPMENT_TEAM"]

with open("project.yml", "w") as f:
    yaml.dump(project, f, sort_keys=False)
