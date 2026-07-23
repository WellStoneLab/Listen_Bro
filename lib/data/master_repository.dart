import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/master_models.dart';

class MasterDataRepository {
  List<CustomerDef> customers = const [];
  List<CocktailDef> cocktails = const [];
  List<TalkStackDef> talkStacks = const [];

  Map<String, CustomerDef> customersById = {};
  Map<String, CocktailDef> cocktailsById = {};

  Future<void> load() async {
    customers = await _loadList('assets/data/customers.json', CustomerDef.fromJson);
    cocktails = await _loadList('assets/data/cocktails.json', CocktailDef.fromJson);
    talkStacks =
        await _loadList('assets/data/talk_stacks.json', TalkStackDef.fromJson);
    customersById = {for (final c in customers) c.id: c};
    cocktailsById = {for (final c in cocktails) c.id: c};
  }

  Future<List<T>> _loadList<T>(
    String asset,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await rootBundle.loadString(asset);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  List<TalkStackDef> stacksFor(String customerId, int level) {
    final list = talkStacks
        .where((t) => t.customerId == customerId && t.level == level)
        .toList()
      ..sort((a, b) => a.step.compareTo(b.step));
    return list;
  }

  TalkStackDef? stepFor(String customerId, int level, int step) {
    final stacks = stacksFor(customerId, level);
    for (final s in stacks) {
      if (s.step == step) return s;
    }
    return stacks.isEmpty ? null : stacks.first;
  }
}
