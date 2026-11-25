
const express = require("express");

const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const adminMiddleware = require("../middleware/adminMiddleware");
const adminController = require("../controllers/adminController");

// Every admin route requires authentication AND admin authorization.
router.use(authMiddleware, adminMiddleware);

// ==========================================
// VERIFICATION MANAGEMENT
// ==========================================

router.get(
  "/verification/pending",
  adminController.getPendingVerifications
);

router.get(
  "/verification/:userId/selfie",
  adminController.getVerificationSelfie
);

router.patch(
  "/verification/:userId/approve",
  adminController.approveVerification
);

router.patch(
  "/verification/:userId/reject",
  adminController.rejectVerification
);

module.exports = router;
