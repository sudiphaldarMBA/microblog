
const { Resend } = require("resend");

const resend = new Resend(process.env.RESEND_API_KEY);

const sendPasswordResetOtp = async (email, otp) => {
  const from = process.env.RESEND_FROM_EMAIL;

  if (!process.env.RESEND_API_KEY || !from) {
    throw new Error("Email service is not configured");
  }

  const { data, error } = await resend.emails.send({
    from,
    to: [email],
    subject: "Your MicroBlog password reset code",
    text: `Your MicroBlog password reset code is ${otp}. It expires in 10 minutes. If you did not request this, ignore this email.`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;">
        <h2>Reset your MicroBlog password</h2>
        <p>Use this verification code to reset your password:</p>
        <div style="font-size:32px;font-weight:bold;letter-spacing:8px;padding:16px 0;">
          ${otp}
        </div>
        <p>This code expires in 10 minutes.</p>
        <p>If you did not request this, you can safely ignore this email.</p>
      </div>
    `,
  });

  if (error) {
    throw new Error(error.message || "Unable to send email");
  }

  return data;
};

module.exports = { sendPasswordResetOtp };
