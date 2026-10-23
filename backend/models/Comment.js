
const mongoose = require("mongoose");

const commentSchema = new mongoose.Schema(
  {
    // Comment content
    content: {
      type: String,
      required: true,
      trim: true,
      maxlength: 300,
    },

    // Comment author
    author: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // Post this comment belongs to
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Post",
      required: true,
    },

    // Parent comment: null for a top-level comment,
    // an ObjectId for a reply
    parentComment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Comment",
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Helps fetch comments and replies efficiently
commentSchema.index({ post: 1, parentComment: 1, createdAt: 1 });

module.exports = mongoose.model("Comment", commentSchema);
