const express = require("express");

const router = express.Router();

const healthController = require("../controllers/healthController");
const authRoutes = require("./authRoutes");

// Health Route
router.get("/health", healthController.healthCheck);

// Authentication Routes
router.use("/auth", authRoutes);

module.exports = router;