
const express = require("express");

const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/authMiddleware");

// ==========================================
// REGISTER
// ==========================================
router.post(
  "/register",
  authController.register
);

// ==========================================
// EMAIL / PASSWORD LOGIN
// ==========================================
router.post(
  "/login",
  authController.login
);

// ==========================================
// FIREBASE LOGIN (GOOGLE / PHONE OTP)
// ==========================================
router.post(
  "/firebase-login",
  authController.firebaseLogin
);

// ==========================================
// GET LOGGED-IN USER
// ==========================================
router.get(
  "/me",
  authMiddleware,
  authController.getMe
);


// ==========================================
// DEVICE SESSION MANAGEMENT
// ==========================================

router.get(
  "/sessions",
  authMiddleware,
  authController.getSessions
);

router.delete(
  "/sessions/:sessionId",
  authMiddleware,
  authController.revokeSession
);

router.delete(
  "/sessions",
  authMiddleware,
  authController.revokeOtherSessions
);

// ==========================================
// CHANGE PASSWORD
// ==========================================
router.put(
  "/change-password",
  authMiddleware,
  authController.changePassword
);

// ==========================================
// UPDATE USER PROFILE
// ==========================================
router.put(
  "/profile",
  authMiddleware,
  authController.updateProfile
);

module.exports = router;
