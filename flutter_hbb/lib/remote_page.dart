import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:tuple/tuple.dart';
import 'common.dart';
import 'model.dart';
import 'package:wakelock/wakelock.dart';

class RemotePage extends StatefulWidget {
  RemotePage({Key key, this.id}) : super(key: key);

  final String id;

  @override
  _RemotePageState createState() => _RemotePageState();
}

// https://github.com/hanxu317317/flutter_plan_demo/blob/master/lib/src/enter.dart
class _RemotePageState extends State<RemotePage> {
  Timer _interval;
  bool _showBar = true;
  double _bottom = 0;
  bool _pan = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    FFI.connect(widget.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // https://stackoverflow.com/questions/46640116/make-flutter-application-fullscreen
      SystemChrome.setEnabledSystemUIOverlays([]);
      showLoading('Connecting...');
      _interval =
          Timer.periodic(Duration(milliseconds: 30), (timer) => interval());
    });
    Wakelock.enable();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
    FFI.close();
    _interval.cancel();
    dismissLoading();
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    Wakelock.disable();
  }

  void interval() {
    var v = MediaQuery.of(context).viewInsets.bottom;
    if (v != _bottom) {
      setState(() {
        _bottom = v;
        if (v < 80) {
          SystemChrome.setEnabledSystemUIOverlays([]);
        }
      });
    }
    FFI.ffiModel.update(widget.id, context, handleMsgbox);
  }

  void handleMsgbox(Map<String, dynamic> evt, String id, BuildContext context) {
    var type = evt['type'];
    var title = evt['title'];
    var text = evt['text'];
    if (type == 're-input-password') {
      wrongPasswordDialog(id, context);
    } else if (type == 'input-password') {
      enterPasswordDialog(id, context);
    } else {
      msgbox(type, title, text, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Size size = MediaQueryData.fromWindow(ui.window).size;
    // MediaQuery.of(context).size.height;
    EasyLoading.instance.loadingStyle = EasyLoadingStyle.light;
    return WillPopScope(
        onWillPop: () async {
          close();
          return false;
        },
        child: Scaffold(
          floatingActionButton: _showBar
              ? null
              : FloatingActionButton(
                  mini: true,
                  child: Icon(Icons.expand_less),
                  backgroundColor: MyTheme.accent50,
                  onPressed: () {
                    setState(() => _showBar = !_showBar);
                  }),
          bottomNavigationBar: _showBar
              ? BottomAppBar(
                  elevation: 10,
                  color: MyTheme.accent,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(children: [
                        IconButton(
                          color: Colors.white,
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            close();
                          },
                        ),
                        IconButton(
                            color: Colors.white,
                            icon: Icon(Icons.keyboard),
                            onPressed: () {
                              SystemChrome.setEnabledSystemUIOverlays(
                                  SystemUiOverlay.values);
                              _focusNode.requestFocus();
                              SystemChannels.textInput
                                  .invokeMethod('TextInput.show');
                            }),
                        Transform.rotate(
                            angle: 15 * math.pi / 180,
                            child: IconButton(
                              color: Colors.white,
                              icon: Icon(Icons.flash_on),
                              onPressed: () {
                                showActions(context);
                              },
                            )),
                        IconButton(
                          color: Colors.white,
                          icon: Icon(Icons.tv),
                          onPressed: () {
                            showOptions(context);
                          },
                        ),
                        Container(
                            color: _pan ? Colors.blue[500] : null,
                            child: IconButton(
                              color: Colors.white,
                              icon: Icon(Icons.pan_tool),
                              onPressed: () {
                                setState(() => _pan = !_pan);
                              },
                            ))
                      ]),
                      IconButton(
                          color: Colors.white,
                          icon: Icon(Icons.expand_more),
                          onPressed: () {
                            setState(() => _showBar = !_showBar);
                          }),
                    ],
                  ),
                )
              : null,
          body: RawGestureDetector(
              gestures: {
                MultiTouchGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        MultiTouchGestureRecognizer>(
                  () => MultiTouchGestureRecognizer(),
                  (MultiTouchGestureRecognizer instance) {
                    instance.onMultiTap = (
                      touchCount,
                      addOrRemove,
                    ) =>
                        print('$touchCount, $addOrRemove');
                  },
                ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTap = () {
                      print('tap');
                    };
                  },
                ),
                ImmediateMultiDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        ImmediateMultiDragGestureRecognizer>(
                  () => ImmediateMultiDragGestureRecognizer(),
                  (ImmediateMultiDragGestureRecognizer instance) {
                    instance
                      ..onStart = (x) {
                        return CustomDrag();
                      };
                  },
                ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(),
                  (LongPressGestureRecognizer instance) {
                    var x = 0.0;
                    var y = 0.0;
                    instance
                      ..onLongPressStart = (details) {
                        x = details.globalPosition.dx;
                        y = details.globalPosition.dy;
                      }
                      ..onLongPress = () {
                        print('long press');
                        () async {
                          await showMenu(
                            context: context,
                            position: RelativeRect.fromLTRB(x, y, 0, 0),
                            items: [
                              PopupMenuItem<String>(
                                  child: const Text('Doge'), value: 'Doge'),
                              PopupMenuItem<String>(
                                  child: const Text('Lion'), value: 'Lion'),
                            ],
                            elevation: 8.0,
                          );
                        }();
                      };
                  },
                ),
                PanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                  () => PanGestureRecognizer(),
                  (PanGestureRecognizer instance) {
                    instance
                      ..onStart = (detail) {
                        print('pan start');
                      }
                      ..onUpdate = (detail) {
                        print('$detail');
                      };
                  },
                ),
                ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (ScaleGestureRecognizer instance) {
                    instance
                      ..onStart = (detail) {
                        print('scale start');
                      }
                      ..onUpdate = (detail) {
                        print('$detail');
                      };
                  },
                ),
                DoubleTapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        DoubleTapGestureRecognizer>(
                  () => DoubleTapGestureRecognizer(),
                  (DoubleTapGestureRecognizer instance) {
                    instance.onDoubleTap = () {
                      print('double tap');
                    };
                  },
                ),
              },
              child: FlutterEasyLoading(
                child: Container(
                    color: MyTheme.canvasColor,
                    child: Stack(children: [
                      ImagePaint(),
                      CursorPaint(),
                      SizedBox(
                        width: 0,
                        height: 0,
                        child: _bottom < 100
                            ? Container()
                            : TextField(
                                textInputAction: TextInputAction.newline,
                                autocorrect: false,
                                enableSuggestions: false,
                                focusNode: _focusNode,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                onChanged: (x) => print('$x'),
                              ),
                      ),
                    ])),
              )),
        ));
  }

  void close() {
    msgbox('', 'Close', 'Are you sure to close the connection?', context);
  }
}

class ImagePaint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = Provider.of<ImageModel>(context);
    return CustomPaint(
      painter: new ImagePainter(image: m.image, x: 0, y: 0),
    );
  }
}

class CursorPaint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = Provider.of<CursorModel>(context);
    return CustomPaint(
      painter: new ImagePainter(image: m.image, x: m.x, y: m.y),
    );
  }
}

class ImagePainter extends CustomPainter {
  ImagePainter({
    this.image,
    this.x,
    this.y,
  });

  ui.Image image;
  double x;
  double y;

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    canvas.drawImage(image, new Offset(x, y), new Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}

void enterPasswordDialog(String id, BuildContext context) {
  final controller = TextEditingController();
  var remember = FFI.getByName('remember', id) == 'true';
  showAlertDialog(
      context,
      (setState) => Tuple3(
            Text('Please enter your password'),
            Column(mainAxisSize: MainAxisSize.min, children: [
              PasswordWidget(controller: controller),
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Remember the password',
                ),
                value: remember,
                onChanged: (v) {
                  setState(() => remember = v);
                },
              ),
            ]),
            [
              FlatButton(
                textColor: MyTheme.accent,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              FlatButton(
                textColor: MyTheme.accent,
                onPressed: () {
                  var text = controller.text.trim();
                  if (text == '') return;
                  FFI.login(text, remember);
                  showLoading('Logging in...');
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ));
}

void wrongPasswordDialog(String id, BuildContext context) {
  showAlertDialog(
      context,
      (_) =>
          Tuple3(Text('Wrong Password'), Text('Do you want to enter again?'), [
            FlatButton(
              textColor: MyTheme.accent,
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            FlatButton(
              textColor: MyTheme.accent,
              onPressed: () {
                enterPasswordDialog(id, context);
              },
              child: Text('Retry'),
            ),
          ]));
}

void showOptions(BuildContext context) {
  var showRemoteCursor =
      FFI.getByName('toggle_option', 'show-remote-cursor') == 'true';
  var lockAfterSessionEnd =
      FFI.getByName('toggle_option', 'lock-after-session-end') == 'true';
  String quality = FFI.getByName('image_quality');
  if (quality == '') quality = 'balanced';
  showAlertDialog(
      context,
      (setState) => Tuple3(
          null,
          Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<String>(
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Good image quality'),
              value: 'best',
              groupValue: quality,
              onChanged: (String value) {
                setState(() {
                  quality = value;
                  FFI.setByName('image_quality', value);
                });
              },
            ),
            RadioListTile<String>(
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Balanced'),
              value: 'balanced',
              groupValue: quality,
              onChanged: (String value) {
                setState(() {
                  quality = value;
                  FFI.setByName('image_quality', value);
                });
              },
            ),
            RadioListTile<String>(
              controlAffinity: ListTileControlAffinity.trailing,
              title: const Text('Optimize reaction time'),
              value: 'low',
              groupValue: quality,
              onChanged: (String value) {
                setState(() {
                  quality = value;
                  FFI.setByName('image_quality', value);
                });
              },
            ),
            Divider(color: Colors.black),
            CheckboxListTile(
                value: showRemoteCursor,
                onChanged: (v) {
                  setState(() {
                    showRemoteCursor = v;
                    FFI.setByName('toggle_option', 'show-remote-cursor');
                  });
                },
                title: Text('Show remote cursor')),
            CheckboxListTile(
                value: lockAfterSessionEnd,
                onChanged: (v) {
                  setState(() {
                    lockAfterSessionEnd = v;
                    FFI.setByName('toggle_option', 'lock-after-session-end');
                  });
                },
                title: Text('Lock after session end'))
          ]),
          null),
      () async => true,
      true,
      0);
}

void showActions(BuildContext context) {
  showAlertDialog(
      context,
      (setState) => Tuple3(
          null,
          Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              onTap: () {
                Navigator.pop(context);
                FFI.setByName('ctrl_alt_del');
              },
              title: Text('Insert Ctrl + Alt + Del'),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                FFI.setByName('lock_screen');
              },
              title: Text('Insert Lock'),
            ),
          ]),
          null),
      () async => true,
      true,
      0);
}

class MultiTouchGestureRecognizer extends MultiTapGestureRecognizer {
  MultiTouchGestureRecognizerCallback onMultiTap;
  var numberOfTouches = 0;

  MultiTouchGestureRecognizer() {
    this
      ..onTapDown = addTouch
      ..onTapUp = removeTouch
      ..onTapCancel = cancelTouch
      ..onTap = captureDefaultTap;
  }

  void addTouch(int pointer, TapDownDetails details) {
    numberOfTouches++;
    onMultiTap(numberOfTouches, true);
  }

  void removeTouch(int pointer, TapUpDetails details) {
    numberOfTouches--;
    onMultiTap(numberOfTouches, false);
  }

  void cancelTouch(int pointer) {
    numberOfTouches--;
    print('$numberOfTouches x');
  }

  void captureDefaultTap(int pointer) {
    print('$pointer');
  }
}

typedef MultiTouchGestureRecognizerCallback = void Function(
    int touchCount, bool addOrRemove);

typedef OnUpdate(DragUpdateDetails details);

class CustomDrag extends Drag {
  @override
  void update(DragUpdateDetails details) {
    print('xx $details');
  }

  @override
  void end(DragEndDetails details) {
    super.end(details);
  }
}
