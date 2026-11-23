
const mongoose = require("mongoose");

const passwordResetSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },

    channel: {
      type: String,
      enum: ["email", "phone"],
      required: true,
    },

    // Store only hashed OTPs.
    otpHash: {
      type: String,
      default: null,
    },

    otpExpiresAt: {
      type: Date,
      default: null,
    },

    attempts: {
      type: Number,
      default: 0,
    },

    lastSentAt: {
      type: Date,
      default: null,
    },

    // Store only a hash of the reset authorization token.
    resetTokenHash: {
      type: String,
      default: null,
    },

    resetTokenExpiresAt: {
      type: Date,
      default: null,
    },

    usedAt: {
      type: Date,
      default: null,
    },

    purgeAt: {
      type: Date,
      required: true,
    },
  },
  {
    timestamps: true,
    autoIndex: false,
  }
);

// Automatically remove expired recovery records.
passwordResetSchema.index(
  { purgeAt: 1 },
  { expireAfterSeconds: 0, name: "password_reset_ttl" }
);

const PasswordReset = mongoose.model(
  "PasswordReset",
  passwordResetSchema
);

module.exports = PasswordReset;
