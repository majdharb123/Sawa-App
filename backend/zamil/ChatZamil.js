const express = require('express');
const router = express.Router();
const db = require('../db'); 

router.get('/unread-chats/:zamil_id', async (req, res) => {
    const zamilId = req.params.zamil_id;

    try {
        const query = `
            SELECT COUNT(m.id) as unreadCount 
            FROM messages m
            JOIN chat_members cm ON m.group_id = cm.group_id
            WHERE cm.zamil_id = ? 
            AND m.captain_id != ? 
            AND m.is_read = 0
        `;
        
        const [results] = await db.promise().query(query, [zamilId, zamilId]);
        const count = results[0].unreadCount;

        res.status(200).json({ 
            success: true, 
            hasUnreadChats: count > 0 
        });

    } catch (error) {
        console.error("❌ Error checking unread chats:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});

router.put('/mark-read/:group_id', async (req, res) => {
    const groupId = req.params.group_id;

    try {
        const query = `
            UPDATE messages 
            SET is_read = 1 
            WHERE group_id = ? 
            AND is_read = 0
        `;
        
        const [result] = await db.promise().query(query, [groupId]);

        
        const io = req.app.get('io');
        if (io) {
            io.emit('chat_marked_read', { groupId });
        }

        console.log(`✅ [DEBUG] Marked ${result.affectedRows} messages as read for group ${groupId}`);
        res.status(200).json({ success: true, message: "Messages marked as read." });
        
    } catch (error) {
        console.error("❌ Error marking messages as read:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/captain-private-groups/:captain_id', async (req, res) => {
    try {
        const captainId = req.params.captain_id;

        const query = `
            SELECT 
                id as group_id, 
                group_name, 
                'Private Group' as departure, 
                group_name as destination, 
                'Available' as trip_date, 
                'Anytime' as trip_time
            FROM chat_groups 
            WHERE captain_id = ? 
              AND trip_type = 'Private'
              AND trip_id = 101
        `;

        const [groups] = await db.promise().query(query, [captainId]);

        res.status(200).json({
            success: true,
            groups: groups
        });

    } catch (error) {
        console.error("❌ Error fetching captain's private groups:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.post('/join-private-group', async (req, res) => {
    const { zamil_id, group_id } = req.body;

    if (!zamil_id || !group_id) {
        return res.status(400).json({ success: false, message: "Missing zamil_id or group_id" });
    }

    try {
        const [existing] = await db.promise().query(
            `SELECT group_id FROM chat_members WHERE group_id = ? AND zamil_id = ?`,
            [group_id, zamil_id]
        );

        if (existing.length > 0) {
            return res.status(200).json({ success: true, message: "Already a member", alreadyJoined: true });
        }

        await db.promise().query(
            `INSERT INTO chat_members (group_id, zamil_id) VALUES (?, ?)`,
            [group_id, zamil_id]
        );

        
        const io = req.app.get('io');
        if (io) {
            io.emit('group_members_updated', { groupId: group_id, zamilId: zamil_id, action: 'joined' });
        }

        res.status(200).json({ success: true, message: "Joined successfully!", alreadyJoined: false });

    } catch (error) {
        console.error("❌ Error joining private group:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/my-groups/:zamil_id', async (req, res) => {
    try {
        const zamilId = req.params.zamil_id;

        const query = `
            SELECT 
                cg.id as group_id, 
                cg.group_name, 
                cg.trip_type, 
                c.full_name as captainName,
                (SELECT content FROM messages WHERE group_id = cg.id ORDER BY created_at DESC LIMIT 1) as lastMsg,
                (SELECT created_at FROM messages WHERE group_id = cg.id ORDER BY created_at DESC LIMIT 1) as lastMsgTime
            FROM chat_members cm
            JOIN chat_groups cg ON cm.group_id = cg.id
            JOIN create_acc_captain c ON cg.captain_id = c.id
            WHERE cm.zamil_id = ?
        `;

        const [myGroups] = await db.promise().query(query, [zamilId]);

        res.status(200).json({
            success: true,
            groups: myGroups
        });

    } catch (error) {
        console.error("❌ Error fetching Zamil's groups:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.get('/messages/:groupId', async (req, res) => {
    try {
        const groupId = req.params.groupId;
        
        const [messages] = await db.promise().query(
            `SELECT id, content, created_at FROM messages 
             WHERE group_id = ? ORDER BY created_at ASC`,
            [groupId]
        );

        res.status(200).json({ success: true, messages });
    } catch (error) {
        console.error("❌ Error fetching messages:", error);
        res.status(500).json({ success: false, message: "Server error." });
    }
});


router.post('/leave-group', async (req, res) => {
    const { zamil_id, group_id } = req.body;

    if (!zamil_id || !group_id) {
        return res.status(400).json({ success: false, message: "Missing parameters" });
    }

    try {
        const [result] = await db.promise().query(
            `DELETE FROM chat_members WHERE group_id = ? AND zamil_id = ?`,
            [group_id, zamil_id]
        );

        if (result.affectedRows > 0) {
            
            const io = req.app.get('io');
            if (io) {
                io.emit('group_members_updated', { groupId: group_id, zamilId: zamil_id, action: 'left' });
            }

            res.status(200).json({ success: true, message: "Left group successfully" });
        } else {
            res.status(404).json({ success: false, message: "Member not found in this group" });
        }
    } catch (error) {
        console.error("❌ Error leaving group:", error);
        res.status(500).json({ success: false, message: "Server error" });
    }
});

module.exports = router;