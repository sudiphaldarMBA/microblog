
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
      unique: true,
    },

    // ==========================================
    // EMAIL
    // Required for password accounts.
    // Optional for Firebase phone accounts.
    // ==========================================

    email: {
      type: String,
      required: function () {
        return !this.firebaseUid;
      },
      trim: true,
      lowercase: true,
      set: (value) => {
        if (value == null || value.trim() === "") {
          return undefined;
        }

        return value.trim().toLowerCase();
      },
    },

    // ==========================================
    // PASSWORD
    // Required for traditional accounts only.
    // ==========================================

    password: {
      type: String,
      required: function () {
        return !this.firebaseUid;
      },
      minlength: 8,
      select: false,
    },

    // ==========================================
    // FIREBASE AUTHENTICATION
    // ==========================================

    firebaseUid: {
      type: String,
      trim: true,
      default: undefined,
    },

    phoneNumber: {
      type: String,
      trim: true,
      default: undefined,
    },

    authProviders: {
      type: [
        {
          type: String,
          enum: ["password", "google", "phone"],
        },
      ],
      default: ["password"],
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
    // DATE OF BIRTH
    // ==========================================

    dateOfBirth: {
      type: Date,
      default: null,
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

    // ==========================================
    // PRIVACY
    // ==========================================

    isPrivate: {
      type: Boolean,
      default: false,
    },

    pendingFollowRequests: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
  },
  {
    timestamps: true,

    // Indexes will be managed explicitly during migration.
    autoIndex: false,
  }
);

// ==========================================
// DATABASE INDEXES
// ==========================================

// Email must be unique when it exists.
// Missing email is allowed for phone-only accounts.
userSchema.index(
  { email: 1 },
  {
    unique: true,
    name: "email_1",
    partialFilterExpression: {
      email: {
        $type: "string",
        $gt: "",
      },
    },
  }
);

// Firebase UID must be unique when it exists.
userSchema.index(
  { firebaseUid: 1 },
  {
    unique: true,
    name: "firebaseUid_1",
    partialFilterExpression: {
      firebaseUid: {
        $type: "string",
        $gt: "",
      },
    },
  }
);

// Phone number must be unique when it exists.
userSchema.index(
  { phoneNumber: 1 },
  {
    unique: true,
    name: "phoneNumber_1",
    partialFilterExpression: {
      phoneNumber: {
        $type: "string",
        $gt: "",
      },
    },
  }
);

const User = mongoose.model("User", userSchema);

module.exports = User;