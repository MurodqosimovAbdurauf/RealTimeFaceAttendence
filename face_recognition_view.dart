import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'person.dart';

class FaceRecognitionView extends StatefulWidget {
  final List<Person> personList;
  const FaceRecognitionView({Key? key, required this.personList}) : super(key: key);

  @override
  State<FaceRecognitionView> createState() => _FaceRecognitionViewState();
}

class _FaceRecognitionViewState extends State<FaceRecognitionView> {
  static const platform = MethodChannel('com.example.facedetection/channel');
  List<Person> _matchedPersons = [];

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_handleMethod);
  }

  Future<void> _handleMethod(MethodCall call) async {
    if (call.method == "onFaceDetected") {
      final List<dynamic> faces = call.arguments;
      await _matchFaces(faces);
    }
  }

  Future<void> _matchFaces(List<dynamic> faces) async {
    List<Person> matches = [];

    for (var face in faces) {
      for (var person in widget.personList) {
        // TODO: similarity hisoblash uchun platform metodi yoki custom plugin kerak bo'ladi
        // Shartli tekshiruv: yuz ID si mos kelsa (demo tarzida)
        if (face['id'] == person.id) {
          matches.add(person);
        }
      }
    }

    setState(() {
      _matchedPersons = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: defaultTargetPlatform == TargetPlatform.android
                ? AndroidView(viewType: 'facedetectionview')
                : UiKitView(viewType: 'facedetectionview'),
          ),
          Expanded(
            flex: 1,
            child: _matchedPersons.isEmpty
                ? const Center(child: Text("No match yet."))
                : ListView.builder(
              itemCount: _matchedPersons.length,
              itemBuilder: (context, index) {
                final person = _matchedPersons[index];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: MemoryImage(person.faceJpg)),
                  title: Text("${person.name} ${person.surname}"),
                  subtitle: Text(person.contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
