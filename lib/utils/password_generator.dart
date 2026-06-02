import 'dart:math';

class PasswordGenerator {
  const PasswordGenerator._();

  static String generate({int length = 18}) {
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const numbers = '23456789';
    const symbols = '!@#%^&*()-_=+[]{}';
    const all = '$lower$upper$numbers$symbols';

    final random = Random.secure();
    final characters = <String>[
      _pick(lower, random),
      _pick(upper, random),
      _pick(numbers, random),
      _pick(symbols, random),
      for (var index = 4; index < length; index++) _pick(all, random),
    ];

    for (var index = characters.length - 1; index > 0; index--) {
      final swapIndex = random.nextInt(index + 1);
      final current = characters[index];
      characters[index] = characters[swapIndex];
      characters[swapIndex] = current;
    }

    return characters.join();
  }

  static String _pick(String source, Random random) {
    return source[random.nextInt(source.length)];
  }
}
