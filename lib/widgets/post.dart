import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/models/user.dart';
import 'package:instaflutter/pages/activity_feed.dart';
import 'package:instaflutter/pages/comments.dart';
import 'package:instaflutter/pages/home.dart';
import 'package:instaflutter/widgets/custom_image.dart';
import 'package:instaflutter/widgets/progress.dart';


class Post extends StatefulWidget {
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String caption;
  final String mediaUrl;
  final dynamic likes;

  Post({
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.caption,
    this.mediaUrl,
    this.likes,
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      caption: doc['caption'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }

  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();


  int getLikeCount(likes){
    // If no likes, return 0
    if(likes == null){
      return 0;
    }

    int count = 0;
    // if the key is explicitly set to true, add a like
    likes.values.forEach((val){
      if(val == true){
        count += 1;
      }
    });
    return count;

  }

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    caption: this.caption,
    mediaUrl: this.mediaUrl,
    likes: this.likes,
    likeCount: getLikeCount(this.likes),
  );
}

class _PostState extends State<Post> {
  final String currentUSerId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String caption;
  final String mediaUrl;
  int likeCount;
  Map likes;
  bool isLiked;
  bool showHeart = false;

  _PostState({
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.caption,
    this.mediaUrl,
    this.likes,
    this.likeCount,
  });

  buildPostHeader(){
    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot){
        if(!snapshot.hasData){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.photoUrl),
          ),
          title: GestureDetector(
            onTap: () => showProfile(context, profileId: user.id),
            child: Text(
              user.username,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          subtitle: Text(location),
          trailing: IconButton(
            onPressed: () => print('deleting'),
            icon: Icon(Icons.more_vert),
          ),
        );
      },
    );
  }

  handleLikePost(){
    bool _isLiked = likes[currentUSerId] == true;

    if(_isLiked){   //if the current user previously liked the post
      postsRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .updateData({'likes.$currentUSerId': false});
      print(postId);

      //Update Like count if post is in our timeline
      timelineRef
          .document(currentUSerId)
          .collection('timelinePosts')
          .document(postId)
          .updateData({'likes.$currentUSerId': false});

      removeLikeFromActivityFeed();
      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUSerId] = false;
      });




    } else if(!_isLiked){
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({'likes.$currentUSerId': true});
          print(postId);

      //Update Like count if post is in our timeline
      timelineRef
          .document(currentUSerId)
          .collection('timelinePosts')
          .document(postId)
          .updateData({'likes.$currentUSerId': true});

      addLikeToActivityFeed();
      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUSerId] = true;
        showHeart = true;
      });


      Timer(Duration(milliseconds: 500), (){
        setState(() {
          showHeart = false;
        });
      });

    }



  }



  addLikeToActivityFeed(){
    // add a notification to the postOwner's feed only from other people and not ourselves
    bool isNotPostOwner = currentUSerId != ownerId;
      if(isNotPostOwner){
        activityFeedRef
            .document(ownerId)
            .collection("feedItems")
            .document(postId)
            .setData({
          "type": "like",
          "username": currentUser.username,
          "userId": currentUser.id,
          "userProfileImg": currentUser.photoUrl,
          "postId": postId,
          "mediaUrl":mediaUrl,
          "timestamp":timestamp,
        });
      }

  }

  removeLikeFromActivityFeed(){
    // add a notification to the postOwner's feed only from other people and not ourselves
    bool isNotPostOwner = currentUSerId != ownerId;
    if(isNotPostOwner){
      activityFeedRef
          .document(ownerId)
          .collection("feedItems")
          .document(postId)
          .get().then((doc) {           //Check if it exists
        if(doc.exists){
          doc.reference.delete();
        }
      });
    }

  }

  buildPostImage(){
      return GestureDetector(
        onDoubleTap: handleLikePost,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            //Image.network(mediaUrl),
            cachedNetworkImage(mediaUrl),
//            showHeart ? Animator(
//              duration: Duration(milliseconds: 300),
//              tween: Tween(begin: 0.8, end: 1.4),
//              curve: Curves.elasticOut,
//              cycles: 0,
//              builder: (context,anim,child) => Transform.scale(
//                  scale: anim.value,
//                  child: Icon(
//                    Icons.favorite,
//                    size: 80.0,
//                    color: Colors.red,
//                  ),
//              ),
//            ) : Text(""),
            showHeart ? Icon(Icons.favorite,size: 80.0,color: Colors.red,): Text(""),
          ],
        ),
      );
  }

  buildPostFooter(){
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 40.0, left: 20.0)),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20.0)),
            GestureDetector(
              onTap: () => showComments(
                context,        //we use context to be able to push data from post.dart to comments.dart page
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl,
              ),
              child: Icon(
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                "$likeCount likes",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Padding(padding: EdgeInsets.only(top: 5)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                username,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 5.0,bottom: 25.0),
              child: Text(caption),)
          ],
        ),
      ],
    );

  }

  @override
  Widget build(BuildContext context) {
    isLiked = likes[currentUSerId] == true; //sets the value of like to false by default when post has no like interaction to prevent errors

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        buildPostHeader(),
        buildPostImage(),
        buildPostFooter()
      ],
    );
  }
}

showComments(BuildContext context, { String postId, String ownerId, String mediaUrl }){

  Navigator.push(context, MaterialPageRoute(builder: (context){
    return Comments(
      postId: postId,
      postOwnerId: ownerId,
      postMediaUrl: mediaUrl
    );
  }));

}