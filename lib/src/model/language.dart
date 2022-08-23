class Language {
  final String _language;

  static const NONE = Language('');

  static const ENGLISH = Language('en_us');

  const Language(String language) : _language = language;

  String get language => _language;
}
