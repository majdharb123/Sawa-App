const express = require('express');
const router = express.Router();
const db = require('../db');


router.get('/groups/:captainId', async (req, res) => {
    const { captainId } = req.params;
    try {
        const [groups] = await db.promise().query(
            `SELECT * FROM chat_groups WHERE captain_id = ? ORDER BY created_at DESC`,
            [captainId]
        );
        res.status(200).json({ success: true, count: groups.length, groups });
    } catch (error) {
        console.error("❌ Error fetching captain groups:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.post('/create-private', async (req, res) => {
    const { captain_id, trip_id, group_name } = req.body;

    if (!captain_id || !trip_id || !group_name) {
        return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    try {
        const [result] = await db.promise().query(
            `INSERT INTO chat_groups (trip_id, captain_id, trip_type, group_name) VALUES (?, ?, 'Private', ?)`,
            [trip_id, captain_id, group_name]
        );

        const io = req.app.get('io');
        if (io) {
            io.emit('group_list_updated', { captain_id, message: "New group created" });
        }

        res.status(200).json({ success: true, message: "Private group created", groupId: result.insertId });
    } catch (error) {
        console.error("❌ Error creating private group:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

router.post('/send-message', async (req, res) => {
    const { group_id, captain_id, content } = req.body;

    if (!group_id || !captain_id || !content) {
        return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    try {
        const [result] = await db.promise().query(
            `INSERT INTO messages (group_id, captain_id, content) VALUES (?, ?, ?)`,
            [group_id, captain_id, content]
        );

        const io = req.app.get('io');
        if (io) {
            io.emit('new_message', {
                id: result.insertId,
                group_id,
                captain_id,
                content
            });
        }

        res.status(200).json({ success: true, message: "Message sent", messageId: result.insertId });
    } catch (error) {
        console.error("❌ Error sending message:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/messages/:groupId', async (req, res) => {
    const { groupId } = req.params;
    try {
        const [messages] = await db.promise().query(
            `SELECT * FROM messages WHERE group_id = ? ORDER BY created_at ASC`,
            [groupId]
        );
        res.status(200).json({ success: true, count: messages.length, messages });
    } catch (error) {
        console.error("❌ Error fetching messages:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

router.get('/members/:groupId', async (req, res) => {
    const { groupId } = req.params;
    try {
        const query = `
            SELECT z.id, z.full_name, z.phone, cm.joined_at 
            FROM chat_members cm
            JOIN create_acc_zamil z ON cm.zamil_id = z.id
            WHERE cm.group_id = ?
        `;
        const [members] = await db.promise().query(query, [groupId]);
        res.status(200).json({ success: true, count: members.length, members });
    } catch (error) {
        console.error("❌ Error fetching group members:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.delete('/delete-message/:messageId', async (req, res) => {
    const { messageId } = req.params;
    try {
        await db.promise().query(`DELETE FROM messages WHERE id = ?`, [messageId]);

        const io = req.app.get('io');
        if (io) {
            io.emit('message_deleted', { messageId });
        }

        res.status(200).json({ success: true, message: "Message deleted successfully." });
    } catch (error) {
        console.error("❌ Error deleting message:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.delete('/delete-group/:groupId', async (req, res) => {
    const { groupId } = req.params;
    try {
        await db.promise().query(`DELETE FROM messages WHERE group_id = ?`, [groupId]);
        await db.promise().query(`DELETE FROM chat_members WHERE group_id = ?`, [groupId]);
        await db.promise().query(`DELETE FROM chat_groups WHERE id = ?`, [groupId]);

        const io = req.app.get('io');
        if (io) {
            io.emit('group_deleted', { groupId });
        }

        res.status(200).json({ success: true, message: "Group and all its data deleted successfully." });
    } catch (error) {
        console.error("❌ Error deleting group:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/group-details/:groupId', async (req, res) => {
    try {
        const groupId = req.params.groupId;

        const [captainInfo] = await db.promise().query(
            `SELECT cg.group_name, c.full_name AS captain_name, c.phone AS captain_phone 
             FROM chat_groups cg
             JOIN create_acc_captain c ON cg.captain_id = c.id
             WHERE cg.id = ?`,
            [groupId]
        );

        if (captainInfo.length === 0) {
            return res.status(404).json({ success: false, message: "Group not found" });
        }

        const [passengers] = await db.promise().query(
            `SELECT z.id, z.full_name, z.phone, z.email, z.selfie_image 
             FROM chat_members cm
             JOIN create_acc_zamil z ON cm.zamil_id = z.id
             WHERE cm.group_id = ?`,
            [groupId]
        );

        res.status(200).json({
            success: true,
            group_name: captainInfo[0].group_name,
            captain: {
                name: captainInfo[0].captain_name,
                phone: captainInfo[0].captain_phone
            },
            passengers: passengers
        });

    } catch (error) {
        console.error("❌ Error fetching group details:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

module.exports = router;