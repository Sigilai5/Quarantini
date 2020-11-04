import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/pages/activity_feed.dart';
import 'package:instaflutter/pages/home.dart';
import 'package:instaflutter/widgets/header.dart';
import 'package:instaflutter/widgets/progress.dart';
import 'package:timeago/timeago.dart' as timeago;

class Comments extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final String postMediaUrl;

  Comments({
  this.postId,
  this.postOwnerId,
  this.postMediaUrl
  });

  @override
  CommentsState createState() => CommentsState(
    postId: this.postId,
    postOwnerId: this.postOwnerId,
    postMediaUrl: this.postMediaUrl
  );
}

class CommentsState extends State<Comments> {
  TextEditingController commentController = TextEditingController();
  final String postId;
  final String postOwnerId;
  final String postMediaUrl;

  CommentsState({
    this.postId,
    this.postOwnerId,
    this.postMediaUrl
  });

  //I've realized that if one input is invalid,the data won't save in Firebase e.g if you put commentController instead of commentController.text
  addComment(){
    commentsRef
        .document(postId)
        .collection("comments")
        .add({
      "username": currentUser.username,
      "comment":commentController.text,
      "timestamp": timestamp,
      "avatarUrl":currentUser.photoUrl,
      "userId": currentUser.id,
    });

    // add a notification to the postOwner's feed only from other people and not ourselves
    bool isNotPostOwner = currentUser.id != postOwnerId;
    if(!isNotPostOwner){
      activityFeedRef
          .document(postOwnerId)
          .collection("feedItems")
          .add({
        "type": "comment",
        "commentData":commentController.text,
        "timestamp":timestamp,
        "username": currentUser.username,
        "userId": currentUser.id,
        "userProfileImg": currentUser.photoUrl,
        "postId": postId,
        "mediaUrl":postMediaUrl,
      });
    }

    commentController.clear();
  }

  buildComments(){
    return StreamBuilder(
      stream: commentsRef.document(postId).collection("comments")
          .orderBy("timestamp", descending: false).snapshots(),
      builder: (context, snapshot){
        if(!snapshot.hasData){
          return circularProgress();
        } else if(snapshot.hasData){
          List<Comment> comments = [];
          snapshot.data.documents.forEach((doc){
            comments.add(Comment.fromDocument(doc));
          });
          return ListView(children: comments,);
        }else{
          return Text(" No comments"); //appears not to be working at the moment,will debug
        }

      },
    );


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context,titleText: "Comments"),
      body: Column(
        children: <Widget>[
          Expanded(child: buildComments()),
          Divider(),
          ListTile(
            title: TextFormField(
              controller: commentController,
              decoration: InputDecoration(labelText: "Write a comment..."),
            ),
            trailing: OutlineButton(
              onPressed:addComment,
              borderSide: BorderSide.none,
              child: Text("Post"),
            ),
          ),
        ],
      ),
    );
  }
}

class Comment extends StatelessWidget {
  final String username;
  final String userId;
  final String avatarUrl;
  final String comment;
  final Timestamp timestamp;


  Comment({
  this.username,
  this.userId,
  this.avatarUrl,
  this.comment,
  this.timestamp
  });

  factory Comment.fromDocument(DocumentSnapshot doc){
    return Comment(
      username: doc['username'],
      userId: doc['userId'],
      comment: doc['comment'],
      timestamp: doc['timestamp'],
      avatarUrl: doc['avatarUrl'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: () => showProfile(context, profileId: userId),
          child: ListTile(
            title: Text('@'+ username),
            subtitle: Text(comment),
            leading: CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            ),
            trailing: Text(timeago.format(timestamp.toDate())),
          ),
        ),Divider(),
      ],
    );
  }
}
