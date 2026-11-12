
const express = require("express");

const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/authMiddleware");
const followController = require("../controllers/followController");

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

// ==========================================
// PUBLIC PROFILE AND FOLLOW SYSTEM
// ==========================================
router.get(
  "/users/:userId",
  authMiddleware,
  followController.getProfile
);

router.post(
  "/users/:userId/follow",
  authMiddleware,
  followController.follow
);

router.delete(
  "/users/:userId/follow",
  authMiddleware,
  followController.unfollow
);

// ==========================================
// INCOMING FOLLOW REQUESTS
// ==========================================
router.get(
  "/follow-requests",
  authMiddleware,
  followController.getFollowRequests
);

router.post(
  "/follow-requests/:requesterId/accept",
  authMiddleware,
  followController.acceptFollowRequest
);

router.delete(
  "/follow-requests/:requesterId",
  authMiddleware,
  followController.rejectFollowRequest
);

module.exports = router;
