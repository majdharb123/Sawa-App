const express = require("express");
const cors = require("cors");
require("dotenv").config();
const path = require("path");

const http = require("http");
const { Server } = require("socket.io");

const db = require("./db");
const startCronJobs = require("./cronJobs");

const app = express();

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
  },
});

app.set("io", io);

app.use(cors());
app.use(express.json());


const zamilAuth = require("./auth/CreateAccZamil");
app.use("/api/auth", zamilAuth);

const captainAuth = require("./auth/CreateAccCaptain");
app.use("/api/auth", captainAuth);

const login = require("./auth/Login");
app.use("/api/auth", login);

const forgotPassword = require("./auth/ForgotPass");
app.use("/api/auth", forgotPassword);

const ProfileZamil = require("./zamil/ProfileZamil");
app.use("/api/zamil/profile", ProfileZamil);

const ProfileCaptain = require("./captain/ProfileCaptain");
app.use("/api/captain/profile", ProfileCaptain);

const TripsCaptain = require("./captain/Trips");
app.use("/api/captain/trips", TripsCaptain);

const TripsZamil = require("./zamil/Trips");
app.use("/api/zamil/trips", TripsZamil);

const NotificationsCaptain = require("./captain/NotificationsCaptain");
app.use("/api/captain/notifications", NotificationsCaptain);

const NotificationsZamil = require("./zamil/NotificationsZamil");
app.use("/api/zamil/notifications", NotificationsZamil);

const ChatCaptain = require("./captain/ChatCaptain");
app.use("/api/captain/chat/", ChatCaptain);

const zamilHistory = require("./zamil/HistoryZamil");
app.use("/api/zamil/history", zamilHistory);

const ChatZamil = require("./zamil/ChatZamil");
app.use("/api/zamil/chat", ChatZamil);

const reportsRoute = require("./Routes/ReportsRoute");
app.use("/api/reports", reportsRoute);

const HistoryCaptain = require("./captain/HistoryCaptain");
app.use("/api/captain/history", HistoryCaptain);

app.use("/uploads", express.static(path.join(__dirname, "uploads")));


io.on("connection", (socket) => {
  console.log(`🟢 User Connected: ${socket.id}`);

  socket.on("join-trip", (tripId) => {
    socket.join(`trip_${tripId}`);
    console.log(`📍 User ${socket.id} joined trip room: trip_${tripId}`);
  });

  socket.on("join-personal-room", (data) => {
    const roomName = `${data.role}_${data.id}`; 
    socket.join(roomName);
    console.log(`👤 User joined personal room: ${roomName}`);
  });

  socket.on("join-chat-group", (groupId) => {
    socket.join(`chat_${groupId}`);
    console.log(`💬 User joined chat group: chat_${groupId}`);
  });

  socket.on("send-location", (data) => {
    const { trip_id, lat, lng } = data;

    socket.to(`trip_${trip_id}`).emit("location-updated", {
      lat: lat,
      lng: lng,
      timestamp: new Date(),
    });

    io.emit("admin-radar-update", {
      trip_id: trip_id,
      lat: lat,
      lng: lng,
    });
  });

  socket.on("disconnect", () => {
    console.log(`🔴 User Disconnected: ${socket.id}`);
  });
});

startCronJobs(io);

server.listen(5000, () => {
  console.log("🚀 Server running on port 5000");
});