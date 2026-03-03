import sys

content = open('Sources/Features/Experiences/UI/ExperiencesCatalogView.swift').read()
content = content.replace('@Environment(\\.dismiss) private var dismiss', '''@Environment(\\.dismiss) private var dismiss
    @State private var selectedExperience: ExperienceRoute? = nil''')

old_action = '''                                    ExperienceCard(summary: exp) {
                                        if let route = store.loadExperience(filename: exp.filename) {
                                            onSelectExperience(route)
                                            dismiss()
                                        }
                                    }'''

new_action = '''                                    ExperienceCard(summary: exp) {
                                        if let route = store.loadExperience(filename: exp.filename) {
                                            selectedExperience = route
                                        }
                                    }'''
content = content.replace(old_action, new_action)

sheet = '''            }
            .navigationBarTitleDisplayMode(.inline)'''
new_sheet = '''            }
            .sheet(item: $selectedExperience) { exp in
                ExperienceDetailView(experience: exp, onStart: {
                    onSelectExperience(exp)
                    dismiss()
                })
            }
            .navigationBarTitleDisplayMode(.inline)'''

content = content.replace(sheet, new_sheet)

open('Sources/Features/Experiences/UI/ExperiencesCatalogView.swift', 'w').write(content)
