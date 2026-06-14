const express = require("express");
const router = express.Router();
const db = require("../db"); 


router.get("/available", async (req, res) => {
  try {
    const query = `
            SELECT 
                t.*, 
                c.full_name AS captainName, 
                c.bus_name AS busName, 
                c.email AS captainEmail,
                c.features AS amenities 
            FROM trips t
            JOIN create_acc_captain c ON t.captain_id = c.id
            WHERE t.status = 'Active' 
              AND t.available_seats > 0
              AND (
                  t.trip_date > CURDATE() 
                  OR (
                      t.trip_date = CURDATE() AND 
                      COALESCE(STR_TO_DATE(t.trip_time, '%h:%i %p'), STR_TO_DATE(t.trip_time, '%l:%i %p'), TIME(t.trip_time)) > CURTIME()
                  )
              )
            ORDER BY t.trip_date ASC, t.trip_time ASC
        `;

    const [availableTrips] = await db.promise().query(query);

    res.status(200).json({
      success: true,
      trips: availableTrips,
    });
  } catch (error) {
    console.error("Error fetching available trips for Zamil:", error);
    res.status(500).json({ success: false, message: "Server error while fetching trips." });
  }
});


router.post("/book", async (req, res) => {
  const { trip_id, zamil_id, special_request } = req.body;

  try {
    const [tripCheck] = await db.promise().query(
      `SELECT available_seats, captain_id, trip_date, trip_time, recurrent_route_id 
             FROM trips WHERE id = ? AND status = 'Active'`,
      [trip_id],
    );

    if (tripCheck.length === 0) {
      return res.status(404).json({ success: false, message: "Trip not found or no longer available.", });
    }

    if (tripCheck[0].available_seats <= 0) {
      return res.status(400).json({ success: false, message: "Sorry, no seats available!" });
    }

    const captainId = tripCheck[0].captain_id;
    const tripDate = tripCheck[0].trip_date;
    const tripTime = tripCheck[0].trip_time;
    const recurrentRouteId = tripCheck[0].recurrent_route_id; 

    const [timeConflict] = await db.promise().query(
      `SELECT b.id 
             FROM bookings b
             JOIN trips t ON b.trip_id = t.id
             WHERE b.zamil_id = ? 
             AND t.trip_date = ? 
             AND t.trip_time = ? 
             AND b.status = 'Confirmed'`,
      [zamil_id, tripDate, tripTime],
    );

    if (timeConflict.length > 0) {
      return res.status(400).json({ success: false, message: "You already have another trip booked at this exact date and time!", });
    }

    try {
      await db.promise().query(
          `INSERT INTO bookings (trip_id, zamil_id, special_request) VALUES (?, ?, ?)`,
          [trip_id, zamil_id, special_request || null],
        );
    } catch (err) {
      if (err.code === "ER_DUP_ENTRY") {
        return res.status(400).json({ success: false, message: "You have already booked this trip!", });
      }
      throw err;
    }

    
    if (recurrentRouteId) {
      try {
        await db.promise().query(
          `INSERT IGNORE INTO recurrent_bookings 
                    (zamil_id, recurrent_route_id, start_date, special_request, status) 
                    VALUES (?, ?, ?, ?, 'Active')`,
          [zamil_id, recurrentRouteId, tripDate, special_request || null],
        );
        
        
        const io = req.app.get('io');
        if (io) {
             io.emit('new_subscription', { captainId, recurrentRouteId, zamil_id });
        }
      } catch (subErr) {
        console.error("⚠️ Error auto-subscribing zamil:", subErr);
      }
    }

    await db.promise().query(
        `UPDATE trips SET available_seats = available_seats - 1 WHERE id = ?`,
        [trip_id],
      );

    let searchTripId = recurrentRouteId ? recurrentRouteId : trip_id;
    let searchTripType = recurrentRouteId ? "Recurrent" : "Private";

    const [groupCheck] = await db.promise().query(
        `SELECT id FROM chat_groups WHERE trip_id = ? AND trip_type = ? LIMIT 1`,
        [searchTripId, searchTripType],
      );

    if (groupCheck.length > 0) {
      const groupId = groupCheck[0].id;
      await db.promise().query(
          `INSERT IGNORE INTO chat_members (group_id, zamil_id) VALUES (?, ?)`,
          [groupId, zamil_id],
        );
    } 

    let notifTitle = "New Seat Booked! 🎉";
    let notifMessage = `A passenger has booked a seat on your trip #${trip_id}.`;

    if (recurrentRouteId) {
      notifTitle = "New Subscriber! 🚀";
      notifMessage = `A passenger has booked and subscribed to your recurrent route #${recurrentRouteId}.`;
    }

    if (special_request && special_request.trim() !== "") {
      notifMessage += `\nPassenger Note: "${special_request}"`;
    }

    await db.promise().query(
      `INSERT INTO notifications (captain_id, title, message, type, reference_id) 
             VALUES (?, ?, ?, 'Booking', ?)`,
      [captainId, notifTitle, notifMessage, trip_id],
    );

    const io = req.app.get('io');
    if (io) {
        io.emit('seat_booked', { trip_id, remaining_seats: tripCheck[0].available_seats - 1 });
        io.emit('new_booking_notification', { captainId, message: notifMessage });
    }

    res.status(200).json({ success: true, message: "Seat booked successfully!" });
  } catch (error) {
    console.error("Error booking seat:", error);
    res.status(500).json({ success: false, message: "Server error during booking." });
  }
});


router.get("/check-booking/:trip_id/:zamil_id", async (req, res) => {
  try {
    const [check] = await db.promise().query(`SELECT id FROM bookings WHERE trip_id = ? AND zamil_id = ?`, [
        req.params.trip_id,
        req.params.zamil_id,
      ]);

    res.status(200).json({ isBooked: check.length > 0 });
  } catch (error) {
    console.error("Error checking booking status:", error);
    res.status(500).json({ success: false });
  }
});


router.get("/upcoming/:zamil_id", async (req, res) => {
  try {
    const zamilId = req.params.zamil_id;

    const query = `
            SELECT t.id, t.departure, t.destination, t.trip_date, t.trip_time, t.duration
            FROM bookings b
            JOIN trips t ON b.trip_id = t.id
            WHERE b.zamil_id = ? 
              AND b.status = 'Confirmed' 
              AND t.status = 'Active'
              AND (
                  t.trip_date > CURDATE() 
                  OR (
                      t.trip_date = CURDATE() AND 
                      COALESCE(STR_TO_DATE(t.trip_time, '%h:%i %p'), STR_TO_DATE(t.trip_time, '%l:%i %p'), TIME(t.trip_time)) > CURTIME()
                  )
              )
            ORDER BY 
                t.trip_date ASC, 
                COALESCE(STR_TO_DATE(t.trip_time, '%h:%i %p'), STR_TO_DATE(t.trip_time, '%l:%i %p'), TIME(t.trip_time)) ASC
            LIMIT 1
        `;

    const [upcomingTrip] = await db.promise().query(query, [zamilId]);

    if (upcomingTrip.length > 0) {
      res.status(200).json({ success: true, trip: upcomingTrip[0] });
    } else {
      res.status(200).json({ success: true, trip: null });
    }
  } catch (error) {
    console.error("Error fetching upcoming trip:", error);
    res.status(500).json({ success: false, message: "Server error while fetching upcoming trip.", });
  }
});


router.get('/current-trip', async (req, res) => {
    const email = req.query.email;

    if (!email) return res.status(400).json({ success: false, message: "Zamil email is required." });

    try {
        const [zamil] = await db.promise().query('SELECT id FROM create_acc_zamil WHERE email = ?', [email]);
        if (zamil.length === 0) return res.status(404).json({ success: false, message: "Zamil not found." });

        const zamilId = zamil[0].id;

        const now = new Date();
        const beirutTime = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Beirut" }));
        const todayStr = `${beirutTime.getFullYear()}-${String(beirutTime.getMonth() + 1).padStart(2, '0')}-${String(beirutTime.getDate()).padStart(2, '0')}`; 

        const query = `
            SELECT t.id as trip_id, t.start_lat, t.start_lng, t.dest_lat, t.dest_lng, 
                   t.departure, t.destination, t.trip_time, t.status as trip_status,
                   c.full_name as captain_name, c.phone as captain_phone
            FROM bookings b
            JOIN trips t ON b.trip_id = t.id
            JOIN create_acc_captain c ON t.captain_id = c.id
            WHERE b.zamil_id = ? 
              AND t.trip_date = ? 
              AND b.status = 'Confirmed' 
              AND LOWER(t.status) IN ('active', 'started')
            ORDER BY t.trip_time ASC
            LIMIT 1
        `;

        const [trips] = await db.promise().query(query, [zamilId, todayStr]);

        if (trips.length > 0) {
            res.status(200).json({ success: true, trip: trips[0] });
        } else {
            res.status(200).json({ success: true, trip: null, message: "No confirmed trips for today." });
        }

    } catch (error) {
        console.error("❌ Error fetching Zamil current trip:", error);
        res.status(500).json({ success: false, message: "Server error" });
    }
});


router.put('/cancel-booking', async (req, res) => {
    const { trip_id, zamil_id } = req.body;

    if (!trip_id || !zamil_id) {
        return res.status(400).json({ success: false, message: "Missing trip_id or zamil_id" });
    }

    try {
        const [result] = await db.promise().query(
            `UPDATE bookings SET status = 'Cancelled' WHERE trip_id = ? AND zamil_id = ? AND status = 'Confirmed'`,
            [trip_id, zamil_id]
        );

        if (result.affectedRows === 0) {
            return res.status(404).json({ success: false, message: "Booking not found or already cancelled." });
        }

        await db.promise().query(
            `UPDATE trips SET available_seats = available_seats + 1 WHERE id = ?`,
            [trip_id]
        );

        
        const io = req.app.get('io');
        if (io) {
             io.emit('booking_cancelled', { trip_id, zamil_id });
             io.emit('seat_available', { trip_id }); 
        }

        res.status(200).json({ success: true, message: "Booking cancelled successfully." });
    } catch (error) {
        console.error("❌ Error cancelling booking:", error);
        res.status(500).json({ success: false, message: "Server error" });
    }
});

module.exports = router;