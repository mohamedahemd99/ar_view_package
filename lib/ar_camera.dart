import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ArCamera extends StatefulWidget {
  const ArCamera({
    Key? key,
    required this.onCameraError,
    required this.onCameraSuccess,
  }) : super(key: key);

  final Function(String error) onCameraError;
  final Function() onCameraSuccess;

  @override
  State<ArCamera> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCamera> {

  bool isCameraAuthorize = false;

  @override
  void initState() {
    super.initState();

    _requestCameraAuthorization();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraAuthorize) {
      return _showCirularLoading(context);
    }

    if(isCameraAuthorize) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: CameraAwesomeBuilder.custom(
          saveConfig: SaveConfig.photo(),
          previewFit: CameraPreviewFit.cover,
          sensorConfig: SensorConfig.single(
            sensor: Sensor.position(SensorPosition.back),
            flashMode: FlashMode.none,
            aspectRatio: CameraAspectRatios.ratio_16_9,
            zoom: 0.0,
          ),
          progressIndicator: _showCirularLoading(context),
          imageAnalysisConfig: AnalysisConfig(
            androidOptions: const AndroidAnalysisOptions.nv21(
              width: 250,
            ),
            maxFramesPerSecond: 5,
          ),
          builder: (state, preview) {
            return IgnorePointer(
              child: StreamBuilder(
                stream: state.sensorConfig$,
                builder: (_, snapshot) {
                  return const SizedBox();
                }
              ),
            );
          },
        ),
      );
    }
    return const Text('Camera error');
  }

  Future<void> _requestCameraAuthorization() async {
    try {
      var isGranted = await Permission.camera.isGranted;
      if (!isGranted) {
        await Permission.camera.request();
        isGranted = await Permission.camera.isGranted;
        if (!isGranted) {
          widget.onCameraError('Camera need authorization permission');
        } else {
          isCameraAuthorize = true;
          setState(() {});

          widget.onCameraSuccess();
        }
      } else {
        isCameraAuthorize = true;
        setState(() {});
        widget.onCameraSuccess();
      }
    } catch (ex) {
      widget.onCameraError('Camera need authorization permission');
    } finally {
      setState(() {});
    }

    
  }

  Widget _showCirularLoading(context){
    return Container(
      alignment: Alignment.center,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Container(
        height: 70.0,
        width: 70.0,
        child: const CircularProgressIndicator(),
      )
    );
  }
}
