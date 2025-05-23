import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

class NewsService {
  // Default API key as provided
  final String _defaultApiKey = '292738e336f44779b2db8aed22871538';
  final String _baseUrl = 'https://newsapi.org/v2';
  
  // Valid categories and country codes
  final List<String> _validCategories = [
    'business', 'sports', 'technology', 'health', 
    'science', 'entertainment', 'general'
  ];
  
  final Map<String, String> _countryCodes = {
    'india': 'in',
    'australia': 'au',
    'canada': 'ca',
    'china': 'cn',
    'france': 'fr',
    'germany': 'de',
    'japan': 'jp',
    'uk': 'gb',
    'us': 'us',
    'usa': 'us',
    'united states': 'us',
    'united kingdom': 'gb',
  };
  
  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('news_api_key') ?? _defaultApiKey;
  }
  
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('news_api_key', apiKey);
  }
  
  /// Parse voice command to extract intent, category, and location
  Map<String, String?> parseVoiceCommand(String command) {
    final String normalizedCommand = command.toLowerCase().trim();
    String? category;
    String? country;
    String? location;
    
    // Extract location first as it's the highest priority parameter
    final List<String> commonCities = [
      'delhi', 'mumbai', 'bangalore', 'bengaluru', 'chennai', 'kolkata',
      'hyderabad', 'pune', 'ahmedabad', 'surat', 'hubli', 'hubballi', 'dharwad',
      'new york', 'london', 'paris', 'tokyo', 'sydney', 'dubai', 'singapore',
      'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'thane', 'goa',
      'bhopal', 'visakhapatnam', 'patna', 'vadodara', 'ghaziabad', 'mangalore',
      'mysore', 'belgaum', 'gulbarga', 'bellary', 'bijapur', 'shimoga', 'tumkur',
      'udupi', 'manipal', 'davangere', 'hassan', 'mandya', 'chikmagalur'
    ];
    
    // Pattern matching for various location phrasings
    // 1. "news from/in/of [city]"
    // 2. "[city] news"
    // 3. "tell me about [city]"
    // 4. "what's happening in [city]"
    final List<RegExp> locationRegexes = [
      RegExp(r'(?:in|from|of|at|about|for|near)\s+([a-z\s]+)(?:\s|$)', caseSensitive: false),
      RegExp(r'([a-z\s]+)\s+news', caseSensitive: false),
      RegExp(r'tell\s+me\s+(?:about|the)\s+([a-z\s]+)', caseSensitive: false),
      RegExp(r'what\s+is\s+happening\s+in\s+([a-z\s]+)', caseSensitive: false)
    ];
    
    // Try each regex pattern
    for (final regex in locationRegexes) {
      final matches = regex.allMatches(normalizedCommand);
      if (matches.isNotEmpty) {
        for (final match in matches) {
          final extractedLocation = match.group(1)?.trim();
          if (extractedLocation != null) {
            // Check if the extracted text contains a known city
            for (final city in commonCities) {
              if (extractedLocation.contains(city)) {
                location = city;
                break;
              }
            }
            
            // If we found a location, break out of the loop
            if (location != null) break;
          }
        }
      }
      // If we found a location, break out of the outer loop too
      if (location != null) break;
    }
    
    // Direct city name check if regex fails
    if (location == null) {
      for (final city in commonCities) {
        if (normalizedCommand.contains(city)) {
          location = city;
          break;
        }
      }
    }
    
    // Extract category after location
    for (final validCategory in _validCategories) {
      if (normalizedCommand.contains(validCategory)) {
        category = validCategory;
        break;
      }
    }
    
    // More comprehensive category mapping for similar terms
    if (category == null) {
      final Map<String, String> categoryMapping = {
        'politics': 'general',
        'political': 'general',
        'financial': 'business',
        'finance': 'business',
        'economy': 'business',
        'economic': 'business',
        'market': 'business',
        'markets': 'business',
        'stock': 'business',
        'stocks': 'business',
        'tech': 'technology',
        'technological': 'technology',
        'digital': 'technology',
        'software': 'technology',
        'hardware': 'technology',
        'health': 'health',
        'healthcare': 'health',
        'medical': 'health',
        'medicine': 'health',
        'wellness': 'health',
        'sport': 'sports',
        'cricket': 'sports',
        'football': 'sports',
        'soccer': 'sports',
        'tennis': 'sports',
        'basketball': 'sports',
        'entertainment': 'entertainment',
        'movie': 'entertainment',
        'movies': 'entertainment',
        'film': 'entertainment',
        'celebrity': 'entertainment',
        'celebrities': 'entertainment',
        'science': 'science',
        'research': 'science',
        'scientific': 'science',
        'discovery': 'science',
        'space': 'science'
      };
      
      for (final entry in categoryMapping.entries) {
        if (normalizedCommand.contains(entry.key)) {
          category = entry.value;
          break;
        }
      }
    }
    
    // Extract country last (lowest priority as we default to India)
    for (final entry in _countryCodes.entries) {
      if (normalizedCommand.contains(entry.key)) {
        country = entry.value;
        break;
      }
    }
    
    // Default to India if no country is mentioned
    country ??= 'in';
    
    // Handle special cases like "near me" - default to user's location
    if (normalizedCommand.contains('near me')) {
      // For demo purposes, we'll just default to a major Indian city
      location = 'bangalore';
    }
    
    // Handle category + location combinations (e.g., "business news from Hubli")
    if (location != null && category != null) {
      // This is already handled by having both values set
      print('Found category ($category) + location ($location) request');
    }
    
    // Handle direct city name queries (e.g., "Hubli news")
    if (location != null && category == null && !normalizedCommand.contains("news")) {
      // If just a city name is mentioned without "news", assume it's a news query
      print('Interpreting "$normalizedCommand" as news from $location');
    }
    
    // Handle generic queries properly
    final List<String> genericNewsQueries = [
      'tell me the news',
      'what\'s happening',
      'what is happening',
      'latest news',
      'current news',
      'news update',
      'news updates',
      'today\'s news',
      'todays news',
      'recent news'
    ];
    
    bool isGenericQuery = false;
    for (final query in genericNewsQueries) {
      if (normalizedCommand.contains(query)) {
        isGenericQuery = true;
        break;
      }
    }
    
    // For very generic news requests without specifics
    if (normalizedCommand == 'news' || isGenericQuery) {
      if (location == null && category == null) {
        // Default to top headlines from India
        category = null;
        country = 'in';
        location = null;
      }
    }
    
    print('Parsed command: category=$category, country=$country, location=$location');
    return {
      'category': category,
      'country': country,
      'location': location,
    };
  }
  
  /// Get news based on the parsed voice command parameters
  Future<List<NewsArticle>> getNewsFromVoiceCommand(String command) async {
    final parameters = parseVoiceCommand(command);
    final category = parameters['category'];
    final country = parameters['country'];
    final location = parameters['location'];
    
    // Build API URL based on parameters
    String url;
    final apiKey = await _getApiKey();
    
    // Case A: If only location is mentioned
    if (location != null) {
      url = '$_baseUrl/everything?q=$location&sortBy=publishedAt&language=en&apiKey=$apiKey';
    } 
    // Case C: If country + category
    else if (category != null && country != null) {
      url = '$_baseUrl/top-headlines?country=$country&category=$category&apiKey=$apiKey';
    }
    // Case D: If only category
    else if (category != null) {
      url = '$_baseUrl/top-headlines?category=$category&apiKey=$apiKey';
    }
    // Case B & E: Default/Fallback - general query or invalid parameters
    else {
      url = '$_baseUrl/top-headlines?country=$country&apiKey=$apiKey';
    }
    
    return await _fetchNewsFromUrl(url);
  }
  
  /// Fetch news from the given URL
  Future<List<NewsArticle>> _fetchNewsFromUrl(String url, {int limit = 5}) async {
    try {
      final response = await http.get(Uri.parse(url));
      
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
  
  Future<List<NewsArticle>> getTopHeadlines({int limit = 5}) async {
    try {
      final apiKey = await _getApiKey();
      // Use techcrunch as source as specified in requirements
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?sources=techcrunch&apiKey=$apiKey'),
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
  
  /// Generates a spoken summary of news based on a voice command
  Future<String> getNewsForSpeech(String command, {int limit = 3}) async {
    try {
      final articles = await getNewsFromVoiceCommand(command);
      final parameters = parseVoiceCommand(command);
      
      if (articles.isEmpty) {
        return 'No news articles available at this time.';
      }
      
      // Prepare introduction text based on parameters
      final StringBuffer summary = StringBuffer();
      
      // Build introduction phrase
      if (parameters['location'] != null) {
        final String location = parameters['location']!;
        if (parameters['category'] != null) {
          summary.write('Here is the latest ${parameters['category']} news from $location: ');
        } else {
          summary.write('Here is the latest news from $location: ');
        }
      } else if (parameters['category'] != null && parameters['country'] == 'in') {
        summary.write('Here is the latest ${parameters['category']} news from India: ');
      } else if (parameters['category'] != null) {
        summary.write('Here is the latest ${parameters['category']} news: ');
      } else if (parameters['country'] == 'in') {
        summary.write('Here is the latest news from India: ');
      } else {
        summary.write('Here are the latest headlines: ');
      }
      
      // Add articles to the summary with clean formatting for both speech and display
      for (int i = 0; i < articles.length; i++) {
        final article = articles[i];
        
        // Add separator between articles
        if (i > 0) {
          summary.write('\n\n----------------------------------------\n\n');
        }
        
        // Format article number for better readability
        summary.write('ARTICLE ${i + 1}\n\n');
        
        // Include title and remove any trailing dots as we'll add our own
        String title = article.title;
        if (title.endsWith('.')) {
          title = title.substring(0, title.length - 1);
        }
        
        summary.write('TITLE: $title.\n\n');
        
        // Add source for attribution
        summary.write('SOURCE: ${article.source}.\n\n');
        
        // Published date if available
        if (article.publishedAt.isNotEmpty) {
          // Simple date formatting - could be enhanced in a production app
          summary.write('PUBLISHED: ${article.publishedAt}.\n\n');
        }
        
        // Include description if it's not redundant with the title
        String description = article.description;
        if (description != 'No description available' && 
            !title.toLowerCase().contains(description.toLowerCase()) &&
            !description.toLowerCase().contains(title.toLowerCase())) {
          
          if (description.endsWith('.')) {
            description = description.substring(0, description.length - 1);
          }
          summary.write('DESCRIPTION: $description.\n\n');
        }
        
        // Add content if available (truncate if too long)
        final content = article.content;
        if (content.isNotEmpty && 
            content != 'No content available' && 
            !title.toLowerCase().contains(content.toLowerCase()) &&
            !content.toLowerCase().contains(title.toLowerCase()) &&
            !description.toLowerCase().contains(content.toLowerCase()) &&
            !content.toLowerCase().contains(description.toLowerCase())) {
            
          // Remove the trailing "[+chars chars]" that often appears in NewsAPI responses
          String cleanContent = content.replaceAll(RegExp(r'\[\+\d+ chars\]$'), '');
          
          // Format content for readability
          if (cleanContent.endsWith('.')) {
            cleanContent = cleanContent.substring(0, cleanContent.length - 1);
          }
          
          summary.write('CONTENT: $cleanContent.\n\n');
        }
        
        // Add URL for reference
        if (article.url.isNotEmpty) {
          summary.write('LINK: ${article.url}\n');
        }
      }
      
      return summary.toString();
    } catch (e) {
      return 'Unable to get news information at this time. Please try again later. Error: $e';
    }
  }
  
  /// Generates a speech-friendly version of the news summary
  Future<String> getNewsForSpeechOutput(String command, {int limit = 3}) async {
    try {
      final articles = await getNewsFromVoiceCommand(command);
      final parameters = parseVoiceCommand(command);
      
      if (articles.isEmpty) {
        return 'No news articles available at this time. Please try again later or try a different query.';
      }
      
      // Prepare introduction text based on parameters
      final StringBuffer summary = StringBuffer();
      
      // Build introduction phrase with more context
      if (parameters['location'] != null) {
        final String location = parameters['location']!;
        if (parameters['category'] != null) {
          summary.write('Here is the latest ${parameters['category']} news from $location as reported recently. ');
        } else {
          summary.write('Here is the latest news from $location as reported recently. ');
        }
      } else if (parameters['category'] != null && parameters['country'] == 'in') {
        summary.write('Here is the latest ${parameters['category']} news from India. ');
      } else if (parameters['category'] != null) {
        summary.write('Here is the latest ${parameters['category']} news. ');
      } else if (parameters['country'] == 'in') {
        summary.write('Here is the latest news from India. ');
      } else {
        summary.write('Here are the latest news headlines. ');
      }
      
      // Add count information
      if (articles.length > 1) {
        summary.write('I found ${articles.length} articles for you. ');
      }
      
      // Add articles to the summary with speech-friendly formatting
      for (int i = 0; i < articles.length; i++) {
        final article = articles[i];
        
        // Add numbering and separator between articles for clarity
        if (i > 0) {
          summary.write('Moving to the next article. ');
        }
        
        if (articles.length > 1) {
          summary.write('Article ${i+1}: ');
        }
        
        // Include title and remove any trailing dots as we'll add our own
        String title = article.title;
        if (title.endsWith('.')) {
          title = title.substring(0, title.length - 1);
        }
        
        // Add source with a more natural phrasing
        summary.write('$title, ');
        
        // Add publish date if available
        if (article.publishedAt.isNotEmpty && article.publishedAt != "null") {
          String publishDate = article.publishedAt;
          // Simple date formatting for speech - could be enhanced in a production app
          if (publishDate.length > 10) {
            publishDate = publishDate.substring(0, 10); // Just get YYYY-MM-DD
          }
          summary.write('published on $publishDate, ');
        }
        
        summary.write('reported by ${article.source}. ');
        
        // Include a condensed version of description or content for speech
        String? contentToSpeak;
        
        if (article.description != 'No description available' && 
            !title.toLowerCase().contains(article.description.toLowerCase())) {
          contentToSpeak = article.description;
        } else if (article.content != 'No content available' && 
                   !title.toLowerCase().contains(article.content.toLowerCase())) {
          // Remove the trailing "[+chars chars]" that often appears in NewsAPI responses
          contentToSpeak = article.content.replaceAll(RegExp(r'\[\+\d+ chars\]$'), '');
          
          // Trim content if it's too long for speech (more than ~150 characters)
          if (contentToSpeak.length > 150) {
            contentToSpeak = contentToSpeak.substring(0, 150) + '...';
          }
        }
        
        if (contentToSpeak != null) {
          if (contentToSpeak.endsWith('.')) {
            summary.write('Here\'s a brief summary: $contentToSpeak ');
          } else {
            summary.write('Here\'s a brief summary: $contentToSpeak. ');
          }
        }
        
        // Add a brief pause between articles
        if (i < articles.length - 1) {
          summary.write('... ');
        }
      }
      
      // Add a closing statement
      if (articles.length > 1) {
        summary.write('That\'s all the articles I found based on your request.');
      }
      
      return summary.toString();
    } catch (e) {
      return 'I\'m sorry, I\'m unable to get news information at this time. Please try again later.';
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