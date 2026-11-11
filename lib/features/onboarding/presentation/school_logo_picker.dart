import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/school_logo_repository.dart';

/// Step 3 reusable school-logo picker. Uses a private Supabase bucket,
/// validates bytes, and stores only a path on the applicant-owned draft.
class SchoolLogoPicker extends StatefulWidget {
  const SchoolLogoPicker({
    super.key,
    required this.path,
    required this.onChanged,
    this.repository,
  });
  final String? path;
  final ValueChanged<String?> onChanged;
  final SchoolLogoRepository? repository;

  @override
  State<SchoolLogoPicker> createState() => _SchoolLogoPickerState();
}

class _SchoolLogoPickerState extends State<SchoolLogoPicker> {
  bool busy = false;
  String? imageUrl;
  Uint8List? uploadedPreview;
  String? message;

  SchoolLogoRepository get repository => widget.repository ??
      SupabaseSchoolLogoRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load(widget.path);
  }

  @override
  void didUpdateWidget(covariant SchoolLogoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      uploadedPreview = null;
      _load(widget.path);
    }
  }

  Future<void> _load(String? path) async {
    if (path == null) {
      if (mounted) setState(() => imageUrl = null);
      return;
    }
    try {
      final url = await repository.signedUrl(path);
      if (mounted && widget.path == path) {
        setState(() => imageUrl = url);
      }
    } catch (_) {
      if (mounted && widget.path == path) {
        setState(() => message = 'Logo preview unavailable. You can re-upload it.');
      }
    }
  }

  Future<void> _pick() async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      final result = await repository.chooseAndUpload();
      if (!mounted || result == null) return;
      setState(() {
        uploadedPreview = result.previewBytes;
        imageUrl = null;
        message = 'Logo uploaded privately. Save Draft to keep it.';
      });
      widget.onChanged(result.path);
    } on FormatException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) setState(() => message =
          'Could not upload logo. Check the image and internet connection.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('school-logo-control'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .22),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 64,height: 64,child:
                uploadedPreview != null ? Image.memory(
                  uploadedPreview!,fit: BoxFit.cover)
                : imageUrl != null ? Image.network(
                  imageUrl!,fit:BoxFit.cover,
                  errorBuilder: (_,__,___) =>
                    const Icon(Icons.school_outlined))
                : Icon(Icons.school_outlined,
                    size: 32,color: colors.primary))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('School logo (optional)',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                Text('PNG, JPEG or WebP · Max 2 MB · Private',
                  style: TextStyle(
                    fontSize: 11,color: colors.onSurfaceVariant)),
              ])),
          ]),
          const SizedBox(height: 11),
          Wrap(spacing: 8,runSpacing: 7,children: [
            OutlinedButton.icon(
              key: const Key('school-upload-logo'),
              onPressed: busy ? null : _pick,
              icon: busy ? const SizedBox(width:16,height:16,
                child: CircularProgressIndicator(strokeWidth:2))
                : const Icon(Icons.upload_file_outlined,size:18),
              label: Text(widget.path == null ? 'Choose Logo' : 'Replace Logo')),
            if (widget.path != null)
              TextButton.icon(
                key: const Key('school-remove-logo'),
                onPressed: busy ? null : () {
                  setState(() {
                    uploadedPreview = null;
                    imageUrl = null;
                    message = 'Logo removed from draft. Save to confirm.';
                  });
                  widget.onChanged(null);
                },
                icon: const Icon(Icons.close,size:18),
                label: const Text('Remove')),
          ]),
          if (message != null)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(message!,
                style: TextStyle(fontSize: 11,
                  color: colors.onSurfaceVariant))),
        ],
      ),
    );
  }
}
