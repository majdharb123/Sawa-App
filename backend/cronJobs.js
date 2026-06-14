const cron = require("node-cron");
const db = require("./db"); 

function startCronJobs(io) {
  
  cron.schedule("0 2 * * *", async () => {
    console.log("🤖 [Cron Job] 2:00 AM - Cleaning up finished trips, bookings, and chats...");

    try {
      const [tripsResult] = await db.promise().query(`
            UPDATE trips 
            SET status = 'Completed' 
            WHERE status = 'Active' 
            AND (trip_date < CURDATE() OR (trip_date = CURDATE() AND trip_time < CURTIME()))
        `);
      console.log(`✅ [Cron Job] Updated ${tripsResult.affectedRows} trips to Completed.`);

      const [bookingsResult] = await db.promise().query(`
            UPDATE bookings b
            JOIN trips t ON b.trip_id = t.id
            SET b.status = 'Completed'
            WHERE t.status = 'Completed' AND b.status = 'Confirmed'
        `);
      console.log(`✅ [Cron Job] Updated ${bookingsResult.affectedRows} bookings to Completed.`);

      const [completedPrivateGroups] = await db.promise().query(`
          SELECT cg.id FROM chat_groups cg
          JOIN trips t ON cg.trip_id = t.id
          WHERE cg.trip_type = 'Private' AND t.status = 'Completed'
      `);
      
      let deletedChatsCount = 0;
      for (let group of completedPrivateGroups) {
          await db.promise().query(`DELETE FROM messages WHERE group_id = ?`, [group.id]);
          await db.promise().query(`DELETE FROM chat_members WHERE group_id = ?`, [group.id]);
          await db.promise().query(`DELETE FROM chat_groups WHERE id = ?`, [group.id]);
          deletedChatsCount++;
      }
      if (deletedChatsCount > 0) {
          console.log(`✅ [Cron Job] Deleted ${deletedChatsCount} completed Private chat groups.`);
      }

      if (io) {
          io.emit('system_cleanup_completed');
      }

    } catch (error) {
      console.error("❌ [Cron Job] Error during night cleanup:", error);
    }
  });

  
  cron.schedule("0 0 * * *", async () => {
    try {
      console.log("⏳ Cron: Generating recurrent trips and processing subscriptions...");

      const now = new Date();
      const beirutTime = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Beirut" }));
      const year = beirutTime.getFullYear();
      const month = String(beirutTime.getMonth() + 1).padStart(2, "0");
      const day = String(beirutTime.getDate()).padStart(2, "0");
      const todayStr = `${year}-${month}-${day}`;

      const daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
      const dayName = daysOfWeek[beirutTime.getDay()];

      const [routes] = await db.promise().query(
        `
                SELECT r.*, req.captain_id
                FROM recurrent_routes r
                JOIN route_requests req ON r.id = req.route_id
                WHERE LOWER(req.status) IN ('approved', 'active')
                AND r.start_date <= ? 
                AND (r.end_date IS NULL OR r.end_date >= ?)
            `,
        [todayStr, todayStr]
      );

      let createdCount = 0;
      let totalAutoBookings = 0;

      for (let route of routes) {
        let opDays = route.operational_days || "";
        let isOperatingToday = true;

        if (opDays.length > 2 && opDays !== "[]" && opDays !== "null") {
          if (!opDays.includes(dayName)) isOperatingToday = false;
        }

        if (isOperatingToday) {
          const [existing] = await db.promise().query(
            `SELECT id FROM trips WHERE recurrent_route_id = ? AND trip_date = ? AND captain_id = ?`,
            [route.id, todayStr, route.captain_id]
          );

          if (existing.length === 0) {
            
            const insertQuery = `
                            INSERT INTO trips 
                            (captain_id, recurrent_route_id, departure, destination, meeting_point, dropoff_point, start_lat, start_lng, dest_lat, dest_lng, trip_date, trip_time, duration, available_seats, price, status)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active')
                        `;

            const [insertResult] = await db.promise().query(insertQuery, [
                route.captain_id, route.id, route.from_city, route.to_city,
                route.from_city + " Station", route.to_city + " Station",
                route.start_lat || null, route.start_lng || null,
                route.dest_lat || null, route.dest_lng || null,
                todayStr, route.departure_time, route.estimated_duration,
                route.max_passengers || 15, route.price_lbp || 250000,
              ]);

            const newTripId = insertResult.insertId;
            createdCount++;

            const [chatGroupRes] = await db.promise().query(
                `SELECT id FROM chat_groups WHERE trip_id = ? AND trip_type = 'Recurrent' LIMIT 1`,
                [route.id]
            );
            const chatGroupId = chatGroupRes.length > 0 ? chatGroupRes[0].id : null;

            const [subscribers] = await db.promise().query(
              `
                            SELECT zamil_id, special_request 
                            FROM recurrent_bookings 
                            WHERE recurrent_route_id = ? AND status = 'Active' 
                            AND start_date <= ? AND (end_date IS NULL OR end_date >= ?)
                        `,
              [route.id, todayStr, todayStr]
            );

            let bookedSeatsCount = 0;

            for (let sub of subscribers) {
              try {
                await db.promise().query(
                    `INSERT INTO bookings (trip_id, zamil_id, special_request, status) VALUES (?, ?, ?, 'Confirmed')`,
                    [newTripId, sub.zamil_id, sub.special_request || "Auto-booked via subscription"]
                  );

                await db.promise().query(
                    `INSERT INTO notifications (zamil_id, title, message, type, reference_id) VALUES (?, ?, ?, 'Auto-Booking', ?)`,
                    [sub.zamil_id, "Auto-Booking Successful! 🚌", `Your seat for today's trip (${route.from_city} to ${route.to_city}) has been automatically booked.`, newTripId]
                  );

                if (chatGroupId) {
                    await db.promise().query(
                        `INSERT IGNORE INTO chat_members (group_id, zamil_id) VALUES (?, ?)`,
                        [chatGroupId, sub.zamil_id]
                    );
                }

                bookedSeatsCount++;
                totalAutoBookings++;
              } catch (err) {
                console.error(`❌ Failed to auto-book Zamil ${sub.zamil_id}: `, err);
              }
            }

            if (bookedSeatsCount > 0) {
              await db.promise().query(
                  `UPDATE trips SET available_seats = available_seats - ? WHERE id = ?`,
                  [bookedSeatsCount, newTripId]
                );

              await db.promise().query(
                  `INSERT INTO notifications (captain_id, title, message, type, reference_id) VALUES (?, ?, ?, 'Auto-Booking', ?)`,
                  [route.captain_id, "Auto-Bookings Processed! 🎉", `${bookedSeatsCount} passengers were automatically booked for your trip today via their subscriptions.`, newTripId]
                );
            }
          }
        }
      }
      console.log(`✅ Cron: Generated ${createdCount} trips and processed ${totalAutoBookings} automatic subscriptions. `);

      
      if (io && createdCount > 0) {
          io.emit('daily_trips_generated');
      }

    } catch (error) {
      console.error("❌ Cron Error (Generation):", error);
    }
  });

  
  cron.schedule('0 3 * * *', async () => {
    console.log('🧹 [Cron Job] 3:00 AM - Cleaning up Expired Recurrent Routes...');
    
    try {
        const [expiredRoutes] = await db.promise().query(
            `SELECT id FROM recurrent_routes WHERE end_date < CURDATE() AND status = 'Active'`
        );

        if (expiredRoutes.length > 0) {
            const routeIds = expiredRoutes.map(r => r.id);

            await db.promise().query(`UPDATE recurrent_routes SET status = 'Expired' WHERE id IN (?)`, [routeIds]);

            const [groups] = await db.promise().query(`SELECT id FROM chat_groups WHERE trip_id IN (?) AND trip_type = 'Recurrent'`, [routeIds]);

            if (groups.length > 0) {
                const groupIds = groups.map(g => g.id);
                await db.promise().query(`DELETE FROM messages WHERE group_id IN (?)`, [groupIds]);
                await db.promise().query(`DELETE FROM chat_members WHERE group_id IN (?)`, [groupIds]);
                await db.promise().query(`DELETE FROM chat_groups WHERE id IN (?)`, [groupIds]);
            }

            
            if (io) {
                io.emit('recurrent_routes_expired');
            }

            console.log(`✅ [Cron Job] Cleaned up ${expiredRoutes.length} expired routes and deleted their chat groups.`);
        } else {
            console.log('✅ [Cron Job] No expired recurrent routes found today.');
        }
    } catch (error) {
        console.error('❌ [Cron Job] Error cleaning up expired routes:', error);
    }
  });
}

module.exports = startCronJobs;