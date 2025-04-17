import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class NewsService {
  // In a real app, this should be stored securely, not hardcoded
  final String _apiKey = 'YOUR_NEWSAPI_API_KEY';
  final String _baseUrl = 'https://newsapi.org/v2/top-headlines';
  
  Future<List<NewsArticle>> getTopHeadlines({String country = 'us', int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?country=$country&pageSize=$limit&apiKey=$_apiKey'),
        headers: {'X-Api-Key': _apiKey},
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> articles = data['articles'];
        
        return articles
            .take(limit)
            .map((article) => NewsArticle.fromJson(article))
            .toList();
      } else {
        throw Exception('Failed to load news. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load news: $e');
    }
  }
  
  Future<String> getTopHeadlinesSummary({String country = 'us', int limit = 3}) async {
    try {
      final articles = await getTopHeadlines(country: country, limit: limit);
      
      if (articles.isEmpty) {
        return 'No news articles available at this time.';
      }
      
      final StringBuffer summary = StringBuffer('Here are the latest headlines: ');
      
      for (int i = 0; i < articles.length; i++) {
        summary.write('${i + 1}. ${articles[i].toString()} ');
      }
      
      return summary.toString();
    } catch (e) {
      return 'Unable to get news information at this time. Please try again later.';
    }
  }
} 