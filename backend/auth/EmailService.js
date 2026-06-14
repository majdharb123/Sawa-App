const nodemailer = require('nodemailer');
require('dotenv').config();


const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true, 
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});


const sendOTPEmail = async (targetEmail, otpCode) => {
  const mailOptions = {
    from: `"SAWA App" <${process.env.EMAIL_USER}>`,
    to: targetEmail,
    subject: 'SAWA - Reset Your Password',
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <h2 style="color: #1D9E75;">Password Reset Request</h2>
        <p>Hello,</p>
        <p>You requested to reset your password for your <b>SAWA</b> account. Use the code below to proceed:</p>
        <h1 style="background: #f4f4f4; padding: 10px; text-align: center; color: #1D9E75; letter-spacing: 5px;">${otpCode}</h1>
        <p>This code is valid for 15 minutes. If you didn't request this, you can safely ignore this email.</p>
        <p>Best regards,<br>The SAWA Team</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log('OTP Email sent successfully to:', targetEmail);
    return true;
  } catch (error) {
    console.error('Error sending email:', error);
    return false;
  }
};

module.exports = { sendOTPEmail };