
const mongoose = require("mongoose");
const User = require("../models/User");

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

function sameId(a, b) {
  return String(a) === String(b);
}

function publicProfile(user, viewer) {
  const userId = String(user._id);
  const viewerId = String(viewer._id);

  const followers = (user.followers || []).map(String);
  const following = (user.following || []).map(String);
  const pending = (user.pendingFollowRequests || []).map(String);

  const isOwnProfile = userId === viewerId;
  const isFollowing = followers.includes(viewerId);
  const hasRequested =
    !isOwnProfile &&
    Boolean(user.isPrivate) &&
    pending.includes(viewerId);

  return {
    id: userId,
    displayName: user.displayName || user.username,
    username: user.username,
    bio: user.bio || "",
    avatar: user.avatar || "",
    coverPhoto: user.coverPhoto || "",
    location: user.location || "",
    website: user.website || "",
    dateOfBirth: user.dateOfBirth || "",
    createdAt: user.createdAt,
    isPrivate: Boolean(user.isPrivate),
    followersCount: followers.length,
    followingCount: following.length,
    isOwnProfile,
    isFollowing,
    hasRequested,
    followsYou: following.includes(viewerId),
    canViewPosts:
      isOwnProfile ||
      !user.isPrivate ||
      isFollowing,
  };
}


// ==========================================
// GET USER PROFILE
// ==========================================
exports.getProfile = async (req, res) => {
  try {
    const viewerId = req.userId;
    const { userId } = req.params;

    if (!viewerId) {
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

    const [profile, viewer] = await Promise.all([
      User.findById(userId)
        .select("-password -email")
        .lean(),

      User.findById(viewerId)
        .select("_id followers following pendingFollowRequests")
        .lean(),
    ]);

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (!viewer) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        user: publicProfile(profile, viewer),
      },
    });
  } catch (error) {
    console.error("Get Profile Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve profile",
    });
  }
};


// ==========================================
// FOLLOW USER OR SEND FOLLOW REQUEST
// ==========================================
exports.follow = async (req, res) => {
  try {
    const viewerId = req.userId;
    const targetId = req.params.userId;

    if (!viewerId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!isValidObjectId(targetId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (sameId(viewerId, targetId)) {
      return res.status(400).json({
        success: false,
        message: "You cannot follow yourself",
      });
    }

    const [viewer, target] = await Promise.all([
      User.findById(viewerId),
      User.findById(targetId),
    ]);

    if (!viewer || !target) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const alreadyFollowing = (target.followers || []).some(
      (id) => sameId(id, viewer._id)
    );

    if (alreadyFollowing) {
      // Remove any stale request if the relationship already exists.
      target.pendingFollowRequests.pull(viewer._id);
      await target.save();

      return res.status(200).json({
        success: true,
        status: "following",
        message: "Already following this account",
      });
    }

    if (target.isPrivate) {
      const alreadyRequested = (
        target.pendingFollowRequests || []
      ).some((id) => sameId(id, viewer._id));

      if (!alreadyRequested) {
        target.pendingFollowRequests.addToSet(viewer._id);
        await target.save();
      }

      return res.status(200).json({
        success: true,
        status: "requested",
        message: alreadyRequested
          ? "Follow request already sent"
          : "Follow request sent",
      });
    }

    // Public account: follow immediately.
    // A request left over from when the account was private is removed.
    target.pendingFollowRequests.pull(viewer._id);
    target.followers.addToSet(viewer._id);
    viewer.following.addToSet(target._id);

    await Promise.all([
      target.save(),
      viewer.save(),
    ]);

    return res.status(200).json({
      success: true,
      status: "following",
      message: "Followed successfully",
    });
  } catch (error) {
    console.error("Follow Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to follow this account",
    });
  }
};


// ==========================================
// UNFOLLOW USER OR CANCEL REQUEST
// ==========================================
exports.unfollow = async (req, res) => {
  try {
    const viewerId = req.userId;
    const targetId = req.params.userId;

    if (!viewerId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!isValidObjectId(targetId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID",
      });
    }

    if (sameId(viewerId, targetId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid follow action",
      });
    }

    const [viewer, target] = await Promise.all([
      User.findById(viewerId),
      User.findById(targetId),
    ]);

    if (!viewer || !target) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    target.followers.pull(viewer._id);
    target.pendingFollowRequests.pull(viewer._id);
    viewer.following.pull(target._id);

    await Promise.all([
      target.save(),
      viewer.save(),
    ]);

    return res.status(200).json({
      success: true,
      status: "not_following",
      message: "Follow removed or request cancelled",
    });
  } catch (error) {
    console.error("Unfollow Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to unfollow this account",
    });
  }
};


// ==========================================
// GET MY PENDING FOLLOW REQUESTS
// ==========================================
exports.getFollowRequests = async (req, res) => {
  try {
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    const user = await User.findById(userId)
      .select("isPrivate pendingFollowRequests")
      .populate({
        path: "pendingFollowRequests",
        select: "displayName username avatar bio",
      });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Only return requests belonging to the authenticated account.
    // If the account is public, no approval is required.
    const requests = user.isPrivate
      ? (user.pendingFollowRequests || [])
      : [];

    return res.status(200).json({
      success: true,
      data: {
        requests,
      },
    });
  } catch (error) {
    console.error("Get Follow Requests Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve follow requests",
    });
  }
};


// ==========================================
// ACCEPT FOLLOW REQUEST
// ==========================================
exports.acceptFollowRequest = async (req, res) => {
  try {
    const ownerId = req.userId;
    const requesterId = req.params.requesterId;

    if (!ownerId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!isValidObjectId(requesterId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid requester ID",
      });
    }

    if (sameId(ownerId, requesterId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid follow request",
      });
    }

    const [owner, requester] = await Promise.all([
      User.findById(ownerId),
      User.findById(requesterId),
    ]);

    if (!owner || !requester) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const hasRequest = (
      owner.pendingFollowRequests || []
    ).some((id) => sameId(id, requester._id));

    if (!hasRequest) {
      return res.status(404).json({
        success: false,
        message: "Follow request not found",
      });
    }

    // Remove the request and establish the relationship.
    owner.pendingFollowRequests.pull(requester._id);
    owner.followers.addToSet(requester._id);
    requester.following.addToSet(owner._id);

    await Promise.all([
      owner.save(),
      requester.save(),
    ]);

    return res.status(200).json({
      success: true,
      message: "Follow request approved",
    });
  } catch (error) {
    console.error("Accept Follow Request Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to approve follow request",
    });
  }
};


// ==========================================
// REJECT FOLLOW REQUEST
// ==========================================
exports.rejectFollowRequest = async (req, res) => {
  try {
    const ownerId = req.userId;
    const requesterId = req.params.requesterId;

    if (!ownerId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!isValidObjectId(requesterId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid requester ID",
      });
    }

    if (sameId(ownerId, requesterId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid follow request",
      });
    }

    const owner = await User.findById(ownerId);

    if (!owner) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const hasRequest = (
      owner.pendingFollowRequests || []
    ).some((id) => sameId(id, requesterId));

    if (!hasRequest) {
      return res.status(404).json({
        success: false,
        message: "Follow request not found",
      });
    }

    owner.pendingFollowRequests.pull(requesterId);
    await owner.save();

    return res.status(200).json({
      success: true,
      message: "Follow request rejected",
    });
  } catch (error) {
    console.error("Reject Follow Request Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to reject follow request",
    });
  }
};
