# Tono3 - AR Gamified Chinese Learning App

Tono3 is an augmented reality (AR) app that helps users learn Chinese by exploring their surroundings and practicing vocabulary through gamified interactions. The app uses ARKit and Core ML to detect objects in the real world and display their Chinese names, allowing users to learn vocabulary in an immersive and interactive way.

![image of scene with 3d labels on objects](post-media/giphy.gif)

## Overview

Tono3 has two main modes:

1. **Explore Mode**: Users scan their environment with the camera, and the app identifies objects and displays their Chinese names, pinyin, and pronunciation. Users can practice pronouncing the words and receive feedback on their pronunciation.

2. **Practice Mode**: Users review previously learned words through quizzes, with a spaced repetition system (SRS) to optimize learning and retention.

## Technical Details

- **Platform**: iOS
- **Language**: Swift
- **Frameworks**: 
  - ARKit for augmented reality
  - Core ML for object recognition
  - AVFoundation for audio playback and recording
  - Speech framework for speech recognition
  - AudioKit for tone analysis
  - Core Data for local storage

## Features

- Real-time object recognition using Core ML
- Chinese vocabulary learning with proper pronunciation
- Pronunciation feedback using speech recognition
- Spaced Repetition System (SRS) for optimized learning
- Gamification elements (points, achievements, levels)
- Offline functionality

## Project Status

This project is currently in development. See the [Checklist](docs/Checklist.md) for the current status and upcoming tasks.

## Getting Started

### Prerequisites

- Xcode (latest version)
- iOS device with ARKit support (iPhone 6s or later, running iOS 14+)

### Installation

1. Clone this repository
   ```
   git clone https://github.com/Audacity88/Tono3.git
   ```
2. Open the project in Xcode
   ```
   open Tono3.xcodeproj
   ```
3. Build and run the project on your iOS device

## Acknowledgments

This project is based on the [CoreML-in-ARKit](https://github.com/hanleyweng/CoreML-in-ARKit) project by Hanley Weng, which provides a foundation for integrating Core ML with ARKit for object detection.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Note: This project is a work in progress. See the [Product Requirements Document](docs/Product%20Requirements%20Document%20(PRD).md) for detailed specifications.*
