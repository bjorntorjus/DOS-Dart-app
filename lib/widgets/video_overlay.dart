import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shows an asset video or GIF as a full-screen overlay dialog.
/// Auto-dismisses when the video finishes (or after duration for GIFs).
/// User can tap to dismiss early.
class VideoOverlay extends StatefulWidget {
  final String assetPath;

  const VideoOverlay({super.key, required this.assetPath});

  @override
  State<VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<VideoOverlay> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isGif = false;
  bool _dismissed = false;

  static const Duration _gifDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _isGif = widget.assetPath.endsWith('.gif');

    if (_isGif) {
      setState(() => _initialized = true);
      // Auto-dismiss GIF after duration
      Future.delayed(_gifDuration, () {
        if (mounted && !_dismissed) {
          _dismissed = true;
          Navigator.of(context).pop();
        }
      });
    } else {
      _controller = VideoPlayerController.asset(widget.assetPath)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _initialized = true);
          _controller!.play();
          _controller!.addListener(_onVideoUpdate);
        }).catchError((_) {
          if (mounted && !_dismissed) {
            _dismissed = true;
            Navigator.of(context).pop();
          }
        });
    }
  }

  void _onVideoUpdate() {
    final c = _controller;
    if (c == null || _dismissed) return;
    if (!c.value.isPlaying &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      _dismissed = true;
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_dismissed) {
          _dismissed = true;
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: _initialized
              ? _isGif
                  ? Image.asset(
                      widget.assetPath,
                      fit: BoxFit.contain,
                    )
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
              : const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }
}
