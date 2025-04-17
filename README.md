# Vision Assist

A Flutter application designed to assist visually impaired users with their daily needs using real-time camera feed, voice commands, and AI-powered features.

## Features

- **Voice Command Recognition**: Use voice commands to control the app
- **Object Recognition**: Detect and announce objects in the camera view
- **Text Reading (OCR)**: Identify and read text from images or the camera feed
- **Weather Information**: Get current weather updates via voice command
- **News Updates**: Get the latest news headlines via voice command
- **Accessible UI**: High-contrast, large-button interface with voice feedback

## Voice Commands

- "Read text" - Activates OCR to read text from camera
- "Detect objects" - Identifies objects in the camera view
- "Weather" - Provides current weather information
- "News" - Reads the latest news headlines
- "Help" - Lists available commands
- "Stop" - Stops current speech output

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (API level 21 or higher)
- iOS device (iOS 11.0 or higher) for iPhone support

### API Keys

Before running the app, you need to obtain the following API keys:

1. News API key from [NewsAPI.org](https://newsapi.org)
2. Weather API key from [OpenWeatherMap](https://openweathermap.org/api)

Update the API keys in:
- `lib/services/weather_service.dart`
- `lib/services/news_service.dart`

### Installation

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Connect a device or start an emulator
4. Run `flutter run` to build and launch the app

## Permissions

The app requires the following permissions:
- Camera - For object detection and OCR
- Microphone - For voice command recognition
- Internet - For weather and news information
