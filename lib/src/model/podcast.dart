import 'dart:async';
import 'dart:io';

import 'package:dart_rss/dart_rss.dart';
import 'package:dio/dio.dart';
import 'package:itunes_podcast_search/itunes_podcast_search.dart';
import 'package:itunes_podcast_search/src/model/chapter.dart';
import 'package:itunes_podcast_search/src/model/chapter_headers.dart';
import 'package:itunes_podcast_search/src/model/chapters.dart';
import 'package:itunes_podcast_search/src/model/episode.dart';
import 'package:itunes_podcast_search/src/model/funding.dart';
import 'package:itunes_podcast_search/src/model/locked.dart';
import 'package:itunes_podcast_search/src/search/base_search.dart';
import 'package:itunes_podcast_search/src/utils/utils.dart';


class Podcast {
  final String? url;

  /// Podcast link.
  final String? link;

  /// Name of the podcast.
  final String? title;

  /// Optional description.
  final String? description;

  /// Url of artwork image
  final String? image;

  /// Copyright
  final String? copyright;

  /// Indicates to podcast platforms whether this feed can be imported or not. If [true] the
  /// feed is locked and should not be imported elsewhere.
  final Locked? locked;

  /// If the podcast supports funding this will contain an instance of [Funding] that
  /// contains the Url and optional description.
  final List<Funding>? funding;

  /// A list of current episodes.
  final List<Episode>? episodes;

  Podcast._({
    this.url,
    this.link,
    this.title,
    this.description,
    this.image,
    this.copyright,
    this.locked,
    this.funding,
    this.episodes,
  });

  static Future<Podcast> loadFeed({
    required String url,
    int timeout = 20000,
    String userAgent = '',
  }) async {
    final client = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {
          'User-Agent': userAgent.isEmpty ? '$podcastSearchAgent' : '$userAgent',
        },
      ),
    );

    try {
      final response = await client.get(url);

      var rssFeed = RssFeed.parse(response.data);

      // Parse the episodes
      return _loadFeed(rssFeed, url);
    } on DioError catch (e) {
      switch (e.type) {
        case DioErrorType.connectTimeout:
        case DioErrorType.sendTimeout:
        case DioErrorType.receiveTimeout:
        case DioErrorType.other:
          throw PodcastTimeoutException(e.message);
        case DioErrorType.response:
          throw PodcastFailedException(e.message);
        case DioErrorType.cancel:
          throw PodcastCancelledException(e.message);
      }
    }
  }

  static Future<Podcast> loadFeedFile({
    required String file,
  }) async {
    var f = File(file);

    if (f.existsSync()) {
      var input = f.readAsStringSync();
      var rssFeed = RssFeed.parse(input);

      return _loadFeed(rssFeed, file);
    }

    return Podcast._(url: file);
  }

  static Podcast _loadFeed(RssFeed rssFeed, String url) {
    // Parse the episodes
    var episodes = <Episode>[];
    var author = rssFeed.itunes!.author;

    var funding = <Funding>[];

    _loadEpisodes(rssFeed, episodes);

    return Podcast._(
      url: url,
      link: rssFeed.link,
      title: rssFeed.title,
      description: rssFeed.description,
      image: rssFeed.image?.url ?? rssFeed.itunes?.image?.href,
      copyright: author,
      funding: funding,
      episodes: episodes,
    );
  }

  static Future<Episode> loadEpisodeChapters({
    required Episode episode,
    bool forceReload = false,
    int timeout = 20000,
  }) async {
    final client = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    if (episode.chapters!.chapters.isNotEmpty && !episode.chapters!.loaded && !forceReload) {
      try {
        final response = await client.get(episode.chapters!.url);

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          _loadChapters(response, episode.chapters!);
        }
      } on DioError catch (e) {
        switch (e.type) {
          case DioErrorType.connectTimeout:
          case DioErrorType.sendTimeout:
          case DioErrorType.receiveTimeout:
          case DioErrorType.other:
            throw PodcastTimeoutException(e.message);
          case DioErrorType.response:
            throw PodcastFailedException(e.message);
          case DioErrorType.cancel:
            throw PodcastCancelledException(e.message);
        }
      }
    }

    return episode;
  }

  /// Podcasts that support the newer podcast namespace can include chapter markers. Typically this
  /// is in the form of a Url in the RSS feed pointing to a JSON file. This method takes the Url
  /// and loads the chapters, return a populated Chapters object.
  static Future<Chapters> loadChaptersByUrl({
    required String url,
    int timeout = 20000,
  }) async {
    final client = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    var chapters = Chapters();

    try {
      final response = await client.get(url);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        _loadChapters(response, chapters);
      }
    } on DioError catch (e) {
      switch (e.type) {
        case DioErrorType.connectTimeout:
        case DioErrorType.sendTimeout:
        case DioErrorType.receiveTimeout:
        case DioErrorType.other:
          throw PodcastTimeoutException(e.message);
        case DioErrorType.response:
          throw PodcastFailedException(e.message);
        case DioErrorType.cancel:
          throw PodcastCancelledException(e.message);
      }
    }

    return chapters;
  }

  static void _loadChapters(Response response, Chapters c) {
    final data = Map<String, dynamic>.from(response.data);
    final chapters = data['chapters'] ?? [];

    c.headers = ChapterHeaders(
      version: data['version'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      podcastName: data['podcastName'] ?? '',
      description: data['description'] ?? '',
      fileName: data['fileName'] ?? '',
    );

    c.loaded = true;

    for (var chapter in chapters) {
      double? startTime = 0.0;
      double? endTime = 0.0;

      // The spec says that the start and end times are a float; however,
      // some chapters come in as whole seconds whilst others include the
      // fraction. We test the type here to prevent conversion/casting errors.
      if (chapter['startTime'] != null) {
        if (chapter['startTime'] is double) {
          startTime = chapter['startTime'];
        } else if (chapter['startTime'] is int) {
          startTime = (chapter['startTime'] as int).toDouble();
        }
      }

      if (chapter['endTime'] != null) {
        if (chapter['endTime'] is double) {
          endTime = chapter['endTime'];
        } else if (chapter['endTime'] is int) {
          endTime = (chapter['endTime'] as int).toDouble();
        }
      }

      c.chapters.add(
        Chapter(
            url: chapter['url'] ?? '',
            imageUrl: chapter['img'] ?? '',
            title: chapter['title'] ?? '',
            startTime: startTime ?? 0.0,
            endTime: endTime ?? 0.0,
            toc: (chapter['toc'] != null && (chapter['toc'] as bool?) == false) ? false : true),
      );
    }
  }

  static void _loadEpisodes(RssFeed rssFeed, List<Episode> episodes) {
    rssFeed.items.forEach((item) {
      episodes.add(Episode(
        guid: item.guid ?? '',
        title: item.title ?? '',
        description: item.description ?? '',
        link: item.link,
        publicationDate: Utils.parseRFC2822Date(item.pubDate!),
        author: item.author ?? item.itunes!.author ?? item.dc?.creator,
        duration: item.itunes?.duration,
        contentUrl: item.enclosure?.url,
        imageUrl: item.itunes?.image?.href,
        season: item.itunes?.season,
        episode: item.itunes?.episode,
      ));
    });
  }
}