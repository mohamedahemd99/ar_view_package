import 'package:camerawesome/camerawesome_plugin.dart' as cam;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


class ArCamera extends StatefulWidget {
  const ArCamera({
    super.key,
    required this.onCameraError,
    required this.onCameraSuccess,
  });

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
    _requestCameraPermission();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraAuthorize) {
      return _showCircularProgress(context);
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: cam.CameraAwesomeBuilder.custom(
        saveConfig: cam.SaveConfig.photo(),
        previewFit: cam.CameraPreviewFit.cover, // Use cover to fill screen
        sensorConfig: cam.SensorConfig.single(
          sensor: cam.Sensor.position(cam.SensorPosition.back),
          flashMode: cam.FlashMode.none,
          aspectRatio: MediaQuery.of(context).size.aspectRatio > 1
              ? cam.CameraAspectRatios.ratio_16_9
              : cam.CameraAspectRatios.ratio_4_3, // Dynamic aspect ratio
          zoom: 0.0,
        ),
        progressIndicator: _showCircularProgress(context),
        imageAnalysisConfig: cam.AnalysisConfig(
          androidOptions: const cam.AndroidAnalysisOptions.nv21(
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
                }),
          );
        },
      ),
    );
  }

  Future<void> _requestCameraPermission() async {
    try {
      var isGranted = await Permission.camera.isGranted;
      if (!isGranted) {
        await Permission.camera.request();
        isGranted = await Permission.camera.isGranted;
        if (!isGranted) {
          widget.onCameraError('Camera permission denied');
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
      widget.onCameraError('Camera permission error: $ex');
    }
  }

  Widget _showCircularProgress(context) {
    return Container(
      alignment: Alignment.center,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: const SizedBox(
        height: 70.0,
        width: 70.0,
        child: CircularProgressIndicator(),
      ),
    );
  }
}