import sys

content = open('Sources/Features/Experiences/UI/ExperienceDetailView.swift').read()
content = content.replace('let experience: ExperienceRoute', '''let experience: ExperienceRoute
    var onStart: (() -> Void)? = nil''')
content = content.replace('dismiss()\n    }', '''dismiss()\n        onStart?()\n    }''')
open('Sources/Features/Experiences/UI/ExperienceDetailView.swift', 'w').write(content)
