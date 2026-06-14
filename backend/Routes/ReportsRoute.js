const express = require('express');
const router = express.Router();
const db = require('../db'); 

router.post('/add', (req, res) => {
    const { name, role, category, details, email, phone } = req.body;

    if (!name || !role || !category || !details || !email) {
        return res.status(400).json({ error: 'Please fill in all required fields' });
    }

    const sqlInsert = 'INSERT INTO reports (name, role, category, details, email, phone) VALUES (?, ?, ?, ?, ?, ?)';
    
    db.query(sqlInsert, [name, role, category, details, email, phone], (err, result) => {
        if (err) {
            console.error("Error inserting report:", err);
            return res.status(500).json({ error: 'Server error while saving the report' });
        }

        const io = req.app.get('io');
        if (io) {
            io.emit('new_report_submitted', { 
                reportId: result.insertId,
                name: name,
                role: role,
                category: category
            });
        }

        res.status(200).json({ message: 'Report submitted successfully', reportId: result.insertId });
    });
});

router.get('/all', (req, res) => {
    const sqlSelect = 'SELECT * FROM reports ORDER BY created_at DESC';
    
    db.query(sqlSelect, (err, results) => {
        if (err) {
            console.error("Error fetching reports:", err);
            return res.status(500).json({ error: 'Server error while fetching reports' });
        }
        res.status(200).json(results); 
    });
});

module.exports = router;