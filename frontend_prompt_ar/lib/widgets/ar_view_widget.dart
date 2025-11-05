import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

/// Widget for displaying AR view with 3D model
class ARViewWidget extends StatefulWidget {
  final String modelFilePath;
  final VoidCallback? onClose;

  const ARViewWidget({
    super.key,
    required this.modelFilePath,
    this.onClose,
  });

  @override
  State<ARViewWidget> createState() => _ARViewWidgetState();
}

class _ARViewWidgetState extends State<ARViewWidget> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARNode? arNode;
  bool isARInitialized = false;
  String? errorMessage;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          customPlaneTexturePath: null,
          showWorldOrigin: false,
          handleTaps: false,
        );
    this.arObjectManager!.onInitialize();

    // Load the 3D model after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      _loadModel();
    });
  }

  Future<void> _loadModel() async {
    if (arObjectManager == null) {
      debugPrint('ARObjectManager is null, cannot load model');
      return;
    }

    try {
      final file = File(widget.modelFilePath);
      if (!await file.exists()) {
        throw Exception('Model file not found: ${widget.modelFilePath}');
      }

      // Create AR node with the model
      // Use GLB/GLTF2 format for both iOS and Android
      final newNode = ARNode(
        type: NodeType.localGLTF2,
        uri: widget.modelFilePath,
        scale:
            vector.Vector3(0.2, 0.2, 0.2), // Scale down for better visibility
        position: vector.Vector3(0, 0, -0.5), // Place in front of camera
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      // Add node to AR view
      bool? didAddNode = await arObjectManager!.addNode(newNode);

      if (didAddNode == true) {
        arNode = newNode;
        setState(() {
          isARInitialized = true;
        });
        debugPrint('Model loaded successfully');
      } else {
        throw Exception('Failed to add node to AR scene');
      }
    } catch (e) {
      debugPrint('Error loading model: $e');
      setState(() {
        errorMessage = 'Failed to load model: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: widget.onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // AR View
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Loading overlay while initializing
          if (!isARInitialized)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Initializing AR...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Point your camera at a flat surface to see the model.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
