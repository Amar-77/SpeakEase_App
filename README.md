# 🎙️ SpeakEase – AI-Powered Speech Analysis App

SpeakEase is a Flutter mobile application that helps users improve their 
spoken English through real-time AI analysis, personalized feedback, 
and an interactive AI tutor.

## 🔗 Related Repositories
- **Backend (Local Dev):** [SpeakEase_2.0](https://github.com/Amar-77/SpeakEase_2.0)
- **Production Backend + Models:** [Hugging Face Space](https://huggingface.co/spaces/amarre/speakease-models)

## ✨ Features
- 🎤 Real-time speech recording and transcription
- 📊 Fluency, Pronunciation & Clarity scoring (0–10)
- 🔤 Word-by-word analysis with color-coded feedback
  - 🟢 Correct | 🔴 Incorrect | 🟠 Extra | ⚫ Omitted
- 🤖 Speaky – AI conversational tutor (powered by LLaMA 3.1 via Groq)
- 🔊 Teacher voice playback (Microsoft Edge TTS – NeerjaExpressive Neural)
- 📈 Session analytics with end-of-session report card
- 👤 Age group detection from voice

## 🛠️ Tech Stack
| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Auth & Storage | Firebase |
| Speech Recording | Flutter audio plugins |
| Backend API | FastAPI (Python) |
| AI Models | Custom fine-tuned Whisper, Wav2Vec2 |
| LLM | LLaMA 3.1 8B via Groq API |
| TTS | Microsoft Edge TTS (NeerjaExpressive) |
| Deployment | Hugging Face Spaces |

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x+)
- Android Studio / VS Code
- Backend server running (see SpeakEase_2.0 or Hugging Face)

### Setup
```bash
git clone https://github.com/Amar-77/SpeakEase_App.git
cd SpeakEase_App
flutter pub get
flutter run
```

### Configure Backend URL
In `lib/config/` (or wherever your API base URL is set), update:
```dart
const String BASE_URL = "https://amarre-speakease-models.hf.space";
```

## 📱 App Structure
