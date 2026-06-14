const express = require('express');
const router = express.Router();
const db = require('../db');
const { sendOTPEmail } = require('./EmailService');
const bcrypt = require('bcrypt');


router.post('/forgot-password', async (req, res) => {
    const { email } = req.body;

    try {

        const [zamil] = await db.promise().query('SELECT * FROM create_acc_zamil WHERE email = ?', [email]);
        const [captain] = await db.promise().query('SELECT * FROM create_acc_captain WHERE email = ?', [email]);

        if (zamil.length === 0 && captain.length === 0) {
            return res.status(404).json({ message: "Email not found in SAWA system" });
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        const expiresAt = new Date(Date.now() + 15 * 60000);


        await db.promise().query('DELETE FROM password_resets WHERE email = ?', [email]);
        await db.promise().query('INSERT INTO password_resets (email, otp_code, expires_at) VALUES (?, ?, ?)',
            [email, otp, expiresAt]);

        const sent = await sendOTPEmail(email, otp);

        if (sent) {
            res.status(200).json({ message: "OTP sent successfully" });
        } else {
            res.status(500).json({ message: "Failed to send email" });
        }
    } catch (err) {
        console.error("Error in forgot-password:", err);
        res.status(500).json({ message: "Server Error", error: err.message });
    }
});


router.post('/verify-otp', async (req, res) => {
    const { email, otp } = req.body;

    try {
       
        const [rows] = await db.promise().query(
            'SELECT * FROM password_resets WHERE email = ? AND otp_code = ?',
            [email, otp]
        );

        if (rows.length === 0) {
            return res.status(400).json({ message: "Invalid OTP code" });
        }

        const record = rows[0];
        if (new Date() > new Date(record.expires_at)) {
            return res.status(400).json({ message: "OTP code has expired" });
        }

        res.status(200).json({ message: "OTP verified successfully" });
    } catch (err) {
        console.error("Error in verify-otp:", err);
        res.status(500).json({ message: "Server Error" });
    }
});


router.post('/reset-password', async (req, res) => {
    const { email, newPassword } = req.body;

    try {
        const hashedPassword = await bcrypt.hash(newPassword, 10);

        
        await db.promise().query('UPDATE create_acc_zamil SET password = ? WHERE email = ?', [hashedPassword, email]);
        await db.promise().query('UPDATE create_acc_captain SET password = ? WHERE email = ?', [hashedPassword, email]);

        
        await db.promise().query('DELETE FROM password_resets WHERE email = ?', [email]);

        res.status(200).json({ message: "Password reset successfully" });
    } catch (err) {
        console.error("Error in reset-password:", err);
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;