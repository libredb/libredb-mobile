import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// The statement language of the editor's connection, for its colouring and its label.
///
/// A Cubit, not a Bloc: one cached read when the editor opens, with nothing to debounce, drop or replay.
class EditorLanguageCubit extends Cubit<EditorLanguageState> {
  EditorLanguageCubit({required this._providerMeta, required this.connectionId}) : super(const EditorLanguageLoading());

  final IProviderMetaRepository _providerMeta;
  final String connectionId;

  Future<void> load() async {
    final result = await _providerMeta.providerMeta(connectionId);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(EditorLanguageKnown(EditorLanguage.of(data)));
      case Failure(:final error):
        emit(EditorLanguageUnknown(AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
    }
  }
}

sealed class EditorLanguageState extends Equatable {
  const EditorLanguageState();

  @override
  List<Object?> get props => const [];
}

final class EditorLanguageLoading extends EditorLanguageState {
  const EditorLanguageLoading();
}

final class EditorLanguageKnown extends EditorLanguageState {
  const EditorLanguageKnown(this.language);

  final EditorLanguage language;

  @override
  List<Object?> get props => [language];
}

/// Studio did not answer the engine's meta, so the text is plain and the page says why.
final class EditorLanguageUnknown extends EditorLanguageState {
  const EditorLanguageUnknown(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
