class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RateLimitedException extends LlmException {
  RateLimitedException() : super('LLM rate limited. Try again later.');
}
