
const mongoose = require('mongoose');

const postViewSchema = new mongoose.Schema(
  {
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Post',
      required: true,
    },

    viewer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// A signed-in user can count only once per post.
postViewSchema.index(
  { post: 1, viewer: 1 },
  { unique: true }
);

module.exports = mongoose.model('PostView', postViewSchema);
