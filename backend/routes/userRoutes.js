const express = require("express");

const userController = require("../controllers/userController");

// Uses the same auth middleware as your post routes. The lookup
// below works whichever way authMiddleware exports its function.
const authModule = require("../middleware/authMiddleware");

const auth =
  typeof authModule === "function"
    ? authModule
    : authModule.authMiddleware ||
      authModule.protect ||
      authModule.verifyToken ||
      authModule.authenticate ||
      authModule.auth;

if (typeof auth !== "function") {
  throw new Error(
    "userRoutes: could not find the auth middleware function in ../middleware/authMiddleware"
  );
}

const router = express.Router();

router.get("/:userId", auth, userController.getUserProfile);

router.post("/:userId/follow", auth, userController.toggleFollow);

module.exports = router;