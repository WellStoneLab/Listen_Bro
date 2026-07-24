enum TalkType { chat, suffer, question, order }

TalkType talkTypeFromString(String raw) {
  switch (raw) {
    case 'suffer':
      return TalkType.suffer;
    case 'question':
      return TalkType.question;
    case 'Order':
    case 'order':
      return TalkType.order;
    case 'chat':
    default:
      return TalkType.chat;
  }
}

class CustomerDef {
  const CustomerDef({
    required this.id,
    required this.customerName,
    required this.prefAlcohol,
    required this.prefSweet,
    required this.prefFresh,
    required this.prefVisual,
    required this.avgStayHours,
    required this.preferredCocktailIds,
    this.spriteOrder,
    this.spriteDrink,
  });

  final String id;
  final String customerName;
  final int prefAlcohol;
  final int prefSweet;
  final int prefFresh;
  final int prefVisual;
  final double avgStayHours;
  final List<String> preferredCocktailIds;
  final String? spriteOrder;
  /// Optional drinking pose (e.g. holding glass). Falls back to [spriteOrder].
  final String? spriteDrink;

  factory CustomerDef.fromJson(Map<String, dynamic> json) {
    return CustomerDef(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      prefAlcohol: (json['prefAlcohol'] as num).toInt(),
      prefSweet: (json['prefSweet'] as num).toInt(),
      prefFresh: (json['prefFresh'] as num).toInt(),
      prefVisual: (json['prefVisual'] as num).toInt(),
      avgStayHours: (json['avgStayHours'] as num).toDouble(),
      preferredCocktailIds: (json['preferredCocktailIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      spriteOrder: json['spriteOrder'] as String?,
      spriteDrink: json['spriteDrink'] as String?,
    );
  }
}

class CocktailDef {
  const CocktailDef({
    required this.id,
    required this.cocktailName,
    required this.base,
    required this.mixLiquor,
    required this.shake,
    required this.afterShake,
    required this.prefAlcohol,
    required this.prefSweet,
    required this.prefFresh,
    required this.prefVisual,
    this.glassType,
  });

  final String id;
  final String cocktailName;
  final String base;
  final List<String> mixLiquor;
  final bool shake;
  final List<String> afterShake;
  final int prefAlcohol;
  final int prefSweet;
  final int prefFresh;
  final int prefVisual;
  final String? glassType;

  factory CocktailDef.fromJson(Map<String, dynamic> json) {
    final mix = (json['mixLiquor'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .where((e) => e != 'None')
        .toList();
    return CocktailDef(
      id: json['id'] as String,
      cocktailName: json['cocktailName'] as String,
      base: json['base'] as String,
      mixLiquor: mix,
      shake: json['shake'] as bool? ?? false,
      afterShake: (json['afterShake'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      prefAlcohol: (json['prefAlcohol'] as num).toInt(),
      prefSweet: (json['prefSweet'] as num).toInt(),
      prefFresh: (json['prefFresh'] as num).toInt(),
      prefVisual: (json['prefVisual'] as num).toInt(),
      glassType: json['glassType'] as String?,
    );
  }
}

class TalkStackDef {
  const TalkStackDef({
    required this.id,
    required this.customerId,
    required this.level,
    required this.step,
    required this.endOfStack,
    required this.talkType,
    required this.text,
    required this.questionAnswers,
    this.expectation,
  });

  final String id;
  final String customerId;
  final int level;
  final int step;
  final bool endOfStack;
  final TalkType talkType;
  final String text;
  final List<String> questionAnswers;

  /// Notion Expectation — question の期待回答（未設定なら null）
  final String? expectation;

  factory TalkStackDef.fromJson(Map<String, dynamic> json) {
    return TalkStackDef(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      level: (json['level'] as num).toInt(),
      step: (json['step'] as num).toInt(),
      endOfStack: json['endOfStack'] as bool? ?? false,
      talkType: talkTypeFromString(json['talkType'] as String? ?? 'chat'),
      text: json['text'] as String,
      questionAnswers: (json['questionAnswers'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      expectation: (json['expectation'] as String?) ??
          (json['correctAnswer'] as String?),
    );
  }
}
