import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:instaflutter/models/user.dart';
import 'package:instaflutter/pages/activity_feed.dart';
import 'package:instaflutter/pages/create_account.dart';
import 'package:instaflutter/pages/profile.dart';
import 'package:instaflutter/pages/search.dart';
import 'package:instaflutter/pages/timeline.dart';
import 'package:instaflutter/pages/upload.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final StorageReference storageRef = FirebaseStorage.instance.ref();
final usersRef = Firestore.instance.collection("users");
final postsRef= Firestore.instance.collection('posts');
final commentsRef = Firestore.instance.collection('comments');
final activityFeedRef = Firestore.instance.collection('feed');
final followersRef = Firestore.instance.collection('followers');
final followingRef = Firestore.instance.collection('following');
final timelineRef = Firestore.instance.collection('timeline');
final DateTime timestamp = DateTime.now();
User currentUser;

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isAuth = false;
  PageController pageController;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController =
        PageController(); //we put it on initState when page is loaded
    // Detects when user signed in
    googleSignIn.onCurrentUserChanged.listen((account) {
      handleSignIn(account);
    }, onError: (err) {
      print('Error signining in: $err');
    });
    //Reauthenticate user when app is opened
    googleSignIn.signInSilently(suppressErrors: false).then((account) {
      handleSignIn(account);
    }).catchError((err) {
      print('Error signining in: $err');
    });
  }

  handleSignIn(GoogleSignInAccount account) async {
    if (account != null) {
      await createUserInFirestore();
      setState(() {
        isAuth = true;
      });
    } else {
      setState(() {
        isAuth = false;
      });
    }
  }

  createUserInFirestore() async {
    // 1)Check if user exists in users collection id database base on id.
    final GoogleSignInAccount user =
        googleSignIn.currentUser; //Get current user
    DocumentSnapshot doc =
        await usersRef.document(user.id).get(); //Get the id of current user
    //print(doc.data['displayName']);

    // 2)If user doesn't exist,make them create and account in account page.
    if (!doc.exists) {
      final username = await Navigator.push(
          context, MaterialPageRoute(builder: (context) => CreateAccount()));

      // 3)ge username from create account, use it to make new user document in users collection.
      usersRef.document(user.id).setData({
        "id": user.id,
        "username": username,
        "photoUrl": user.photoUrl,
        "email": user.email,
        "displayName": user.displayName,
        "bio": "",
        "timestamp": timestamp
      });

      // make new user their own follower in order to get their posts in timeline
      await followersRef
          .document(user.id)
          .collection('userFollowers')
          .document(user.id)
          .setData({});

      doc = await usersRef.document(user.id).get(); //Get the id of current user

    }

    currentUser = User.fromDocument(doc);

  }

  @override
  void dispose() {
    pageController.dispose(); //we put it on dispose State when we switch pages
    super.dispose();
  }

  login() {
    googleSignIn.signIn();
  }

  logout() {
    googleSignIn.signOut();
  }

  onPageChanged(int pageIndex) {
    setState(() {
      this.pageIndex = pageIndex;
    });
  }

  onTap(int pageIndex) {
    pageController.animateToPage(
      pageIndex,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Scaffold buildAuthScreen() {
    return Scaffold(
      body: PageView(
        children: <Widget>[
          //RaisedButton(child: Text("Logout"),onPressed: logout,),
          Timeline(currentUser: currentUser),
          ActivityFeed(),
          Upload(currentUser: currentUser),
          Search(),
          Profile(profileId: currentUser?.id) //We use ? to make sure that it's not null in order to minimize errors
        ],
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: CupertinoTabBar(
          currentIndex: pageIndex,
          onTap: onTap,
          activeColor: Theme.of(context).primaryColor,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.whatshot),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active),
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.photo_camera,
                size: 35.0,
              ),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
            ),
          ]),
    );
//    return RaisedButton(
//      child: Text('Logout'),
//      onPressed: logout,
//    );
  }

  Widget buildUnAuthScreen() {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          Theme.of(context).accentColor,
          Theme.of(context).primaryColor,
        ], begin: Alignment.topRight, end: Alignment.bottomLeft)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, //up down
          crossAxisAlignment: CrossAxisAlignment.center, //left right
          children: [
            Text(
              'InstaFlutter',
              style: TextStyle(
                  fontFamily: "Signatra", fontSize: 90.0, color: Colors.white),
            ),
            GestureDetector(
              onTap: login,
              child: Container(
                width: 260,
                height: 60.0,
                decoration: BoxDecoration(
                  image: DecorationImage(
                      image:
                          AssetImage('assets/images/google_signin_button.png'),
                      fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isAuth ? buildAuthScreen() : buildUnAuthScreen();
  }
}
