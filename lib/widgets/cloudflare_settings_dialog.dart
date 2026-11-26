import 'package:flutter/material.dart';
import '../services/cloudflare_storage_service.dart';
import '../services/storage_service.dart';

class CloudflareSettingsDialog extends StatefulWidget {
  const CloudflareSettingsDialog({super.key});

  @override
  State<CloudflareSettingsDialog> createState() => _CloudflareSettingsDialogState();
}

class _CloudflareSettingsDialogState extends State<CloudflareSettingsDialog> {
  late final TextEditingController _accountIdController;
  late final TextEditingController _bucketController;
  late final TextEditingController _publicDomainController;
  late final TextEditingController _workerUrlController;
  late StorageProvider _selectedProvider;

  @override
  void initState() {
    super.initState();
    _accountIdController = TextEditingController(text: CloudflareConfig.accountId);
    _bucketController = TextEditingController(text: CloudflareConfig.bucketName);
    _publicDomainController = TextEditingController(text: CloudflareConfig.publicDomain);
    _workerUrlController = TextEditingController(text: CloudflareConfig.workerUploadUrl);
    _selectedProvider = StorageService.currentProvider;
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _bucketController.dispose();
    _publicDomainController.dispose();
    _workerUrlController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    CloudflareConfig.accountId = _accountIdController.text.trim();
    CloudflareConfig.bucketName = _bucketController.text.trim().isNotEmpty
        ? _bucketController.text.trim()
        : 'snapstudy-notes';
    CloudflareConfig.publicDomain = _publicDomainController.text.trim();
    CloudflareConfig.workerUploadUrl = _workerUrlController.text.trim();
    StorageService.currentProvider = _selectedProvider;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storage settings saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_queue_rounded, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Storage Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider selector
            SegmentedButton<StorageProvider>(
              segments: const [
                ButtonSegment(
                  value: StorageProvider.cloudflare,
                  label: Text('Cloudflare R2'),
                  icon: Icon(Icons.cloud_done_rounded),
                ),
                ButtonSegment(
                  value: StorageProvider.firebase,
                  label: Text('Firebase'),
                  icon: Icon(Icons.local_fire_department_rounded),
                ),
              ],
              selected: {_selectedProvider},
              onSelectionChanged: (set) {
                setState(() => _selectedProvider = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Cloudflare Free Tier Benefits Card
            if (_selectedProvider == StorageProvider.cloudflare) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Cloudflare Free Tier Included:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    SizedBox(height: 4),
                    Text('• 10 GB Storage Free / month', style: TextStyle(fontSize: 13)),
                    Text('• 10M Free Read & 1M Free Write operations', style: TextStyle(fontSize: 13)),
                    Text('• Zero Egress / Bandwidth Fees forever', style: TextStyle(fontSize: 13)),
                    Text('• Instant Free Mode: Works immediately with 0 config!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _accountIdController,
                decoration: const InputDecoration(
                  labelText: 'Cloudflare Account ID (Optional)',
                  hintText: 'e.g. 1a2b3c4d5e6f...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _bucketController,
                decoration: const InputDecoration(
                  labelText: 'R2 Bucket Name',
                  hintText: 'snapstudy-notes',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _publicDomainController,
                decoration: const InputDecoration(
                  labelText: 'R2 Public Domain (Optional)',
                  hintText: 'https://pub-xxxx.r2.dev',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _workerUrlController,
                decoration: const InputDecoration(
                  labelText: 'Worker Upload URL (Optional)',
                  hintText: 'https://r2-upload.your-subdomain.workers.dev',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Firebase Storage requires initializing the Storage bucket in the Firebase Console (snapstudy-hackathon).',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
