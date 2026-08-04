const express = require("express");

const app = express();

const PORT = 3000;

// ==============================
// Middleware
// ==============================
app.use(express.json());

// ==============================
// Import Routes
// ==============================
const apiRoutes = require("./routes/api");

// ==============================
// Default Route
// ==============================
app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Welcome to MicroBlog Backend",
    version: "1.0.0"
  });
});

// ==============================
// API Routes
// ==============================
app.use("/api", apiRoutes);

// ==============================
// 404 Route
// ==============================
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found"
  });
});

// ==============================
// Start Server
// ==============================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});