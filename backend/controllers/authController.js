exports.register = (req, res) => {
  const { username, email, password } = req.body;

  res.status(201).json({
    success: true,
    message: "Registration request received",
    data: {
      username,
      email,
      password
    }
  });
};

exports.login = (req, res) => {
  const { email, password } = req.body;

  res.status(200).json({
    success: true,
    message: "Login request received",
    data: {
      email,
      password
    }
  });
};