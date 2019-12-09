import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

void main() => runApp(MyApp());

bool fpCalled = false;

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: FaceDetectPage(title: 'Inhuman'),
    );
  }
}

class FaceDetectPage extends StatefulWidget {
  FaceDetectPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  FaceDetectPageState createState() => FaceDetectPageState();
}

class FaceDetectPageState extends State<FaceDetectPage> {
  ImageSource isrc = ImageSource.camera;
  var _imageFile;
  var _faces;
  int _currPageIndex = 0;
  List<ImagesAndFaces> _pages = <ImagesAndFaces>[];

  void _getImageAndDetectFaces() async {
    final imageFile = await ImagePicker.pickImage(source: isrc);

    final image = FirebaseVisionImage.fromFile(imageFile);
    final faceDetector = FirebaseVision.instance
        .faceDetector(FaceDetectorOptions(enableLandmarks: false));

    final faces = await faceDetector.processImage(image);
    _pages.add(new ImagesAndFaces(imageFile: imageFile, faces: faces));

    if (mounted) {
      setState(() {
        print(_pages != null);
        _imageFile = imageFile;
        _faces = faces;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
      ),
      drawer: Drawer(
        elevation: 10,
        child: Container(
            //color: Colors.white,

            child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 7),
                          child: Text(
                            'SETTINGS',
                            style: TextStyle(color: Colors.white),
                          ))
                    ],
                  )
                ],
              ),
              decoration: BoxDecoration(color: Colors.deepPurple),
            ),
            ListTile(
              title: Text(
                'Change Source to: ' +
                    (isrc == ImageSource.camera ? 'Gallery' : 'Camera'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  isrc = (isrc == ImageSource.camera
                      ? ImageSource.gallery
                      : ImageSource.camera);
                });
              },
            )
          ],
        )),
      ),
      body: (_imageFile != null && _faces != null && _pages.length > 0
          ? PageView.builder(
              pageSnapping: true,
              physics: BouncingScrollPhysics(),
              itemCount: _pages.length,
              itemBuilder: (context, i) {
                return _pages[i];
              },
              onPageChanged: (index) {
                _currPageIndex = index;
              },
            )
          : Center(
              child: Text('Select a picture to get started!'),
            )),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red,
              child: Icon(Icons.remove),
              onPressed: () {
                setState(() {
                  _pages.removeAt(_currPageIndex);
                });
              },
              tooltip: 'Pick an image',
            ),
          ),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.blue,
            child: Icon(isrc == ImageSource.camera
                ? Icons.add_a_photo
                : Icons.add_photo_alternate),
            onPressed: () {
              _getImageAndDetectFaces();
            },
            tooltip: 'Pick an image',
          )
        ],
      ),
    );
  }
}

class ImagesAndFaces extends StatelessWidget {
  ImagesAndFaces({Key key, @required this.imageFile, @required this.faces})
      : super(key: key);
  File imageFile;
  final List<Face> faces;
  ui.Image image;

  Future<ui.Image> setImageFromFile() async {
    final data = await imageFile.readAsBytes();
    return await decodeImageFromList(data);
  }

  Future<void> placeholderFuture() async {
    image = await setImageFromFile();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: <Widget>[
          Flexible(
              flex: 2,
              child: Container(
                  constraints: BoxConstraints.expand(),
                  child: FutureBuilder(
                    future: placeholderFuture(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.done) {
                        return Padding(
                            padding: EdgeInsets.zero,
                            child: FittedBox(
                              child: SizedBox(
                                  height: image.height.toDouble(),
                                  width: image.height.toDouble(),
                                  child: CustomPaint(
                                      foregroundPainter:
                                          FacePainter(image, faces),
                                      ),
                            )));
                      } else {
                        return Center(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator()));
                      }
                    },
                  ))), //Image.file(imageFile, fit: BoxFit.cover))),
          Flexible(
              flex: 1,
              child: ListView(
                  children: faces
                      .map<Widget>((f) => FaceCoordinates(
                            face: f,
                          ))
                      .toList()))
        ],
      ),
    );
  }
}

class FaceCoordinates extends StatefulWidget {
  FaceCoordinates({Key key, @required this.face}) : super(key: key);
  final Face face;

  @override
  FaceCoordinatesState createState() => FaceCoordinatesState();
}

class FaceCoordinatesState extends State<FaceCoordinates> {
  bool cbVal = false;

  @override
  Widget build(BuildContext context) {
    final pos = widget.face.boundingBox;
    return ListTile(
      title: Text('${pos.top}, ${pos.left}, ${pos.bottom}, ${pos.right}'),
      leading: Checkbox(
        value: cbVal,
      ),
      onTap: () {
        setState(() {
          cbVal = !cbVal;
        });
      },
    );
  }
}

class FacePainter extends CustomPainter {
  FacePainter(this.image, this.faces);

  final List<Face> faces;
  var image;

  @override
  void paint(Canvas canvas, Size size) async {
    // Don't draw on the screen, but on another canvas which can be recorded
    fpCalled = true;

    ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    Canvas canvasDup = Canvas(pictureRecorder);
    canvas.drawImage(image, Offset.zero, Paint());

    for (var i = 0; i < faces.length; i++) {
      canvas.drawRect(faces[i].boundingBox, Paint());
    }

    //ui.Picture finalPict = pictureRecorder.endRecording();
    //ui.Image finalImage = await finalPict.toImage(size.width.toInt(), size.height.toInt());

    //File(join((await getTemporaryDirectory()).path, 'temp.png')).writeAsBytesSync((await finalImage.toByteData()).buffer.asInt8List());
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) =>
      //image != oldDelegate.image ||
      faces != oldDelegate.faces;
}
