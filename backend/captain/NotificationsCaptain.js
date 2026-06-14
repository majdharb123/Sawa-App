const express = require('express');
const router = express.Router();
const db = require('../db'); 


router.get('/check-unread/:id', async (req, res) => {
    const captainId = req.params.id;

    try {
        const query = `
            SELECT COUNT(*) as unreadCount 
            FROM notifications 
            WHERE captain_id = ? AND (is_read = 0 OR is_read IS NULL OR is_read = false)
        `;
        
        const [results] = await db.promise().query(query, [captainId]);
        const count = results[0].unreadCount;

        res.status(200).json({ 
            success: true, 
            hasUnread: count > 0, 
            count: count 
        });

    } catch (error) {
        console.error("❌ Error checking unread notifications:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/:id', async (req, res) => {
    const captainId = req.params.id; 

    try {
        const query = `
            SELECT id, title, message, type, reference_id, is_read, created_at
            FROM notifications
            WHERE captain_id = ?
            ORDER BY created_at DESC
        `;
        
        const [results] = await db.promise().query(query, [captainId]);

        const formattedNotifications = results.map(row => {
            let isReadStatus = false;
            if (row.is_read === 1 || row.is_read === true) {
                isReadStatus = true;
            } else if (Buffer.isBuffer(row.is_read) && row.is_read.length > 0 && row.is_read[0] === 1) {
                isReadStatus = true;
            }

            return {
                id: row.id,
                title: row.title,
                message: row.message,
                type: row.type || 'Account',
                reference_id: row.reference_id, 
                is_read: isReadStatus, 
                created_at: row.created_at 
            };
        });

        res.status(200).json({
            success: true,
            notifications: formattedNotifications
        });

    } catch (error) {
        console.error("❌ Error fetching captain notifications:", error);
        res.status(500).json({ success: false, message: "Server error while fetching notifications." });
    }
});


router.put('/:id/read', async (req, res) => {
    const notifId = req.params.id;
    try {
        await db.promise().query(`UPDATE notifications SET is_read = 1 WHERE id = ?`, [notifId]);

        const io = req.app.get('io');
        if (io) {
            io.emit('notification_read_update', { notifId });
        }

        res.status(200).json({ success: true, message: "Notification marked as read." });
    } catch (error) {
        console.error("Error updating captain notification status:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

module.exports = router;