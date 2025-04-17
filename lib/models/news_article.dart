class NewsArticle {
  final String title;
  final String description;
  final String source;
  final String url;
  final String publishedAt;
  final String content;
  
  NewsArticle({
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.content,
  });
  
  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? 'No title',
      description: json['description'] ?? 'No description available',
      source: json['source']['name'] ?? 'Unknown source',
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      content: json['content'] ?? 'No content available',
    );
  }
  
  @override
  String toString() {
    return 'News from $source: $title. $description';
  }
} 