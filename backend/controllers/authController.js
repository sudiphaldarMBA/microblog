exports.register = (req, res) => {
  res.status(201).json({
    success: true,
    message: "User registered successfully",
  });
};

exports.login = (req, res) => {
  res.status(200).json({
    success: true,
    message: "Login successful",
  });
};