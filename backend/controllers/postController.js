const mongoose = require('mongoose');

const Post = require('../models/Post');
const Comment = require('../models/Comment');
const Bookmark = require('../models/Bookmark');

const AUTHOR_FIELDS =
  'displayName username email avatar coverPhoto';

// ============================================================
// HELPERS
// ============================================================

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

function cleanString(value) {
  return String(value ?? '').trim();
}

function formatAuthor(author) {
  if (!author) return null;

  return author;
}

// ============================================================
// CREATE POST
// ============================================================

exports.createPost = async (
  req,
  res
) => {
  try {
    const userId =
      req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message:
          'Authenticated user not found',
      });
    }

    const {
      content = '',
      image = '',
      video = '',
      location = '',
      poll = null,
    } = req.body || {};

    const cleanContent =
      cleanString(content);

    const cleanImage =
      cleanString(image);

    const cleanVideo = cleanString(video);

    const cleanLocation =
      cleanString(location);

    let cleanPoll = undefined;

    if (
      poll &&
      Array.isArray(
        poll.options
      )
    ) {
      const options =
        poll.options
          .map(cleanString)
          .filter(Boolean)
          .slice(0, 4);

      if (options.length < 2) {
        return res.status(400).json({
          success: false,
          message:
            'A poll needs at least two options',
        });
      }

      const durationDays =
        Math.min(
          30,
          Math.max(
            1,
            Number(
              poll.durationDays
            ) || 1
          )
        );

      cleanPoll = {
        options,
        durationDays,
      };
    }

    if (
      !cleanContent &&
      !cleanImage &&
      !cleanVideo &&
      !cleanLocation &&
      !cleanPoll
    ) {
      return res.status(400).json({
        success: false,
        message:
          'Post content or media is required',
      });
    }

    const post =
      await Post.create({
        content:
          cleanContent,
        image:
          cleanImage,
          video: 
          cleanVideo,
        location:
          cleanLocation,
        poll:
          cleanPoll,
        author:
          userId,
      });

    await post.populate(
      'author',
      AUTHOR_FIELDS
    );

    return res.status(201).json({
      success: true,
      message:
        'Post created successfully',
      data: {
        post: {
          ...post.toObject(),
          likesCount: 0,
          likedByMe: false,
          commentsCount: 0,
          bookmarkedByMe: false,
          repostsCount: 0,
        },
      },
    });
  } catch (error) {
    console.error(
      'Create Post Error:',
      error
    );

    return res.status(500).json({
      success: false,
      message:
        'Server error while creating post',
    });
  }
};

// ============================================================
// GET POSTS
// ============================================================

exports.getPosts = async (
  req,
  res
) => {
  try {
    const userId =
      req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message:
          'Authenticated user not found',
      });
    }

    const posts =
      await Post.find()
        .populate(
          'author',
          AUTHOR_FIELDS
        )
        .populate({
          path: 'repostOf',
          populate: {
            path: 'author',
            select: AUTHOR_FIELDS,
          },
        })
        .sort({
          createdAt: -1,
        })
        .lean();

    const postIds =
      posts.map(
        post => post._id
      );

    const [
      commentCounts,
      bookmarks,
    ] = await Promise.all([
      postIds.length
        ? Comment.aggregate([
            {
              $match: {
                post: {
                  $in: postIds,
                },
              },
            },
            {
              $group: {
                _id: '$post',
                count: {
                  $sum: 1,
                },
              },
            },
          ])
        : [],

      postIds.length
        ? Bookmark.find({
            user: userId,
            post: {
              $in: postIds,
            },
          })
            .select('post')
            .lean()
        : [],
    ]);

    const commentMap =
      {};

    for (
      const item of commentCounts
    ) {
      commentMap[
        item._id.toString()
      ] = item.count;
    }

    const bookmarkedIds =
      new Set(
        bookmarks.map(
          bookmark =>
            bookmark.post.toString()
        )
      );

    const formattedPosts =
      posts.map(post => {
        const id =
          post._id.toString();

        const likedByMe =
          Array.isArray(
            post.likes
          ) &&
          post.likes.some(
            likeId =>
              likeId.toString() ===
              userId.toString()
          );

        return {
          ...post,

          author:
            formatAuthor(
              post.author
            ),

          likesCount:
            Array.isArray(
              post.likes
            )
              ? post.likes.length
              : 0,

          likedByMe,

          commentsCount:
            commentMap[id] || 0,

          bookmarkedByMe:
            bookmarkedIds.has(id),

          repostsCount:
            Number(
              post.repostsCount
            ) || 0,
        };
      });

    return res.status(200).json({
      success: true,
      message:
        'Posts retrieved successfully',
      data: {
        posts:
          formattedPosts,
      },
    });
  } catch (error) {
    console.error(
      'Get Posts Error:',
      error
    );

    return res.status(500).json({
      success: false,
      message:
        'Server error while retrieving posts',
    });
  }
};

// ============================================================
// LIKE / UNLIKE
// ============================================================

exports.toggleLike = async (
  req,
  res
) => {
  try {
    const {
      postId,
    } = req.params;

    const userId =
      req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message:
          'Authenticated user not found',
      });
    }

    if (
      !isValidObjectId(
        postId
      )
    ) {
      return res.status(400).json({
        success: false,
        message:
          'Invalid post ID',
      });
    }

    const post =
      await Post.findById(
        postId
      );

    if (!post) {
      return res.status(404).json({
        success: false,
        message:
          'Post not found',
      });
    }

    const alreadyLiked =
      post.likes.some(
        id =>
          id.toString() ===
          userId.toString()
      );

    if (alreadyLiked) {
      post.likes =
        post.likes.filter(
          id =>
            id.toString() !==
            userId.toString()
        );
    } else {
      post.likes.push(
        userId
      );
    }

    await post.save();

    return res.status(200).json({
      success: true,
      message:
        alreadyLiked
          ? 'Post unliked successfully'
          : 'Post liked successfully',
      data: {
        liked:
          !alreadyLiked,
        likesCount:
          post.likes.length,
      },
    });
  } catch (error) {
    console.error(
      'Toggle Like Error:',
      error
    );

    return res.status(500).json({
      success: false,
      message:
        'Server error while liking post',
    });
  }
};


 // ============================================================
 // CREATE COMMENT / REPLY
 // ============================================================

exports.createComment = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.userId;

    const content = cleanString(req.body?.content);
    const parentId = req.body?.parentId || null;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authenticated user not found',
      });
    }

    if (!isValidObjectId(postId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid post ID',
      });
    }

    if (!content) {
      return res.status(400).json({
        success: false,
        message: 'Comment content is required',
      });
    }

    if (content.length > 300) {
      return res.status(400).json({
        success: false,
        message: 'Comment cannot exceed 300 characters',
      });
    }

    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    // If this is a reply, validate its parent comment.
    let parentComment = null;

    if (parentId) {
      if (!isValidObjectId(parentId)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid parent comment ID',
        });
      }

      parentComment = await Comment.findOne({
        _id: parentId,
        post: postId,
      });

      if (!parentComment) {
        return res.status(404).json({
          success: false,
          message: 'Parent comment not found for this post',
        });
      }
    }

    const comment = await Comment.create({
      content,
      author: userId,
      post: postId,
      parentComment: parentComment
        ? parentComment._id
        : null,
    });

    await comment.populate('author', AUTHOR_FIELDS);

    const commentsCount = await Comment.countDocuments({
      post: postId,
    });

    return res.status(201).json({
      success: true,
      message: parentId
        ? 'Reply created successfully'
        : 'Comment created successfully',
      data: {
        comment,
        commentsCount,
      },
    });
  } catch (error) {
    console.error('Create Comment Error:', error);

    return res.status(500).json({
      success: false,
      message: 'Server error while creating comment',
    });
  }
};


// ============================================================
// GET COMMENTS WITH NESTED REPLIES
// ============================================================

exports.getComments = async (req, res) => {
  try {
    const { postId } = req.params;

    if (!isValidObjectId(postId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid post ID',
      });
    }

    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    const comments = await Comment.find({
      post: postId,
    })
      .populate('author', AUTHOR_FIELDS)
      .sort({ createdAt: 1 })
      .lean();

    // Prepare every comment for nesting.
    const commentMap = new Map();

    comments.forEach((comment) => {
      comment.replies = [];
      commentMap.set(String(comment._id), comment);
    });

    const topLevelComments = [];

    comments.forEach((comment) => {
      const parentId = comment.parentComment
        ? String(comment.parentComment)
        : null;

      const parent = parentId
        ? commentMap.get(parentId)
        : null;

      if (parent && String(parent._id) !== String(comment._id)) {
        parent.replies.push(comment);
      } else {
        // Older comments without parentComment remain top-level.
        topLevelComments.push(comment);
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Comments retrieved successfully',
      data: {
        comments: topLevelComments,
        commentsCount: comments.length,
      },
    });
  } catch (error) {
    console.error('Get Comments Error:', error);

    return res.status(500).json({
      success: false,
      message: 'Server error while retrieving comments',
    });
  }
};


// ==========================================
// EDIT COMMENT
// ==========================================
exports.updateComment = async (req, res) => {
  try {
    const { postId, commentId } = req.params;
    const userId = req.userId;

    const content =
      typeof req.body.content === "string"
        ? req.body.content.trim()
        : "";

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    if (!content) {
      return res.status(400).json({
        success: false,
        message: "Comment content is required",
      });
    }

    if (content.length > 300) {
      return res.status(400).json({
        success: false,
        message: "Comment cannot exceed 300 characters",
      });
    }

    const comment = await Comment.findOne({
      _id: commentId,
      post: postId,
    });

    if (!comment) {
      return res.status(404).json({
        success: false,
        message: "Comment not found",
      });
    }

    // Only the original author can edit this comment.
    if (comment.author.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only edit your own comments",
      });
    }

    comment.content = content;
    await comment.save();

    await comment.populate("author", AUTHOR_FIELDS);

    return res.status(200).json({
      success: true,
      message: "Comment updated successfully",
      data: { comment },
    });
  } catch (error) {
    console.error("Update Comment Error:", error);

    return res.status(500).json({
      success: false,
      message: "Server error while updating comment",
    });
  }
};


// ==========================================
// DELETE COMMENT AND ITS REPLIES
// ==========================================
exports.deleteComment = async (req, res) => {
  try {
    const { postId, commentId } = req.params;
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    const comment = await Comment.findOne({
      _id: commentId,
      post: postId,
    });

    if (!comment) {
      return res.status(404).json({
        success: false,
        message: "Comment not found",
      });
    }

    // Only the original author can delete this comment.
    if (comment.author.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only delete your own comments",
      });
    }

    // Find every reply and nested reply belonging to this comment.
    const allComments = await Comment.find({
      post: postId,
    }).select("_id parentComment");

    const idsToDelete = new Set([
      comment._id.toString(),
    ]);

    let changed = true;

    while (changed) {
      changed = false;

      for (const item of allComments) {
        const parentId = item.parentComment
          ? item.parentComment.toString()
          : "";

        const itemId = item._id.toString();

        if (
          parentId &&
          idsToDelete.has(parentId) &&
          !idsToDelete.has(itemId)
        ) {
          idsToDelete.add(itemId);
          changed = true;
        }
      }
    }

    await Comment.deleteMany({
      _id: { $in: Array.from(idsToDelete) },
      post: postId,
    });

    return res.status(200).json({
      success: true,
      message: "Comment deleted successfully",
      data: { deletedCount: idsToDelete.size },
    });
  } catch (error) {
    console.error("Delete Comment Error:", error);

    return res.status(500).json({
      success: false,
      message: "Server error while deleting comment",
    });
  }
};
// ============================================================
// GET POSTS COMMENTED ON BY CURRENT USER
// ============================================================

exports.getMyCommentedPosts = async (req, res) => {
  try {
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated user not found",
      });
    }

    // ----------------------------------------------------------
    // Find comments written by the current user.
    // ----------------------------------------------------------

    const comments = await Comment.find({
      author: userId,
    })
      .sort({
        createdAt: -1,
      })
      .populate({
        path: "post",
        populate: [
          {
            path: "author",
            select:
              "displayName username email avatar coverPhoto",
          },
          {
            path: "repostOf",
            populate: {
              path: "author",
              select:
                "displayName username email avatar coverPhoto",
            },
          },
        ],
      });

    // ----------------------------------------------------------
    // Remove deleted/missing posts and duplicate posts.
    // ----------------------------------------------------------

    const seen = new Set();

    const posts = [];

    for (const comment of comments) {
      const post = comment.post;

      if (!post) {
        continue;
      }

      const postId =
        post._id.toString();

      if (seen.has(postId)) {
        continue;
      }

      seen.add(postId);

      posts.push(post);
    }

    // ----------------------------------------------------------
    // Add the same useful information returned by getPosts().
    // ----------------------------------------------------------

    const formattedPosts =
      await Promise.all(
        posts.map(async (post) => {
          const likes =
            Array.isArray(post.likes)
              ? post.likes
              : [];

          const likedByMe =
            likes.some(
              (id) =>
                id.toString() ===
                userId.toString()
            );

          const commentsCount =
            await Comment.countDocuments({
              post: post._id,
            });

          const bookmark =
            await Bookmark.exists({
              user: userId,
              post: post._id,
            });

          return {
            ...post.toObject(),

            likesCount:
              likes.length,

            likedByMe,

            bookmarkedByMe:
              !!bookmark,

            commentsCount,

            repostsCount:
              post.repostsCount || 0,
          };
        })
      );

    return res.status(200).json({
      success: true,
      message:
        "Commented posts retrieved successfully",
      data: {
        posts: formattedPosts,
      },
    });
  } catch (error) {
    console.error(
      "Get My Commented Posts Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message:
        "Server error while retrieving commented posts",
    });
  }
};

// ============================================================
// BOOKMARK / UNBOOKMARK
// ============================================================

exports.toggleBookmark =
  async (
    req,
    res
  ) => {
    try {
      const {
        postId,
      } = req.params;

      const userId =
        req.userId;

      if (!userId) {
        return res.status(401).json({
          success: false,
          message:
            'Authenticated user not found',
        });
      }

      if (
        !isValidObjectId(
          postId
        )
      ) {
        return res.status(400).json({
          success: false,
          message:
            'Invalid post ID',
        });
      }

      const post =
        await Post.findById(
          postId
        );

      if (!post) {
        return res.status(404).json({
          success: false,
          message:
            'Post not found',
        });
      }

      const existing =
        await Bookmark.findOne({
          user:
            userId,
          post:
            postId,
        });

      if (existing) {
        await Bookmark.deleteOne({
          _id:
            existing._id,
        });

        return res.status(200).json({
          success: true,
          message:
            'Post removed from saved',
          data: {
            bookmarked:
              false,
          },
        });
      }

      try {
        await Bookmark.create({
          user:
            userId,
          post:
            postId,
        });
      } catch (error) {
        if (
          error.code !==
          11000
        ) {
          throw error;
        }
      }

      return res.status(200).json({
        success: true,
        message:
          'Post saved successfully',
        data: {
          bookmarked:
            true,
        },
      });
    } catch (error) {
      console.error(
        'Toggle Bookmark Error:',
        error
      );

      return res.status(500).json({
        success: false,
        message:
          'Server error while saving post',
      });
    }
  };

// ============================================================
// GET BOOKMARKS
// ============================================================

exports.getBookmarks =
  async (
    req,
    res
  ) => {
    try {
      const userId =
        req.userId;

      if (!userId) {
        return res.status(401).json({
          success: false,
          message:
            'Authenticated user not found',
        });
      }

      const bookmarks =
        await Bookmark.find({
          user:
            userId,
        })
          .populate({
            path:
              'post',
            populate: [
              {
                path:
                  'author',
                select:
                  AUTHOR_FIELDS,
              },
              {
                path:
                  'repostOf',
                populate: {
                  path:
                    'author',
                  select:
                    AUTHOR_FIELDS,
                },
              },
            ],
          })
          .sort({
            createdAt:
              -1,
          });

      const validPosts =
        bookmarks
          .filter(
            bookmark =>
              bookmark.post
          )
          .map(
            bookmark =>
              bookmark.post
          );

      const postIds =
        validPosts.map(
          post =>
            post._id
        );

      const commentCounts =
        postIds.length
          ? await Comment.aggregate([
              {
                $match: {
                  post: {
                    $in:
                      postIds,
                  },
                },
              },
              {
                $group: {
                  _id:
                    '$post',
                  count:
                    {
                      $sum: 1,
                    },
                },
              },
            ])
          : [];

      const commentMap =
        {};

      for (
        const item of commentCounts
      ) {
        commentMap[
          item._id.toString()
        ] =
          item.count;
      }

      const posts =
        validPosts.map(
          post => {
            const id =
              post._id.toString();

            const likedByMe =
              Array.isArray(
                post.likes
              ) &&
              post.likes.some(
                likeId =>
                  likeId.toString() ===
                  userId.toString()
              );

            return {
              ...post.toObject(),

              likesCount:
                Array.isArray(
                  post.likes
                )
                  ? post.likes.length
                  : 0,

              likedByMe,

              bookmarkedByMe:
                true,

              commentsCount:
                commentMap[id] ||
                0,

              repostsCount:
                Number(
                  post.repostsCount
                ) || 0,
            };
          }
        );

      return res.status(200).json({
        success: true,
        message:
          'Saved posts retrieved successfully',
        data: {
          posts,
        },
      });
    } catch (error) {
      console.error(
        'Get Bookmarks Error:',
        error
      );

      return res.status(500).json({
        success: false,
        message:
          'Server error while retrieving saved posts',
      });
    }
  };

  // ============================================================
// POLL VOTE
// ============================================================

exports.votePoll = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authenticated user not found',
      });
    }

    if (!isValidObjectId(postId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid post ID',
      });
    }

    const optionIndex = Number(
      req.body?.optionIndex
    );

    if (!Number.isInteger(optionIndex)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid poll option',
      });
    }

    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    if (
      !post.poll ||
      !Array.isArray(post.poll.options) ||
      post.poll.options.length < 2
    ) {
      return res.status(400).json({
        success: false,
        message: 'This post does not contain a poll',
      });
    }

    if (
      optionIndex < 0 ||
      optionIndex >= post.poll.options.length
    ) {
      return res.status(400).json({
        success: false,
        message: 'Invalid poll option',
      });
    }

    // Check whether this user already voted.
    const existingVoteIndex =
      post.pollVotes.findIndex(
        (vote) =>
          vote.user &&
          vote.user.toString() ===
            userId.toString()
      );

    if (existingVoteIndex >= 0) {
      // Update existing vote.
      post.pollVotes[
        existingVoteIndex
      ].optionIndex = optionIndex;
    } else {
      // Add new vote.
      post.pollVotes.push({
        user: userId,
        optionIndex,
      });
    }

    await post.save();

    const voteCounts =
      post.poll.options.map(
        (_, index) =>
          post.pollVotes.filter(
            (vote) =>
              vote.optionIndex === index
          ).length
      );

    const totalVotes =
      voteCounts.reduce(
        (sum, value) => sum + value,
        0
      );

    return res.status(200).json({
      success: true,
      message: 'Poll vote recorded',
      data: {
        selectedOption: optionIndex,
        voteCounts,
        totalVotes,
      },
    });
  } catch (error) {
    console.error(
      'Poll Vote Error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to vote in poll',
    });
  }
};

// ============================================================
// REPOST WITH CAPTION
// ============================================================

exports.repost = async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authenticated user not found',
      });
    }

    if (!isValidObjectId(postId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid post ID',
      });
    }

    const original = await Post.findById(postId);

    if (!original) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    const caption = cleanString(req.body?.caption);

    // If this user already reposted it, undo that repost.
    const existingRepost = await Post.findOne({
      author: userId,
      repostOf: original._id,
    });

    if (existingRepost) {
      await Post.deleteOne({ _id: existingRepost._id });

      original.repostsCount = Math.max(
        0,
        (Number(original.repostsCount) || 0) - 1
      );

      await original.save();

      return res.status(200).json({
        success: true,
        message: 'Repost removed successfully',
        data: {
          reposted: false,
          repostsCount: original.repostsCount,
        },
      });
    }

    // Otherwise, create a new repost.
    const repost = await Post.create({
      content: caption,
      repostCaption: caption,
      image: original.image || '',
      location: original.location || '',
      poll: original.poll
        ? {
            options: original.poll.options,
            durationDays: original.poll.durationDays,
          }
        : undefined,
      author: userId,
      repostOf: original._id,
    });

    original.repostsCount =
      (Number(original.repostsCount) || 0) + 1;

    await original.save();

    await repost.populate('author', AUTHOR_FIELDS);

    await repost.populate({
      path: 'repostOf',
      populate: {
        path: 'author',
        select: AUTHOR_FIELDS,
      },
    });

    return res.status(201).json({
      success: true,
      message: 'Post reposted successfully',
      data: {
        reposted: true,
        post: repost,
        repostsCount: original.repostsCount,
      },
    });
  } catch (error) {
    console.error('Repost Error:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to repost',
    });
  }
};

// ============================================================
// MY PROFILE STATS
// ============================================================

exports.getMyStats =
  async (
    req,
    res
  ) => {
    try {
      const userId =
        req.userId;

      if (!userId) {
        return res.status(401).json({
          success: false,
          message:
            'Authenticated user not found',
        });
      }

      const [
        myPosts,
        postsCount,
        likedPostsCount,
      ] =
        await Promise.all([
          Post.find({
            author:
              userId,
          })
            .populate(
              'author',
              AUTHOR_FIELDS
            )
            .populate({
              path: 'repostOf',
              populate: {
                path: 'author',
                select: AUTHOR_FIELDS,
              },
            })
            .sort({
              createdAt:
                -1,
            }),

          Post.countDocuments({
            author:
              userId,
          }),

          Post.countDocuments({
            likes:
              userId,
          }),
        ]);

      const postIds =
        myPosts.map(
          post =>
            post._id
        );

      const commentCounts =
        postIds.length
          ? await Comment.aggregate([
              {
                $match: {
                  post: {
                    $in:
                      postIds,
                  },
                },
              },
              {
                $group: {
                  _id:
                    '$post',
                  count:
                    {
                      $sum: 1,
                    },
                },
              },
            ])
          : [];

      const commentMap =
        {};

      for (
        const item of commentCounts
      ) {
        commentMap[
          item._id.toString()
        ] =
          item.count;
      }

      const posts =
        myPosts.map(
          post => {
            const id =
              post._id.toString();

            return {
              ...post.toObject(),

              authorId:
                post.author?._id ??
                null,

              likesCount:
                Array.isArray(
                  post.likes
                )
                  ? post.likes.length
                  : 0,

              likedByMe:
                Array.isArray(
                  post.likes
                ) &&
                post.likes.some(
                  likeId =>
                    likeId.toString() ===
                    userId.toString()
                ),

              commentsCount:
                commentMap[id] ||
                0,

              repostsCount:
                Number(
                  post.repostsCount
                ) || 0,
            };
          }
        );

      return res.status(200).json({
        success: true,
        message:
          'Profile statistics retrieved successfully',
        data: {
          postsCount,
          likedPostsCount,
          posts,
        },
      });
    } catch (error) {
      console.error(
        'Get My Stats Error:',
        error
      );

      return res.status(500).json({
        success: false,
        message:
          'Server error while retrieving profile statistics',
      });
    }
  };