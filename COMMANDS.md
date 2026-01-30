# Kids App - Complete Commands Guide

## ✅ Status: Flutter App Running Successfully!

Your Flutter Kids App is now set up and running. Here's a complete guide to all commands you need.

---

## 🏃 How to Run the App

### Quick Start (From Project Directory)
```powershell
# Navigate to the project
cd C:\Users\Dell\OneDrive\Desktop\KIDS_APP\kids_app

# Run on Chrome (Web Browser)
flutter run -d chrome

# Run on Edge (Web Browser)
flutter run -d edge

# Run on Windows Desktop
flutter run -d windows
```

### List Available Devices
```powershell
flutter devices
```

**Output will show:**
- Windows (desktop)
- Chrome (web)
- Edge (web)
- Android emulators (if configured)

---

## 💻 Development Keyboard Shortcuts (While App is Running)

| Key | Action |
|-----|--------|
| `r` | **Hot Reload** - Refresh changes instantly |
| `R` | **Hot Restart** - Full app restart |
| `h` | **Help** - Show help menu |
| `w` | **Show Widget Inspector** |
| `q` | **Quit** - Stop the app |

---

## 📁 Project Structure

```
kids_app/
├── lib/
│   └── main.dart              ← YOUR APP CODE HERE
├── test/
│   └── widget_test.dart       ← Unit tests
├── android/                   ← Android configuration
├── ios/                       ← iOS configuration
├── web/                       ← Web configuration
├── windows/                   ← Windows configuration
├── pubspec.yaml               ← Dependencies
├── README.md                  ← Project documentation
└── COMMANDS.md               ← This file
```

---

## 🔧 Build Commands

### Build for Release
```bash
# Android APK
flutter build apk

# iOS
flutter build ios

# Web
flutter build web

# Windows
flutter build windows
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

---

## 📝 Git & GitHub Workflow

### 1️⃣ Initial Setup (Already Done ✅)
```bash
git init
git config user.name "Your Name"
git config user.email "your.email@example.com"
git add .
git commit -m "initial: setup kids app project with README"
```

### 2️⃣ Create Feature Branch
```bash
# Create and switch to feature branch
git checkout -b feature/your-feature-name

# Example: Adding a new screen
git checkout -b feature/add-kids-games-screen
```

### 3️⃣ Make Changes & Commit
```bash
# View changes
git status

# Stage specific files
git add lib/main.dart
git add README.md

# Or stage all changes
git add .

# Commit with descriptive message
git commit -m "feat: add new feature description"
git commit -m "fix: fix bug description"
git commit -m "docs: update documentation"
git commit -m "style: format code"
```

### 4️⃣ Push to GitHub
```bash
# First, add your remote repository
git remote add origin https://github.com/YOUR_USERNAME/kids_app.git

# Push your feature branch
git push -u origin feature/your-feature-name

# Or if already set up
git push origin feature/your-feature-name
```

### 5️⃣ Create Pull Request
1. Go to GitHub: https://github.com/YOUR_USERNAME/kids_app
2. Click "Compare & pull request" (appears after push)
3. Add title: "Add your feature title"
4. Add description: What changes did you make?
5. Click "Create pull request"

### 6️⃣ Merge to Main (After PR Review)
```bash
# Switch to main branch
git checkout main

# Pull latest changes from remote
git pull origin main

# Merge feature branch
git merge feature/your-feature-name

# Push to remote
git push origin main
```

---

## 🎯 Common Workflow Example

```bash
# 1. Start new feature
git checkout -b feature/add-animations

# 2. Edit your code
# Edit lib/main.dart...

# 3. Check what changed
git status

# 4. Stage and commit
git add .
git commit -m "feat: add animations to kids app"

# 5. Push to GitHub
git push -u origin feature/add-animations

# 6. Go to GitHub and create PR
# 7. After review and approval, merge to main
git checkout main
git pull origin main
git merge feature/add-animations
git push origin main

# 8. Delete feature branch (optional)
git branch -d feature/add-animations
git push origin --delete feature/add-animations
```

---

## 🔍 Useful Git Commands

### View Commit History
```bash
git log                    # Full log
git log --oneline         # Compact log
git log --graph --all     # Visual branch graph
```

### View Branch Info
```bash
git branch                # List local branches
git branch -a             # List all branches (local + remote)
```

### Undo Changes
```bash
git status                # See what changed
git diff                  # See detailed changes
git checkout .            # Discard all changes
git reset HEAD~1          # Undo last commit (keep changes)
```

### Switch Branches
```bash
git checkout main
git checkout feature/your-feature-name
git checkout -b new-feature  # Create and switch
```

---

## 📚 Commit Message Format (Conventional)

```bash
feat: add new feature
fix: fix a bug
docs: update documentation
style: format code
refactor: restructure code
perf: improve performance
test: add tests
chore: update dependencies
```

**Examples:**
```bash
git commit -m "feat: add splash screen"
git commit -m "fix: fix button alignment issue"
git commit -m "docs: update README with setup instructions"
git commit -m "style: format code with dart analyzer"
```

---

## 🚀 Complete Setup Instructions

### First Time Setup
```powershell
# Navigate to project
cd C:\Users\Dell\OneDrive\Desktop\KIDS_APP\kids_app

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```

### Daily Development
```powershell
# 1. Navigate to project
cd C:\Users\Dell\OneDrive\Desktop\KIDS_APP\kids_app

# 2. Create feature branch (if starting new work)
git checkout -b feature/what-you-are-building

# 3. Run the app
flutter run -d chrome

# 4. Edit code in lib/main.dart
# 5. Press 'r' in terminal to hot reload
# 6. Test your changes

# 7. When done, commit
git add .
git commit -m "feat: describe your changes"

# 8. Push to GitHub
git push origin feature/what-you-are-building
```

---

## ⚠️ Troubleshooting

### Error: "Unable to open main.dart" in VS Code
```powershell
# Close VS Code completely
# Then run:
flutter clean
flutter pub get

# Open VS Code again
```

### Flutter Build Issues
```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

### Port Already in Use
```powershell
# Use a different port
flutter run -d chrome --web-port 8080
```

### OneDrive Path Issues
- Ensure the project is in a local folder without special characters
- If using OneDrive, move to a local drive if possible

---

## 📦 Current Project Details

- **Project Name:** kids_app
- **Framework:** Flutter 3.22.0
- **Language:** Dart 3.4.0
- **Location:** `C:\Users\Dell\OneDrive\Desktop\KIDS_APP\kids_app`
- **Main File:** `lib/main.dart`
- **Repository:** Local Git initialized ✅

---

## 🎨 Now You Can:

1. ✅ Edit `lib/main.dart` to customize the app
2. ✅ Use `r` key to hot reload and see changes instantly
3. ✅ Commit changes with git
4. ✅ Push to GitHub and create pull requests
5. ✅ Build for production

---

**Happy Coding! 🚀**

For more help: `flutter --help` or visit https://flutter.dev
