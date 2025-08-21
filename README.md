```markdown
# PropertyManager

A SwiftUI + SwiftData property management app.

Overview
- Tracks properties, maintenance tasks, documents, utilities and inventory.
- Built with SwiftUI and SwiftData.

Quick start
1. Open PropertyManager.xcodeproj or PropertyManager.xcworkspace in Xcode.
2. Build & run on a simulator or device (iOS target).
3. Tests: Product → Test or run via CI.

Notes on recent improvements
- Reworked FileHelper to avoid force-unwraps and to provide URL helpers.
- Added AddTaskSheet and improved TasksView to avoid optional-binding pitfalls.
- Re-styled the app with a neutral professional theme and consistent card surfaces.
- Added basic SwiftLint config and a CI workflow.

Contributing
- Please open PRs for bug fixes and UI changes.
- Keep accessibility in mind: meaningful labels, dynamic type, and contrast.
```