import 'package:flutter/material.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              const SizedBox(height: 60),

              const Icon(
                Icons.forum,
                size: 90,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "MicroBlog",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              const CustomTextField(
  label: "Email",
  icon: Icons.email,
),

              const SizedBox(height: 20),

              const CustomTextField(
  label: "Password",
  icon: Icons.lock,
  obscureText: true,
),

              const SizedBox(height: 30),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},

                  child: const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  },

  child: const Text(
    "Create New Account",
  ),
),

            ],
          ),
        ),
      ),
    );
  }
}