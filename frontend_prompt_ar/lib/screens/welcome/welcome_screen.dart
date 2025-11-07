import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

/// Welcome screen - landing page of the app
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isCheckingPermission = true;
  bool _hasPermission = false;
  bool _permissionDenied = false;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    setState(() {
      _isCheckingPermission = true;
      _permissionDenied = false;
      _isPermanentlyDenied = false;
    });

    try {
      // Use camera package to check permission - this is more reliable
      // If we can get available cameras, permission is granted
      debugPrint('WelcomeScreen: Checking camera access via camera package');
      final cameras = await availableCameras();
      debugPrint('WelcomeScreen: Found ${cameras.length} cameras');

      if (cameras.isNotEmpty) {
        // Camera access works - permission is granted
        setState(() {
          _hasPermission = true;
          _isCheckingPermission = false;
          _permissionDenied = false;
          _isPermanentlyDenied = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('WelcomeScreen: Camera access error: $e');
      // Camera access failed - need to request permission
    }

    // If camera package check failed, use permission_handler as fallback
    final status = await Permission.camera.status;
    debugPrint('WelcomeScreen: Permission handler status: $status');

    if (status.isGranted || status.isLimited) {
      setState(() {
        _hasPermission = true;
        _isCheckingPermission = false;
        _permissionDenied = false;
        _isPermanentlyDenied = false;
      });
      return;
    }

    if (status.isPermanentlyDenied) {
      setState(() {
        _hasPermission = false;
        _permissionDenied = true;
        _isPermanentlyDenied = true;
        _isCheckingPermission = false;
      });
      return;
    }

    if (status.isDenied) {
      // Request permission - this should show the iOS permission dialog
      debugPrint('WelcomeScreen: Requesting camera permission');
      final result = await Permission.camera.request();
      debugPrint('WelcomeScreen: Permission request result: $result');

      // After requesting, ALWAYS verify with camera package
      // permission_handler can be unreliable on iOS
      try {
        final cameras = await availableCameras();
        debugPrint(
            'WelcomeScreen: After request - found ${cameras.length} cameras');
        if (cameras.isNotEmpty) {
          // Camera package confirms access - permission is actually granted
          setState(() {
            _hasPermission = true;
            _isCheckingPermission = false;
            _permissionDenied = false;
            _isPermanentlyDenied = false;
          });
          return;
        }
      } catch (e) {
        debugPrint(
            'WelcomeScreen: Camera still not accessible after request: $e');
      }

      // If camera package check failed, but permission_handler says granted, trust it
      if (result.isGranted || result.isLimited) {
        setState(() {
          _hasPermission = true;
          _isCheckingPermission = false;
          _permissionDenied = false;
          _isPermanentlyDenied = false;
        });
        return;
      }

      // If permission_handler says permanentlyDenied but we haven't verified,
      // it might be a false positive - show the grant button anyway
      // (on iOS, permanentlyDenied usually only happens after multiple denials)
      setState(() {
        _hasPermission = false;
        _permissionDenied = true;
        // Don't trust permanentlyDenied on first request - might be permission_handler bug
        _isPermanentlyDenied = false; // Allow user to try granting again
        _isCheckingPermission = false;
      });
      return;
    }

    // Restricted or other state
    setState(() {
      _hasPermission = false;
      _permissionDenied = true;
      _isPermanentlyDenied = status.isRestricted;
      _isCheckingPermission = false;
    });
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // Recheck permission after user returns from settings
    await Future.delayed(const Duration(milliseconds: 500));
    _checkCameraPermission();
  }

  void _navigateToARView() {
    if (_hasPermission) {
      Navigator.of(context).pushNamed('/ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.view_in_ar,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // App Title
                const Text(
                  'PromptAR',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Transform your ideas into 3D AR experiences',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Description
                Text(
                  'Simply type what you imagine, and watch it come to life in augmented reality right before your eyes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.6,
                  ),
                ),
                const Spacer(),

                // Permission status or Get Started Button
                if (_isCheckingPermission)
                  const SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else if (_permissionDenied)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera Access Required',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isPermanentlyDenied
                                  ? 'Camera access was permanently denied. Please enable it in Settings to use AR features.'
                                  : 'Camera access is required to use AR features. Please grant camera permission to continue.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isPermanentlyDenied)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _checkCameraPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Grant Permission',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (!_isPermanentlyDenied) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _openAppSettings,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side:
                                const BorderSide(color: Colors.white, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _navigateToARView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
