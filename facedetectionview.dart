import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facesdk_plugin/facedetection_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'person.dart';

class FaceRecognitionView extends StatefulWidget {
  final List<Person> personList;
  final Function(String) onRecognized;

  FaceRecognitionView({
    Key? key,
    required this.personList,
    required this.onRecognized,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => FaceRecognitionViewState();
}

class FaceRecognitionViewState extends State<FaceRecognitionView> {
  dynamic _faces;
  double _livenessThreshold = 0;
  double _identifyThreshold = 0;
  bool _recognized = false;
  final _facesdkPlugin = FacesdkPlugin();
  FaceDetectionViewController? faceDetectionViewController;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? livenessThreshold = prefs.getString("liveness_threshold");
    String? identifyThreshold = prefs.getString("identify_threshold");
    setState(() {
      _livenessThreshold = double.parse(livenessThreshold ?? "0.7");
      _identifyThreshold = double.parse(identifyThreshold ?? "0.8");
    });
  }

  Future<void> faceRecognitionStart() async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");
    setState(() {
      _faces = null;
      _recognized = false;
    });
    await faceDetectionViewController?.startCamera(cameraLens ?? 1);
  }

  Future<bool> onFaceDetected(faces) async {
    if (_recognized) return false;
    if (!mounted) return false;

    setState(() {
      _faces = faces;
    });

    bool recognized = false;
    double maxSimilarity = -1;
    String maxSimilarityName = "";
    double maxLiveness = -1;

    if (faces.isNotEmpty) {
      var face = faces[0];
      for (var person in widget.personList) {
        double similarity =
            await _facesdkPlugin.similarityCalculation(face['templates'], person.templates) ?? -1;
        if (maxSimilarity < similarity) {
          maxSimilarity = similarity;
          maxSimilarityName = person.name;
          maxLiveness = face['liveness'];
        }
      }

      if (maxSimilarity > _identifyThreshold && maxLiveness > _livenessThreshold) {
        recognized = true;
      }
    }

    if (recognized) {
      widget.onRecognized(maxSimilarityName);
    }

    return recognized;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        faceDetectionViewController?.stopCamera();
        return true;
      },
      child: Stack(
        children: <Widget>[
          FaceDetectionView(faceRecognitionViewState: this),
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(
              painter: FacePainter(
                  faces: _faces, livenessThreshold: _livenessThreshold),
            ),
          ),
        ],
      ),
    );
  }
}

class FaceDetectionView extends StatefulWidget
    implements FaceDetectionInterface {
  final FaceRecognitionViewState faceRecognitionViewState;

  FaceDetectionView({Key? key, required this.faceRecognitionViewState})
      : super(key: key);

  @override
  Future<void> onFaceDetected(faces) async {
    await faceRecognitionViewState.onFaceDetected(faces);
  }

  @override
  State<StatefulWidget> createState() => _FaceDetectionViewState();
}

class _FaceDetectionViewState extends State<FaceDetectionView> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return UiKitView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
  }

  void _onPlatformViewCreated(int id) async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    widget.faceRecognitionViewState.faceDetectionViewController =
        FaceDetectionViewController(id, widget);

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.initHandler();

    int? livenessLevel = prefs.getInt("liveness_level");
    await widget.faceRecognitionViewState._facesdkPlugin
        .setParam({'check_liveness_level': livenessLevel ?? 0});

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.startCamera(cameraLens ?? 1);
  }
}

class FacePainter extends CustomPainter {
  dynamic faces;
  double livenessThreshold;
  FacePainter({required this.faces, required this.livenessThreshold});

  @override
  void paint(Canvas canvas, Size size) {
    if (faces != null) {
      var paint = Paint();
      paint.color = const Color.fromARGB(0xff, 0xff, 0, 0);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;

      for (var face in faces) {
        double xScale = face['frameWidth'] / size.width;
        double yScale = face['frameHeight'] / size.height;

        String title = "";
        Color color;
        if (face['liveness'] < livenessThreshold) {
          color = const Color.fromARGB(0xff, 0xff, 0, 0);
          title = "Spoof";
        } else {
          color = const Color.fromARGB(0xff, 0, 0xff, 0);
          title = "Real";
        }

        TextSpan span =
        TextSpan(style: TextStyle(color: color, fontSize: 20), text: title);
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(
            canvas, Offset(face['x1'] / xScale, face['y1'] / yScale - 30));

        paint.color = color;
        canvas.drawRect(
            Offset(face['x1'] / xScale, face['y1'] / yScale) &
            Size((face['x2'] - face['x1']) / xScale,
                (face['y2'] - face['y1']) / yScale),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
