class SearchProvider {
  const SearchProvider();
}

/// Pass an instance of this class to use iTunes as the podcast search engine.
class ITunesProvider extends SearchProvider {
  const ITunesProvider();
}

/// Pass an instance of this class to use PodcastIndex as the podcast search engine.
// class PodcastIndexProvider extends SearchProvider {
//   /// The API key.
//   final String key;

//   /// The API secret.
//   final String secret;

//   PodcastIndexProvider({
//     required this.key,
//     required this.secret,
//   });
// }