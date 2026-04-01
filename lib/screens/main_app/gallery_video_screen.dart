import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/utils/nav.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:video_player/video_player.dart';
import 'package:hook_app/widgets/web_image.dart';

class GalleryVideoScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const GalleryVideoScreen({super.key, required this.userProfile});

  @override
  State<GalleryVideoScreen> createState() => _GalleryVideoScreenState();
}

class _GalleryVideoScreenState extends State<GalleryVideoScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isUploadingImage = false;
  bool _isUploadingVideo = false;

  // Live gallery URLs already saved to backend
  List<String> _galleryUrls = [];

  String? _videoUrl; // existing video from backend
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeData() {
    final data = widget.userProfile;
    debugPrint('==== GalleryVideoScreen raw profile data ===='  );
    debugPrint(jsonEncode(data));
    debugPrint('============================================');

    // Backend may return photo_gallery (snake_case) or photoGallery (camelCase)
    final galleryRaw = data['photo_gallery'] ?? data['photoGallery'];
    if (galleryRaw != null) {
      if (galleryRaw is List) {
        _galleryUrls = List<String>.from(
          galleryRaw
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .where((e) {
                final v = e.toString().trim().toLowerCase();
                return v != 'null' && v != 'undefined';
              }),
        );
      } else if (galleryRaw is String && galleryRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(galleryRaw);
          if (decoded is List) {
            _galleryUrls = List<String>.from(
              decoded
                  .where((e) => e != null && e.toString().trim().isNotEmpty)
                  .where((e) {
                    final v = e.toString().trim().toLowerCase();
                    return v != 'null' && v != 'undefined';
                  }),
            );
          }
        } catch (_) {}
      }
    }
    _galleryUrls = _galleryUrls.where(_isValidMediaUrl).toList();
    if (_galleryUrls.length > 6) {
      _galleryUrls = _galleryUrls.take(6).toList();
    }

    // Backend may return profile_video_url or profileVideoUrl
    _videoUrl = data['profile_video_url'] ?? data['profileVideoUrl'];
    if (_videoUrl != null) {
      final cleaned = _videoUrl!.trim();
      if (cleaned.isEmpty || cleaned.toLowerCase() == 'null' || cleaned.toLowerCase() == 'undefined') {
        _videoUrl = null;
      } else {
        _videoUrl = cleaned;
      }
    }
    if (_videoUrl != null && !_isValidMediaUrl(_videoUrl!)) {
      _videoUrl = null;
    }
    _initializeVideoPlayer();
  }

  // Remove local _getProxiedUrl as it's now in AppConstants

  void _initializeVideoPlayer() {
    if (_videoUrl != null && _videoUrl!.isNotEmpty) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(AppConstants.getProxiedUrl(_videoUrl!)))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((e) {
          debugPrint('Video init error for $_videoUrl: $e');
          if (mounted) {
            setState(() {
              _videoUrl = null;
              _videoController?.dispose();
              _videoController = null;
            });
          }
        });
    } else {
      _videoController?.dispose();
      _videoController = null;
    }
  }

  bool _isValidMediaUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  // ─── Upload helpers ────────────────────────────────────────────────────────

  Future<String?> _uploadMedia(XFile file, String type) async {
    try {
      final String? authToken = await StorageService.getAuthToken();
      final uri = Uri.parse('${AppConstants.mediaUpload}?type=$type');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';

      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'upload_${DateTime.now().millisecondsSinceEpoch}',
        contentType:
            type == 'video' ? MediaType('video', 'mp4') : MediaType('image', 'jpeg'),
      ));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final respData = jsonDecode(responseBody);
        return respData['url'] as String?;
      } else {
        debugPrint('Upload failed: $responseBody');
        return null;
      }
    } catch (error) {
      debugPrint('Upload error: $error');
      return null;
    }
  }

  Future<void> _saveGalleryToProfile(List<String> urls) async {
    await UserService.updateUserProfile(photoGallery: urls);
  }

  Future<void> _saveVideoToProfile(String? url) async {
    await UserService.updateUserProfile(profileVideoUrl: url);
  }

  // ─── Gallery actions ───────────────────────────────────────────────────────

  Future<void> _pickAndUploadImages() async {
    if (_galleryUrls.length >= 6) {
      _showSnack('You can upload a maximum of 6 photos.', isError: true);
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    final int remaining = 6 - _galleryUrls.length;
    final List<XFile> toUpload = images.take(remaining).toList();

    setState(() => _isUploadingImage = true);

    try {
      List<String> newUrls = List.from(_galleryUrls);
      int uploaded = 0;

      for (final file in toUpload) {
        final url = await _uploadMedia(file, 'gallery');
        if (url != null) {
          newUrls.add(url);
          uploaded++;
        }
      }

      if (uploaded > 0) {
        await _saveGalleryToProfile(newUrls);
        if (mounted) {
          setState(() => _galleryUrls = newUrls);
          _showSnack('$uploaded photo${uploaded > 1 ? 's' : ''} added!');
        }
      } else {
        _showSnack('Failed to upload images. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _deleteGalleryImage(int index) async {
    final confirm = await _showDeleteConfirm('Remove this photo from your gallery?');
    if (!confirm) return;

    setState(() => _isUploadingImage = true);
    try {
      final newUrls = List<String>.from(_galleryUrls)..removeAt(index);
      await _saveGalleryToProfile(newUrls);
      if (mounted) {
        setState(() => _galleryUrls = newUrls);
        _showSnack('Photo removed.');
      }
    } catch (e) {
      _showSnack('Failed to delete: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _replaceGalleryImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final url = await _uploadMedia(image, 'gallery');
      if (url != null) {
        final newUrls = List<String>.from(_galleryUrls);
        newUrls[index] = url;
        await _saveGalleryToProfile(newUrls);
        if (mounted) {
          setState(() => _galleryUrls = newUrls);
          _showSnack('Photo replaced successfully!');
        }
      } else {
        _showSnack('Failed to upload image. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageOptionsDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: platformAwareImage(
                    AppConstants.getProxiedUrl(_galleryUrls[index]),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Options
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, color: AppConstants.primaryColor),
                      label: const Text('Replace', style: TextStyle(color: AppConstants.primaryColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppConstants.primaryColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _replaceGalleryImage(index);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor),
                      label: const Text('Delete', style: TextStyle(color: AppConstants.errorColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppConstants.errorColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _deleteGalleryImage(index);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Video actions ─────────────────────────────────────────────────────────

  Future<void> _pickAndUploadVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 40),
    );
    if (video == null) return;

    setState(() => _isUploadingVideo = true);
    try {
      final url = await _uploadMedia(video, 'video');
      if (url != null) {
        await _saveVideoToProfile(url);
        if (mounted) {
          setState(() {
            _videoUrl = url;
            _initializeVideoPlayer();
          });
          _showSnack('Video uploaded successfully!');
        }
      } else {
        _showSnack('Failed to upload video. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _deleteVideo() async {
    final confirm = await _showDeleteConfirm('Remove your profile video?');
    if (!confirm) return;

    setState(() => _isUploadingVideo = true);
    try {
      await _saveVideoToProfile(null);
      if (mounted) {
        setState(() {
          _videoUrl = null;
          _videoController?.dispose();
          _videoController = null;
        });
        _showSnack('Video removed.');
      }
    } catch (e) {
      _showSnack('Failed to delete: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingVideo = false);
    }
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppConstants.errorColor : AppConstants.successColor,
    ));
  }

  Future<bool> _showDeleteConfirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppConstants.surfaceColor,
            title: const Text('Confirm Delete',
                style: TextStyle(color: AppConstants.softWhite)),
            content: Text(message,
                style: const TextStyle(color: AppConstants.mutedGray)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppConstants.mutedGray))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: AppConstants.errorColor))),
            ],
          ),
        ) ??
        false;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final contentMaxWidth = isDesktop ? 680.0 : 520.0;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 20, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppConstants.softWhite),
                          onPressed: () => Nav.safePop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Gallery & Video',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.softWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 120,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor,
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Upload Your Photo',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.softWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add up to 6 photos. They save automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppConstants.mutedGray,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _isUploadingImage
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 30),
                                    child: Column(
                                      children: [
                                        CircularProgressIndicator(
                                            color: AppConstants.primaryColor),
                                        SizedBox(height: 12),
                                        Text('Uploading…',
                                            style: TextStyle(
                                                color: AppConstants.mutedGray)),
                                      ],
                                    ),
                                  ),
                                )
                              : _buildGalleryGrid(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Nav.safePop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'My Video',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.softWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload one short video (max 30 seconds). It uploads and saves automatically.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppConstants.mutedGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildVideoCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoMosaic() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_galleryUrls.isEmpty) {
          return _buildSingleAddSlot();
        }

        final gap = 12.0;
        final total = constraints.maxWidth;
        final leftW = (total - gap) * 0.58;
        final rightW = total - gap - leftW;
        final leftH = leftW;
        final smallH = (leftH - gap) / 2;
        final bottomTile = (total - 2 * gap) / 3;

        final int urlCount = _galleryUrls.length;

        String? getUrl(int index) => index < urlCount ? _galleryUrls[index] : null;
        bool isAddSlot(int index) => index == urlCount && urlCount < 6;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoSlot(0, leftW, leftH, getUrl(0), isAdd: isAddSlot(0)),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _buildPhotoSlot(1, rightW, smallH, getUrl(1), isAdd: isAddSlot(1)),
                    const SizedBox(height: 12),
                    _buildPhotoSlot(2, rightW, smallH, getUrl(2), isAdd: isAddSlot(2)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPhotoSlot(3, bottomTile, bottomTile, getUrl(3), isAdd: isAddSlot(3)),
                const SizedBox(width: 12),
                _buildPhotoSlot(4, bottomTile, bottomTile, getUrl(4), isAdd: isAddSlot(4)),
                const SizedBox(width: 12),
                _buildPhotoSlot(5, bottomTile, bottomTile, getUrl(5), isAdd: isAddSlot(5)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoSlot(int index, double w, double h, String? url, {required bool isAdd}) {
    final hasImage = url != null && url.trim().isNotEmpty;
    return SizedBox(
      width: w,
      height: h,
      child: GestureDetector(
        onTap: hasImage
            ? () => _showImageOptionsDialog(index)
            : (isAdd ? _pickAndUploadImages : null),
        child: Stack(
          children: [
            if (hasImage)
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.cardNavy,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: platformAwareImage(
                    AppConstants.getProxiedUrl(url!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (isAdd)
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppConstants.primaryColor, size: 22),
                ),
              ),
            if (!hasImage)
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.cardNavy,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppConstants.primaryColor.withOpacity(isAdd ? 0.55 : 0.12),
                    width: isAdd ? 1.4 : 1.0,
                  ),
                ),
              ),
            if (hasImage)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _deleteGalleryImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppConstants.errorColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderSlot() {
    return Container(
      color: AppConstants.cardNavy,
      child: const Center(
        child: Icon(Icons.person, color: AppConstants.mutedGray, size: 32),
      ),
    );
  }

  Widget _buildSingleAddSlot() {
    return GestureDetector(
      onTap: _pickAndUploadImages,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppConstants.primaryColor.withValues(alpha: 0.5),
            width: 1.6,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: AppConstants.primaryColor, size: 42),
            SizedBox(height: 10),
            Text('Add your first photo',
                style: TextStyle(
                    color: AppConstants.softWhite,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Up to 6 photos',
                style: TextStyle(color: AppConstants.mutedGray, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final int urlCount = _galleryUrls.length;
    if (urlCount == 0) {
      return _buildSingleAddSlot();
    }
    // Show existing images + one "add" button if less than 6
    final int totalCells =
        urlCount < 6 ? urlCount + 1 : urlCount; // +1 for add button

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: totalCells.clamp(1, 7), // at least 1 (the add button)
      itemBuilder: (context, index) {
        if (index < urlCount) {
          return _buildImageTile(index);
        }
        // "Add" button
        return _buildAddTile();
      },
    );
  }

  Widget _buildImageTile(int index) {
    return GestureDetector(
      onTap: () => _showImageOptionsDialog(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: platformAwareImage(
              AppConstants.getProxiedUrl(_galleryUrls[index]),
              fit: BoxFit.cover,
            ),
          ),
          // Border overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppConstants.primaryColor.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _galleryUrls.length < 6 ? _pickAndUploadImages : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppConstants.primaryColor.withValues(alpha: 0.5),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo,
                color: AppConstants.primaryColor, size: 30),
            SizedBox(height: 6),
            Text('Add Photo',
                style: TextStyle(
                    color: AppConstants.primaryColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    if (_isUploadingVideo) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppConstants.primaryColor.withValues(alpha: 0.3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppConstants.accentColor),
            SizedBox(height: 12),
            Text('Uploading video…',
                style: TextStyle(color: AppConstants.mutedGray)),
          ],
        ),
      );
    }

    if (_videoUrl != null &&
        _videoUrl!.trim().isNotEmpty &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      // Show existing video with option to change or delete
      return Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppConstants.successColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 50,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickAndUploadVideo,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryColor,
                    side: BorderSide(
                        color: AppConstants.primaryColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _deleteVideo,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.errorColor,
                    side: BorderSide(
                        color: AppConstants.errorColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // No video yet
    return GestureDetector(
      onTap: _pickAndUploadVideo,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppConstants.primaryColor.withValues(alpha: 0.4),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_call,
                color: AppConstants.primaryColor, size: 52),
            SizedBox(height: 10),
            Text(
              'Tap to upload video',
              style: TextStyle(
                  color: AppConstants.softWhite, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Max 30 seconds',
              style: TextStyle(color: AppConstants.mutedGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
