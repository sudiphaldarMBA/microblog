const mongoose = require('mongoose');

const postSchema = new mongoose.Schema(
  {
    content: {
      type: String,
      trim: true,
      maxlength: 500,
      default: '',
    },

    author: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    image: {
      type: String,
      default: '',
    },

    video: {
  type: String,
  default: '',
},

    // Multiple media (up to 10 photos / 5 videos per post).
    images: {
      type: [String],
      default: [],
    },

    videos: {
      type: [String],
      default: [],
    },

    // true = posted from the Shorts screen: shown only in Shorts and
    // the profile Shorts tab, never in the Home feed.
    isShort: {
      type: Boolean,
      default: false,
      index: true,
    },

viewsCount: {
  type: Number,
  default: 0,
  min: 0,
},
    
    location: {
      type: String,
      trim: true,
      maxlength: 200,
      default: '',
    },

    poll: {
      options: [
        {
          type: String,
          trim: true,
          maxlength: 100,
        },
      ],

      durationDays: {
        type: Number,
        min: 1,
        max: 30,
        default: 1,
      },
    },

    pollVotes: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'User',
        },

        optionIndex: {
          type: Number,
          min: 0,
        },
      },
    ],

    likes: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],

    repostOf: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Post',
      default: null,
      index: true,
    },
repostCaption: {
  type: String,
  trim: true,
  maxlength: 500,
  default: '',
},
    repostsCount: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true,
  }
);

module.exports =
  mongoose.model(
    'Post',
    postSchema
  );