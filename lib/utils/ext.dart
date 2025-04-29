extension ListExt<T> on List<T>{
  /// Remove all blank value and return the list.
  List<T> getNoBlankList(){
    List<T> newList = [];
    for(var value in this){
      if(value.toString() != ""){
        newList.add(value);
      }
    }
    return newList;
  }

  T? firstWhereOrNull(bool Function(T element) test){
    for(var element in this){
      if(test(element)){
        return element;
      }
    }
    return null;
  }

  void addIfNotNull(T? value){
    if(value != null){
      add(value);
    }
  }

  /// Compare every element of this list with another list.
  /// Return true if all elements are equal.
  bool isEqualTo(List<T> list){
    if(length != list.length){
      return false;
    }
    for(int i=0; i<length; i++){
      if(this[i] != list[i]){
        return false;
      }
    }
    return true;
  }
}

extension StringExt on String{
  ///Remove all value that would display blank on the screen.
  String get removeAllBlank => replaceAll("\n", "").replaceAll(" ", "").replaceAll("\t", "");

  /// convert this to a one-element list.
  List<String> toList() => [this];

  String _nums(){
    String res = "";
    for(int i=0; i<length; i++){
      res += this[i].isNum?this[i]:"";
    }
    return res;
  }

  String get nums => _nums();

  String setValueAt(String value, int index){
    return replaceRange(index, index+1, value);
  }

  String? subStringOrNull(int start, [int? end]){
    if(start < 0 || (end != null && end > length)){
      return null;
    }
    return substring(start, end);
  }

  String replaceLast(String from, String to) {
    if (isEmpty || from.isEmpty) {
      return this;
    }

    final lastIndex = lastIndexOf(from);
    if (lastIndex == -1) {
      return this;
    }

    final before = substring(0, lastIndex);
    final after = substring(lastIndex + from.length);
    return '$before$to$after';
  }

  bool _isURL(){
    final regex = RegExp(
        r'^((http|https|ftp)://)[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-|]*[\w@?^=%&/~+#-])?$',
        caseSensitive: false);
    return regex.hasMatch(this);
  }

  bool get isURL => _isURL();

  bool get isNum => double.tryParse(this) != null;

  bool get isInt => int.tryParse(this) != null;
}

abstract class ListOrNull{
  static List<T>? from<T>(Iterable<dynamic>? i){
    return i == null ? null : List.from(i);
  }
}

abstract class MapOrNull{
  static Map<K, V>? from<K, V>(Map<dynamic, dynamic>? i){
    return i == null ? null : Map<K, V>.from(i);
  }
}

extension FutureExt<T> on Future<T>{
  /// Wrap the future to make sure it will return at least the duration.
  Future<T> minTime(Duration duration) async {
    var res = await Future.wait([
      this,
      Future.delayed(duration),
    ]);
    return res[0];
  }
}