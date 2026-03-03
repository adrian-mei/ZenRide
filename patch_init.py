import sys

content = open('Sources/Features/Experiences/UI/ExperienceDetailView.swift').read()
content = content.replace('init(experience: ExperienceRoute) {', '''init(experience: ExperienceRoute, onStart: (() -> Void)? = nil) {
        self.onStart = onStart''')
open('Sources/Features/Experiences/UI/ExperienceDetailView.swift', 'w').write(content)
