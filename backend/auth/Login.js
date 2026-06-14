const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const db = require("../db");

router.post("/login", async (req, res) => {
  try {
  
    const { email, password, fcmToken } = req.body;

    const [zamilResult] = await db
      .promise()
      .query("SELECT * FROM create_acc_zamil WHERE email = ?", [email]);

    if (zamilResult.length > 0) {
      const user = zamilResult[0];

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch)
        return res.status(401).json({ success: false, message: "Wrong password" });

      if (user.status === "Pending")
        return res.status(403).json({ success: false, message: "Account is pending admin approval" });
          
      if (user.status === "Rejected") {
        const [notif] = await db.promise().query(
          "SELECT message FROM notifications WHERE zamil_id = ? ORDER BY created_at DESC LIMIT 1",
          [user.id]
        );
        const reasonText = notif.length > 0 ? notif[0].message : "Please review your info and resubmit.";

        return res.status(403).json({ 
          success: false, 
          isRejected: true, 
          role: "Zamil", 
          message: "Your application was rejected.",
          reason: reasonText
        });
      }

      if (fcmToken && fcmToken.trim() !== "") {
          await db.promise().query(
              `UPDATE create_acc_zamil SET fcm_token = ? WHERE id = ?`, 
              [fcmToken, user.id]
          );
      }

      const io = req.app.get('io');
      if (io) {
        io.emit('user_logged_in', { 
            role: 'Zamil', 
            id: user.id, 
            name: user.full_name,
            message: `Zamil ${user.full_name} is now online.`
        });
      }

      return res.status(200).json({
        success: true,
        role: "Zamil",
        id: user.id, 
        message: "Login successful",
        data: { id: user.id, name: user.full_name, email: user.email },
      });
    }

   
    const [captainResult] = await db
      .promise()
      .query("SELECT * FROM create_acc_captain WHERE email = ?", [email]);

    if (captainResult.length > 0) {
      const user = captainResult[0];

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch)
        return res.status(401).json({ success: false, message: "Wrong password" });

      if (user.status === "Pending")
        return res.status(403).json({ success: false, message: "Account is pending admin approval" });
          
      if (user.status === "Rejected") {
        const [notif] = await db.promise().query(
          "SELECT message FROM notifications WHERE captain_id = ? ORDER BY created_at DESC LIMIT 1",
          [user.id]
        );
        const reasonText = notif.length > 0 ? notif[0].message : "Please review your info and resubmit.";

        return res.status(403).json({ 
          success: false, 
          isRejected: true, 
          role: "Captain",
          message: "Your application was rejected.",
          reason: reasonText
        });
      }

      if (fcmToken && fcmToken.trim() !== "") {
          await db.promise().query(
              `UPDATE create_acc_captain SET fcm_token = ? WHERE id = ?`, 
              [fcmToken, user.id]
          );
      }

      const io = req.app.get('io');
      if (io) {
        io.emit('user_logged_in', { 
            role: 'Captain', 
            id: user.id, 
            name: user.full_name,
            message: `Captain ${user.full_name} is now online.`
        });
      }

      return res.status(200).json({
        success: true,
        role: "Captain",
        id: user.id, 
        message: "Login successful",
      });
    }

    return res.status(404).json({ success: false, message: "Email not found" });
  } catch (error) {
    console.error("❌ Login Error: ", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;