# SAWA Mobile Application

SAWA is a full-stack transportation application designed for daily commuters and transit operators in Lebanon. It provides separate experiences for passengers (Zamils) and drivers (Captains), with trip management, live location updates, interactive maps, booking, chat, profiles, and notifications.

This project was developed as a senior-year software engineering capstone project.

## Key Features

* Cross-platform mobile application built with Flutter and Dart.
* Separate passenger and driver workflows.
* Trip creation, booking, cancellation, and history management.
* Live location updates and real-time communication using Socket.IO.
* Interactive maps and route visualization using Google Maps.
* Address geocoding through a rate-limited backend endpoint powered by OpenStreetMap Nominatim.
* Password hashing using bcrypt.
* Email-based password reset using Nodemailer.
* Image and document uploads using Multer.
* Relational data storage using MySQL.
* Firebase Cloud Messaging token integration.

## Tech Stack

* **Mobile:** Flutter, Dart
* **Backend:** Node.js, Express.js
* **Database:** MySQL
* **Real-Time Communication:** Socket.IO
* **Maps:** Google Maps API
* **Geocoding:** OpenStreetMap Nominatim
* **Authentication Security:** bcrypt
* **Messaging:** Firebase Cloud Messaging
* **Email:** Nodemailer

## Project Structure

```text
Sawa-App/
├── backend/   # Node.js and Express API
└── sawa/      # Flutter mobile application
```

## Getting Started

### Prerequisites

* Flutter SDK
* Node.js 18 or later
* npm
* MySQL Server
* Google Cloud project with the required Maps APIs enabled

## Backend Setup

1. Navigate to the backend directory:

```bash
cd backend
```

2. Install dependencies:

```bash
npm install
```

3. Create the environment file from the provided example:

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

4. Configure the following variables inside `.env`:

```env
DB_HOST=your_database_host
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_NAME=your_database_name

EMAIL_USER=your_email@example.com
EMAIL_PASS=your_email_app_password
```

5. Start the backend:

```bash
node server.js
```

The backend runs locally on port `5000`.

## Flutter Setup

1. Navigate to the Flutter project:

```bash
cd sawa
```

2. Install dependencies:

```bash
flutter pub get
```

### Android Maps Configuration

Add the Google Maps API key to:

```text
android/local.properties
```

```properties
MAPS_API_KEY=your_android_maps_api_key
```

`local.properties` is ignored by Git and must not be committed.

### iOS Maps Configuration

Create:

```text
ios/Flutter/Secrets.xcconfig
```

Add:

```xcconfig
GOOGLE_MAPS_API_KEY=your_ios_maps_api_key
```

`Secrets.xcconfig` is ignored by Git and must not be committed.

### Running the Application

The route-polyline integration reads its Google Maps key from a compile-time environment variable:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

When testing on a physical device, update the backend `baseUrl` in the Flutter application to use the computer's local network IP address.

## Security

* Database and email credentials are stored in `backend/.env`.
* Android and iOS Maps keys are stored in ignored local configuration files.
* API keys and passwords must never be committed to Git.
* Google Maps keys should be restricted by application and API in Google Cloud Console.
* Passwords are hashed before database storage.
* The geocoding endpoint includes request validation, caching, timeouts, and rate limiting.
* Backend dependencies are checked using:

```bash
npm audit --omit=dev
```

Firebase client configuration files are included for application initialization. Firebase security must be enforced through appropriate Firebase rules and API-key restrictions.

## OpenStreetMap Attribution

Address search uses OpenStreetMap Nominatim through the backend.

Geocoding data © OpenStreetMap contributors.

If the application is publicly distributed, visible OpenStreetMap attribution must also be displayed inside the application, and usage must comply with the Nominatim usage policy.

## Authors

### Majd Harb

* [LinkedIn](https://www.linkedin.com/in/majd-harb-cs/)
* [GitHub](https://github.com/majdharb123)
* [Email](mailto:majdharb37@gmail.com)

### Nour Bathiche

Co-author and project partner.

---

Developed as a senior-year software engineering capstone project under the supervision of Dr. Mahmoud Samad.
