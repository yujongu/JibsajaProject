/// A minimal Success/Failure wrapper for all external (Google Sheets) calls.
///
/// CLAUDE.md mandates `Result` types for I/O instead of throwing, so the
/// presentation layer can render errors gracefully without try/catch.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// The value if successful, otherwise null.
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>() => success(self.value),
      Failure<T>() => failure(self.error),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.error);
  final Object error;
}
