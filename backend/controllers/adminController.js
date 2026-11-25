
const mongoose = require("mongoose");
const User = require("../models/User");

// ==========================================
// GET PENDING VERIFICATION REQUESTS
// ==========================================

exports.getPendingVerifications = async (req, res) => {
  try {
    const users = await User.find({
      verificationStatus: "pending",
    })
      .select(
        "_id displayName username email verificationStatus verificationSubmittedAt"
      )
      .sort({ verificationSubmittedAt: 1 });

    return res.status(200).json({
      success: true,
      count: users.length,
      requests: users,
    });
  } catch (error) {
    console.error("Get pending verifications error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve verification requests.",
    });
  }
};

// ==========================================
// GET VERIFICATION SELFIE
// ==========================================

exports.getVerificationSelfie = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID.",
      });
    }

    const user = await User.findOne({
      _id: userId,
      verificationStatus: "pending",
    }).select("+verificationSelfie");

    if (!user || !user.verificationSelfie) {
      return res.status(404).json({
        success: false,
        message: "Pending verification selfie not found.",
      });
    }

    return res.status(200).json({
      success: true,
      userId: user._id,
      selfie: user.verificationSelfie,
    });
  } catch (error) {
    console.error("Get verification selfie error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve verification selfie.",
    });
  }
};

// ==========================================
// APPROVE VERIFICATION
// ==========================================

exports.approveVerification = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID.",
      });
    }

    const user = await User.findOneAndUpdate(
      {
        _id: userId,
        verificationStatus: "pending",
      },
      {
        $set: {
          verificationStatus: "verified",
          verificationReviewedAt: new Date(),
          verificationRejectionReason: "",
        },
        // Delete the selfie after the review decision.
        $unset: {
          verificationSelfie: 1,
        },
      },
      {
        new: true,
        runValidators: true,
      }
    ).select(
      "_id displayName username verificationStatus verificationReviewedAt"
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Pending verification request not found.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Account verification approved.",
      user,
    });
  } catch (error) {
    console.error("Approve verification error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to approve verification.",
    });
  }
};

// ==========================================
// REJECT VERIFICATION
// ==========================================

exports.rejectVerification = async (req, res) => {
  try {
    const { userId } = req.params;
    const reason =
      typeof req.body.reason === "string"
        ? req.body.reason.trim()
        : "";

    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid user ID.",
      });
    }

    if (!reason || reason.length > 500) {
      return res.status(400).json({
        success: false,
        message: "A rejection reason of 1–500 characters is required.",
      });
    }

    const user = await User.findOneAndUpdate(
      {
        _id: userId,
        verificationStatus: "pending",
      },
      {
        $set: {
          verificationStatus: "rejected",
          verificationReviewedAt: new Date(),
          verificationRejectionReason: reason,
        },
        // Delete the selfie after the review decision.
        $unset: {
          verificationSelfie: 1,
        },
      },
      {
        new: true,
        runValidators: true,
      }
    ).select(
      "_id displayName username verificationStatus verificationReviewedAt verificationRejectionReason"
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Pending verification request not found.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Verification request rejected.",
      user,
    });
  } catch (error) {
    console.error("Reject verification error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to reject verification.",
    });
  }
};
