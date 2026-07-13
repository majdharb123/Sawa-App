# 🚌 SAWA Mobile Application

A full-stack mobile application tailored for daily commuters and transit operators in Lebanon, featuring a cross-platform frontend and a robust, secure backend API. This project demonstrates real-time mobile UI development combined with live GPS tracking, relational database management, and secure data flow.

## ✨ Key Features
*   **Cross-Platform UI:** Smooth and responsive mobile experience built with Flutter for both passengers (Zamils) and drivers (Captains).
*   **Live GPS Tracking:** Real-time bus tracking, interactive mapping, and live updates using Google Maps API and Socket.io.
*   **Secure Authentication:** User login and registration protected by JWT and Bcrypt password hashing.
*   **Relational Database:** Efficient data storage, booking management, and retrieval using MySQL.
*   **RESTful API:** Scalable backend architecture built on Node.js and Express to handle mobile client requests.

## 🛠️ Tech Stack
*   **Frontend:** Flutter, Dart
*   **Backend:** Node.js,
*   **Database:** MySQL
*   **Real-time & Maps:** Socket.io, Google Maps API
*   **Security:** JWT, Bcrypt,Firebase(Notifications)

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK
*   Node.js & npm
*   MySQL Server
*   Google Cloud Console Account (for Maps API Keys)

### Backend Setup
1.  **Navigate to the backend directory:**
    ```bash
    cd backend
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Environment Variables:** Configure your `.env` file with your database credentials, JWT secret key, and port numbers.
4.  **Start the server:**
    ```bash
    node server.js
    ```

### Frontend Setup
1.  **Navigate to the frontend directory:**
    ```bash
    cd frontend
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the application:**
    ```bash
    flutter run
    ```

## 👤 Authors

**Majd Harb**
* **LinkedIn:** [https://www.linkedin.com/in/majd-harb-cs/]
* **GitHub:** [https://github.com/majdharb123]
* **Email:** [majdhaeb37@gmail.com]

**Nour Bathiche**
* **Co-Author & Project Partner**

---
*This project was developed as a senior year software engineering capstone project under the supervision of Dr. Mahmoud Samad.*
