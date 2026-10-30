const dns = require("node:dns");
dns.setServers(["8.8.8.8", "1.1.1.1"]);

require("dotenv").config();

const express = require("express");
const connectDB = require("./config/db");


const app = express();

const PORT = process.env.PORT || 3000;

// ==========================================================
// BODY PARSER
// ==========================================================
//
// Profile images are sent as compressed Base64 data URLs.
// Allow a larger JSON body.
// ==========================================================

app.use(
  express.json({
    limit: "100mb",
  })
);

// ==========================================================
// DEFAULT ROUTE
// ==========================================================

app.get("/", (req, res) => {
  res.json({
    status: "success",
    message: "MicroBlog API is running",
    version: "1.0.0",
  });
});

// ==========================================================
// ROUTES
// ==========================================================

const apiRoutes =
  require("./routes/api");

const postRoutes =
  require("./routes/postRoutes");

// ==========================================================
// API ROUTES
// ==========================================================

app.use(
  "/api",
  apiRoutes
);

app.use(
  "/api/posts",
  postRoutes
);
app.get("/api/view-route-check", (req, res) => {
  res.json({
    success: true,
    message: "Latest backend deployment is active",
    viewRouteFileLoaded: true
  });
});
app.use("/api/users", require("./routes/userRoutes"));

// ==========================================================
// START SERVER
// ==========================================================

const startServer = async () => {
  try {
    await connectDB();

    app.listen(
      PORT,
      "0.0.0.0",
      () => {
        console.log(
          `🚀 Server running on http://0.0.0.0:${PORT}`
        );
      }
    );
  } catch (error) {
    console.error(
      "❌ Failed to start server:",
      error.message
    );

    process.exit(1);
  }
};

startServer();