const mongoose = require("mongoose");

const User = require("../models/User");

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// Public view of a user. Never includes email or password.
function buildPublicProfile(user, viewerId) {
  const followers = Array.isArray(user.followers) ? user.followers : [];
  const following = Array.isArray(user.following) ? user.following : [];

  return {
    id: user._id,
    _id: user._id,

    displayName:
      user.displayName && user.displayName.trim()
        ? user.displayName.trim()
        : user.username,

    username: user.username,
    bio: user.bio || "",
    avatar: user.avatar || "",
    coverPhoto: user.coverPhoto || "",
    location: user.location || "",
    website: user.website || "",

    dateOfBirth: user.dateOfBirth
      ? user.dateOfBirth.toISOString().slice(0, 10)
      : "",

    followersCount: followers.length,
    followingCount: following.length,

    isFollowing: followers.some(
      (id) => String(id) === String(viewerId)
    ),

    isMe: String(user._id) === String(viewerId),

    createdAt: user.createdAt,
  };
}

// ==========================================================
// GET A USER'S PUBLIC PROFILE
// GET /api/users/:userId
// ==========================================================

exports.getUserProfile = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!isValidObjectId(userId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    const user = await User.findById(userId).select("-password");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "User retrieved successfully",
      data: { user: buildPublicProfile(user, req.userId) },
    });
  } catch (error) {
    console.error("Get User Profile Error:", error);

    return res.status(500).json({
      success: false,
      message: "Server error while retrieving user",
    });
  }
};

// ==========================================================
// FOLLOW / UNFOLLOW
// POST /api/users/:userId/follow
// ==========================================================

exports.toggleFollow = async (req, res) => {
  try {
    const { userId } = req.params;
    const myId = req.userId;

    if (!myId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!isValidObjectId(userId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (String(userId) === String(myId)) {
      return res.status(400).json({
        success: false,
        message: "You cannot follow yourself",
      });
    }

    const target = await User.findById(userId).select("followers");

    if (!target) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const alreadyFollowing = (target.followers || []).some(
      (id) => String(id) === String(myId)
    );

    if (alreadyFollowing) {
      await Promise.all([
        User.updateOne({ _id: userId }, { $pull: { followers: myId } }),
        User.updateOne({ _id: myId }, { $pull: { following: userId } }),
      ]);
    } else {
      await Promise.all([
        User.updateOne({ _id: userId }, { $addToSet: { followers: myId } }),
        User.updateOne({ _id: myId }, { $addToSet: { following: userId } }),
      ]);
    }

    const updated = await User.findById(userId).select("followers");

    return res.status(200).json({
      success: true,
      message: alreadyFollowing ? "Unfollowed" : "Followed",
      data: {
        following: !alreadyFollowing,
        followersCount: updated.followers.length,
      },
    });
  } catch (error) {
    console.error("Toggle Follow Error:", error);

    return res.status(500).json({
      success: false,
      message: "Server error while updating follow",
    });
  }
};