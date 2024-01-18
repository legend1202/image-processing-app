import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';

List<CameraDescription> cameras =
    []; //stores all the camera available in the device which incase of mobile is one
double camera_mag = 0.0;
double lens_mag = 0.0;
double tot_mag = 0.0;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras(); //selects the available camera
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Example',
      home: TakePictureScreen(),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  double _maxZoomLevel = 1.0;
  double _scale = 1.0;
  double? _value;
  @override
  void initState() {
    super.initState();
    _controller = CameraController(
        cameras[0],
        ResolutionPreset
            .medium); //required for pixel to microns conversion rate
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale *= details.scale;
      _scale = max(1.0, min(_scale, _maxZoomLevel));
      _controller.setZoomLevel(_scale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set your Camera to maximum zoom')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            _controller.getMaxZoomLevel().then((maxZoom) {
              setState(() {
                _maxZoomLevel = maxZoom;
                camera_mag = _maxZoomLevel;
              });
            });
            return GestureDetector(
              onScaleUpdate: _onScaleUpdate,
              child: Center(
                child: CameraPreview(_controller),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final path = (await _controller.takePicture()).path;
            final result =
                await ImageGallerySaver.saveImage(File(path).readAsBytesSync());
            setState(() {
              _value = null;
            });
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return InputValueDialog(
                  key: UniqueKey(),
                  onSave: (value) {
                    _value = value;
                    lens_mag = _value!;
                    Navigator.of(context).pop();
                  },
                );
              },
            );
          } catch (e) {
            // ignore: avoid_print
            print(e);
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 60.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePage(),
                  ),
                );
              },
              child: const Text("Go to Image Page"),
            ),
          ),
        ),
      ),
    );
  }
}

class InputValueDialog extends StatefulWidget {
  final Function(double) onSave;
  const InputValueDialog({required Key key, required this.onSave})
      : super(key: key);
  @override
  _InputValueDialogState createState() => _InputValueDialogState();
}

class _InputValueDialogState extends State<InputValueDialog> {
  final TextEditingController _textEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Enter the magnification of lens "),
      content: TextField(
        controller: _textEditingController,
        keyboardType: TextInputType.number,
      ),
      actions: <Widget>[
        ElevatedButton(
          child: const Text("Save"),
          onPressed: () {
            double? value = double.tryParse(_textEditingController.text);
            if (value != null) {
              widget.onSave(value);
            }
          },
        ),
        ElevatedButton(
          child: const Text("Cancel"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class ImagePage extends StatefulWidget {
  @override
  _ImagePageState createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  Offset _start = Offset.zero;
  Offset _end = Offset.zero;
  double _distance = 0;
  File? image;
  double conversionFactor = 0.1; // 1 cm = 10 pixels

  final picker = ImagePicker(); //to select image from gallery

  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        File _image = File(pickedFile.path);
        image = _image;
      } else {
        print('No image selected.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Distance Between Two Points on Image'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Stack(
                children: [
                  image == null
                      ? const Text('No image selected.')
                      : Image.file(image!),
                  CustomPaint(
                    painter: LinePainter(_start, _end),
                  ),
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _start = details
                            .localPosition; //the location of the the first of two points
                        _end = Offset.zero;
                        _distance = 0;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _end = details
                            .localPosition; //the location of the last point
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _distance = (_end - _start).distance * conversionFactor;
                      });
                    },
                  ),
                  if (_start != null)
                    Positioned(
                      top: _start.dy - 20,
                      left: _start.dx - 20,
                      child: const Icon(Icons.adjust), // icons for points
                    ),
                  if (_end != null)
                    Positioned(
                      top: _end.dy - 20,
                      left: _end.dx - 20,
                      child: const Icon(Icons.adjust),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  Offset start;
  Offset end;
  double img_len = 0.0;
  double obj_len = 0.0;
  LinePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    if (start != null && end != null) {
      Paint paint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, paint);
      String img_len = calculateDistance(start, end).toStringAsFixed(2);
      double imgLen = double.parse(img_len) * 10000.0;
      tot_mag = camera_mag * lens_mag;
      obj_len = imgLen / tot_mag;
      String objlen = obj_len.toStringAsFixed(2);
      TextSpan span = new TextSpan(
          style: new TextStyle(
            fontSize: 16.0,
            color: Colors.red,
          ),
          text: '${objlen}microns');

      TextPainter tp = new TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(
        canvas,
        Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
      );
    }
  }

  double calculateDistance(Offset start, Offset end) {
// assume that the image has a scale factor of 1
// and 1 logical pixel is equal to 0.02645833333 cm
    double scale = 0.02645833333;
    double distanceInLogicalPixels = (end - start).distance;
    return distanceInLogicalPixels * scale;
  }

  @override
  bool shouldRepaint(LinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
