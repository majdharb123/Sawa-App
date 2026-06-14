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
        cb(null, 'profile_captain_' + Date.now() + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

router.post('/get-data', async (req, res) => {
    const { email } = req.body;
    try {
        const [rows] = await db.promise().query(
            'SELECT id, full_name, phone, email, selfie_image, bus_name, bus_type, features, bus_interior_image FROM create_acc_captain WHERE email = ?', 
            [email]
        );
        if (rows.length === 0) return res.status(404).json({ message: "Captain not found" });
        
        if (rows[0].features && typeof rows[0].features === 'string') {
            rows[0].features = JSON.parse(rows[0].features);
        }

        res.status(200).json(rows[0]);
    } catch (err) {
        console.error("❌ Error fetching Captain data:", err);
        res.status(500).json({ message: "Server Error", error: err.message });
    }
});

router.post('/update-info', async (req, res) => {
    const { currentEmail, newName, newPhone, newEmail, newBusName, newBusType, newFeatures } = req.body;
    try {
        const featuresJson = JSON.stringify(newFeatures || []);

        await db.promise().query(
            'UPDATE create_acc_captain SET full_name = ?, phone = ?, email = ?, bus_name = ?, bus_type = ?, features = ? WHERE email = ?',
            [newName, newPhone, newEmail, newBusName, newBusType, featuresJson, currentEmail]
        );

        
        const io = req.app.get('io');
        if (io) {
            io.emit('user_profile_updated', { role: 'Captain', email: currentEmail, type: 'info' });
        }

        res.status(200).json({ message: "Captain profile and bus info updated successfully" });
    } catch (err) {
        console.error("❌ Error updating Captain info:", err);
        res.status(500).json({ message: "Update failed" });
    }
});

router.post('/update-image', upload.single('image'), async (req, res) => {
    const { email } = req.body;
    if (!req.file) return res.status(400).json({ message: "No image uploaded" });

    const imagePath = req.file.path;
    try {
        await db.promise().query('UPDATE create_acc_captain SET selfie_image = ? WHERE email = ?', [imagePath, email]);

        
        const io = req.app.get('io');
        if (io) {
            io.emit('user_profile_updated', { role: 'Captain', email: email, type: 'selfie' });
        }

        res.status(200).json({ message: "Image updated", imagePath: imagePath });
    } catch (err) {
        console.error("❌ Error updating Captain image:", err);
        res.status(500).json({ message: "Database error" });
    }
});

router.post('/update-bus-image', upload.single('image'), async (req, res) => {
    try {
        const { email } = req.body;
        const imagePath = req.file.path; 

        if (!email || !imagePath) {
            return res.status(400).json({ success: false, message: "Missing data" });
        }

        const query = 'UPDATE create_acc_captain SET bus_interior_image = ? WHERE email = ?';
        await db.promise().query(query, [imagePath, email]);

        const io = req.app.get('io');
        if (io) {
            io.emit('user_profile_updated', { role: 'Captain', email: email, type: 'bus_image' });
        }

        res.status(200).json({ success: true, imagePath: imagePath });
    } catch (error) {
        console.error("Error updating bus image:", error);
        res.status(500).json({ success: false, message: "Server Error" });
    }
});

module.exports = router;