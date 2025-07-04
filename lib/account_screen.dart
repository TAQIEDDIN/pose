import 'package:flutter/material.dart';
import 'main.dart'; // Import main.dart to access HomeScreenContent if needed

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(color: Colors.black)), // Page title
        backgroundColor: Colors.white, // White background
        elevation: 0, // Remove shadow from app bar
        iconTheme: const IconThemeData(color: Colors.black), // App bar icon color
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top section: Get more features
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A2BE2), Color(0xFFDA70D6)], // Purple/pink gradient colors
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      spreadRadius: 3,
                      blurRadius: 10,
                      offset: const Offset(0, 5), // Soft shadow
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.star, // Star icon
                      color: Colors.white,
                      size: 60.0,
                    ),
                    const SizedBox(height: 15.0),
                    const Text(
                      'Get more features',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10.0),
                    const Text(
                      'Create an account and use HUB Web to create your first project',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Add logic for Sign up button
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sign up clicked!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // White background
                            foregroundColor: const Color(0xFF8A2BE2), // Purple text
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30), // Rounded corners
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            'Sign up',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Add logic for Sign in button
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sign in clicked!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDA70D6), // Pink background
                            foregroundColor: Colors.white, // White text
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30), // Rounded corners
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25.0),

              // Support section
              Text(
                'Support',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 15.0),
              _buildSupportOption(context, 'Report a bug', Icons.bug_report),
              _buildSupportOption(context, 'Request a feature', Icons.lightbulb_outline),
              _buildSupportOption(context, 'Ask a question', Icons.help_outline),
              const SizedBox(height: 25.0),

              // Bottom section: Unleash growth
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4169E1), Color(0xFF00BFFF)], // Blue gradient colors
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 3,
                      blurRadius: 10,
                      offset: const Offset(0, 5), // Soft shadow
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Unleash growth',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10.0),
                    const Text(
                      'Plan customised to suit your business needs.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25.0),
                    ElevatedButton(
                      onPressed: () {
                        // Add logic for Learn more button
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Learn more clicked!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // White background
                        foregroundColor: const Color(0xFF4169E1), // Blue text
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Rounded corners
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Learn more',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar was removed from here
    );
  }

  // Helper function to build support options
  Widget _buildSupportOption(BuildContext context, String title, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 3, // Soft shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Rounded corners
      ),
      child: InkWell(
        onTap: () {
          // Add logic for option tap
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title clicked!')),
          );
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[700], size: 28), // Option icon
              const SizedBox(width: 15.0),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20), // Arrow icon
            ],
          ),
        ),
      ),
    );
  }
}
