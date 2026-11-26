import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class StudyImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const StudyImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;

    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIndex = imageUrl.indexOf(',');
        final base64Data = commaIndex != -1 ? imageUrl.substring(commaIndex + 1) : imageUrl;
        final Uint8List bytes = base64Decode(base64Data);
        imageWidget = Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (e) {
        imageWidget = const SizedBox.shrink();
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
