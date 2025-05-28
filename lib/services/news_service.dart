import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

class NewsService {
  // Default API key as provided
  final String _defaultApiKey = '292738e336f44779b2db8aed22871538';
  final String _baseUrl = 'https://newsapi.org/v2';
  
  // Valid categories according to NewsAPI.org
  final List<String> _validCategories = [
    'business', 'sports', 'technology', 'health', 
    'science', 'entertainment', 'general'
  ];
  
  // Comprehensive mapping of spoken terms to valid NewsAPI categories
  final Map<String, String> _categoryMapping = {
    // Direct matches
    'business': 'business',
    'sports': 'sports',
    'sport': 'sports',
    'technology': 'technology',
    'tech': 'technology',
    'health': 'health',
    'science': 'science',
    'entertainment': 'entertainment',
    'general': 'general',
    
    // Business category variations
    'financial': 'business',
    'finance': 'business',
    'economy': 'business',
    'economic': 'business',
    'market': 'business',
    'markets': 'business',
    'stock': 'business',
    'stocks': 'business',
    'investment': 'business',
    'investments': 'business',
    
    // Technology category variations
    'technological': 'technology',
    'digital': 'technology',
    'software': 'technology',
    'hardware': 'technology',
    'ai': 'technology',
    'artificial intelligence': 'technology',
    'computer': 'technology',
    'computers': 'technology',
    'smartphone': 'technology',
    'smartphones': 'technology',
    
    // Health category variations
    'healthcare': 'health',
    'medical': 'health',
    'medicine': 'health',
    'wellness': 'health',
    'hospital': 'health',
    'hospitals': 'health',
    'doctor': 'health',
    'doctors': 'health',
    'fitness': 'health',
    
    // Sports category variations
    'cricket': 'sports',
    'football': 'sports',
    'soccer': 'sports',
    'tennis': 'sports',
    'basketball': 'sports',
    'hockey': 'sports',
    'baseball': 'sports',
    'games': 'sports',
    'olympics': 'sports',
    'athletic': 'sports',
    'athletics': 'sports',
    
    // Entertainment category variations
    'movie': 'entertainment',
    'movies': 'entertainment',
    'film': 'entertainment',
    'films': 'entertainment',
    'celebrity': 'entertainment',
    'celebrities': 'entertainment',
    'actor': 'entertainment',
    'actress': 'entertainment',
    'music': 'entertainment',
    'television': 'entertainment',
    'tv': 'entertainment',
    'show': 'entertainment',
    'shows': 'entertainment',
    
    // Science category variations
    'research': 'science',
    'scientific': 'science',
    'discovery': 'science',
    'space': 'science',
    'astronomy': 'science',
    'physics': 'science',
    'chemistry': 'science',
    'biology': 'science',
    'environment': 'science',
    'climate': 'science',
    
    // General category variations
    'politics': 'general',
    'political': 'general',
    'government': 'general',
    'world': 'general',
    'national': 'general',
    'international': 'general',
    'global': 'general',
    'current affairs': 'general',
    'current events': 'general',
    'headline': 'general',
    'headlines': 'general'
  };
  
  // Country codes according to NewsAPI.org (2-letter ISO 3166-1 codes)
  final Map<String, String> _countryCodes = {
    'india': 'in',
    'australia': 'au',
    'canada': 'ca',
    'china': 'cn',
    'france': 'fr',
    'germany': 'de',
    'japan': 'jp',
    'uk': 'gb',
    'britain': 'gb',
    'england': 'gb',
    'united kingdom': 'gb',
    'us': 'us',
    'usa': 'us',
    'america': 'us',
    'united states': 'us',
    'russia': 'ru',
    'italy': 'it',
    'brazil': 'br',
    'south africa': 'za',
    'mexico': 'mx',
    'netherlands': 'nl',
    'norway': 'no',
    'sweden': 'se',
    'switzerland': 'ch',
    'turkey': 'tr',
    'uae': 'ae',
    'united arab emirates': 'ae',
    'south korea': 'kr',
    'korea': 'kr',
    'singapore': 'sg',
    'malaysia': 'my',
    'indonesia': 'id',
    'thailand': 'th',
    'philippines': 'ph',
    'new zealand': 'nz',
    'argentina': 'ar',
    'austria': 'at',
    'belgium': 'be',
    'bulgaria': 'bg',
    'colombia': 'co',
    'cuba': 'cu',
    'czech republic': 'cz',
    'egypt': 'eg',
    'greece': 'gr',
    'hong kong': 'hk',
    'hungary': 'hu',
    'ireland': 'ie',
    'israel': 'il',
    'latvia': 'lv',
    'lithuania': 'lt',
    'morocco': 'ma',
    'nigeria': 'ng',
    'poland': 'pl',
    'portugal': 'pt',
    'romania': 'ro',
    'saudi arabia': 'sa',
    'serbia': 'rs',
    'slovakia': 'sk',
    'slovenia': 'si',
    'taiwan': 'tw',
    'ukraine': 'ua',
    'venezuela': 've'
  };
  
  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('news_api_key') ?? _defaultApiKey;
  }
  
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('news_api_key', apiKey);
  }
  
  /// Parse voice command to extract category, country, and location with improved accuracy
  Map<String, String?> parseVoiceCommand(String command) {
    final String normalizedCommand = command.toLowerCase().trim();
    String? category;
    String? country;
    String? location;
    
    print('Original command: "$normalizedCommand"');
    
    // Step 1: Extract location first as it's the highest priority parameter
    final List<String> commonCities = [
      'delhi', 'mumbai', 'bangalore', 'bengaluru', 'chennai', 'kolkata',
      'hyderabad', 'pune', 'ahmedabad', 'surat', 'hubli', 'hubballi', 'dharwad',
      'new york', 'london', 'paris', 'tokyo', 'sydney', 'dubai', 'singapore',
      'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'thane', 'goa',
      'bhopal', 'visakhapatnam', 'patna', 'vadodara', 'ghaziabad', 'mangalore',
      'mysore', 'belgaum', 'gulbarga', 'bellary', 'bijapur', 'shimoga', 'tumkur',
      'udupi', 'manipal', 'davangere', 'hassan', 'mandya', 'chikmagalur'
    ];
    
    // Pattern matching for various location phrasings with enhanced regex
    final List<RegExp> locationRegexes = [
      RegExp(r'(?:in|from|of|at|about|for|near)\s+([a-z\s]+?)(?:\s+news|\s|$)'),
      RegExp(r'([a-z\s]+?)\s+news'),
      RegExp(r'tell\s+me\s+(?:about|the)\s+([a-z\s]+?)(?:\s+news|\s|$)'),
      RegExp(r'what\s+is\s+happening\s+in\s+([a-z\s]+?)(?:\s|$)'),
      RegExp(r'whats\s+happening\s+in\s+([a-z\s]+?)(?:\s|$)')
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
              if (extractedLocation.contains(city) && 
                  (extractedLocation == city || 
                   extractedLocation.startsWith('$city ') || 
                   extractedLocation.endsWith(' $city') || 
                   extractedLocation.contains(' $city '))) {
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
        if (normalizedCommand.contains(city) && 
            (normalizedCommand == city || 
             normalizedCommand.startsWith('$city ') || 
             normalizedCommand.endsWith(' $city') || 
             normalizedCommand.contains(' $city '))) {
          location = city;
          break;
        }
      }
    }
    
    // Step 2: Extract country - check before category to avoid confusion
    for (final entry in _countryCodes.entries) {
      final countryName = entry.key;
      if (normalizedCommand.contains(countryName) && 
          (normalizedCommand == countryName || 
           normalizedCommand.startsWith('$countryName ') || 
           normalizedCommand.endsWith(' $countryName') || 
           normalizedCommand.contains(' $countryName '))) {
        country = entry.value;
        break;
      }
    }
    
    // Special case for US/United States
    if (country == null) {
      if (normalizedCommand.contains('us news') || 
          normalizedCommand.contains('u.s. news') || 
          normalizedCommand.contains('u.s news') || 
          normalizedCommand.contains('american news') || 
          normalizedCommand.contains('united states') || 
          normalizedCommand.contains('united state') ||
          (normalizedCommand.contains('us') && normalizedCommand.contains('news'))) {
        country = 'us';
      }
    }
    
    // Step 3: Extract category with improved priority
    // First, check for direct category matches in the original command
    for (final validCategory in _validCategories) {
      // Make sure we're matching whole words, not partial words (e.g. "sports" not "sport")
      final categoryPattern = RegExp(r'\b' + validCategory + r'\b', caseSensitive: false);
      if (categoryPattern.hasMatch(normalizedCommand)) {
        category = validCategory;
        break;
      }
    }
    
    // If no direct category match, try category variations
    if (category == null) {
      // Find all possible category matches
      final List<String> possibleMatches = [];
      
      for (final entry in _categoryMapping.entries) {
        final term = entry.key;
        // Match whole words only
        final termPattern = RegExp(r'\b' + term + r'\b', caseSensitive: false);
        if (termPattern.hasMatch(normalizedCommand)) {
          possibleMatches.add(term);
        }
      }
      
      // Sort by length (longer matches are more specific)
      possibleMatches.sort((a, b) => b.length.compareTo(a.length));
      
      // Use the most specific match if available
      if (possibleMatches.isNotEmpty) {
        category = _categoryMapping[possibleMatches.first];
      }
    }
    
    // Default to India if no country is mentioned
    country ??= 'in';
    
    // Handle special cases like "near me" - default to user's location
    if (normalizedCommand.contains('near me')) {
      // For demo purposes, we'll just default to a major Indian city
      location = 'bangalore';
    }
    
    // Handle direct "just news" or similar generic queries
    final List<String> genericNewsQueries = [
      'news',
      'tell me the news',
      'what\'s happening',
      'what is happening',
      'latest news',
      'current news',
      'news update',
      'news updates',
      'today\'s news',
      'todays news',
      'recent news',
      'top news',
      'headline',
      'headlines',
      'top headlines'
    ];
    
    bool isGenericQuery = false;
    for (final query in genericNewsQueries) {
      if (normalizedCommand == query || 
          normalizedCommand.trim() == query.trim()) {
        isGenericQuery = true;
        break;
      }
    }
    
    // For very generic news requests without specifics
    if (isGenericQuery) {
      if (location == null && category == null) {
        // For "just news" request, use global top headlines
        category = null;
        country = null; // This will trigger the global top headlines
        location = null;
      }
    }
    
    // Special handling for "top headlines" query - should override any category
    if (normalizedCommand == 'top headlines' || 
        normalizedCommand == 'headlines' || 
        normalizedCommand == 'top headline') {
      category = null;
      country = null;
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
    final String? category = parameters['category'];
    final String? country = parameters['country'];
    final String? location = parameters['location'];
    
    // Build API URL based on parameters
    String url;
    final apiKey = await _getApiKey();
    
    // Special handling for exact top headlines queries
    final String normalizedCommand = command.trim().toLowerCase();
    if (normalizedCommand == 'news' || 
        normalizedCommand == 'top headlines' ||
        normalizedCommand == 'headlines') {
      url = '$_baseUrl/top-headlines?apiKey=$apiKey';
      print('Using global top headlines URL: $url');
      return await _fetchNewsFromUrl(url);
    }
    
    // Case A: If specific location (city) is mentioned
    if (location != null) {
      // If both location and category are mentioned
      if (category != null) {
        url = '$_baseUrl/everything?q=$location+$category&sortBy=publishedAt&language=en&apiKey=$apiKey';
        print('Using location + category search URL: $url');
      } else {
        url = '$_baseUrl/everything?q=$location&sortBy=publishedAt&language=en&apiKey=$apiKey';
        print('Using location search URL: $url');
      }
    } 
    // Case B: If country + category
    else if (category != null && country != null) {
      url = '$_baseUrl/top-headlines?country=$country&category=$category&apiKey=$apiKey';
      print('Using country + category URL: $url');
    }
    // Case C: If only category is mentioned (global category news)
    else if (category != null) {
      url = '$_baseUrl/top-headlines?category=$category&apiKey=$apiKey';
      print('Using global category URL: $url');
    }
    // Case D: If only country is mentioned (top headlines for country)
    else if (country != null) {
      url = '$_baseUrl/top-headlines?country=$country&apiKey=$apiKey';
      print('Using country top headlines URL: $url');
    }
    // Case E: Default/Fallback - general top headlines
    else {
      url = '$_baseUrl/top-headlines?apiKey=$apiKey';
      print('Using fallback global top headlines URL: $url');
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
        
        if (articles.isEmpty) {
          print('API returned 0 articles');
          return [];
        }
        
        print('API returned ${articles.length} articles, using ${limit < articles.length ? limit : articles.length}');
        return articles
            .take(limit)
            .map((article) => NewsArticle.fromJson(article))
            .toList();
      } else {
        print('Failed to load news. Status code: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load news. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching news: $e');
      throw Exception('Failed to load news: $e');
    }
  }
  
  Future<List<NewsArticle>> getTopHeadlines({int limit = 5}) async {
    try {
      final apiKey = await _getApiKey();
      // Use global top headlines for simple "news" request
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?apiKey=$apiKey'),
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
      } else if (parameters['country'] != null && parameters['country'] == 'in') {
        summary.write('Here is the latest news from India: ');
      } else if (parameters['country'] != null) {
        // Look up the country name from the code for a more natural output
        String countryName = 'the selected country';
        for (final entry in _countryCodes.entries) {
          if (entry.value == parameters['country']) {
            countryName = entry.key;
            break;
          }
        }
        summary.write('Here is the latest news from $countryName: ');
      } else {
        summary.write('Here are the latest global headlines: ');
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
      print('Error in getNewsForSpeech: $e');
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
      } else if (parameters['country'] != null && parameters['country'] == 'in') {
        summary.write('Here is the latest news from India. ');
      } else if (parameters['country'] != null) {
        // Look up the country name from the code for a more natural output
        String countryName = 'the selected country';
        for (final entry in _countryCodes.entries) {
          if (entry.value == parameters['country']) {
            countryName = entry.key;
            break;
          }
        }
        summary.write('Here is the latest news from $countryName. ');
      } else {
        summary.write('Here are the latest global headlines. ');
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
      print('Error in getNewsForSpeechOutput: $e');
      return 'I\'m sorry, I\'m unable to get news information at this time. Please try again later.';
    }
  }
  
  Future<String> getTopHeadlinesSummary({int limit = 3}) async {
    try {
      final articles = await getTopHeadlines(limit: limit);
      
      if (articles.isEmpty) {
        return 'No news articles available at this time.';
      }
      
      final StringBuffer summary = StringBuffer('Here are the latest global headlines: ');
      
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
      print('Error in getTopHeadlinesSummary: $e');
      return 'Unable to get news information at this time. Please try again later.';
    }
  }
} 