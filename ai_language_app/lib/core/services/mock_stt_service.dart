import 'stt_service.dart';

class MockSttService implements SttService {
  static const _phrases = [
    'Hello, my name is Carlos and I am learning English.',
    'I would like to talk about my daily routine.',
    'Yesterday I went to the supermarket to buy some food.',
    'Can you help me practice my pronunciation?',
    'I think this conversation is very helpful for me.',
  ];

  int _index = 0;

  @override
  Future<SttResult> recognize(Stream<List<int>> audioStream) async {
    await Future.delayed(const Duration(seconds: 3));
    final transcript = _phrases[_index % _phrases.length];
    _index++;
    return SttResult(transcript: transcript, confidence: 0.9);
  }

  @override
  Future<void> cancel() async {}
}
