exports.healthCheck = (req, res) => {
  res.status(200).json({
    status: "success",
    message: "MicroBlog API is running",
    version: "1.0.0"
  });
};