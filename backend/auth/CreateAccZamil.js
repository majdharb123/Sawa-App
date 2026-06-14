const express = require("express");
const router = express.Router();
const multer = require("multer");
const bcrypt = require("bcrypt");
const path = require("path");
const fs = require("fs");
const db = require("../db");


const uploadDir = "uploads/";
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}


const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/"); 
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + "-" + file.fieldname + path.extname(file.originalname));
  },
});
const upload = multer({ storage: storage });


router.post(
  "/zamil/register",
  upload.fields([
    { name: "id_image", maxCount: 1 },
    { name: "selfie_image", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const { full_name, email, phone, password, dob, governorate, address, fcm_token, current_country, current_city } = req.body;

      const checkEmailQuery = `
        SELECT email FROM create_acc_zamil WHERE email = ?
        UNION
        SELECT email FROM create_acc_captain WHERE email = ?
      `;
      const [existingEmail] = await db.promise().query(checkEmailQuery, [email, email]);

      if (existingEmail.length > 0) {
        return res.status(400).json({ success: false, message: "This email is already registered in SAWA!" });
      }

      const idImagePath = req.files && req.files["id_image"] ? req.files["id_image"][0].path : null;
      const selfieImagePath = req.files && req.files["selfie_image"] ? req.files["selfie_image"][0].path : null;

      let formattedDate = null;
      if (dob) {
        const parts = dob.split("/");
        if (parts.length === 3) {
          formattedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
        }
      }

      const hashedPassword = await bcrypt.hash(password, 10);

      const query = `
            INSERT INTO create_acc_zamil 
            (full_name, email, phone, password, dob, governorate, address, id_image, selfie_image, fcm_token, current_country, current_city, status) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending')
        `;

      const values = [full_name, email, phone, hashedPassword, formattedDate, governorate, address, idImagePath, selfieImagePath, fcm_token, current_country, current_city];

      const [result] = await db.promise().query(query, values);

      
      const io = req.app.get('io');
      if (io) {
        io.emit('new_zamil_request', { 
            message: 'A new Zamil has registered and is awaiting verification.', 
            zamilName: full_name 
        });
      }

      res.status(201).json({
        success: true,
        message: "Zamil account created successfully! Images uploaded.",
        insertId: result.insertId,
      });
    } catch (error) {
      console.error("❌ Error in Zamil Registration: ", error);
      res.status(500).json({ success: false, message: "Database error", error: error.message });
    }
  }
);


router.put(
  "/zamil/resubmit",
  upload.fields([
    { name: "id_image", maxCount: 1 },
    { name: "selfie_image", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const { full_name, email, phone, dob, governorate, address, fcm_token, current_country, current_city } = req.body;

      let formattedDate = null;
      if (dob) {
        const parts = dob.split("/");
        if (parts.length === 3) formattedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
      }

      let query = `
        UPDATE create_acc_zamil 
        SET full_name=?, phone=?, dob=?, governorate=?, address=?, fcm_token=?, current_country=?, current_city=?, status='Pending'
      `;
      let values = [full_name, phone, formattedDate, governorate, address, fcm_token, current_country, current_city];

      if (req.files && req.files["id_image"]) { 
        query += ", id_image=?"; 
        values.push(req.files["id_image"][0].path); 
      }
      if (req.files && req.files["selfie_image"]) { 
        query += ", selfie_image=?"; 
        values.push(req.files["selfie_image"][0].path); 
      }

      query += " WHERE email=?";
      values.push(email);

      await db.promise().query(query, values);

      const io = req.app.get('io');
      if (io) {
        io.emit('new_zamil_request', { 
            message: 'A Zamil has updated and resubmitted their documents.', 
            zamilName: full_name 
        });
      }

      res.status(200).json({ success: true, message: "Application updated and resubmitted successfully!" });
    } catch (error) {
      console.error("❌ Error in Zamil Resubmit: ", error);
      res.status(500).json({ success: false, message: "Database error", error: error.message });
    }
  }
);

module.exports = router;