import sys

content = open('Sources/Features/Experiences/UI/ExperienceDetailView.swift').read()

content = content.replace('.textCase(None)', '.textCase(nil)')

open('Sources/Features/Experiences/UI/ExperienceDetailView.swift', 'w').write(content)
