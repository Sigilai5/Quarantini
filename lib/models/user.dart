import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String photoUrl;
  final String displayName;
  final String bio;

  User({
  this.id,
  this.username,
  this.email,
  this.photoUrl,
  this.displayName,
  this.bio,
  });

  //Responsible for taking a document snapshot and creating an insance of a User class to be used in different pageviews
  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
      id: doc['id'],
      email: doc['email'],
      username: doc['username'],
      photoUrl: doc['photoUrl'],
      displayName: doc['displayName'],
      bio: doc['bio'],
    );
  }

}
