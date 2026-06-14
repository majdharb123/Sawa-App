const express = require('express');
const router = express.Router();
const db = require('../db'); 


router.get('/get-history/:captainId', async (req, res) => {
    try {
        const captainId = req.params.captainId;

        const [trips] = await db.promise().query(
            `SELECT id, departure, destination, trip_date, trip_time, status 
             FROM trips 
             WHERE captain_id = ? AND (status = 'Completed' OR trip_date < CURDATE())
             ORDER BY trip_date DESC, trip_time DESC`,
            [captainId]
        );

        if (trips.length === 0) {
            return res.status(200).json({ success: true, history: [] });
        }

        let historyData = [];

        for (let trip of trips) {
            const [passengers] = await db.promise().query(
                `SELECT z.full_name AS name, z.email
                 FROM bookings b
                 JOIN create_acc_zamil z ON b.zamil_id = z.id
                 WHERE b.trip_id = ?`, 
                [trip.id]
            );

            const formattedDate = new Date(trip.trip_date).toISOString().split('T')[0];

            historyData.push({
                trip_id: trip.id,
                route: `${trip.departure} → ${trip.destination}`,
                date: formattedDate,
                time: trip.trip_time,
                status: trip.status === 'Completed' ? 'Completed' : 'Past',
                passengers: passengers 
            });
        }

        res.status(200).json({ success: true, history: historyData });

    } catch (error) {
        console.error("❌ Error fetching captain history:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

module.exports = router;