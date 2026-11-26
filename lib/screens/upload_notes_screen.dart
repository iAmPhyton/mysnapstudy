import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/study_queue_service.dart';
import '../services/gemini_service.dart';
import '../widgets/cloudflare_settings_dialog.dart';

class UploadNotesScreen extends StatefulWidget {
  final String userId;

  const UploadNotesScreen({super.key, required this.userId});

  @override
  State<UploadNotesScreen> createState() => _UploadNotesScreenState();
}

class _UploadNotesScreenState extends State<UploadNotesScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final StorageService _storageService = StorageService();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isProcessing = false;
  String _currentStepStatus = '';

  @override
  void initState() {
    super.initState();
    final defaultTitle = 'Notes - ${DateFormat('MMM d, h:mm a').format(DateTime.now())}';
    _titleController.text = defaultTitle;
    if (GeminiService.savedApiKey != null && GeminiService.savedApiKey!.isNotEmpty) {
      _apiKeyController.text = GeminiService.savedApiKey!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _processAndUpload() async {
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture a photo first.')),
      );
      return;
    }

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Untitled Notes';

    setState(() {
      _isProcessing = true;
      _currentStepStatus = 'Preparing note photo for background queue...';
    });

    try {
      final noteId = const Uuid().v4();

      // 1. Upload photo to Cloudflare Storage / Base64 fallback (instant offline fallback)
      String downloadUrl = '';
      try {
        downloadUrl = await _storageService.uploadNotePhoto(
          userId: widget.userId,
          imageBytes: _selectedImageBytes!,
        );
      } catch (storageError) {
        debugPrint('Storage notice: $storageError');
        final base64String = base64Encode(_selectedImageBytes!);
        downloadUrl = 'data:image/jpeg;base64,$base64String';
      }

      if (downloadUrl.isEmpty) {
        final base64String = base64Encode(_selectedImageBytes!);
        downloadUrl = 'data:image/jpeg;base64,$base64String';
      }

      final customKey = _apiKeyController.text.trim().isNotEmpty
          ? _apiKeyController.text.trim()
          : null;
      if (customKey != null) {
        GeminiService.savedApiKey = customKey;
      }

      // 2. Enqueue into background queue to prevent traffic spikes & blocking
      await StudyQueueService.instance.enqueue(
        noteId: noteId,
        userId: widget.userId,
        title: title,
        imageBytes: _selectedImageBytes!,
        imageUrl: downloadUrl,
        customApiKey: customKey,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.offline_pin_rounded, color: Colors.greenAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notes staged! Saved safely on device and queued for AI generation.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

        // Immediately return to Home Screen so student can see the live queue status
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to queue notes: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap Study Notes'),
        actions: [
          IconButton(
            tooltip: 'Storage Settings',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => _openStorageSettings(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offline Commuter Snapping Mode Badge
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Snapping Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Capture notes anytime offline or commuting. Notes are safely staged on-device and automatically synced once connected.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cloudflare Storage Badge
            InkWell(
              onTap: () => _openStorageSettings(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: Colors.deepOrange, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Storage: Cloudflare R2 (Free Tier Enabled)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                    const Icon(Icons.settings_outlined, color: Colors.deepOrange, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Study Set Title',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Optional Gemini API Key field
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Gemini API Key (Optional / Overrides env)',
                hintText: 'Enter API key or use project default',
                prefixIcon: const Icon(Icons.key_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Photo picker container
            InkWell(
              onTap: _isProcessing ? null : () => _showPickerOptions(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImageBytes != null
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                ),
                child: _selectedImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedImageName ?? 'Photo selected',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _showPickerOptions(context),
                                    icon: const Icon(Icons.refresh_rounded,
                                        color: Colors.white, size: 18),
                                    label: const Text('Change',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 56,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to take a photo or upload notes',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports handwriting, printed handouts, textbooks',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Processing status banner
            if (_isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentStepStatus,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Submit Button
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _processAndUpload,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isProcessing
                      ? 'Processing with Gemini...'
                      : 'Generate Study Pack with Gemini',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStorageSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CloudflareSettingsDialog(),
    );
  }
}
