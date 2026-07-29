const express = require("express");

const router = express.Router();

const healthController = require("../controllers/healthController");

// Health Check Route
router.get("/health", healthController.healthCheck);

module.exports = router;