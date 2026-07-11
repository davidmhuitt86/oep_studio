import 'package:flutter/material.dart';

/// The kinds of Source Material Work Package 008 STUDIO-TASK-000016
/// supports attaching: "Supported initially: PDF, Images, Markdown,
/// Text." No OCR, no parsing — Studio only manages the evidence file
/// itself.
enum SourceMaterialType {
  pdf('PDF', Icons.picture_as_pdf_outlined),
  image('Image', Icons.image_outlined),
  markdown('Markdown', Icons.article_outlined),
  text('Text', Icons.description_outlined),
  other('Other', Icons.insert_drive_file_outlined);

  const SourceMaterialType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Classifies a file by its extension — the only signal available
  /// without parsing the file's contents (explicitly out of scope:
  /// "No OCR. No parsing.").
  static SourceMaterialType fromExtension(String fileName) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (extension) {
      'pdf' => SourceMaterialType.pdf,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'bmp' || 'webp' => SourceMaterialType.image,
      'md' || 'markdown' => SourceMaterialType.markdown,
      'txt' => SourceMaterialType.text,
      _ => SourceMaterialType.other,
    };
  }
}
