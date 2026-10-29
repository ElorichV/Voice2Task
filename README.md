# Voice2Task

App iOS nativa (SwiftUI + SwiftData, iOS 17+) que graba notas de voz, las transcribe con `SFSpeechRecognizer`, extrae tareas con OpenAI (`gpt-4o-mini`) y las sincroniza como issues de GitHub.

## Requisitos
- Xcode 16 o superior (el proyecto usa carpetas sincronizadas: cualquier archivo `.swift` dentro de `Voice2Task/` se agrega al target automáticamente).
- iOS 17.0+

## Estructura
```
Voice2Task/
├── Voice2TaskApp.swift
├── Models/        # SwiftData (@Model) y structs
├── Services/      # Audio, OpenAI, GitHub
├── ViewModels/    # @Observable
└── Views/         # SwiftUI
```

## Compilar
```sh
xcodebuild -project Voice2Task.xcodeproj -scheme Voice2Task \
  -destination 'generic/platform=iOS Simulator' build
```
