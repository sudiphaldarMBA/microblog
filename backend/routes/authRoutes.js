
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
// UPDATE USER PROFILE
// ==========================================
router.put(
  "/profile",
  authMiddleware,
  authController.updateProfile
);

module.exports = router;
