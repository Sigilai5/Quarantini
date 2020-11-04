import 'dart:async';
import 'dart:io';
import 'package:toast/toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/pages/profile.dart';
import 'package:photofilters/photofilters.dart';
import 'package:path/path.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/models/user.dart';
import 'package:instaflutter/widgets/progress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as Im;
import 'package:uuid/uuid.dart';

import 'home.dart';

class Upload extends StatefulWidget {
  final User currentUser;

  Upload({ this.currentUser });

  @override
  _UploadState createState() => _UploadState();
}

class _UploadState extends State<Upload> with
  AutomaticKeepAliveClientMixin<Upload> {   //with AutomaticKeepAliveClientMixin helps in preserving our state when we change page and come back
  TextEditingController locationController = TextEditingController();
  TextEditingController captionController = TextEditingController();
  File file;
  File pickedFile;
  final picker = ImagePicker();
  bool isUploading = false;
  String postId = Uuid().v4();
  double latitude;
  double longitude;
  String currentPosition;
  String fileName;
  List<Filter> filters = presetFiltersList;



  handleTakePhoto() async{
    Navigator.pop(this.context); //Remove dialog first  also it should have been 'context' but path file brings issues
    final pickedFile = await picker.getImage(source: ImageSource.camera,
    maxHeight: 675,
      maxWidth: 960,
    );

    setState(() {
      file = File(pickedFile.path);
      this.file = file;
    });
  }

  handleChooseFromGallery(context) async {
    Navigator.pop(this.context); //Remove dialog first
    pickedFile = await ImagePicker.pickImage(source: ImageSource.gallery);
    fileName = basename(pickedFile.path);
    var image = Im.decodeImage(pickedFile.readAsBytesSync());
    image = Im.copyResize(image, width: 600);
    Map pickedfile = await Navigator.push(
        this.context,
        new MaterialPageRoute(
            builder: (context) => new PhotoFilterSelector(
                title: Text('Apply Filter'),
                filters: presetFiltersList,
                image: image,
                filename: fileName,
                loader: Center(child: circularProgress()),
                fit: BoxFit.contain,
            ),
        ),
    );
    if(pickedfile != null && pickedfile.containsKey('image_filtered')){
      setState(() {
        pickedFile = pickedfile['image_filtered'];
        file = pickedFile;
        this.file = file;
      });
    }

  }

  selectImage(parentContext){
    return showDialog(
        context: parentContext,
        builder: (context){
          return SimpleDialog(
            title: Text("Create Post"),
            children: <Widget>[
              SimpleDialogOption(
                child: Text("Photo with Camera"),
                onPressed: handleTakePhoto,
              ),
              SimpleDialogOption(
                child: Text("Image from Gallery"),
                onPressed: () => handleChooseFromGallery(this.context),
              ),
              SimpleDialogOption(
                child: Text("Cancel"),
                onPressed:() => Navigator.pop(context) , //remove dialog
              ),

            ],
          );
        }
    );
  }

  Container buildSplashScreen(){
    return Container(
      color: Theme.of(this.context).accentColor.withOpacity(0.6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SvgPicture.asset('assets/images/upload.svg', height: 260.0),
          Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: RaisedButton(
              color: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
              child: Text("Upload Image", style: TextStyle(
                color: Colors.white,
                fontSize: 22.0
              ),
              ),
              onPressed: () => selectImage(this.context),
            ),
          )
        ],
      ),
    );
  }

  clearImage(){
    setState(() {
      file = null;
    });
  }

  //Compress imge to save on space
  compressImage() async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    Im.Image imageFile = Im.decodeImage(file.readAsBytesSync());
    final compressedImageFile = File('$path/img_$postId.jpg')..writeAsBytesSync(Im.encodeJpg(imageFile, quality: 85));
    setState(() {
      file = compressedImageFile;
    });
  }

  //Save image file in storage and get the url
  Future<String>uploadImage(imageFile) async{
    StorageUploadTask uploadTask = storageRef.child("post_$postId.jpg").putFile(imageFile);
    StorageTaskSnapshot storageSnap = await uploadTask.onComplete;
    String downloadUrl = await storageSnap.ref.getDownloadURL();
    return downloadUrl;
  }

  createPostInFirestore({String mediaUrl, String caption, String location}){
    postsRef
      .document(currentUser.id)
      .collection("userPosts")
      .document(postId)
      .setData({
      "postId": postId,
      "ownerId": currentUser.id,
      "username":currentUser.username,
      "mediaUrl": mediaUrl,
      "caption": caption,
      "location": location,
      "timestamp": timestamp,
      "likes": {currentUser.id : false},
      "post_latitude":latitude,
      "post_longitude":longitude,
    });
  }


  handleSubmit() async {
    setState(() {
      isUploading = true;
    });
    await compressImage();
    String mediaUrl = await uploadImage(file);
    createPostInFirestore(
      mediaUrl: mediaUrl,
      caption: captionController.text,
      location: locationController.text,
    );

      updateTimeLine(
        mediaUrl: mediaUrl,
        caption: captionController.text,
        location: locationController.text,
      );  //Get timeline data if page is refreshed


    captionController.clear();
    locationController.clear();


    setState(() {
      file = null;
      isUploading = false;
    });

    //Navigate Back to Profile Page
    isUploading ?  Text("") : Navigator.push(this.context,MaterialPageRoute(builder: (context)=> Profile(profileId: currentUser.id)));

    //Show toast
    isUploading ? Text("") : showToast("Post Uploaded!",duration: Toast.LENGTH_LONG, gravity: Toast.BOTTOM);



  }

  //Update TimeLine if there is new data
  updateTimeLine({String mediaUrl, String caption, String location}) async {
    // 1)Create timeline for followed users posts
    QuerySnapshot snapshot = await followersRef
        .document(widget.currentUser.id)
        .collection('userFollowers')
        .getDocuments();

        snapshot.documents.forEach((doc) {
          if(doc.exists){

            timelineRef
                .document(doc['userFollowerId'])
                .collection('timelinePosts')
                .document(postId)
                .setData({
              "postId": postId,
              "ownerId": currentUser.id,
              "username":currentUser.username,
              "mediaUrl": mediaUrl,
              "caption": caption,
              "location": location,
              "timestamp": timestamp,
              "likes": {currentUser.id : false},
              "post_latitude":latitude,
              "post_longitude":longitude,
            },);

          }

        });


  }

  showToast(String msg, {int duration, int gravity}) {
    Toast.show(msg, this.context, duration: duration, gravity: gravity);
  }

  Scaffold buildUploadForm(){
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white70,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black,),
            onPressed: clearImage),
        title: Center(child: Text("Caption Post", style: TextStyle(color:Colors.black),)),
        actions: [
          FlatButton(
            onPressed: isUploading ? null : () => handleSubmit(),
            child: Text(
              "Post",
              style: TextStyle(color: Colors.blueAccent,fontWeight: FontWeight.bold,fontSize:20.0 ),

            ),
          )
        ],
      ),
      body: ListView(
        children: <Widget>[
          isUploading ? linearProgress() : Text(""),
          Container(
            height: 220.0,
            width: MediaQuery.of(this.context).size.width * 0.9,
            child: Center(
              child: AspectRatio(
                  aspectRatio: 16/9,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                          image: FileImage(file)
                      )
                    ),
                  ),
              ),
            ),
          ),

          Padding(
              padding: EdgeInsets.only(top: 10.0)
          ),

          ListTile(
            leading: CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(
                currentUser.photoUrl
              ),
            ),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: captionController,
                decoration: InputDecoration(
                  hintText: "Write a caption...",
                  border: InputBorder.none
                ),
              ),
            ),
          ),

          Divider(),

          ListTile(
            leading: Icon(Icons.pin_drop, color: Colors.orange,size: 35.0,),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: locationController,
                decoration: InputDecoration(
                  hintText: "Where was this photo taken?",
                  border: InputBorder.none,
                ),
              )
            ),
          ),

          Container(
            width: 200.0,
            height: 100.0,
            alignment: Alignment.center,
            child: RaisedButton.icon(
                onPressed: getUserLocation,
                icon: Icon(
                  Icons.my_location,
                  color: Colors.white
                ),
                label: Text("Use Current Location",
                style: TextStyle(color: Colors.white),),
                color: Colors.blue,
                shape:RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ) ,
            ),
          )

        ],
      ),
    );
  }

  getUserLocation() async{
    Position position = await Geolocator().getCurrentPosition
      (desiredAccuracy: LocationAccuracy.high);
    List<Placemark> placemarks = await Geolocator()
    .placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark placemark = placemarks[0];
    String completeAddress = '${placemark.subThoroughfare} ${placemark.thoroughfare},${placemark.subLocality},${placemark.locality},${placemark.subAdministrativeArea},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}';
    print(completeAddress);
    String formattedAddress = "${placemark.locality}, ${placemark.country}";
    locationController.text = formattedAddress;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
  }

  bool get wantKeepAlive => true;   //for maintaining state

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return file == null ? buildSplashScreen() : buildUploadForm();
  }
}
