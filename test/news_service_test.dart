import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/services/news_service.dart';

void main() {
  late NewsService newsService;

  setUp(() {
    newsService = NewsService();
  });

  group('Voice command parsing tests', () {
    test('Parses simple location query correctly', () {
      final result = newsService.parseVoiceCommand('Bangalore news');
      
      expect(result['location'], equals('bangalore'));
      expect(result['category'], isNull);
      expect(result['country'], equals('in'));
    });

    test('Parses category correctly', () {
      final result = newsService.parseVoiceCommand('sports news');
      
      expect(result['category'], equals('sports'));
      expect(result['location'], isNull);
      expect(result['country'], equals('in'));
    });

    test('Parses sports synonyms correctly', () {
      final result = newsService.parseVoiceCommand('sport news');
      
      expect(result['category'], equals('sports'));
    });

    test('Parses location and category together', () {
      final result = newsService.parseVoiceCommand('Bangalore sports news');
      
      expect(result['location'], equals('bangalore'));
      expect(result['category'], equals('sports'));
      expect(result['country'], equals('in'));
    });

    test('Parses variations of sports and locations', () {
      final result = newsService.parseVoiceCommand('Mumbai cricket news');
      
      expect(result['location'], equals('mumbai'));
      expect(result['category'], equals('sports'));
    });

    test('Parses tech variations correctly', () {
      final result = newsService.parseVoiceCommand('tech news');
      
      expect(result['category'], equals('technology'));
    });

    test('Parses complex technology phrase correctly', () {
      final result = newsService.parseVoiceCommand('give me artificial intelligence news from Bangalore');
      
      expect(result['location'], equals('bangalore'));
      expect(result['category'], equals('technology'));
    });

    test('Parses business variations correctly', () {
      final result = newsService.parseVoiceCommand('financial news');
      
      expect(result['category'], equals('business'));
    });

    test('Handles "just news" correctly', () {
      final result = newsService.parseVoiceCommand('news');
      
      expect(result['category'], isNull);
      expect(result['country'], isNull);
      expect(result['location'], isNull);
    });

    test('Handles "top headlines" correctly', () {
      final result = newsService.parseVoiceCommand('top headlines');
      
      expect(result['category'], isNull);
      expect(result['country'], isNull);
      expect(result['location'], isNull);
    });

    test('Parses country with category correctly', () {
      final result = newsService.parseVoiceCommand('UK business news');
      
      expect(result['country'], equals('gb'));
      expect(result['category'], equals('business'));
      expect(result['location'], isNull);
    });

    test('Prioritizes specific categories in complex phrases', () {
      final result = newsService.parseVoiceCommand('give me the latest football updates from London');
      
      expect(result['location'], equals('london'));
      expect(result['category'], equals('sports'));
    });
  });
} 