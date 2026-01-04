enum EditorStyle {
  plain,
  notebook,
  cross,
  dotted,
  card;

  String get displayName {
    switch (this) {
      case EditorStyle.plain:
        return 'Plain';
      case EditorStyle.notebook:
        return 'Notebook';
      case EditorStyle.cross:
        return 'Cross';
      case EditorStyle.dotted:
        return 'Dotted';
      case EditorStyle.card:
        return 'Card';
    }
  }
}