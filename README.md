# Masha's Tasks (Flutter Task Manager)

A task management app built with Flutter and SQLite, with a Masha and the Bear theme.

## Features
- Today, Completed and Repeated task views
- Add, edit, delete and mark tasks as completed
- Repeat tasks daily or on selected weekdays (auto reset each day)
- Subtasks with progress bar and percentage
- Local notifications: instant "Task added" alert, alert at due time, and optional reminder before due time
- Choose notification sound (Default, Alarm, Ringtone)
- Light and Dark theme
- Export tasks to CSV, PDF and Email
- SQLite database for storage

## How to run
Android (phone):
flutter pub get
flutter run

Chrome (web):
flutter pub get
flutter run -d chrome

Note: On Android the app uses SQLite and phone notifications. In Chrome, SQLite is not supported, so tasks are saved in browser storage and reminders appear as browser notifications and in-app alerts with sound.

## APK
Download: app-arm64-v8a-release.apk (in this repository)

## User manual
1. Tap "Add Task", enter the details, choose date and time, and optionally repeat, reminder and subtasks, then Save.
2. Tap the circle on a task to mark it completed.
3. Use the three-dot menu on a task to edit or delete it.
4. Top right: share icon for export, gear icon for settings (theme and sound).

## Video demo
#Android demo
https://drive.google.com/file/d/1QE-fG8IY01Y1pO6It6-uTSe7vq-kGB1h/view?usp=drive_link

#Chrome demo
https://drive.google.com/file/d/1ulB6b1erb8iTDtnffroHAiDblmTQxS9A/view?usp=drive_link
