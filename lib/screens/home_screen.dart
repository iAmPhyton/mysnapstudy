import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/study_material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/study_queue_service.dart';
import '../services/gemini_service.dart';
import 'study_view_screen.dart';
import 'upload_notes_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_stories_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'MySnapStudy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null || user.photoURL!.isEmpty
                      ? Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      await Provider.of<AuthService>(context, listen: false).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<StudyMaterial>>(
        stream: firestoreService.getStudyMaterials(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Failed to load study notes: ${snapshot.error}'),
                  ],
                ),
              ),
            );
          }

          final materials = snapshot.data ?? [];

          if (materials.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Study Notes Yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Snap a photo of your notebook, textbook, or whiteboard to generate AI summaries, flashcards, and quizzes!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UploadNotesScreen(userId: user.uid),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: const Text('Snap Your First Notes'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Compute quick stats
          final totalCards =
              materials.fold<int>(0, (sum, item) => sum + item.flashcards.length);
          final totalQuizzes =
              materials.fold<int>(0, (sum, item) => sum + item.quiz.length);

          return CustomScrollView(
            slivers: [
              // Stats banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(context, '${materials.length}', 'Study Sets',
                              Icons.menu_book_rounded),
                          _buildStatItem(context, '$totalCards', 'Flashcards',
                              Icons.style_rounded),
                          _buildStatItem(context, '$totalQuizzes', 'Quiz Qs',
                              Icons.quiz_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Background Queue Status Banner
              _buildQueueBanner(context, materials),

              // Section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Your Study Materials',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                  ),
                ),
              ),

              // Study Materials List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = materials[index];
                      return _buildStudyCard(context, item, firestoreService);
                    },
                    childCount: materials.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadNotesScreen(userId: user.uid),
            ),
          );
        },
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Snap Notes'),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String count, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          count,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildQueueBanner(BuildContext context, List<StudyMaterial> materials) {
    final pendingCount = materials.where((m) => m.isPending).length;
    if (pendingCount == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pendingCount Study Set${pendingCount > 1 ? 's' : ''} Processing in Background',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Paced sequentially to prevent Gemini 503 traffic spikes & rate limits.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyCard(BuildContext context, StudyMaterial item,
      FirestoreService firestoreService) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat.yMMMd().format(item.createdAt);

    final isKeyNeeded = item.errorMessage != null &&
        (item.errorMessage!.toLowerCase().contains('api key') ||
         item.errorMessage!.toLowerCase().contains('api_key') ||
         item.errorMessage!.toLowerCase().contains('unauthorized') ||
         item.errorMessage!.toLowerCase().contains('missing gemini api key'));

    Color? cardBorderColor;
    if (item.isQueued) {
      cardBorderColor = Colors.blue.withOpacity(0.4);
    } else if (item.isProcessing) {
      cardBorderColor = Colors.amber.withOpacity(0.6);
    } else if (item.isFailed) {
      cardBorderColor = colorScheme.error.withOpacity(0.5);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: cardBorderColor != null
            ? BorderSide(color: cardBorderColor, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (item.isPending) {
            final isOffline = item.errorMessage != null && item.errorMessage!.contains('Offline');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      isOffline ? Icons.offline_pin_rounded : Icons.hourglass_top_rounded,
                      color: isOffline ? Colors.greenAccent : Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOffline
                            ? '"${item.title}" was captured offline during your commute. Safely staged on device—AI study deck will automatically generate when online.'
                            : (item.isProcessing
                                ? 'Gemini is currently generating flashcards & quiz for "${item.title}". It will be ready in a moment!'
                                : '"${item.title}" is queued in background to prevent server overload.'),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          if (item.isFailed) {
            _promptRetry(context, item);
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudyViewScreen(material: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) async {
                      if (val == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Study Set'),
                            content: Text('Delete "${item.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await firestoreService.deleteStudyMaterial(
                              item.userId, item.id);
                        }
                      } else if (val == 'refresh' || val == 'retry') {
                        _refreshAndSyncNote(context, item);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: item.isPending
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
              ),

              // Progress bar for pending generation
              if (item.isPending) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  if (item.isCompleted) ...[
                    _buildBadge(context, '${item.flashcards.length} Cards',
                        Icons.style_rounded),
                    const SizedBox(width: 8),
                    _buildBadge(context, '${item.quiz.length} Qs',
                        Icons.quiz_rounded),
                    const SizedBox(width: 8),
                    _buildCustomBadge(
                      context,
                      item.errorMessage == 'offline_fallback'
                          ? 'Nano 4 Offline (Tap ⋮ to Refresh)'
                          : 'Nano 4 Offline',
                      Icons.bolt_rounded,
                      Colors.green.shade800,
                      Colors.green.shade100,
                    ),
                  ] else if (item.isProcessing) ...[
                    _buildCustomBadge(
                      context,
                      'Generating Study Pack...',
                      Icons.bolt_rounded,
                      Colors.amber.shade800,
                      Colors.amber.shade100,
                    ),
                  ] else if (item.isQueued) ...[
                    _buildCustomBadge(
                      context,
                      item.errorMessage != null && item.errorMessage!.contains('Offline')
                          ? 'Offline (Staged)'
                          : 'Queued (Paced)',
                      item.errorMessage != null && item.errorMessage!.contains('Offline')
                          ? Icons.offline_pin_rounded
                          : Icons.hourglass_empty_rounded,
                      item.errorMessage != null && item.errorMessage!.contains('Offline')
                          ? Colors.teal.shade800
                          : Colors.blue.shade700,
                      item.errorMessage != null && item.errorMessage!.contains('Offline')
                          ? Colors.teal.shade100
                          : Colors.blue.shade100,
                    ),
                  ] else if (item.isFailed) ...[
                    _buildCustomBadge(
                      context,
                      isKeyNeeded ? 'API Key Required' : 'Server Busy - Tap Retry',
                      isKeyNeeded ? Icons.key_rounded : Icons.warning_amber_rounded,
                      isKeyNeeded ? Colors.amber.shade900 : colorScheme.error,
                      isKeyNeeded ? Colors.amber.shade100 : colorScheme.errorContainer,
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _promptRetry(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isKeyNeeded ? Colors.amber.shade800 : colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isKeyNeeded ? Icons.vpn_key_rounded : Icons.refresh, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              isKeyNeeded ? 'Set Key' : 'Retry',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptRetry(BuildContext context, StudyMaterial item) async {
    final isKeyNeeded = item.errorMessage != null &&
        (item.errorMessage!.toLowerCase().contains('api key') ||
         item.errorMessage!.toLowerCase().contains('api_key') ||
         item.errorMessage!.toLowerCase().contains('unauthorized') ||
         item.errorMessage!.toLowerCase().contains('missing gemini api key'));

    final apiKeyController = TextEditingController(text: GeminiService.savedApiKey ?? '');

    final shouldRetry = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final dTheme = Theme.of(dialogCtx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isKeyNeeded ? Icons.key_rounded : Icons.cloud_sync_rounded,
                color: isKeyNeeded ? Colors.amber.shade800 : dTheme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(isKeyNeeded ? 'Gemini API Key' : 'Retry AI Generation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKeyNeeded
                    ? 'A Gemini API key is required to run cloud multimodal note processing and study pack generation.'
                    : 'The cloud AI service encountered temporary traffic or high load. You can retry processing "${item.title}".',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (item.errorMessage != null && item.errorMessage!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dTheme.colorScheme.errorContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.errorMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: dTheme.colorScheme.error,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key (optional/custom)',
                  hintText: 'Enter your Gemini API key...',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 6),
              const Text(
                'Leave blank to use default environment key or enter your free Google AI Studio key.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final enteredKey = apiKeyController.text.trim();
                if (enteredKey.isNotEmpty) {
                  GeminiService.savedApiKey = enteredKey;
                }
                Navigator.pop(dialogCtx, true);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Now'),
            ),
          ],
        );
      },
    );

    if (shouldRetry != true || !context.mounted) return;

    final customKey = apiKeyController.text.trim();
    final success = await StudyQueueService.instance.retry(
      item,
      customApiKey: customKey.isNotEmpty ? customKey : null,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-enqueued "${item.title}" for background AI generation.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Original photo not cached. Please re-snap the notes.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshAndSyncNote(BuildContext context, StudyMaterial item) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Syncing "${item.title}" with Gemini AI...'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    final success = await StudyQueueService.instance.syncWithCloud(
      item,
      customApiKey: GeminiService.savedApiKey,
    );

    if (!success && context.mounted) {
      final shouldPick = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Re-sync with Gemini AI'),
          content: Text(
            'The original photo for "${item.title}" is not cached in local memory. Would you like to select the note photo to re-sync?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Select Photo & Sync'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (shouldPick == true && context.mounted) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null && context.mounted) {
          final bytes = await picked.readAsBytes();
          await StudyQueueService.instance.syncWithImageBytes(
            item,
            bytes,
            customApiKey: GeminiService.savedApiKey,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Syncing "${item.title}" with selected photo...'),
                backgroundColor: Colors.green.shade800,
              ),
            );
          }
        }
      }
    }
  }

  Widget _buildCustomBadge(
    BuildContext context,
    String text,
    IconData icon,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
