import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/parcel.dart';
import '../repositories/gml_repository.dart';

final gmlRepositoryProvider = Provider<GmlRepository>((ref) => GmlRepository());

final gmlStateProvider =
    StateNotifierProvider<GmlNotifier, AsyncValue<List<Parcel>>>((ref) {
  return GmlNotifier(ref.read(gmlRepositoryProvider));
});

class GmlNotifier extends StateNotifier<AsyncValue<List<Parcel>>> {
  GmlNotifier(this._repository) : super(const AsyncValue.data([]));

  final GmlRepository _repository;

  Future<void> loadFile(List<int> bytes) async {
    state = const AsyncValue.loading();
    try {
      await _repository.parseGml(Uint8List.fromList(bytes));
      state = AsyncValue.data(List.unmodifiable(_repository.parcels));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    _repository.clear();
    state = const AsyncValue.data([]);
  }
}
