import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SizedBox(
          height: 48,
          child: SignInButton(
            Buttons.google,
            onPressed: () async {
              final account = await GoogleSignIn(scopes: ['email']).signIn();
              if (account == null) return;

              final googleAuth = await account.authentication;
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );

              await FirebaseAuth.instance.signInWithCredential(credential);
            },
          ),
        ),
      ),
    );
  }
}
