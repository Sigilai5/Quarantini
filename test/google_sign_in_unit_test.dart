import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:test/test.dart';

void main() {
  test('Sign in test', () async {
    final googleSignIn = MockGoogleSignIn();
    final signinAccount = await googleSignIn.signIn();
    final signinAuthentication = await signinAccount.authentication;
    expect(signinAuthentication, isNotNull);
  });


  test('Sign out test', () async {
    final googleSignIn = MockGoogleSignIn();
    final signinAccount = await googleSignIn.signOut();
    expect(signinAccount, null);
  });

}


