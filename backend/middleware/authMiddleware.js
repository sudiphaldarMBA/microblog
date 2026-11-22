
const jwt = require("jsonwebtoken");

const User = require("../models/User");
const Session = require("../models/Session");

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: "Authorization token is required",
      });
    }

    const parts = authHeader.split(" ");

    if (parts.length !== 2 || parts[0] !== "Bearer") {
      return res.status(401).json({
        success: false,
        message: "Invalid authorization format",
      });
    }

    const token = parts[1];

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET
    );

    if (!decoded.userId) {
      return res.status(401).json({
        success: false,
        message: "Invalid authentication token",
      });
    }

    // ==========================================
    // CHECK USER ACCOUNT
    // ==========================================

    const user = await User.findById(decoded.userId)
      .select("accountStatus");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User account not found",
      });
    }

    if (
      user.accountStatus &&
      user.accountStatus !== "active"
    ) {
      return res.status(403).json({
        success: false,
        message: "This account is not active",
        code: "ACCOUNT_INACTIVE",
      });
    }

    // ==========================================
    // CHECK SESSION (NEW TOKENS)
    // ==========================================

    if (decoded.sid) {
      const session = await Session.findOne({
        sessionId: decoded.sid,
        user: decoded.userId,
        revokedAt: null,
        expiresAt: { $gt: new Date() },
      }).select("_id");

      if (!session) {
        return res.status(401).json({
          success: false,
          message: "Your login session has expired or been revoked",
          code: "SESSION_INVALID",
        });
      }
    }

    // Legacy tokens without sid remain accepted
    // until they expire, provided the account is active.

    req.userId = decoded.userId;
    req.sessionId = decoded.sid || null;

    next();
  } catch (error) {
    console.error(
      "Auth Middleware Error:",
      error.message
    );

    return res.status(401).json({
      success: false,
      message: "Invalid or expired token",
    });
  }
};

module.exports = authMiddleware;
