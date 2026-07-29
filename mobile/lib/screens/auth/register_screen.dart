import 'package:flutter/material.dart';

import '../../widgets/custom_text_field.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              const SizedBox(height: 20),

              const Icon(
                Icons.person_add,
                size: 90,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  "Join the MicroBlog community",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const CustomTextField(
                label: "Username",
                icon: Icons.person,
              ),

              const SizedBox(height: 20),

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

              const SizedBox(height: 20),

              const CustomTextField(
                label: "Confirm Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},

                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },

                child: const Text(
                  "Already have an account? Login",
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}