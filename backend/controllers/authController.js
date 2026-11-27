const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const User = require("../models/User");
const Session = require("../models/Session");
const PasswordReset = require("../models/PasswordReset");
const { sendPasswordResetOtp } = require("../config/emailService");
const { auth: firebaseAuth } = require("../config/firebaseAdmin");

// ==========================================================
// HELPER: BUILD USER RESPONSE
// ==========================================================

// Escape user input before using it inside a RegExp.
function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Case-insensitive exact match, so "M_Haldar" and "m_haldar" count
// as the same username even though the typed case is preserved.
function usernameMatcher(username) {
  return new RegExp(`^${escapeRegex(username)}$`, "i");
}

function buildUserResponse(user) {
  const displayName =
    user.displayName &&
    user.displayName.trim()
      ? user.displayName.trim()
      : user.username;

  return {
    id: user._id,

    displayName: displayName,

    username: user.username,

    accountType: user.accountType || "individual",

    email: user.email || "",

    bio: user.bio || "",

    avatar: user.avatar || "",

    coverPhoto: user.coverPhoto || "",

    location: user.location || "",

    website: user.website || "",

    // "YYYY-MM-DD" (no time zone), or "" when not set.
    dateOfBirth: user.dateOfBirth
      ? user.dateOfBirth.toISOString().slice(0, 10)
      : "",

    followersCount: Array.isArray(user.followers)
        ? user.followers.length
        : 0,

    followingCount: Array.isArray(user.following)
        ? user.following.length
        : 0,

    createdAt: user.createdAt,
  };
}

// ==========================================================
// HELPER: CREATE AUTHENTICATION SESSION
// ==========================================================

async function createAuthSession(user, req) {
  const sessionId = crypto.randomUUID();

  const token = jwt.sign(
    {
      userId: user._id.toString(),
      ...(user.email ? { email: user.email } : {}),
      sid: sessionId,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    }
  );

  const decoded = jwt.decode(token);

  
const userAgent = req.get("user-agent") || "";

const requestedDeviceType = (
  req.get("x-device-type") || ""
).toLowerCase();

const allowedDeviceTypes = [
  "mobile",
  "tablet",
  "desktop",
  "web",
  "unknown",
];

let deviceType = allowedDeviceTypes.includes(requestedDeviceType)
  ? requestedDeviceType
  : "unknown";

// Fallback to user-agent detection when no valid device type is supplied.
if (deviceType === "unknown") {
  if (/tablet|ipad/i.test(userAgent)) {
    deviceType = "tablet";
  } else if (/mobile|android|iphone/i.test(userAgent)) {
    deviceType = "mobile";
  } else if (/windows|macintosh|linux/i.test(userAgent)) {
    deviceType = "desktop";
  }
}


  await Session.create({
    sessionId,
    user: user._id,
    deviceName: req.get("x-device-name") || "Unknown device",
    deviceType,
    userAgent: userAgent.substring(0, 500),
    lastActiveAt: new Date(),
    expiresAt: new Date(decoded.exp * 1000),
  });

  return token;
}

// ==========================================================
// REGISTER
// ==========================================================

exports.register = async (req, res) => {
  try {
    const {
  displayName,
  username,
  email,
  password,
  accountType = "individual",
} = req.body;

    // --------------------------------------------------------
    // REQUIRED FIELDS
    // --------------------------------------------------------

    if (
      !displayName ||
      !username ||
      !email ||
      !password
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Display name, username, email and password are required",
      });
    }

    // --------------------------------------------------------
    // NORMALIZE
    // --------------------------------------------------------

    const trimmedDisplayName =
      displayName.toString().trim();

    // Keep the username exactly as typed (case preserved).
    const normalizedUsername =
      username.toString().trim();

    const normalizedEmail =
      email.toString().trim().toLowerCase();

      const normalizedAccountType =
  typeof accountType === "string"
    ? accountType.trim().toLowerCase()
    : "";

if (!["individual", "business"].includes(normalizedAccountType)) {
  return res.status(400).json({
    success: false,
    message: "Invalid account type.",
  });
}

    // --------------------------------------------------------
    // VALIDATE DISPLAY NAME
    // --------------------------------------------------------

    if (trimmedDisplayName.length < 3) {
      return res.status(400).json({
        success: false,
        message:
          "Display name must be at least 3 characters",
      });
    }

    if (trimmedDisplayName.length > 50) {
      return res.status(400).json({
        success: false,
        message:
          "Display name cannot exceed 50 characters",
      });
    }

    // --------------------------------------------------------
    // VALIDATE USERNAME
    // --------------------------------------------------------

    if (normalizedUsername.length < 3) {
      return res.status(400).json({
        success: false,
        message:
          "Username must be at least 3 characters",
      });
    }

    if (normalizedUsername.length > 30) {
      return res.status(400).json({
        success: false,
        message:
          "Username cannot exceed 30 characters",
      });
    }

    // --------------------------------------------------------
    // VALIDATE PASSWORD
    // --------------------------------------------------------

    if (password.toString().length < 8) {
      return res.status(400).json({
        success: false,
        message:
          "Password must be at least 8 characters",
      });
    }

    // --------------------------------------------------------
    // CHECK EMAIL
    // --------------------------------------------------------

    const existingEmail =
      await User.findOne({
        email: normalizedEmail,
      });

    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message:
          "Email is already registered",
      });
    }

    // --------------------------------------------------------
    // CHECK USERNAME
    // --------------------------------------------------------

    const existingUsername =
      await User.findOne({
        username: usernameMatcher(normalizedUsername),
      });

    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message:
          "Username is already taken",
      });
    }

    // --------------------------------------------------------
    // HASH PASSWORD
    // --------------------------------------------------------

    const hashedPassword =
      await bcrypt.hash(password, 10);

    // --------------------------------------------------------
    // CREATE USER
    // --------------------------------------------------------

    const user =
      await User.create({
        displayName:
          trimmedDisplayName,

        username:
          normalizedUsername,

        email:
          normalizedEmail,

          accountType:
          normalizedAccountType,

        password:
          hashedPassword,
      });

    // --------------------------------------------------------
    // RESPONSE
    // --------------------------------------------------------

    return res.status(201).json({
      success: true,

      message:
        "Registration successful",

      data: {
        id: user._id,

        displayName:
          user.displayName,

        username:
          user.username,

        email:
          user.email,
         
          accountType:
            user.accountType,
      },
    });
  } catch (error) {
    console.error(
      "Registration Error:",
      error
    );

    // Duplicate key protection
    if (error.code === 11000) {
      const duplicateField =
        Object.keys(error.keyPattern || {})[0];

      if (duplicateField === "email") {
        return res.status(409).json({
          success: false,
          message:
            "Email is already registered",
        });
      }

      if (duplicateField === "username") {
        return res.status(409).json({
          success: false,
          message:
            "Username is already taken",
        });
      }
    }

    return res.status(500).json({
      success: false,
      message:
        "Server error during registration",
    });
  }
};

// ==========================================================
// LOGIN
// ==========================================================

exports.login = async (req, res) => {
  try {
    const {
      email,
      password,
    } = req.body;

    // --------------------------------------------------------
    // VALIDATE
    // --------------------------------------------------------

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message:
          "Email and password are required",
      });
    }

    // --------------------------------------------------------
    // NORMALIZE EMAIL
    // --------------------------------------------------------

    const normalizedEmail =
      email.toString().trim().toLowerCase();

    // --------------------------------------------------------
    // FIND USER
    // --------------------------------------------------------

    const user = await User.findOne({
         email: normalizedEmail,
    }).select("+password");

    if (!user) {
      return res.status(401).json({
        success: false,
        message:
          "Invalid email or password",
      });
    }

    // --------------------------------------------------------
    // CHECK PASSWORD
    // --------------------------------------------------------

    const passwordMatch =
      await bcrypt.compare(
        password,
        user.password
      );

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message:
          "Invalid email or password",
      });
    }

    // --------------------------------------------------------
    // JWT SECRET CHECK
    // --------------------------------------------------------

    if (!process.env.JWT_SECRET) {
      console.error(
        "JWT_SECRET is missing from .env"
      );

      return res.status(500).json({
        success: false,
        message:
          "Server authentication configuration error",
      });
    }

    // --------------------------------------------------------
    // CREATE JWT
    // --------------------------------------------------------

    const token = await createAuthSession(user, req);

    // --------------------------------------------------------
    // RESPONSE
    // --------------------------------------------------------

    return res.status(200).json({
      success: true,

      message:
        "Login successful",

      data: {
        token: token,

        user:
          buildUserResponse(user),
      },
    });
  } catch (error) {
    console.error(
      "Login Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message:
        "Server error during login",
    });
  }
};

// ==========================================================
// FIREBASE LOGIN (GOOGLE + PHONE OTP)
// ==========================================================

exports.firebaseLogin = async (req, res) => {
  try {
    const {
  idToken,
  displayName,
  username,
  accountType = "individual",
} = req.body;

    // --------------------------------------------------------
    // VALIDATE FIREBASE TOKEN
    // --------------------------------------------------------

    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({
        success: false,
        message: "Firebase ID token is required",
      });
    }

    if (!process.env.JWT_SECRET) {
      console.error("JWT_SECRET is missing from .env");

      return res.status(500).json({
        success: false,
        message: "Server authentication configuration error",
      });
    }

    // Verify the token with Firebase Admin.
    const decodedToken = await firebaseAuth.verifyIdToken(idToken);

    const firebaseUid = decodedToken.uid;

    const signInProvider =
      decodedToken.firebase?.sign_in_provider;

    // Accept only Google and phone authentication.
    let provider;

    if (signInProvider === "google.com") {
      provider = "google";
    } else if (signInProvider === "phone") {
      provider = "phone";
    } else {
      return res.status(400).json({
        success: false,
        message: "Unsupported authentication provider",
      });
    }

    // Google accounts must have a verified email.
    const verifiedEmail =
      provider === "google" &&
      decodedToken.email_verified === true
        ? decodedToken.email?.trim().toLowerCase()
        : undefined;

    if (provider === "google" && !verifiedEmail) {
      return res.status(403).json({
        success: false,
        message: "Please verify your Google email address",
      });
    }

    // Firebase verifies the phone number during phone sign-in.
    const verifiedPhone =
      provider === "phone"
        ? decodedToken.phone_number
        : undefined;

    if (provider === "phone" && !verifiedPhone) {
      return res.status(403).json({
        success: false,
        message: "Verified phone number is missing",
      });
    }

    // --------------------------------------------------------
    // FIND EXISTING FIREBASE ACCOUNT
    // --------------------------------------------------------

    let user = await User.findOne({
      firebaseUid: firebaseUid,
    });

    // --------------------------------------------------------
    // EXISTING FIREBASE USER
    // --------------------------------------------------------

    if (user) {
      // Record the provider used by this Firebase identity.
      if (!Array.isArray(user.authProviders)) {
        user.authProviders = [];
      }

      if (!user.authProviders.includes(provider)) {
        user.authProviders.push(provider);
        await user.save();
      }

      const token = jwt.sign(
        {
          userId: user._id.toString(),
          ...(user.email ? { email: user.email } : {}),
        },
        process.env.JWT_SECRET,
        {
          expiresIn: process.env.JWT_EXPIRES_IN || "7d",
        }
      );

      return res.status(200).json({
        success: true,
        message: "Login successful",
        data: {
          token,
          user: buildUserResponse(user),
        },
      });
    }

    // --------------------------------------------------------
    // PREVENT AUTOMATIC ACCOUNT LINKING
    // --------------------------------------------------------

    if (verifiedEmail) {
      const existingEmail = await User.findOne({
        email: verifiedEmail,
      });

      if (existingEmail) {
        return res.status(409).json({
          success: false,
          message:
            "An account with this email already exists. Please sign in using your existing login method.",
          code: "ACCOUNT_ALREADY_EXISTS",
        });
      }
    }

    if (verifiedPhone) {
      const existingPhone = await User.findOne({
        phoneNumber: verifiedPhone,
      });

      if (existingPhone) {
        return res.status(409).json({
          success: false,
          message:
            "This phone number is already associated with another account.",
          code: "PHONE_ALREADY_REGISTERED",
        });
      }
    }

    // --------------------------------------------------------
    // NEW USER: PROFILE SETUP REQUIRED
    // --------------------------------------------------------

    const trimmedDisplayName =
      typeof displayName === "string"
        ? displayName.trim()
        : "";

    const normalizedUsername =
      typeof username === "string"
        ? username.trim()
        : "";

    // Return profile information so Flutter can open
    // the username and display-name setup screen.
    if (!trimmedDisplayName || !normalizedUsername) {
      return res.status(200).json({
        success: true,
        needsProfileSetup: true,
        message: "Please complete your MicroBlog profile",
        data: {
          displayName:
            decodedToken.name || "",
          email: verifiedEmail || "",
          phoneNumber: verifiedPhone || "",
          avatar: decodedToken.picture || "",
          provider,
        },
      });
    }

    // --------------------------------------------------------
// VALIDATE ACCOUNT TYPE FOR NEW FIREBASE USERS
// --------------------------------------------------------

const normalizedAccountType =
  typeof accountType === "string"
    ? accountType.trim().toLowerCase()
    : "";

if (!["individual", "business"].includes(normalizedAccountType)) {
  return res.status(400).json({
    success: false,
    message: "Invalid account type. Choose individual or business.",
  });
}

    // --------------------------------------------------------
    // VALIDATE DISPLAY NAME
    // --------------------------------------------------------

    if (
      trimmedDisplayName.length < 3 ||
      trimmedDisplayName.length > 50
    ) {
      return res.status(400).json({
        success: false,
        message: "Display name must be between 3 and 50 characters",
      });
    }

    // --------------------------------------------------------
    // VALIDATE USERNAME
    // --------------------------------------------------------

    if (
      normalizedUsername.length < 3 ||
      normalizedUsername.length > 30
    ) {
      return res.status(400).json({
        success: false,
        message: "Username must be between 3 and 30 characters",
      });
    }

    const existingUsername = await User.findOne({
      username: usernameMatcher(normalizedUsername),
    });

    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "Username is already taken",
        code: "USERNAME_ALREADY_TAKEN",
      });
    }

    // --------------------------------------------------------
    // CREATE FIREBASE USER
    // --------------------------------------------------------

    user = await User.create({
  displayName: trimmedDisplayName,
  username: normalizedUsername,

  accountType: normalizedAccountType,

  ...(verifiedEmail ? { email: verifiedEmail } : {}),

  firebaseUid: firebaseUid,

  ...(verifiedPhone
    ? { phoneNumber: verifiedPhone }
    : {}),

  authProviders: [provider],

  avatar: decodedToken.picture || "",
});

    // --------------------------------------------------------
    // CREATE MICROBLOG JWT
    // --------------------------------------------------------

    const token = await createAuthSession(user, req);

    return res.status(201).json({
      success: true,
      message: "Account created successfully",
      data: {
        token,
        user: buildUserResponse(user),
      },
    });

  } catch (error) {
    console.error("Firebase Login Error:", error);

    if (
      error.code === "auth/argument-error" ||
      error.code === "auth/id-token-expired" ||
      error.code === "auth/invalid-id-token"
    ) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired Firebase token",
      });
    }

    if (error.code === 11000) {
      const duplicateField =
        Object.keys(error.keyPattern || {})[0];

      const messages = {
        email: "Email is already registered",
        username: "Username is already taken",
        firebaseUid: "This Firebase account is already registered",
        phoneNumber: "Phone number is already registered",
      };

      return res.status(409).json({
        success: false,
        message:
          messages[duplicateField] ||
          "An account with these details already exists",
      });
    }

    return res.status(500).json({
      success: false,
      message: "Server error during Firebase authentication",
    });
  }
};

// ==========================================================
// GET CURRENT USER
// ==========================================================

exports.getMe = async (req, res) => {
  try {
    const user =
      await User.findById(
        req.userId
      ).select("-password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message:
          "User not found",
      });
    }

    return res.status(200).json({
      success: true,

      message:
        "User information retrieved successfully",

      data: {
        user:
          buildUserResponse(user),
      },
    });
  } catch (error) {
    console.error(
      "Get Me Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message:
        "Server error while retrieving user",
    });
  }
};

// ==========================================================
// UPDATE PROFILE
// ==========================================================

exports.updateProfile = async (req, res) => {
  try {
    const {
  displayName,
  username,
  email,
  bio,
  avatar,
  coverPhoto,
  location,
  website,
  dateOfBirth,
} = req.body;
    console.log('DOB RECEIVED BY BACKEND:', req.body.dateOfBirth);
    // --------------------------------------------------------
    // FIND CURRENT USER
    // --------------------------------------------------------

    const user =
      await User.findById(
        req.userId
      );

    if (!user) {
      return res.status(404).json({
        success: false,
        message:
          "User not found",
      });
    }

    // --------------------------------------------------------
    // DISPLAY NAME
    // --------------------------------------------------------

    if (displayName !== undefined) {
      const trimmedDisplayName =
        displayName
          .toString()
          .trim();

      if (trimmedDisplayName.length < 3) {
        return res.status(400).json({
          success: false,
          message:
            "Display name must be at least 3 characters",
        });
      }

      if (trimmedDisplayName.length > 50) {
        return res.status(400).json({
          success: false,
          message:
            "Display name cannot exceed 50 characters",
        });
      }

      user.displayName =
        trimmedDisplayName;
    }

    // --------------------------------------------------------
    // USERNAME
    // --------------------------------------------------------

    if (username !== undefined) {
      const normalizedUsername =
        username
          .toString()
          .trim();

      if (normalizedUsername.length < 3) {
        return res.status(400).json({
          success: false,
          message:
            "Username must be at least 3 characters",
        });
      }

      if (normalizedUsername.length > 30) {
        return res.status(400).json({
          success: false,
          message:
            "Username cannot exceed 30 characters",
        });
      }

      const existingUser =
        await User.findOne({
          username:
            usernameMatcher(normalizedUsername),

          _id: {
            $ne: req.userId,
          },
        });

      if (existingUser) {
        return res.status(409).json({
          success: false,
          message:
            "Username is already taken",
        });
      }

      user.username =
        normalizedUsername;
    }

    // --------------------------------------------------------
    // EMAIL
    // --------------------------------------------------------

    if (email !== undefined) {
      const normalizedEmail =
        email
          .toString()
          .trim()
          .toLowerCase();

      if (!normalizedEmail) {
        return res.status(400).json({
          success: false,
          message:
            "Email cannot be empty",
        });
      }

      const existingUser =
        await User.findOne({
          email:
            normalizedEmail,

          _id: {
            $ne: req.userId,
          },
        });

      if (existingUser) {
        return res.status(409).json({
          success: false,
          message:
            "Email is already registered",
        });
      }

      user.email =
        normalizedEmail;
    }

    // --------------------------------------------------------
    // BIO
    // --------------------------------------------------------

    if (bio !== undefined) {
      const bioText =
        bio
          .toString()
          .trim();

      if (bioText.length > 160) {
        return res.status(400).json({
          success: false,
          message:
            "Bio cannot exceed 160 characters",
        });
      }

      user.bio =
        bioText;
    }

    // --------------------------------------------------------
    // AVATAR
    // --------------------------------------------------------

    if (avatar !== undefined) {
      user.avatar =
        avatar
          .toString()
          .trim();
    }

    // --------------------------------------------------------
    // COVER PHOTO
    // --------------------------------------------------------

    if (coverPhoto !== undefined) {
      user.coverPhoto =
        coverPhoto
          .toString()
          .trim();
    }

    // --------------------------------------------------------
    // LOCATION
    // --------------------------------------------------------

    if (location !== undefined) {
      const locationText =
        location
          .toString()
          .trim();

      if (locationText.length > 100) {
        return res.status(400).json({
          success: false,
          message:
            "Location cannot exceed 100 characters",
        });
      }

      user.location =
        locationText;
    }

    // --------------------------------------------------------
    // WEBSITE
    // --------------------------------------------------------

    if (website !== undefined) {
      const websiteText =
        website
          .toString()
          .trim();

      if (websiteText.length > 200) {
        return res.status(400).json({
          success: false,
          message:
            "Website cannot exceed 200 characters",
        });
      }

      user.website =
        websiteText;
    }

    // --------------------------------------------------------
    // DATE OF BIRTH ("YYYY-MM-DD", or "" to clear)
    // --------------------------------------------------------

    if (dateOfBirth !== undefined) {
      const dobText =
        dateOfBirth === null
          ? ""
          : dateOfBirth
              .toString()
              .trim();

      if (dobText === "") {
        user.dateOfBirth = null;
      } else {
        const dob = /^\d{4}-\d{2}-\d{2}$/.test(dobText)
          ? new Date(`${dobText}T00:00:00.000Z`)
          : new Date(dobText);

        if (Number.isNaN(dob.getTime())) {
          return res.status(400).json({
            success: false,
            message:
              "Invalid date of birth",
          });
        }

        if (
          dob > new Date() ||
          dob.getUTCFullYear() < 1900
        ) {
          return res.status(400).json({
            success: false,
            message:
              "Date of birth is out of range",
          });
        }

        user.dateOfBirth = dob;
        console.log('DOB BEFORE SAVE:', user.dateOfBirth);
      }
    }

    // --------------------------------------------------------
    // SAVE
    // --------------------------------------------------------

    await user.save();
    console.log('DOB AFTER SAVE:', user.dateOfBirth);
console.log(
  'DOB AFTER SAVE ISO:',
  user.dateOfBirth instanceof Date && !Number.isNaN(user.dateOfBirth.getTime())
    ? user.dateOfBirth.toISOString()
    : null
);

    // --------------------------------------------------------
    // RESPONSE
    // --------------------------------------------------------

    return res.status(200).json({
      success: true,

      message:
        "Profile updated successfully",

      data: {
        user:
          buildUserResponse(user),
      },
    });
  } catch (error) {
    console.error(
      "Update Profile Error:",
      error
    );

    if (error.code === 11000) {
      const duplicateField =
        Object.keys(error.keyPattern || {})[0];

      if (duplicateField === "email") {
        return res.status(409).json({
          success: false,
          message:
            "Email is already registered",
        });
      }

      if (duplicateField === "username") {
        return res.status(409).json({
          success: false,
          message:
            "Username is already taken",
        });
      }
    }

    return res.status(500).json({
      success: false,
      message:
        "Server error while updating profile",
    });
  }
};


 
// ==========================================================
// GET ACTIVE LOGIN SESSIONS
// ==========================================================

exports.getSessions = async (req, res) => {
  try {
    const sessions = await Session.find({
      user: req.userId,
      revokedAt: null,
      expiresAt: { $gt: new Date() },
    })
      .sort({ lastActiveAt: -1 })
      .select(
        "sessionId deviceName deviceType lastActiveAt createdAt expiresAt"
      )
      .lean();

    return res.status(200).json({
      success: true,
      data: {
        sessions: sessions.map((session) => ({
          ...session,
          isCurrent: session.sessionId === req.sessionId,
        })),
      },
    });
  } catch (error) {
    console.error("Get Sessions Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve login sessions",
    });
  }
};

// ==========================================================
// REVOKE ONE LOGIN SESSION
// ==========================================================

exports.revokeSession = async (req, res) => {
  try {
    const { sessionId } = req.params;

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        message: "Session ID is required",
      });
    }

    const session = await Session.findOneAndUpdate(
      {
        sessionId,
        user: req.userId,
        revokedAt: null,
      },
      {
        $set: {
          revokedAt: new Date(),
        },
      },
      {
        new: true,
      }
    );

    if (!session) {
      return res.status(404).json({
        success: false,
        message: "Active session not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Login session revoked successfully",
    });
  } catch (error) {
    console.error("Revoke Session Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to revoke login session",
    });
  }
};

// ==========================================================
// LOG OUT OF ALL OTHER DEVICES
// ==========================================================

exports.revokeOtherSessions = async (req, res) => {
  try {
    if (!req.sessionId) {
      return res.status(409).json({
        success: false,
        message:
          "Please sign in again before managing your other sessions",
        code: "SESSION_ID_REQUIRED",
      });
    }

    const result = await Session.updateMany(
      {
        user: req.userId,
        sessionId: { $ne: req.sessionId },
        revokedAt: null,
      },
      {
        $set: {
          revokedAt: new Date(),
        },
      }
    );

    return res.status(200).json({
      success: true,
      message: "Other login sessions revoked successfully",
      data: {
        revokedCount: result.modifiedCount,
      },
    });
  } catch (error) {
    console.error("Revoke Other Sessions Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to revoke other login sessions",
    });
  }
};


// ==========================================================
// CHANGE PASSWORD
// ==========================================================

exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Current password and new password are required",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "New password must be at least 8 characters",
      });
    }

    if (newPassword.length > 128) {
      return res.status(400).json({
        success: false,
        message: "New password is too long",
      });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: "New password must be different from current password",
      });
    }

    const user = await User.findById(req.userId).select("+password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (!user.password) {
      return res.status(400).json({
        success: false,
        message: "This account does not have a password. Use the password setup option instead.",
      });
    }

    const passwordMatch = await bcrypt.compare(
      currentPassword,
      user.password
    );

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: "Current password is incorrect",
      });
    }

    user.password = await bcrypt.hash(newPassword, 12);
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Password changed successfully",
    });
  } catch (error) {
    console.error("Change Password Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to change password",
    });
  }
};


// ==========================================================
// FORGOT PASSWORD — EMAIL OTP
// ==========================================================

const hashPasswordResetValue = (value) => {
  return crypto
    .createHmac("sha256", process.env.JWT_SECRET)
    .update(value)
    .digest("hex");
};

exports.requestPasswordReset = async (req, res) => {
  try {
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    const genericMessage =
      "If an eligible account exists, a verification code will be sent.";

    const user = await User.findOne({
      email,
      password: { $exists: true, $ne: null },
    });

    // Do not reveal whether an account exists.
    if (!user) {
      return res.status(200).json({
        success: true,
        message: genericMessage,
      });
    }

    let resetRecord = await PasswordReset.findOne({
      user: user._id,
    });

    const now = new Date();

    // Prevent repeated OTP requests within 60 seconds.
    if (
      resetRecord?.lastSentAt &&
      now.getTime() - resetRecord.lastSentAt.getTime() < 60000
    ) {
      return res.status(200).json({
        success: true,
        message: genericMessage,
      });
    }

    // Generate a cryptographically secure six-digit OTP.
    const otp = crypto.randomInt(100000, 1000000).toString();

    const otpHash = hashPasswordResetValue(otp);

    if (!resetRecord) {
      resetRecord = new PasswordReset({
        user: user._id,
        channel: "email",
      });
    }

    resetRecord.channel = "email";
    resetRecord.otpHash = otpHash;
    resetRecord.otpExpiresAt = new Date(
      now.getTime() + 10 * 60 * 1000
    );
    resetRecord.attempts = 0;
    resetRecord.lastSentAt = now;
    resetRecord.resetTokenHash = null;
    resetRecord.resetTokenExpiresAt = null;
    resetRecord.usedAt = null;
    resetRecord.purgeAt = new Date(
      now.getTime() + 24 * 60 * 60 * 1000
    );

    await resetRecord.save();

    try {
      await sendPasswordResetOtp(email, otp);
    } catch (emailError) {
      console.error(
        "Password reset email delivery failed:",
        emailError.message
      );

      // Keep the public response generic to avoid
      // revealing whether the account exists.
    }

    return res.status(200).json({
      success: true,
      message: genericMessage,
    });
  } catch (error) {
    console.error("Request password reset error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to process your request",
    });
  }
};

// ==========================================================
// VERIFY PASSWORD RESET EMAIL OTP
// ==========================================================

exports.verifyPasswordResetOtp = async (req, res) => {
  try {
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();

    const otp = String(req.body.otp || "").trim();

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP are required",
      });
    }

    if (!/^\d{6}$/.test(otp)) {
      return res.status(400).json({
        success: false,
        message: "Wrong OTP, try again.",
      });
    }

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Wrong OTP, try again.",
      });
    }

    const resetRecord = await PasswordReset.findOne({
      user: user._id,
      channel: "email",
      usedAt: null,
    });

    if (
      !resetRecord ||
      !resetRecord.otpHash ||
      !resetRecord.otpExpiresAt ||
      resetRecord.otpExpiresAt.getTime() <= Date.now()
    ) {
      return res.status(400).json({
        success: false,
        message: "Verification code has expired. Request a new one.",
      });
    }

    if (resetRecord.attempts >= 5) {
      return res.status(429).json({
        success: false,
        message: "Too many incorrect attempts. Request a new code.",
      });
    }

    const submittedHash = hashPasswordResetValue(otp);

    const storedHashBuffer = Buffer.from(
      resetRecord.otpHash,
      "hex"
    );

    const submittedHashBuffer = Buffer.from(
      submittedHash,
      "hex"
    );

    const isValid =
      storedHashBuffer.length === submittedHashBuffer.length &&
      crypto.timingSafeEqual(
        storedHashBuffer,
        submittedHashBuffer
      );

    if (!isValid) {
      resetRecord.attempts += 1;
      await resetRecord.save();

      return res.status(400).json({
        success: false,
        message: "Wrong OTP, try again.",
      });
    }

    // Generate a separate, high-entropy reset token.
    const resetToken = crypto.randomBytes(32).toString("hex");

    resetRecord.otpHash = null;
    resetRecord.otpExpiresAt = null;
    resetRecord.resetTokenHash =
      hashPasswordResetValue(resetToken);
    resetRecord.resetTokenExpiresAt = new Date(
      Date.now() + 10 * 60 * 1000
    );
    resetRecord.attempts = 0;
    resetRecord.purgeAt = new Date(
      Date.now() + 24 * 60 * 60 * 1000
    );

    await resetRecord.save();

    return res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      resetToken,
    });
  } catch (error) {
    console.error("Verify password reset OTP error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to verify the code",
    });
  }
};


// ==========================================================
// RESET PASSWORD
// ==========================================================

exports.resetPassword = async (req, res) => {
  try {
    const resetToken = String(req.body.resetToken || "").trim();
    const newPassword = req.body.newPassword;

    if (!resetToken || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Reset token and new password are required",
      });
    }

    if (
      typeof newPassword !== "string" ||
      newPassword.length < 8
    ) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 8 characters long",
      });
    }

    if (newPassword.length > 128) {
      return res.status(400).json({
        success: false,
        message: "Password cannot exceed 128 characters",
      });
    }

    const tokenHash = hashPasswordResetValue(resetToken);
    const now = new Date();

    // Find a valid, unused reset token.
    const resetRecord = await PasswordReset.findOne({
      resetTokenHash: tokenHash,
      resetTokenExpiresAt: { $gt: now },
      usedAt: null,
    });

    if (!resetRecord) {
      return res.status(400).json({
        success: false,
        message: "Reset link is invalid or has expired. Please verify again.",
      });
    }

    const user = await User.findById(resetRecord.user);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found",
      });
    }

    // Atomically consume the token to prevent reuse.
    const consumedToken = await PasswordReset.findOneAndUpdate(
      {
        _id: resetRecord._id,
        resetTokenHash: tokenHash,
        resetTokenExpiresAt: { $gt: now },
        usedAt: null,
      },
      {
        $set: {
          usedAt: now,
        },
        $unset: {
          resetTokenHash: 1,
          resetTokenExpiresAt: 1,
          otpHash: 1,
          otpExpiresAt: 1,
        },
      },
      { new: true }
    );

    if (!consumedToken) {
      return res.status(400).json({
        success: false,
        message: "Reset link is invalid or has expired. Please verify again.",
      });
    }

    // Save the new password.
    user.password = await bcrypt.hash(newPassword, 12);

    // Allow Firebase phone users to also use password login.
    if (!Array.isArray(user.authProviders)) {
      user.authProviders = [];
    }

    if (!user.authProviders.includes("password")) {
      user.authProviders.push("password");
    }

    await user.save();

    // Revoke all existing sessions for this account.
    await Session.updateMany(
      {
        user: user._id,
        revokedAt: null,
      },
      {
        $set: {
          revokedAt: new Date(),
        },
      }
    );

    return res.status(200).json({
      success: true,
      message: "Password reset successfully. Please log in again.",
    });
  } catch (error) {
    console.error("Reset password error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to reset password",
    });
  }
};


// ==========================================================
// VERIFY PHONE IDENTITY FOR PASSWORD RECOVERY
// ==========================================================

exports.verifyPasswordResetPhone = async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({
        success: false,
        message: "Firebase ID token is required",
      });
    }

    // Verify the Firebase token.
    const decodedToken = await firebaseAuth.verifyIdToken(idToken);

    // Only accept Firebase phone authentication.
    if (decodedToken.firebase?.sign_in_provider !== "phone") {
      return res.status(403).json({
        success: false,
        message: "Phone verification is required",
      });
    }

    const firebaseUid = decodedToken.uid;
    const verifiedPhone = decodedToken.phone_number;

    if (!verifiedPhone) {
      return res.status(403).json({
        success: false,
        message: "Verified phone number is missing",
      });
    }

    // Find the existing MicroBlog account using both
    // the Firebase identity and verified phone number.
    const user = await User.findOne({
      firebaseUid,
      phoneNumber: verifiedPhone,
      authProviders: "phone",
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "No eligible MicroBlog account was found for this phone number",
      });
    }

    const now = new Date();

    // Create a one-time password reset token.
    const resetToken = crypto.randomBytes(32).toString("hex");

    const resetTokenHash = hashPasswordResetValue(resetToken);

    let resetRecord = await PasswordReset.findOne({
      user: user._id,
    });

    if (!resetRecord) {
      resetRecord = new PasswordReset({
        user: user._id,
        channel: "phone",
      });
    }

    resetRecord.channel = "phone";
    resetRecord.otpHash = null;
    resetRecord.otpExpiresAt = null;
    resetRecord.attempts = 0;
    resetRecord.resetTokenHash = resetTokenHash;
    resetRecord.resetTokenExpiresAt = new Date(
      now.getTime() + 10 * 60 * 1000
    );
    resetRecord.usedAt = null;
    resetRecord.purgeAt = new Date(
      now.getTime() + 24 * 60 * 60 * 1000
    );

    await resetRecord.save();

    // Do not create a MicroBlog login session here.
    return res.status(200).json({
      success: true,
      message: "Phone verified successfully",
      resetToken,
    });
  } catch (error) {
    console.error("Phone password recovery error:", error);

    if (
      error.code === "auth/argument-error" ||
      error.code === "auth/id-token-expired" ||
      error.code === "auth/invalid-id-token"
    ) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired Firebase verification",
      });
    }

    return res.status(500).json({
      success: false,
      message: "Unable to verify phone number",
    });
  }
};

// ==========================================================
// ACCOUNT VERIFICATION — SUBMIT SELFIE
// ==========================================================

exports.submitVerificationSelfie = async (req, res) => {
  try {
    const selfie = req.body.selfie;

    if (!selfie || typeof selfie !== "string") {
      return res.status(400).json({
        success: false,
        message: "Selfie is required",
      });
    }

    // Accept only supported image formats.
    const selfiePattern =
      /^data:image\/(jpeg|jpg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$/;

    if (!selfiePattern.test(selfie)) {
      return res.status(400).json({
        success: false,
        message: "Invalid selfie image format",
      });
    }

    // Limit the encoded image size to approximately 5 MB.
    if (selfie.length > 7 * 1024 * 1024) {
      return res.status(413).json({
        success: false,
        message: "Selfie image is too large. Please upload a smaller image.",
      });
    }

    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (user.verificationStatus === "verified") {
      return res.status(409).json({
        success: false,
        message: "Your account is already verified",
        verificationStatus: "verified",
      });
    }

    if (user.verificationStatus === "pending") {
      return res.status(409).json({
        success: false,
        message: "Your verification application is already under review",
        verificationStatus: "pending",
      });
    }

    // Store the selfie and submit for manual review.
    user.verificationSelfie = selfie;
    user.verificationStatus = "pending";
    user.verificationSubmittedAt = new Date();
    user.verificationReviewedAt = null;
    user.verificationRejectionReason = "";

    await user.save();

    return res.status(200).json({
      success: true,
      message: "Verification application submitted successfully",
      verificationStatus: "pending",
      submittedAt: user.verificationSubmittedAt,
    });
  } catch (error) {
    console.error("Submit verification selfie error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to submit verification application",
    });
  }
};


// ==========================================================
// ACCOUNT VERIFICATION — GET STATUS
// ==========================================================

exports.getVerificationStatus = async (req, res) => {
  try {
    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      verificationStatus:
        user.verificationStatus || "not_submitted",
      submittedAt: user.verificationSubmittedAt,
      reviewedAt: user.verificationReviewedAt,
      rejectionReason:
        user.verificationRejectionReason || "",
    });
  } catch (error) {
    console.error("Get verification status error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve verification status",
    });
  }
};
