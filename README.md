# Mploya — AI-Powered Professional Networking Platform

![Dart](https://img.shields.io/badge/Dart-3.x-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.x-blue) ![Supabase](https://img.shields.io/badge/Backend-Supabase-green)

## Overview

**Mploya** is a mobile-first professional networking platform that connects candidates and companies through AI-powered video pitches, smart matching, and real-time collaboration. Built with Flutter (CupertinoApp), it delivers a premium iOS-native experience on both platforms.

## Architecture

```
lib/
├── main.dart                  # Entry point, global error handling
├── models/models.dart         # NexUser, FeedVideoData, Experience
├── navigation/main_navigation.dart  # Bottom tab bar (4 tabs)
├── providers/user_provider.dart     # Riverpod state management
├── screens/                   # 51 screens
├── services/                  # 46 services
├── theme/app_theme.dart       # NexTheme/MployaTheme design tokens
├── utils/time_utils.dart      # Relative time formatting
└── widgets/                   # 36+ reusable widgets
```

## Tech Stack

| Layer          | Technology                                  |
|----------------|---------------------------------------------|
| **Framework**  | Flutter 3.x (CupertinoApp - iOS native UX)  |
| **State**      | Riverpod                                     |
| **Backend**    | Supabase (Auth, Realtime, Storage, RPC)      |
| **Database**   | PostgreSQL with RLS policies                 |
| **AI**         | Google Gemini 2.5 Flash                      |
| **Video Calls**| Jitsi Meet SDK                               |
| **Maps**       | flutter_map + OpenStreetMap + Nominatim      |
| **Push**       | Firebase Cloud Messaging                     |

## Key Features

### Candidates
- 🎬 **Video Pitch** — 60s professional pitches with AI scoring
- 🤖 **AI Coach** — Resume builder, interview prep, skill assessment
- 📍 **Geo-Discovery** — Interactive map with nearby companies
- 🔔 **Smart Matching** — Swipe-based job matching
- 💬 **Real-time Chat** — Messaging + files + typing indicators
- 📹 **Video Calls** — In-app Jitsi Meet interviews
- 🏆 **Skill Badges** — AI-verified certifications

### Companies
- 📊 **Candidate Discovery** — Browse talent with cross-filtering
- 🎥 **Video Replies** — Micro-pitches to candidates
- ⭐ **Employer Ratings** — Transparent reviews (4 categories)
- 📅 **Scheduling** — Interview calendar management
- ✅ **Verification** — Corporate email badge

## Security

- **Certificate Pinning** — SSL pinning for API calls
- **Root/Jailbreak Detection** — Heuristic (9 Android + 8 iOS paths)
- **Rate Limiting** — 5 login attempts → 60s lockout
- **AI Content Moderation** — Chat/comment filtering
- **Contact Protection** — Blocks email/phone in chat
- **RLS Policies** — Row-level security on all tables

## Getting Started

```bash
flutter pub get

# Run with Supabase credentials
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Build release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

### Firebase Setup
- `google-services.json` → `android/app/`
- `GoogleService-Info.plist` → `ios/Runner/`
- Project: `nexwork-b3007`

## Database (Supabase)

### Core Tables
| Table               | Description                        |
|---------------------|------------------------------------|
| `users`             | Profiles (candidates + companies)  |
| `connections`       | Bi-directional requests            |
| `messages`          | Real-time chat                     |
| `posts`             | Feed content (video posts)         |
| `nexus_signals`     | Interest signals, micro-pitches    |
| `portfolio_videos`  | Portfolio items (up to 3)          |
| `employer_reviews`  | Company ratings                    |
| `stories`           | Ephemeral stories (24h)            |
| `saved_items`       | Bookmarked profiles/jobs           |
| `notifications`     | System notifications               |

### Key RPC Functions
- `get_nearby_users` — Haversine geolocation search
- `get_connection_status` — Check connection state
- `send_connection_request` — Create/accept connection
- `create_system_notification` — Push notification trigger

## Testing

```bash
flutter test              # All tests
flutter test test/services/ # Service tests only
```

**Coverage**: 16/46 services tested (~35%)

## Configuration

- **Bundle ID**: `com.mploya.ai`
- **Min SDK**: Android 21 / iOS 13
- **Target SDK**: 35
- **Analysis**: strict-casts, strict-inference, strict-raw-types + 20 lint rules

## License

Proprietary — All rights reserved © 2026 Mploya
