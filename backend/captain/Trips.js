const express = require('express');
const router = express.Router();
const db = require('../db');

function timeToMinutes(timeStr) {
    if (!timeStr) return 0;
    let str = String(timeStr).toUpperCase();

    let match = str.match(/(\d{1,2}):(\d{1,2})/);
    if (!match) return 0;

    let hours = parseInt(match[1], 10);
    let minutes = parseInt(match[2], 10);

    if (str.includes('P') && !str.includes('A') && hours < 12) {
        hours += 12;
    }
    if (str.includes('A') && hours === 12) {
        hours = 0;
    }

    return (hours * 60) + minutes;
}

router.post('/create', async (req, res) => {
    const {
        email, from, to, meetingPoint, dropoffPoint, date, time,
        duration, seats, price, start_lat, start_lng, dest_lat, dest_lng
    } = req.body;

    if (!email || !from || !to || !meetingPoint || !dropoffPoint || !date || !time || !seats || !price) {
        return res.status(400).json({ success: false, message: "Please provide all required fields." });
    }

    try {
        const [captain] = await db.promise().query('SELECT id FROM create_acc_captain WHERE email = ?', [email]);
        if (captain.length === 0) return res.status(404).json({ success: false, message: "Captain not found." });

        const captainId = captain[0].id;
        const BUFFER_MINS = 120;
        const newTripMins = timeToMinutes(time);

        const [privateTrips] = await db.promise().query(
            `SELECT trip_time FROM trips WHERE captain_id = ? AND trip_date = ? AND LOWER(status) != 'cancelled'`,
            [captainId, date]
        );

        for (let trip of privateTrips) {
            if (Math.abs(newTripMins - timeToMinutes(trip.trip_time)) < BUFFER_MINS) {
                return res.status(409).json({ success: false, message: `Conflict! Private trip scheduled at ${trip.trip_time}.` });
            }
        }

        const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const tripDateObj = new Date(date);
        const newTripDayName = daysOfWeek[tripDateObj.getDay()];

        console.log(`🛑 [DEBUG] Checking Date: ${date} | Day: ${newTripDayName}`);

        const [recurrentTrips] = await db.promise().query(`
            SELECT r.id, r.departure_time, r.operational_days 
            FROM recurrent_routes r
            JOIN route_requests req ON r.id = req.route_id
            WHERE req.captain_id = ? 
              AND LOWER(req.status) IN ('approved', 'active')
              AND r.start_date <= ? 
              AND (r.end_date IS NULL OR r.end_date >= ?)
        `, [captainId, date, date]);

        for (let rTrip of recurrentTrips) {
            let opDays = rTrip.operational_days || "";
            let isOperatingOnThisDay = true;

            if (opDays.length > 2 && opDays !== '[]' && opDays !== 'null') {
                if (!opDays.includes(newTripDayName)) {
                    isOperatingOnThisDay = false;
                }
            }

            if (isOperatingOnThisDay) {
                let existingMins = timeToMinutes(rTrip.departure_time);
                let diff = Math.abs(newTripMins - existingMins);
                console.log(`🛑 [DEBUG] Checking Route ID: ${rTrip.id} | Diff: ${diff} mins`);

                if (diff < BUFFER_MINS) {
                    return res.status(409).json({
                        success: false,
                        message: `Conflict! You have a fixed line around ${rTrip.departure_time} on this day.`
                    });
                }
            }
        }

        const insertQuery = `
            INSERT INTO trips 
            (captain_id, departure, destination, meeting_point, dropoff_point, trip_date, trip_time, duration, available_seats, price, status, start_lat, start_lng, dest_lat, dest_lng) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', ?, ?, ?, ?)
        `;

        const [result] = await db.promise().query(insertQuery, [
            captainId, from, to, meetingPoint, dropoffPoint, date, time,
            duration, parseInt(seats), parseInt(price), start_lat || null,
            start_lng || null, dest_lat || null, dest_lng || null
        ]);

        const io = req.app.get('io');
        if (io) {
            io.emit('new_trip_available', {
                tripId: result.insertId,
                message: "A new trip has been published."
            });
        }

        res.status(201).json({ success: true, message: "Trip published successfully!", tripId: result.insertId });

    } catch (error) {
        console.error("Error creating trip:", error);
        res.status(500).json({ success: false, message: "Server error while creating trip." });
    }
});

router.get('/my-trips', async (req, res) => {
    const email = req.query.email;

    if (!email) return res.status(400).json({ success: false, message: "Captain email is required." });

    try {
        const [trips] = await db.promise().query(`
            SELECT t.* FROM trips t
            JOIN create_acc_captain c ON t.captain_id = c.id
            WHERE c.email = ? AND t.recurrent_route_id IS NULL
            ORDER BY t.created_at DESC
        `, [email]);

        res.status(200).json({ success: true, trips });
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.put('/update/:id', async (req, res) => {
    const tripId = req.params.id;
    const {
        email, from, to, meetingPoint, dropoffPoint, date, time, duration, seats, price,
        start_lat, start_lng, dest_lat, dest_lng
    } = req.body;

    if (!email || !from || !to || !meetingPoint || !dropoffPoint || !date || !time || !seats || !price) {
        return res.status(400).json({ success: false, message: "Please provide all required fields." });
    }

    try {
        const [captain] = await db.promise().query('SELECT id FROM create_acc_captain WHERE email = ?', [email]);
        if (captain.length === 0) return res.status(404).json({ success: false, message: "Captain not found." });

        const captainId = captain[0].id;

        const updateQuery = `
            UPDATE trips 
            SET departure = ?, destination = ?, meeting_point = ?, dropoff_point = ?, trip_date = ?, trip_time = ?, duration = ?, available_seats = ?, price = ?,
                start_lat = COALESCE(?, start_lat), start_lng = COALESCE(?, start_lng), dest_lat = COALESCE(?, dest_lat), dest_lng = COALESCE(?, dest_lng)
            WHERE id = ? AND captain_id = ?
        `;

        const [result] = await db.promise().query(updateQuery, [
            from, to, meetingPoint, dropoffPoint, date, time, duration, parseInt(seats), parseInt(price),
            start_lat || null, start_lng || null, dest_lat || null, dest_lng || null, 
            tripId, captainId
        ]);

        if (result.affectedRows === 0) return res.status(404).json({ success: false, message: "Trip not found or unauthorized." });

        const io = req.app.get('io');
        if (io) {
            io.emit('trip_updated', { tripId });
        }

        res.status(200).json({ success: true, message: "Trip updated successfully!" });
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.delete('/delete/:id', async (req, res) => {
    const tripId = req.params.id;
    const email = req.query.email;

    if (!email) return res.status(400).json({ success: false, message: "Email required." });

    try {
        const [captain] = await db.promise().query('SELECT id FROM create_acc_captain WHERE email = ?', [email]);
        if (captain.length === 0) return res.status(404).json({ success: false, message: "Captain not found." });

        const captainId = captain[0].id;
        const [result] = await db.promise().query('DELETE FROM trips WHERE id = ? AND captain_id = ?', [tripId, captainId]);

        if (result.affectedRows === 0) return res.status(404).json({ success: false, message: "Trip not found." });

        const io = req.app.get('io');
        if (io) {
            io.emit('trip_deleted', { tripId });
        }

        res.status(200).json({ success: true, message: "Trip deleted successfully!" });
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.get('/recurrent', async (req, res) => {
    const email = req.query.email;

    try {
        const query = `
            SELECT r.*, req.status as my_request_status
            FROM recurrent_routes r
            LEFT JOIN route_requests req ON r.id = req.route_id 
            AND req.captain_id = (SELECT id FROM create_acc_captain WHERE email = ?)
            ORDER BY r.created_at DESC
        `;

        const [routes] = await db.promise().query(query, [email]);
        const parsedRoutes = routes.map(route => ({
            ...route,
            status: route.my_request_status || 'Available',
            stops: typeof route.stops === 'string' ? JSON.parse(route.stops) : route.stops
        }));

        res.status(200).json({ success: true, routes: parsedRoutes });
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.post('/request-route', async (req, res) => {
    const { email, routeId, proposedPrice } = req.body;

    if (!email || !routeId || !proposedPrice) return res.status(400).json({ success: false, message: "Missing info." });

    try {
        const [captain] = await db.promise().query('SELECT id FROM create_acc_captain WHERE email = ?', [email]);
        if (captain.length === 0) return res.status(404).json({ success: false, message: "Captain not found." });

        const captainId = captain[0].id;

        const [existingRequest] = await db.promise().query(
            `SELECT id, status FROM route_requests WHERE route_id = ? AND captain_id = ?`,
            [routeId, captainId]
        );

        if (existingRequest.length > 0) {
            const reqStatus = existingRequest[0].status.toLowerCase();
            if (['pending', 'approved', 'active'].includes(reqStatus)) {
                return res.status(400).json({ success: false, message: "Request already active/pending!" });
            } else if (reqStatus === 'rejected') {
                await db.promise().query(
                    `UPDATE route_requests SET status = 'pending', proposed_price = ? WHERE id = ?`,
                    [parseInt(proposedPrice), existingRequest[0].id]
                );

                const io = req.app.get('io');
                if (io) io.emit('new_route_request', { routeId, captainId });

                return res.status(200).json({ success: true, message: "Request updated! Waiting for approval." });
            }
        }

        const [result] = await db.promise().query(
            `INSERT INTO route_requests (route_id, captain_id, proposed_price, status) VALUES (?, ?, ?, 'pending')`,
            [routeId, captainId, parseInt(proposedPrice)]
        );

        const io = req.app.get('io');
        if (io) {
            io.emit('new_route_request', { routeId, captainId });
        }

        res.status(201).json({ success: true, message: "Route requested successfully!", requestId: result.insertId });
    } catch (error) {
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.get('/next-trip', async (req, res) => {
    const email = req.query.email;

    if (!email) return res.status(400).json({ success: false, message: "Captain email is required." });

    try {
        const [captain] = await db.promise().query('SELECT id FROM create_acc_captain WHERE email = ?', [email]);
        if (captain.length === 0) return res.status(404).json({ success: false, message: "Captain not found." });

        const captainId = captain[0].id;

        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const todayStr = `${year}-${month}-${day}`;

        const currentMins = (now.getHours() * 60) + now.getMinutes();

        const [privateTrips] = await db.promise().query(`
            SELECT t.*, FALSE as is_recurrent,
                   (SELECT COUNT(*) FROM bookings b WHERE b.trip_id = t.id AND b.status = 'Confirmed') AS passenger_count
            FROM trips t 
            WHERE t.captain_id = ? AND t.trip_date = ? AND LOWER(t.status) = 'active'
        `, [captainId, todayStr]);

        const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const dayName = daysOfWeek[now.getDay()];

        const [recurrentTrips] = await db.promise().query(`
            SELECT r.*, TRUE as is_recurrent,
                   (SELECT COUNT(*) FROM recurrent_bookings rb WHERE rb.recurrent_route_id = r.id AND rb.status = 'Active') AS passenger_count
            FROM recurrent_routes r
            JOIN route_requests req ON r.id = req.route_id
            WHERE req.captain_id = ? 
            AND LOWER(req.status) IN ('approved', 'active')
            AND r.start_date <= ? 
            AND (r.end_date IS NULL OR r.end_date >= ?)
        `, [captainId, todayStr, todayStr]);

        let allTodayTrips = [...privateTrips];

        for (let rTrip of recurrentTrips) {
            let opDays = rTrip.operational_days || "";
            let isOperatingToday = true;

            if (opDays.length > 2 && opDays !== '[]' && opDays !== 'null') {
                if (!opDays.includes(dayName)) isOperatingToday = false;
            }
            if (isOperatingToday) {
                rTrip.trip_time = rTrip.departure_time;
                rTrip.departure = rTrip.from_city;
                rTrip.destination = rTrip.to_city;
                allTodayTrips.push(rTrip);
            }
        }
        
        let closestTrip = null;
        let smallestDiff = Infinity;

        for (let trip of allTodayTrips) {
            let tripMins = timeToMinutes(trip.trip_time);
            let timeDiff = tripMins - currentMins;

            if (timeDiff >= -30 && timeDiff < smallestDiff) {
                smallestDiff = timeDiff;
                closestTrip = trip;
            }
        }

        if (!closestTrip) {
            const [futureTrips] = await db.promise().query(`
                SELECT t.*, FALSE as is_recurrent,
                       (SELECT COUNT(*) FROM bookings b WHERE b.trip_id = t.id AND b.status = 'Confirmed') AS passenger_count
                FROM trips t 
                WHERE t.captain_id = ? AND t.trip_date > ? AND LOWER(t.status) = 'active'
                ORDER BY t.trip_date ASC, t.trip_time ASC
                LIMIT 1
            `, [captainId, todayStr]);

            if (futureTrips.length > 0) closestTrip = futureTrips[0];
        }

        if (closestTrip) {
            res.status(200).json({ success: true, trip: closestTrip });
        } else {
            res.status(200).json({ success: true, trip: null });
        }

    } catch (error) {
        console.error("Error fetching next trip:", error);
        res.status(500).json({ success: false, message: "Server error" });
    }
});

router.put('/complete/:id', async (req, res) => {
    const tripId = req.params.id;

    try {
        const updateQuery = `UPDATE trips SET status = 'Completed' WHERE id = ?`;
        const [result] = await db.promise().query(updateQuery, [tripId]);

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: "Trip not found." });
        }

        const io = req.app.get('io');
        if (io) {
            io.emit('trip_completed', { tripId });
        }

        res.status(200).json({ success: true, message: "Trip marked as Completed successfully!" });
    } catch (error) {
        console.error("❌ Error completing trip:", error);
        res.status(500).json({ success: false, message: "Server error" });
    }
});

module.exports = router;