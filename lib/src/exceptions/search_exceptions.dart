class PodcastTimeoutException implements Exception {
  final String _message;

  PodcastTimeoutException(this._message);
}

/// Thrown if the search is cancelled.
class PodcastCancelledException implements Exception {
  final String _message;

  PodcastCancelledException(this._message);
}

/// Thrown if we get an invalid response error.
class PodcastFailedException implements Exception {
  final String _message;

  PodcastFailedException(this._message);
}
