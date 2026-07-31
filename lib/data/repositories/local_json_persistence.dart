/// Persistência local de um payload JSON, por chave.
///
/// No web usa `localStorage` e escuta o evento `storage`, para duas abas do
/// mesmo navegador não divergirem. Nas outras plataformas é um stub sem
/// efeito — a persistência nativa ainda não foi feita.
///
/// A chave vem de fora porque há mais de uma coisa a guardar: o fluxo de
/// etapas e a fila de mutações pendentes do Protheus.
library;

export 'local_json_persistence_stub.dart'
    if (dart.library.html) 'local_json_persistence_web.dart';
