const express = require('express');

const router =
  express.Router();

const postController =
  require('../controllers/postController');

const authMiddleware =
  require('../middleware/authMiddleware');

// ============================================================
// POSTS
// ============================================================

router.get(
  '/',
  authMiddleware,
  postController.getPosts
);

router.post(
  '/',
  authMiddleware,
  postController.createPost
);

// ============================================================
// USER STATS
// ============================================================

router.get(
  '/me/stats',
  authMiddleware,
  postController.getMyStats
);

// ============================================================
// BOOKMARKS
// IMPORTANT: Keep /bookmarks before /:postId routes.
// ============================================================

router.get(
  '/bookmarks',
  authMiddleware,
  postController.getBookmarks
);

// ============================================================
// POST ACTIONS
// ============================================================

router.post(
  '/:postId/like',
  authMiddleware,
  postController.toggleLike
);

// CREATE COMMENT
router.post(
  '/:postId/comments',
  authMiddleware,
  postController.createComment
);

// GET COMMENTS
router.get(
  '/:postId/comments',
  authMiddleware,
  postController.getComments
);

// EDIT COMMENT
router.put(
  "/:postId/comments/:commentId",
  authMiddleware,
  postController.updateComment
);

// DELETE COMMENT
router.delete(
  "/:postId/comments/:commentId",
  authMiddleware,
  postController.deleteComment
);

router.post(
  '/:postId/bookmark',
  authMiddleware,
  postController.toggleBookmark
);

// ============================================================
// POLL
// ============================================================

router.post(
  '/:postId/poll/vote',
  authMiddleware,
  postController.votePoll
);

// ============================================================
// REPOST
// ============================================================

router.post(
  '/:postId/repost',
  authMiddleware,
  postController.repost
);

module.exports = router;