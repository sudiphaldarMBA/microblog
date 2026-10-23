const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    // ==========================================
    // DISPLAY NAME
    // ==========================================

    displayName: {
      type: String,
      trim: true,
      minlength: 3,
      maxlength: 50,
      default: "",
    },

    // ==========================================
    // USERNAME / HANDLE
    // ==========================================

    username: {
      type: String,
      required: true,
      trim: true,
      minlength: 3,
      maxlength: 30,
      lowercase: true,
      unique: true,
    },

    // ==========================================
    // EMAIL
    // ==========================================

    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },

    // ==========================================
    // PASSWORD
    // ==========================================

    password: {
      type: String,
      required: true,
      minlength: 8,
    },

    // ==========================================
    // PROFILE BIO
    // ==========================================

    bio: {
      type: String,
      trim: true,
      maxlength: 160,
      default: "",
    },

    // ==========================================
    // PROFILE PHOTO
    // ==========================================

    avatar: {
      type: String,
      trim: true,
      default: "",
    },

    // ==========================================
    // COVER PHOTO
    // ==========================================

    coverPhoto: {
      type: String,
      trim: true,
      default: "",
    },

    // ==========================================
    // LOCATION
    // ==========================================

    location: {
      type: String,
      trim: true,
      maxlength: 100,
      default: "",
    },

    // ==========================================
    // WEBSITE
    // ==========================================

    website: {
      type: String,
      trim: true,
      maxlength: 200,
      default: "",
    },

    // ==========================================
    // FOLLOWERS
    // ==========================================

    followers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    // ==========================================
    // FOLLOWING
    // ==========================================

    following: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
  },
  {
    timestamps: true,
  }
);

const User =
  mongoose.model(
    "User",
    userSchema
  );

module.exports = User;