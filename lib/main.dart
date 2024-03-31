import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as mlkit;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front);
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FaceRecognitionScreen(camera: camera),
    );
  }
}

class FaceRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;

  const FaceRecognitionScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  late CameraController _cameraController;
  bool _isDetectingFaces = false;
  final mlkit.FaceDetector _faceDetector = mlkit.GoogleMlKit.vision.faceDetector();
  late SharedPreferences _prefs;
  List<double> _storedFaceData = [];
  final double _threshold = 80.0;
  bool _isFaceRegistered = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeSharedPreferences();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(widget.camera, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _initializeSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final storedFaceDataStringList = _prefs.getStringList('face_data') ?? [];
    if (storedFaceDataStringList.isNotEmpty) {
      _storedFaceData = storedFaceDataStringList.map((str) => double.parse(str)).toList();
      _isFaceRegistered = true;
    }
  }

  Future<void> _captureAndRegisterFace() async {
    try {
      final image = await _cameraController.takePicture();
      await _registerFace(image.path);
      setState(() {
        _isDetectingFaces = false;
        _isFaceRegistered = true;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _registerFace(String imagePath) async {
    final inputImage = mlkit.InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty) {
      final faceData = _extractFaceData(faces[0]);
      _storeFaceData(faceData);
    } else {
      print('No face detected.');
    }
  }

 Future<void> _detectAndRecognizeFace() async {
  try {
    final image = await _cameraController.takePicture();
    await _detectAndRecognizeFaceFromPath(image.path);
    setState(() {
      _isDetectingFaces = false;
    });
  } catch (e) {
    print(e);
  }
}

Future<void> _detectAndRecognizeFaceFromPath(String imagePath) async {
  final inputImage = mlkit.InputImage.fromFilePath(imagePath);
  final faces = await _faceDetector.processImage(inputImage);
  if (faces.isNotEmpty) {
    final faceData = _extractFaceData(faces[0]);
    if (_isFaceRegistered) {
      final matchPercentage = _compareFaceData(faceData);
      if (matchPercentage >= _threshold) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
      } else {
        print('Face not recognized.');
      }
    } else {
      print('No registered face found.');
    }
  } else {
    print('No face detected.');
  }
}

  List<double> _extractFaceData(mlkit.Face face) {
    final boundingBox = face.boundingBox!;
    return [boundingBox.left, boundingBox.top, boundingBox.width, boundingBox.height];
  }

  double _compareFaceData(List<double> faceData) {
    if (_storedFaceData.isEmpty) {
      return 0.0; // Or another default value if no stored data
    }

    final storedFaceSize = _storedFaceData[2] * _storedFaceData[3];
    final detectedFaceSize = faceData[2] * faceData[3]; // width * height
    final matchPercentage = detectedFaceSize / storedFaceSize * 100;
    return matchPercentage;
  }

  void _storeFaceData(List<double> faceData) {
    final List<String> faceDataStringList = faceData.map((double value) => value.toString()).toList();
    _prefs.setStringList('face_data', faceDataStringList);
    setState(() {
      _storedFaceData = faceData;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isFaceRegistered ? null : () {
                      setState(() {
                        _isDetectingFaces = true;
                      });
                      _captureAndRegisterFace();
                    },
                    child: Text('Register Face'),
                    style: ElevatedButton.styleFrom(
                      primary: _isFaceRegistered ? Colors.grey : Colors.blue,
                      onPrimary: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isDetectingFaces = true;
                      });
                      _detectAndRecognizeFace();
                    },
                    child: Text('Detect Face'),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.orange,
                      onPrimary: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Text('Welcome home!'),
      ),
    );
  }
}
