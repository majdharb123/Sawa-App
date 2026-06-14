const express = require('express');
const router = express.Router();
const db = require('../db'); 
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/'); 
    },
    filename: function (req, file, cb) {
        cb(null, 'profile_zamil_' + Date.now() + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

router.post('/get-data', async (req, res) => {
    const { email } = req.body;
    try {
        const [rows] = await db.promise().query(
            'SELECT full_name, phone, email, selfie_image FROM create_acc_zamil WHERE email = ?', 
            [email]
        );
        if (rows.length === 0) return res.status(404).json({ message: "Zamil not found" });
        
        res.status(200).json(rows[0]);
    } catch (err) {
        console.error("❌ Error fetching Zamil data:", err); 
        res.status(500).json({ message: "Server Error", error: err.message });
    }
});

router.post('/update-info', async (req, res) => {
    const { currentEmail, newName, newPhone, newEmail } = req.body;
    try {
        await db.promise().query(
            'UPDATE create_acc_zamil SET full_name = ?, phone = ?, email = ? WHERE email = ?',
            [newName, newPhone, newEmail, currentEmail]
        );

        const io = req.app.get('io');
        if (io) {
            io.emit('user_profile_updated', { role: 'Zamil', email: currentEmail, type: 'info' });
        }

        res.status(200).json({ message: "Zamil profile updated successfully" });
    } catch (err) {
        console.error("❌ Error updating Zamil info:", err);
        res.status(500).json({ message: "Update failed" });
    }
});

router.post('/update-image', upload.single('image'), async (req, res) => {
    const { email } = req.body;
    if (!req.file) return res.status(400).json({ message: "No image uploaded" });

    const imagePath = req.file.path;
    try {
        await db.promise().query('UPDATE create_acc_zamil SET selfie_image = ? WHERE email = ?', [imagePath, email]);

        
        const io = req.app.get('io');
        if (io) {
            io.emit('user_profile_updated', { role: 'Zamil', email: email, type: 'selfie' });
        }

        res.status(200).json({ message: "Image updated", imagePath: imagePath });
    } catch (err) {
        console.error("❌ Error updating Zamil image:", err);
        res.status(500).json({ message: "Database error" });
    }
});

module.exports = router;