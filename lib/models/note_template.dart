class NoteTemplate {
  final String name;
  final String icon;
  final String content;
  final String description;

  const NoteTemplate({
    required this.name,
    required this.icon,
    required this.content,
    required this.description,
  });

  static List<NoteTemplate> get allTemplates => [
    NoteTemplate(
      name: 'Blank',
      icon: '📄',
      content: '',
      description: 'Start with a blank note',
    ),
    NoteTemplate(
      name: 'Meeting',
      icon: '📝',
      content: '''📅 Date: ${DateTime.now().toString().split(' ')[0]}
👥 Attendees:
- 

📋 Agenda:
1. 

📌 Notes:


✅ Action Items:
- [ ] 
- [ ] 

🔔 Follow-up:
''',
      description: 'Template for meeting notes',
    ),
    NoteTemplate(
      name: 'Todo',
      icon: '✅',
      content: '''# 📝 Todo List

## 🎯 Today
- [ ] 
- [ ] 

## 📅 This Week
- [ ] 
- [ ] 

## 🔮 Later
- [ ] 
- [ ] 

## ✨ Completed
- [x] 
''',
      description: 'Task management template',
    ),
    NoteTemplate(
      name: 'Journal',
      icon: '📔',
      content:
          '''# 📔 Daily Journal
📅 ${DateTime.now().toString().split(' ')[0]}

## 😊 Mood: 

## 🌟 What happened today:


## 🙏 Grateful for:
- 
- 
- 

## 💭 Thoughts & Reflections:


## 🎯 Tomorrow's Goals:
- 
''',
      description: 'Daily journaling template',
    ),
    NoteTemplate(
      name: 'Recipe',
      icon: '🍳',
      content: '''# 🍳 Recipe Name

⏱️ Prep Time: 
⏱️ Cook Time: 
🍽️ Servings: 

## 🥗 Ingredients
- 
- 
- 

## 📝 Instructions
1. 
2. 
3. 

## 💡 Tips
- 

## 📸 Notes
''',
      description: 'Cooking recipe template',
    ),
    NoteTemplate(
      name: 'Study',
      icon: '📚',
      content:
          '''# 📚 Study Notes

📖 Subject: 
📅 Date: ${DateTime.now().toString().split(' ')[0]}

## 🎯 Key Concepts
- 
- 

## 📝 Main Notes




## ❓ Questions
- 
- 

## 💡 Summary


## 📌 Review Date:
''',
      description: 'Study and learning template',
    ),
    NoteTemplate(
      name: 'Project',
      icon: '🚀',
      content: '''# 🚀 Project: [Name]

## 📋 Overview


## 🎯 Goals
- 
- 

## 📅 Timeline
- Start: 
- End: 

## 👥 Team
- 

## 📊 Status: [Not Started/In Progress/Completed]

## ✅ Tasks
- [ ] 
- [ ] 

## 📝 Notes


## 🔗 Resources
- 
''',
      description: 'Project planning template',
    ),
    NoteTemplate(
      name: 'Brainstorm',
      icon: '💡',
      content:
          '''# 💡 Brainstorming Session

📅 Date: ${DateTime.now().toString().split(' ')[0]}
🎯 Topic: 

## 🌟 Ideas
1. 
2. 
3. 

## ✨ Best Ideas
- 

## 🚀 Action Items
- [ ] 
- [ ] 

## 💭 Notes

''',
      description: 'Brainstorming and ideation',
    ),
  ];

  static NoteTemplate? getTemplate(String name) {
    try {
      return allTemplates.firstWhere((t) => t.name == name);
    } catch (e) {
      return null;
    }
  }
}
