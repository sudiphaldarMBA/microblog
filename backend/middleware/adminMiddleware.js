
const adminMiddleware = (req, res, next) => {
  // Read the authorized admin MongoDB user IDs.
  const adminIds = (process.env.ADMIN_USER_IDS || "")
    .split(",")
    .map((id) => id.trim())
    .filter(Boolean);

  // Fail closed if admin access is not configured.
  if (adminIds.length === 0) {
    return res.status(403).json({
      success: false,
      message: "Admin access is not configured.",
    });
  }

  // authMiddleware must run before this middleware.
  const userId = String(req.userId || "");

  if (!userId || !adminIds.includes(userId)) {
    return res.status(403).json({
      success: false,
      message: "Admin access denied.",
    });
  }

  next();
};

module.exports = adminMiddleware;
