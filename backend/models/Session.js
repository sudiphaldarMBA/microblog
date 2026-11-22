
const mongoose = require("mongoose");

const sessionSchema = new mongoose.Schema(
  {
    // ==========================================
    // SESSION ID
    // ==========================================

    sessionId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },

    // ==========================================
    // USER
    // ==========================================

    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // ==========================================
    // DEVICE INFORMATION
    // ==========================================

    deviceName: {
      type: String,
      trim: true,
      default: "Unknown device",
      maxlength: 100,
    },

    deviceType: {
      type: String,
      enum: ["mobile", "tablet", "desktop", "web", "unknown"],
      default: "unknown",
    },

    userAgent: {
      type: String,
      default: "",
      maxlength: 500,
    },

    // ==========================================
    // SESSION ACTIVITY
    // ==========================================

    lastActiveAt: {
      type: Date,
      default: Date.now,
    },

    expiresAt: {
      type: Date,
      required: true,
    },

    revokedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    autoIndex: false,
  }
);

// ==========================================
// DATABASE INDEXES
// ==========================================

sessionSchema.index(
  { sessionId: 1 },
  {
    unique: true,
    name: "sessionId_1",
  }
);

sessionSchema.index(
  { user: 1, revokedAt: 1 },
  {
    name: "user_revokedAt_1",
  }
);

const Session = mongoose.model("Session", sessionSchema);

module.exports = Session;
