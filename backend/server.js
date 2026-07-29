const express = require("express");

const app = express();

const PORT = 3000;

// Import Routes
const apiRoutes = require("./routes/api");

// Middleware
app.use(express.json());

// Default Route
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to MicroBlog Backend"
  });
});

// API Routes
app.use("/api", apiRoutes);

// Start Server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});