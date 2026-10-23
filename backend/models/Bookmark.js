const mongoose = require("mongoose");

const bookmarkSchema = new mongoose.Schema(
  {
    // ==========================================
    // USER WHO SAVED THE POST
    // ==========================================
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // ==========================================
    // SAVED POST
    // ==========================================
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Post",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// ==========================================
// PREVENT DUPLICATE BOOKMARKS
// ==========================================
bookmarkSchema.index(
  {
    user: 1,
    post: 1,
  },
  {
    unique: true,
  }
);

module.exports = mongoose.model(
  "Bookmark",
  bookmarkSchema
);