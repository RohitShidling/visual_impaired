import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

class NewsService {
  // Default API key as provided
  final String _defaultApiKey = '292738e336f44779b2db8aed22871538';
  final String _baseUrl = 'https://newsapi.org/v2/top-headlines';
  
  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('news_api_key') ?? _defaultApiKey;
  }
  
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('news_api_key', apiKey);
  }
  
  Future<List<NewsArticle>> getTopHeadlines({int limit = 5}) async {
    try {
      final apiKey = await _getApiKey();
      // Use techcrunch as source as specified in requirements
      final response = await http.get(
        Uri.parse('$_baseUrl?sources=techcrunch&apiKey=$apiKey'),
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
  
  Future<String> getTopHeadlinesSummary({int limit = 3}) async {
    try {
      final articles = await getTopHeadlines(limit: limit);
      
      if (articles.isEmpty) {
        return 'No news articles available at this time.';
      }
      
      final StringBuffer summary = StringBuffer('Here are the latest headlines: ');
      
      for (int i = 0; i < articles.length; i++) {
        // Add separator between headlines
        if (i > 0) {
          summary.write('\n\nNext article: ');
        }
        // Include title and content as requested
        summary.write('${articles[i].title}. ${articles[i].content}');
      }
      
      return summary.toString();
    } catch (e) {
      return 'Unable to get news information at this time. Please try again later.';
    }
  }
} 