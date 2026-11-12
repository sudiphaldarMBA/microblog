const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const User = require("../models/User");
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

    isPrivate: Boolean(user.isPrivate),

    createdAt: user.createdAt,
  };
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

    const token =
      jwt.sign(
        {
          userId: user._id.toString(),
          email: user.email,
        },
        process.env.JWT_SECRET,
        {
          expiresIn:
            process.env.JWT_EXPIRES_IN || "7d",
        }
      );

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
  isPrivate,
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
// ACCOUNT PRIVACY
// --------------------------------------------------------

if (isPrivate !== undefined) {
  if (typeof isPrivate !== "boolean") {
    return res.status(400).json({
      success: false,
      message: "isPrivate must be true or false",
    });
  }

  user.isPrivate = isPrivate;

  // If the account becomes public, pending approval is no
  // longer necessary. Users can follow the public account.
  if (isPrivate === false) {
    user.pendingFollowRequests = [];
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
