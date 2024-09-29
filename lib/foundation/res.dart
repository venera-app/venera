class Res<T> {
  /// error info
  final String? errorMessage;

  /// data
  final T? _data;

  /// is there an error
  bool get error => errorMessage != null;

  /// whether succeed
  bool get success => !error;

  /// data
  T get data => _data ?? (throw Exception(errorMessage));

  /// get data, or null if there is an error
  T? get dataOrNull => _data;

  final dynamic subData;

  @override
  String toString() => _data.toString();

  Res.fromErrorRes(Res another, {this.subData})
      : _data = null,
        errorMessage = another.errorMessage;

  /// network result
  const Res(this._data, {this.errorMessage, this.subData});

  const Res.error(String err)
      : _data = null,
        subData = null,
        errorMessage = err;
}
