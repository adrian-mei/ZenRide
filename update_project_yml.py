import yaml
import os

with open("project.yml", "r") as f:
    project = yaml.safe_load(f)

# Add signing settings
project["targets"]["ZenRide"]["settings"] = {
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "U79GV5TEWJ",
    "CODE_SIGN_IDENTITY": "Apple Development"
}

with open("project.yml", "w") as f:
    yaml.dump(project, f, sort_keys=False)
