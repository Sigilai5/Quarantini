import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/models/user.dart';
import 'package:instaflutter/pages/edit_profile.dart';
import 'package:instaflutter/pages/home.dart';
import 'package:instaflutter/widgets/header.dart';
import 'package:instaflutter/widgets/post.dart';
import 'package:instaflutter/widgets/post_tile.dart';
import 'package:instaflutter/widgets/progress.dart';


class Profile extends StatefulWidget {
  final String profileId;


  Profile({ this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final String currentUserId = currentUser?.id;
  String postOrientation = "grid";
  bool isLoading = false;
  int postCount = 0;
  List<Post> posts = [];
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;


  @override
  void initState(){
    super.initState();
    getProfilePosts();
    getFollowers();
    getFollowing();
    checkIfFollowing();
  }

  checkIfFollowing() async {
    DocumentSnapshot doc = await followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId)
        .get();
        setState(() {
          isFollowing = doc.exists;
        });
  }

  getFollowers() async {
    QuerySnapshot snapshot = await followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .getDocuments();
    setState(() {
      followerCount = snapshot.documents.length;

    });
  }

  getFollowing() async {
    QuerySnapshot snapshot = await followingRef
        .document(widget.profileId)
        .collection('userFollowing')
        .getDocuments();
    setState(() {
      followingCount = snapshot.documents.length;
    });
  }

  getProfilePosts() async{
    setState(() {
      isLoading = true;
    });
    QuerySnapshot snapshot = await postsRef
        .document(widget.profileId)
        .collection('userPosts')
        .orderBy('timestamp', descending: true)
        .getDocuments();

    setState(() {
      isLoading = false;
      postCount = snapshot.documents.length;
      posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    });
    
  }


  Column buildCountColumn(String label, int count){
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          count.toString(),
          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        ),
        Container(
          margin: EdgeInsets.only(top: 4.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15.0,
              fontWeight: FontWeight.w400,
            ),
          ),
        )
      ],
    );
  }

  editProfile(){
    Navigator.push(context,
    MaterialPageRoute(builder: (context)
    => EditProfile(currentUserId:currentUserId)
    ));
  }

  Container buildButton({ String text, Function function }){
      return Container(
        padding: EdgeInsets.only(top: 2.0),
        child: FlatButton(
            onPressed: function,
            child: Container(
              width: 215.0,
              height: 27.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFollowing ? Colors.white : Colors.blue,
                border: Border.all(
                  color: isFollowing ? Colors.grey : Colors.blue,
                ),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Text(
                text,
                style: TextStyle(
                color: isFollowing ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                ),
              ),
            )
        ),
      );
  }

  buildProfileButton(){
    // when viewing your own profile
    bool isProfileOwner = currentUserId == widget.profileId;
    if(isProfileOwner){
      return buildButton(
        text: "Edit Profile",
        function:editProfile
      );

    }else if(isFollowing){
      return buildButton(text: "Unfollow", function: handleUnfollowUser);
    }else if(!isFollowing){
      return buildButton(text: "Follow", function: handleFollowUser);
    }
  }

  handleUnfollowUser() async{
    setState(() {
      isFollowing = false;
    });
    //Remove Follower
    followersRef
    .document(widget.profileId)
    .collection('userFollowers')
    .document(currentUserId)
    .get().then((doc){
      if(doc.exists){
        doc.reference.delete();
      }
    });

    //Remove following
    followingRef
    .document(currentUserId)
    .collection('userFollowing')
    .document(widget.profileId)
    .get().then((doc){
      if(doc.exists){
        doc.reference.delete();
      }
    });

    //delete activity feed item
    activityFeedRef
    .document(widget.profileId)
    .collection('feedItems')
    .document(currentUserId)
    .get().then((doc){
      if(doc.exists){
        doc.reference.delete();
      }
    });


    //Remove timeline for unfollowed users

    QuerySnapshot snapshot = await postsRef
        .document(widget.profileId)
        .collection('userPosts')
        .getDocuments();

    snapshot.documents.forEach((doc) {
      if(doc.exists){

        final postID = doc['postId'];
        timelineRef
            .document(currentUserId)
            .collection('timelinePosts')
            .document(postID)
            .delete();

      }

    });



  }

  handleFollowUser() async{
    setState(() {
      isFollowing = true;
    });
    //Make auth user follower of THAT user (update THEIR followers collection)
    followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId)
        .setData({
        'userFollowerId' : currentUserId
    });

    //Put THAT user on YOUR following collection (update your follwing collection)
    followingRef
        .document(currentUserId)
        .collection('userFollowing')
        .document(widget.profileId)
        .setData({
        'userFollowingId' : widget.profileId
    });

    //add activity feed item to notify new follower
    activityFeedRef
        .document(widget.profileId)
        .collection('feedItems')
        .document(currentUserId)
        .setData({
      "type": "follow",
      "ownerId": widget.profileId,
      "username": currentUser.username,
      "userId": currentUserId,
      "userProfileImg":currentUser.photoUrl,
      "timestamp": timestamp,
    });


    // 1)Create timeline for followed users posts
     QuerySnapshot snapshot = await followingRef
        .document(currentUserId)
        .collection('userFollowing')
        .getDocuments();

     snapshot.documents.forEach((doc) async {
       //print(doc['userFollowingId'].toString());
//       userSearchItems.add(doc['userFollowingId']);

        if(doc.exists){
          QuerySnapshot snapshot = await postsRef
              .document(doc['userFollowingId'])
              .collection('userPosts')
              .getDocuments();

          snapshot.documents.forEach((doc) {
            if(doc.exists){

              final postID = doc['postId'];
              timelineRef
                  .document(currentUserId)
                  .collection('timelinePosts')
                  .document(postID)
                  .setData(doc.data);

            }

          });

        }

     });




  }

  buildProfileHeader() {
    return FutureBuilder(
        future: usersRef.document(widget.profileId).get(),
        builder: (context, snapshot){
          if(!snapshot.hasData){
            return circularProgress();
          }
          User user = User.fromDocument(snapshot.data);
          return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 40.0,
                        backgroundColor: Colors.grey,
                        backgroundImage: CachedNetworkImageProvider(user.photoUrl),
                      ),


                      Expanded(
                          flex: 2,
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  buildCountColumn("posts",postCount),
                                  buildCountColumn("followers",followerCount),
                                  buildCountColumn("following",followingCount),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  buildProfileButton()
                                ],
                              ),

                            ],
                          ),
                      ),


                    ],
                  ),

                  Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(top: 12.0),
                    child: Text(
                      user.username,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0
                      ),
                    ),
                  ),

                  Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      user.displayName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(top: 2.0),
                    child: Text(
                      user.bio,
                    ),
                  ),

                ],
              ),
          );

        }
    );
  }

  profilePosts(){
    if(posts.isEmpty == false){
      return buildProfilePosts();
    }else{
      return Padding(
        padding: const EdgeInsets.all(100.0),
        child: Center(child: Text("No Posts Yet",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),)),
      );
    }
  }

  buildProfilePosts(){
    if(isLoading){
      return circularProgress();
    } else if(postOrientation == "grid"){
      List<GridTile> gridTiles = [];
      posts.forEach((post) {
        gridTiles.add(GridTile(child: PostTile(post)));
      });

      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    } else if(postOrientation == "list"){
      return Column(
        children: posts,
      );
    }
  }

  setPostOrientation(String postOrientation){
    setState(() {
      this.postOrientation = postOrientation;
    });
  }

  buildTogglePostOrientation(){
    return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            onPressed: () => setPostOrientation("grid"),
            icon: Icon(Icons.grid_on),
            color: postOrientation == "grid" ? Theme.of(context).primaryColor : Colors.grey,
          ),
          IconButton(
            onPressed: () => setPostOrientation("list"),
            icon: Icon(Icons.list),
            color: postOrientation == "list" ? Theme.of(context).primaryColor : Colors.grey,
          )
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context,isAppTitle: false, titleText: "Profile"),
      body: ListView(
        children: <Widget>[
          buildProfileHeader(),
          Divider(),
          buildTogglePostOrientation(),
          Divider(
            height: 0.0, //Remove any padding
          ),
          profilePosts(),

        ],
      ),
    );
  }
}
