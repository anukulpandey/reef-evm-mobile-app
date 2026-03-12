import 'dart:convert';

import 'package:flutter/material.dart';

class IconDataUtils {
  const IconDataUtils._();

  static ImageProvider? resolveImageProvider(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final normalized = iconUrl.trim();
    final dataUri = tryParseDataUri(normalized);
    if (dataUri != null) {
      if (dataUri.mimeType.contains('svg')) return null;
      final bytes = dataUri.contentAsBytes();
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(normalized);
  }

  static String? resolveSvgData(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final dataUri = tryParseDataUri(iconUrl.trim());
    if (dataUri == null || !dataUri.mimeType.contains('svg')) return null;
    final bytes = dataUri.contentAsBytes();
    if (bytes.isEmpty) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static UriData? tryParseDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    try {
      return UriData.parse(value);
    } catch (_) {
      return null;
    }
  }
}
