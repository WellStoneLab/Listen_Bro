import '../config/game_constants.dart';
import '../models/master_models.dart';

enum CocktailResultKind { success, plain, fail }

class CocktailCraftInput {
  const CocktailCraftInput({
    required this.base,
    required this.mixLiquor,
    required this.shake,
    required this.afterShake,
  });

  final String base;
  final List<String> mixLiquor;
  final bool shake;
  final List<String> afterShake;

  factory CocktailCraftInput.fromRecipe(CocktailDef recipe) {
    return CocktailCraftInput(
      base: recipe.base,
      mixLiquor: List<String>.from(recipe.mixLiquor),
      shake: recipe.shake,
      afterShake: List<String>.from(recipe.afterShake),
    );
  }
}

class CocktailCraftResult {
  const CocktailCraftResult({
    required this.kind,
    required this.displayName,
    required this.prefAlcohol,
    required this.prefSweet,
    required this.prefFresh,
    required this.prefVisual,
    this.matched,
  });

  final CocktailResultKind kind;
  final String displayName;
  final int prefAlcohol;
  final int prefSweet;
  final int prefFresh;
  final int prefVisual;
  final CocktailDef? matched;
}

class CocktailMixer {
  CocktailCraftResult craft(
    CocktailCraftInput input,
    List<CocktailDef> catalog,
  ) {
    if (_isFail(input)) {
      return const CocktailCraftResult(
        kind: CocktailResultKind.fail,
        displayName: '失敗（爆発）',
        prefAlcohol: 3,
        prefSweet: 3,
        prefFresh: 3,
        prefVisual: 3,
      );
    }

    for (final c in catalog) {
      if (_matchesRecipe(input, c)) {
        return CocktailCraftResult(
          kind: CocktailResultKind.success,
          displayName: c.cocktailName,
          prefAlcohol: c.prefAlcohol,
          prefSweet: c.prefSweet,
          prefFresh: c.prefFresh,
          prefVisual: c.prefVisual,
          matched: c,
        );
      }
    }

    return const CocktailCraftResult(
      kind: CocktailResultKind.plain,
      displayName: '無難なドリンク',
      prefAlcohol: 3,
      prefSweet: 3,
      prefFresh: 3,
      prefVisual: 3,
    );
  }

  bool _isFail(CocktailCraftInput input) {
    final mix = input.mixLiquor.toSet();
    final top = input.afterShake.toSet();
    final baseHot = input.base == 'Tequila' || input.base == 'Vodka';
    final mixHot = mix.contains('Tequila') || mix.contains('Vodka');
    if (baseHot && mixHot && top.contains('Fire')) return true;
    if ((mix.contains('Beer') || mix.contains('Soda')) && input.shake) {
      return true;
    }
    return false;
  }

  bool _matchesRecipe(CocktailCraftInput input, CocktailDef c) {
    if (input.base != c.base) return false;
    if (input.shake != c.shake) return false;
    final mixIn = input.mixLiquor.toSet();
    final mixRecipe = c.mixLiquor.toSet();
    if (mixIn.length != mixRecipe.length || !mixIn.containsAll(mixRecipe)) {
      return false;
    }
    final topIn = input.afterShake.toSet();
    final topRecipe = c.afterShake.toSet();
    if (topIn.length != topRecipe.length || !topIn.containsAll(topRecipe)) {
      return false;
    }
    return true;
  }

  /// Average of (1 - |diff|/5) across four factors.
  double matchScore(CocktailCraftResult drink, CustomerDef customer) {
    double one(int a, int b) => 1.0 - (a - b).abs() / 5.0;
    return (one(drink.prefAlcohol, customer.prefAlcohol) +
            one(drink.prefSweet, customer.prefSweet) +
            one(drink.prefFresh, customer.prefFresh) +
            one(drink.prefVisual, customer.prefVisual)) /
        4.0;
  }

  double toleranceForLevel(int level) {
    final idx = level.clamp(0, GameConstants.matchToleranceByLevel.length - 1);
    return GameConstants.matchToleranceByLevel[idx];
  }
}
