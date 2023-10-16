import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ml_kit_ocr/ml_kit_ocr.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  XFile? image;
  String recognitions = '';
  String timeElapsed = '';
  bool isProcessing = false;
  String linesAfterIDVNM = '';
  String? ID_front = '';

  Map<String, String?> getMRZData(String data) {
    RegExp regex = RegExp(
        r'([A-Z0-9<]{15})([0-9]{12})([0-9<]{3})\n([0-9]{6})([A-Z0-9]{2})([0-9]{6}).*?\n');

    RegExpMatch? match = regex.firstMatch(data);

    String? id = match!.group(2);
    String? birth = fomatDate(match!.group(4), 1);
    String? expiry = fomatDate(match!.group(6), 0);

    Map<String, String?> re = {"id": id, "birth": birth, "expiry": expiry};
    return re;
  }

  String getFullYearBirth(String year) {
    int currentYear = DateTime.now().year;
    int shortYear = int.parse(year);

    int fullYear = (currentYear ~/ 100) * 100 + shortYear;

    if (fullYear > currentYear) {
      fullYear -= 100;
    }

    return fullYear.toString();
  }

  String getFullYearExpiry(String year) {
    int currentYear = DateTime.now().year;
    int shortYear = int.parse(year);

    int fullYear = (currentYear ~/ 100) * 100 + shortYear;

    return fullYear.toString();
  }

  String fomatDate(String? input, int isBirth) {
    String year = input!.substring(0, 2);
    String month = input!.substring(2, 4);
    String day = input!.substring(4, 6);

    String fullYear =
        isBirth == 1 ? getFullYearBirth(year) : getFullYearExpiry(year);

    return '$fullYear-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MlKit ocr example app'),
        ),
        body: ListView(
          physics: const ClampingScrollPhysics(),
          children: [
            const SizedBox(height: 20),
            if (image != null)
              SizedBox(
                height: 200,
                width: 200,
                child: InteractiveViewer(
                  child: Image.file(
                    File(image!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (recognitions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText('Recognized Text:\n$linesAfterIDVNM'),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    image = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    recognitions = '';
                    timeElapsed = '';
                    setState(() {});
                  },
                  child: const Text('Pick Image'),
                ),
                if (image != null)
                  isProcessing
                      ? const Center(
                          child: CircularProgressIndicator.adaptive(),
                        )
                      : ElevatedButton(
                          onPressed: () async {
                            recognitions = '';
                            final ocr = MlKitOcr();
                            final stopwatch = Stopwatch()..start();
                            isProcessing = true;
                            setState(() {
                              linesAfterIDVNM = '';
                              recognitions = '';
                            });
                            final result = await ocr.processImage(
                                InputImage.fromFilePath(image!.path));
                            timeElapsed =
                                stopwatch.elapsedMilliseconds.toString();
                            isProcessing = false;
                            stopwatch.reset();
                            stopwatch.stop();

                            bool shouldSaveLines = false;
                            bool isFront = false;
                            for (var blocks in result.blocks) {
                              for (var lines in blocks.lines) {
                                recognitions += '\n';
                                for (var words in lines.elements) {
                                  recognitions += words.text;
                                }
                                final lineText = lines.elements
                                    .map((words) => words.text)
                                    .join();
                                if (lineText.startsWith('CĂNCƯỚCCÔNGDÂN') ||
                                    isFront == true) {
                                  isFront = true;
                                  if (lineText.startsWith('sóI')) {
                                    RegExp regExp = RegExp(r'\d+');
                                    Match? match = regExp.firstMatch(lineText);
                                    ID_front = match?.group(0);
                                    // break;
                                  }
                                } else {
                                  if (shouldSaveLines) {
                                    linesAfterIDVNM += (lineText + '\n');
                                  }

                                  if (lineText.startsWith('IDVNM')) {
                                    shouldSaveLines = true;
                                    linesAfterIDVNM += (lineText + '\n');
                                  }
                                }
                              }
                              print('Recognized Text: $recognitions');
                            }
                            if (linesAfterIDVNM.isEmpty) {
                              print('ID_FRONT: $ID_front');
                            } else {
                              Map<String, String?> re =
                                  getMRZData(linesAfterIDVNM);
                              print(
                                  'Lines after IDVNM: ${getMRZData(linesAfterIDVNM)}');
                              print('ID: ${re["id"]}');
                              print('Birth: ${re["birth"]}');
                              print('Expiry: ${re["expiry"]}');
                            }
                          },
                          child: const Text('Predict from Image'),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
