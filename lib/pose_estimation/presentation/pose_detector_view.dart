import 'dart:developer' as dev;
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'detector_view.dart';
import 'painters/pose_painter.dart';

class PoseDetectorView extends StatefulWidget {
  const PoseDetectorView({super.key});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  String? isInFrameAndIn30Degree = 'No';

  @override
  void dispose() async {
    _canProcess = false;
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Is in frame and in 30 degree: $isInFrameAndIn30Degree'),
        Expanded(
          child: DetectorView(
            title: 'Pose Detector',
            customPaint: _customPaint,
            text: _text,
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          ),
        ),
      ],
    );
  }

  bool isUserInFrame(List<Pose> poses) {
    // Define a list of key points that you want to check for user presence
    List<int> keyPointsToCheck = [
      0, // nose
      11, // left shoulder
      12, // right shoulder
      23, // left hip
      24, // right hip
      15, // left wrist
      16, // right wrist
      27, // left ankle
      28 // right ankle
    ];

    // Define a minimum likelihood threshold for key points
    double minLikelihoodThreshold = 0.96; // Adjust this threshold as needed

    // Iterate through the detected poses
    for (var pose in poses) {
      // Get the list of landmarks for the current pose
      List<PoseLandmark> landmarks = pose.landmarks.values.toList();

      // Check if all key points have sufficient likelihood
      bool allKeyPointsPresent = true;
      for (var index in keyPointsToCheck) {
        if (index >= landmarks.length || landmarks[index].likelihood < minLikelihoodThreshold) {
          allKeyPointsPresent = false;
          break;
        }
      }
      // If all key points are present with sufficient likelihood, consider the user in frame
      if (allKeyPointsPresent) {
        return true;
      }
    }
    // If no pose with all key points present is found, consider the user not in frame
    return false;
  }

  bool isUserAt30DegreeAngle(List<Pose> poses) {
    // Define the indexes of the key points representing shoulders and hips

    int leftShoulderIndex = 11; // Index of left shoulder
    int rightShoulderIndex = 12; // Index of right shoulder
    int leftHipIndex = 23; // Index of left hip
    int rightHipIndex = 24; // Index of right hip

    // Define the desired angle (in radians)
    double desiredAngleRadians = 25 * (pi / 180); // Convert 30 degrees to radians

    // Iterate through the detected poses
    for (var pose in poses) {
      // Get the list of landmarks for the current pose
      List<PoseLandmark> landmarks = pose.landmarks.values.toList();

      // Check if all required key points are present
      if (leftShoulderIndex >= landmarks.length ||
          rightShoulderIndex >= landmarks.length ||
          leftHipIndex >= landmarks.length ||
          rightHipIndex >= landmarks.length) {
        continue; // Skip this pose if any key point is missing
      }

      // Calculate the vectors representing shoulders and hips
      Offset leftShoulder = Offset(landmarks[leftShoulderIndex].x, landmarks[leftShoulderIndex].y);
      Offset rightShoulder = Offset(landmarks[rightShoulderIndex].x, landmarks[rightShoulderIndex].y);
      Offset leftHip = Offset(landmarks[leftHipIndex].x, landmarks[leftHipIndex].y);
      Offset rightHip = Offset(landmarks[rightHipIndex].x, landmarks[rightHipIndex].y);

      // Calculate the vectors from left shoulder to right shoulder and from left hip to right hip
      Offset shoulderLine = rightShoulder - leftShoulder;
      Offset hipLine = rightHip - leftHip;

      // Calculate the dot product of the two vectors
      double dotProduct = shoulderLine.dx * hipLine.dx + shoulderLine.dy * hipLine.dy;

      // Calculate the magnitudes of the vectors
      double magnitude1 = sqrt(pow(shoulderLine.dx, 2) + pow(shoulderLine.dy, 2));
      double magnitude2 = sqrt(pow(hipLine.dx, 2) + pow(hipLine.dy, 2));

      // Calculate the angle between the vectors (in radians)
      double angleRadians = acos(dotProduct / (magnitude1 * magnitude2));

      // Check if the angle is approximately equal to the desired angle
      if ((angleRadians - desiredAngleRadians).abs() < 0.26) {
        // Adjust tolerance as needed
        return true;
      }
    }

    // If no pose meets the criteria, return false
    return false;
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });

    final poses = await _poseDetector.processImage(inputImage);
    dev.log('Poses found: ${poses.length}');

    final bool isInFrame = isUserInFrame(poses);
    dev.log('Is in frame: $isInFrame');

    final bool isAt30DegreeAngle = isUserAt30DegreeAngle(poses);
    dev.log('Is at 30 degree angle: $isAt30DegreeAngle');

    isInFrameAndIn30Degree = isInFrame && isAt30DegreeAngle ? 'Yes' : 'No';

    // // print('Poses found: ${poses.length}');
    // // print('Poses found 1: ${poses.first.landmarks.values.first.type.toString()}');
    //
    // // based on the first pose, check if the pose is in frame and in 30 degree
    // if (poses.isNotEmpty) {
    //   for (final pose in poses) {
    //     log('Poses found: ${pose.landmarks.values.length}');
    //     log('Poses found: ${pose.landmarks.values.last.type.toString()}');
    //     log('Poses found: ${pose.landmarks.values.last.likelihood}');
    //
    //     //issues : by putting any object we can easily get likelyhood of like this
    //     /*
    //     Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.9636433720588684
    //           [log] Poses found: 33
    //           [log] Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.9681411385536194
    //           [log] Poses found: 33
    //           [log] Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.9620362520217896
    //           [log] Poses found: 33
    //           [log] Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.9773707389831543
    //           [log] Poses found: 33
    //           [log] Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.9495759606361389
    //           [log] Poses found: 33
    //           [log] Poses found: PoseLandmarkType.rightFootIndex
    //           [log] Poses found: 0.973036527633667
    //      */
    //
    //     // issues: when user have partial body view we got all other body parts landmarks also so not feasible for now
    //   }
    //   // loop through the landmarks of the all the poses
    //   // for (final pose in poses) {
    //   //   // loop through the landmarks of the pose
    //   //   for (final landmark in pose.landmarks.values) {
    //   //     // check if the landmark is in frame and in 30 degree
    //   //
    //   //     final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    //   //     final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    //   //     final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    //   //     final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;
    //   //     final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee]!;
    //   //     final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee]!;
    //   //     final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle]!;
    //   //     final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle]!;
    //   //     final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow]!;
    //   //     final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow]!;
    //   //     final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist]!;
    //   //     final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist]!;
    //   //     final leftPinky = pose.landmarks[PoseLandmarkType.leftPinky]!;
    //   //     final rightPinky = pose.landmarks[PoseLandmarkType.rightPinky]!;
    //   //     final leftIndex = pose.landmarks[PoseLandmarkType.leftIndex]!;
    //   //     final rightIndex = pose.landmarks[PoseLandmarkType.rightIndex]!;
    //   //     final leftThumb = pose.landmarks[PoseLandmarkType.leftThumb]!;
    //   //     final rightThumb = pose.landmarks[PoseLandmarkType.rightThumb]!;
    //   //     final leftHeel = pose.landmarks[PoseLandmarkType.leftHeel]!;
    //   //     final rightHeel = pose.landmarks[PoseLandmarkType.rightHeel]!;
    //   //     final leftFootIndex = pose.landmarks[PoseLandmarkType.leftFootIndex]!;
    //   //     final rightFootIndex = pose.landmarks[PoseLandmarkType.rightFootIndex]!;
    //   //
    //   //     // check if user is in frame
    //   //     // if any of the landmark is not in frame, then user is not in frame
    //   //
    //   //     if (leftShoulder.x == 0 ||
    //   //         rightShoulder.x == 0 ||
    //   //         leftHip.x == 0 ||
    //   //         rightHip.x == 0 ||
    //   //         leftKnee.x == 0 ||
    //   //         rightKnee.x == 0 ||
    //   //         leftAnkle.x == 0 ||
    //   //         rightAnkle.x == 0 ||
    //   //         leftElbow.x == 0 ||
    //   //         rightElbow.x == 0 ||
    //   //         leftWrist.x == 0 ||
    //   //         rightWrist.x == 0 ||
    //   //         leftPinky.x == 0 ||
    //   //         rightPinky.x == 0 ||
    //   //         leftIndex.x == 0 ||
    //   //         rightIndex.x == 0 ||
    //   //         leftThumb.x == 0 ||
    //   //         rightThumb.x == 0 ||
    //   //         leftHeel.x == 0 ||
    //   //         rightHeel.x == 0 ||
    //   //         leftFootIndex.x == 0 ||
    //   //         rightFootIndex.x == 0) {
    //   //       isInFrameAndIn30Degree = 'No';
    //   //     } else {
    //   //       // check if user is in 30 degree
    //   //       // if any of the landmark is not in 30 degree, then user is not in 30 degree
    //   //       if (leftShoulder.x < 0.3 ||
    //   //           rightShoulder.x < 0.3 ||
    //   //           leftHip.x < 0.3 ||
    //   //           rightHip.x < 0.3 ||
    //   //           leftKnee.x < 0.3 ||
    //   //           rightKnee.x < 0.3 ||
    //   //           leftAnkle.x < 0.3 ||
    //   //           rightAnkle.x < 0.3 ||
    //   //           leftElbow.x < 0.3 ||
    //   //           rightElbow.x < 0.3 ||
    //   //           leftWrist.x < 0.3 ||
    //   //           rightWrist.x < 0.3 ||
    //   //           leftPinky.x < 0.3 ||
    //   //           rightPinky.x < 0.3 ||
    //   //           leftIndex.x < 0.3 ||
    //   //           rightIndex.x < 0.3 ||
    //   //           leftThumb.x < 0.3 ||
    //   //           rightThumb.x < 0.3 ||
    //   //           leftHeel.x < 0.3 ||
    //   //           rightHeel.x < 0.3 ||
    //   //           leftFootIndex.x < 0.3 ||
    //   //           rightFootIndex.x < 0.3) {
    //   //         isInFrameAndIn30Degree = 'No';
    //   //       } else {
    //   //         isInFrameAndIn30Degree = 'Yes';
    //   //       }
    //   //     }
    //   //   }
    //   //   // issues: when user have partial body view we got all other body parts landmarks also so not feasible for now
    //   // }
    // }

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      // TODO: set _customPaint to draw landmarks on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
