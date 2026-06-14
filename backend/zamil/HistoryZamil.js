const express = require('express');
const router = express.Router();
const db = require('../db'); 


router.get('/:zamilId', async (req, res) => {
    const { zamilId } = req.params;

    if (!zamilId) {
        return res.status(400).json({ success: false, message: "Zamil ID is required" });
    }

    try {

        const query = `
            SELECT 
                b.id AS booking_id,
                b.status AS booking_status,
                t.id AS trip_id,
                t.departure,
                t.destination,
                t.trip_date,
                t.trip_time,
                t.price,
                c.full_name AS captain_name
            FROM bookings b
            JOIN trips t ON b.trip_id = t.id
            LEFT JOIN create_acc_captain c ON t.captain_id = c.id
            WHERE b.zamil_id = ? AND b.status IN ('Completed', 'Cancelled')
            ORDER BY t.trip_date DESC, t.trip_time DESC
        `;

        const [history] = await db.promise().query(query, [zamilId]);

        res.status(200).json({
            success: true,
            message: "History fetched successfully",
            count: history.length,
            history: history
        });

    } catch (error) {
        console.error("❌ Error fetching Zamil history:", error);
        res.status(500).json({ success: false, message: "Server error while fetching history" });
    }
});

module.exports = router;