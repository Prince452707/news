import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class NewsService {
  static const String _baseUrl = 'https://saurav.tech/NewsAPI/top-headlines/category/health/in.json';

  Future<List<Article>> getTopHeadlines() async {
    final response = await http.get(Uri.parse(_baseUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final articles = (data['articles'] as List)
          .map((article) => Article.fromJson(article))
          .where((article) => article.imageUrl.isNotEmpty)
          .toList();
      return articles;
    } else {
      throw Exception('Failed to load news');
    }
  }
}

class Article {
  final String title;
  final String description;
  final String url;
  final String imageUrl;
  final DateTime publishedAt;
  final String author;
  final String content;

  Article({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.publishedAt,
    required this.author,
    required this.content,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'] ?? '',
      publishedAt: DateTime.parse(json['publishedAt']),
      author: json['author'] ?? 'Unknown',
      content: json['content'] ?? '',
    );
  }
}

class EnhancedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  EnhancedNetworkImage({
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
  });

  String getAlternativeImageUrl(String originalUrl) {
    if (originalUrl.startsWith('http:')) {
      return originalUrl.replaceFirst('http:', 'https:');
    }
    return originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final processedUrl = getAlternativeImageUrl(imageUrl);
    
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CachedNetworkImage(
        imageUrl: processedUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => Container(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          child: Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: colorScheme.surfaceVariant,
        ),
      ),
    );
  }
}

final newsProvider = StateNotifierProvider<NewsNotifier, AsyncValue<List<Article>>>((ref) {
  return NewsNotifier(NewsService());
});

class NewsNotifier extends StateNotifier<AsyncValue<List<Article>>> {
  NewsNotifier(this._newsService) : super(AsyncValue.loading()) {
    loadNews();
  }

  final NewsService _newsService;

  Future<void> loadNews() async {
    try {
      final articles = await _newsService.getTopHeadlines();
      state = AsyncValue.data(articles);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = AsyncValue.loading();
    await loadNews();
  }
}

void main() {
  runApp(ProviderScope(child: NewsApp()));
}

class NewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health News India',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A085),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A085),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: NewsHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NewsHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsState = ref.watch(newsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: colorScheme.primary),
            SizedBox(width: 8),
            Text(
              'Health News India',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: colorScheme.onBackground,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.primary),
            onPressed: () => ref.read(newsProvider.notifier).refresh(),
          ),
        ],
        backgroundColor: colorScheme.background,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(newsProvider.notifier).refresh(),
        color: colorScheme.primary,
        child: newsState.when(
          data: (articles) => NewsList(articles: articles),
          loading: () => LoadingView(),
          error: (error, stackTrace) => ErrorView(error: error.toString()),
        ),
      ),
    );
  }
}

class NewsList extends StatelessWidget {
  final List<Article> articles;

  NewsList({required this.articles});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: articles.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        return NewsCard(article: articles[index]);
      },
    );
  }
}

class NewsCard extends StatelessWidget {
  final Article article;

  NewsCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.imageUrl.isNotEmpty) EnhancedNetworkImage(imageUrl: article.imageUrl),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  article.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: colorScheme.primary),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              article.author,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(article.publishedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.read_more),
                  label: Text('READ FULL ARTICLE'),
                  onPressed: () => _launchURL(article.url),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}

class LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  color: Colors.white,
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 24,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ErrorView extends ConsumerWidget {
  final String error;

  ErrorView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: colorScheme.error),
            SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              onPressed: () => ref.read(newsProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}