// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a tr locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'tr';

  static String m0(code) => "Satırlar sayılamadı (${code})";

  static String m1(value) => "Varsayılan: ${value}";

  static String m2(code) => "Bu anahtarların hangi tabloları açtığı denetlenemedi (${code})";

  static String m3(table, column) => "Başvurduğu: ${table}.${column}";

  static String m4(type) => "${type} (örneklendi)";

  static String m5(parent) => "Bağlı olduğu nesne: ${parent}";

  static String m6(count, formatted) => "${Intl.plural(count, one: '1 satır', other: '${formatted} satır')}";

  static String m7(count, formatted) => "${Intl.plural(count, one: '1 nesne', other: '${formatted} nesne')}";

  static String m8(matched, total) => "${total} nesneden ${matched} tanesi eşleşiyor";

  static String m9(count) => "Aramak için en az ${count} karakter yazın.";

  static String m10(term) => "Adında \"${term}\" geçen nesne yok.";

  static String m11(code) => "Kopyalanamadı (${code})";

  static String m12(code) => "Paylaşılamadı (${code})";

  static String m13(reason) => "Kesildi: ${reason}";

  static String m14(latency) => "Erişilebilir, ${latency} ms";

  static String m15(label) => "Ortam: ${label}";

  static String m16(status) => "Durum: ${status}";

  static String m17(name) => "${name} artık kullanılamıyor";

  static String m18(url) => "${url} açılamadı";

  static String m19(currentVersion, minimumVersion) => "Mevcut: ${currentVersion}  •  Gerekli: ${minimumVersion}";

  static String m20(count) => "${Intl.plural(count, one: '1 öğe listelendi', other: '${count} öğe listelendi')}";

  static String m21(count) =>
      "${Intl.plural(count, one: '1 öğe listelendi; devamı var', other: '${count} öğe listelendi; devamı var')}";

  static String m22(reason) => "Bu liste eksik ve motor nedenini gösterebiliyor: ${reason}";

  static String m23(reason) =>
      "Bu liste okumanın gördüğüdür. Bu motorda her şeyin bu olup olmadığı belirlenemez: ${reason}";

  static String m24(count) => "${Intl.plural(count, one: '1 anahtar tarandı', other: '${count} anahtar tarandı')}";

  static String m25(count) =>
      "${Intl.plural(count, one: '1 anahtar tarandı; devamı var', other: '${count} anahtar tarandı; devamı var')}";

  static String m26(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı";

  static String m27(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m28(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı";

  static String m29(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m30(count, reason) =>
      "${Intl.plural(count, one: 'Bu taramada 1 anahtar dışarıda kaldı: ${reason}', other: 'Bu taramada ${count} anahtar dışarıda kaldı: ${reason}')}";

  static String m31(type) => "Studio\'ya göre bu anahtarın türü: ${type}.";

  static String m32(time) => "Tahmini bitiş: ${time}";

  static String m33(time) => "Çevrimdışı: ${time} itibarıyla yüklenenler gösteriliyor";

  static String m34(count, rows) => "${Intl.plural(count, one: '1 satır etkilendi', other: '${rows} satır etkilendi')}";

  static String m35(id) => "#${id}";

  static String m36(code) => "Kopyalanamadı (${code})";

  static String m37(count, rows) => "${Intl.plural(count, one: '1 tane daha yükle', other: '${rows} tane daha yükle')}";

  static String m38(count, rows) =>
      "${Intl.plural(count, one: '1 tane daha yükleniyor…', other: '${rows} tane daha yükleniyor…')}";

  static String m39(count) => "${Intl.plural(count, one: '+1 alan daha', other: '+${count} alan daha')}";

  static String m40(index, count) => "Satır ${index} / ${count}";

  static String m41(index) => "Satır ${index}";

  static String m42(count, rows, time) =>
      "${Intl.plural(count, one: '1 satır, ${time} ms', other: '${rows} satır, ${time} ms')}";

  static String m43(code) => "Kod ${code}";

  static String m44(severity, message) => "${severity}: ${message}";

  static String m45(count) => "${Intl.plural(count, one: '1 uyarı', other: '${count} uyarı')}";

  static String m46(seconds) => "${seconds} sn sonra yeniden deneyebilirsiniz.";

  static String m47(message) => "Hata: ${message}";

  static String m48(detail) => "Ayrıntı: ${detail}";

  static String m49(host) => "Studio adresi: ${host}";

  static String m50(count) => "${Intl.plural(count, other: '${count} satır listelendi.')}";

  static String m51(name) => "Onaylamak için \"${name}\" yazın";

  static String m52(word, line) => "Veriyi değiştirebilir: ${line}. satırda ${word}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account": MessageLookupByLibrary.simpleMessage("Hesabım"),
    "account_refusal_title": MessageLookupByLibrary.simpleMessage("Hesabınızın Studio\'ya erişimi yok"),
    "active": MessageLookupByLibrary.simpleMessage("Aktif"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Uygula"),
    "authorities": MessageLookupByLibrary.simpleMessage("Roller"),
    "back": MessageLookupByLibrary.simpleMessage("Geri"),
    "browse_count_failed": m0,
    "browse_count_rows": MessageLookupByLibrary.simpleMessage("Satırları say"),
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Sütunlar"),
    "browse_detail_default": m1,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Dışlama kısıtlamaları"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Yabancı anahtarlar"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Dizinler"),
    "browse_detail_links_unchecked": m2,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio hiç sütun listelemiyor."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio hiç yabancı anahtar listelemiyor."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio hiç dizin listelemiyor."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Boş olabilir"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Birincil anahtar"),
    "browse_detail_references": m3,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Sütunlar örneklenen belgelerden çıkarıldı"),
    "browse_detail_sampled_type": m4,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Benzersiz"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Ayrıntılar"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio burada hiç nesne saymıyor."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio bu düzeyde bir şey listelemiyor."),
    "browse_object_attached_to": m5,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Adı kopyala"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Ad kopyalandı"),
    "browse_object_rows": m6,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Devre dışı"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Geçersiz"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("Kaynağı görüntüle"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Nesneler"),
    "browse_objects_count": m7,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio burada bu türde nesne listelemiyor."),
    "browse_objects_match": m8,
    "browse_preview_unavailable": MessageLookupByLibrary.simpleMessage("Bu motor için önizleme henüz kullanılamıyor"),
    "browse_rows_database_says": MessageLookupByLibrary.simpleMessage("Veritabanının yanıtı"),
    "browse_search_action": MessageLookupByLibrary.simpleMessage("Nesnelerde ara"),
    "browse_search_clear": MessageLookupByLibrary.simpleMessage("Aramayı temizle"),
    "browse_search_hint": MessageLookupByLibrary.simpleMessage("Ada göre ara"),
    "browse_search_min_length": m9,
    "browse_search_no_results": m10,
    "browse_search_not_available": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıda arama yapılamaz; bunun yerine göz atın",
    ),
    "browse_search_title": MessageLookupByLibrary.simpleMessage("Ara"),
    "browse_source": MessageLookupByLibrary.simpleMessage("Kaynak"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Tümünü kopyala"),
    "browse_source_copy_failed": m11,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Kısmi"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage(
      "Studio tarafından yeniden oluşturuldu, saklanan metin değil",
    ),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Paylaş"),
    "browse_source_share_failed": m12,
    "browse_source_truncated": m13,
    "browse_source_unavailable": MessageLookupByLibrary.simpleMessage("Bu tanım okunamadı"),
    "browse_view_rows": MessageLookupByLibrary.simpleMessage("Satırları göster"),
    "cancel": MessageLookupByLibrary.simpleMessage("İptal"),
    "cell_null_semantics": MessageLookupByLibrary.simpleMessage("Boş değer"),
    "community_contribute": MessageLookupByLibrary.simpleMessage("Katkıda Bulun"),
    "community_docs": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "community_issue": MessageLookupByLibrary.simpleMessage("Sorun Bildir"),
    "community_source_available": MessageLookupByLibrary.simpleMessage("Kaynak Kodu Erişilebilir"),
    "community_sponsor": MessageLookupByLibrary.simpleMessage("Sponsor Ol"),
    "community_star": MessageLookupByLibrary.simpleMessage("Yıldız & Fork"),
    "community_subtitle": MessageLookupByLibrary.simpleMessage(
      "LibreDB\'nin kaynak kodu herkese açıktır. Katkılarınız onu daha iyi yapar!",
    ),
    "community_title": MessageLookupByLibrary.simpleMessage("Topluluğa Katılın"),
    "community_translate": MessageLookupByLibrary.simpleMessage("Çeviriye Yardım Et"),
    "connection_active": MessageLookupByLibrary.simpleMessage("Etkin bağlantı"),
    "connection_check": MessageLookupByLibrary.simpleMessage("Kontrol et"),
    "connection_check_anyway": MessageLookupByLibrary.simpleMessage("Yine de kontrol et"),
    "connection_check_checking": MessageLookupByLibrary.simpleMessage("Kontrol ediliyor"),
    "connection_check_degraded": MessageLookupByLibrary.simpleMessage("Erişilebilir, sağlık bilgisi yok"),
    "connection_check_failed": MessageLookupByLibrary.simpleMessage("Kontrol başarısız"),
    "connection_check_idle": MessageLookupByLibrary.simpleMessage("Henüz kontrol edilmedi"),
    "connection_check_not_checked": MessageLookupByLibrary.simpleMessage(
      "Kontrol edilmedi: kontrol, ücretli işlem gücünü başlatır",
    ),
    "connection_check_online": m14,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Erişilebilir"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Veritabanı"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Ortam"),
    "connection_environment_badge": m15,
    "connection_environment_filter": MessageLookupByLibrary.simpleMessage("Ortama göre süz"),
    "connection_environment_other": MessageLookupByLibrary.simpleMessage("Diğer"),
    "connection_favorites": MessageLookupByLibrary.simpleMessage("Favoriler"),
    "connection_group": MessageLookupByLibrary.simpleMessage("Grup"),
    "connection_group_other": MessageLookupByLibrary.simpleMessage("Diğer"),
    "connection_host": MessageLookupByLibrary.simpleMessage("Sunucu"),
    "connection_list_empty": MessageLookupByLibrary.simpleMessage("Kullanabileceğiniz bir bağlantı yok"),
    "connection_list_empty_governed": MessageLookupByLibrary.simpleMessage(
      "Size henüz hiçbir veritabanı erişimi verilmedi. Erişim için bir yöneticiye başvurun.",
    ),
    "connection_list_load_failed": MessageLookupByLibrary.simpleMessage("Bağlantılar yüklenemedi"),
    "connection_list_unavailable": MessageLookupByLibrary.simpleMessage("Bağlantılar kullanılamıyor"),
    "connection_read_only": MessageLookupByLibrary.simpleMessage("Salt okunur"),
    "connection_recent": MessageLookupByLibrary.simpleMessage("Son açılanlar"),
    "connection_search_clear": MessageLookupByLibrary.simpleMessage("Aramayı temizle"),
    "connection_search_hint": MessageLookupByLibrary.simpleMessage("Bağlantılarda ara"),
    "connection_search_no_match": MessageLookupByLibrary.simpleMessage("Eşleşen bağlantı yok"),
    "connection_star": MessageLookupByLibrary.simpleMessage("Favorilere ekle"),
    "connection_statement_capture_full": MessageLookupByLibrary.simpleMessage(
      "Çalıştırdığınız ifadeler bu sunucunun sorgu günlüğüne eksiksiz kaydedilir.",
    ),
    "connection_status": MessageLookupByLibrary.simpleMessage("Durum"),
    "connection_status_semantics": m16,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Bağlantı değiştir"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Motor"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Favorilerden çıkar"),
    "connection_vanished": m17,
    "connections": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı yok"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Çevrimdışı: internet bağlantısı yok. Ekrandakiler daha önce yüklendi.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Silmek istediğinize emin misiniz?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "edit": MessageLookupByLibrary.simpleMessage("Düzenle"),
    "editor_saved_text_discard": MessageLookupByLibrary.simpleMessage("Sil"),
    "editor_saved_text_discard_message": MessageLookupByLibrary.simpleMessage(
      "Okunamayan kayıtlı metin bu telefondan silinir. Bu işlem geri alınamaz.",
    ),
    "editor_saved_text_discard_title": MessageLookupByLibrary.simpleMessage("Kayıtlı metin silinsin mi?"),
    "english": MessageLookupByLibrary.simpleMessage("İngilizce"),
    "error_auth_invalid_access_token": MessageLookupByLibrary.simpleMessage("Geçersiz erişim belirteci"),
    "error_auth_oidc_config": MessageLookupByLibrary.simpleMessage(
      "Bu uygulamada tek oturum açma doğru yapılandırılmamış. Yöneticinize başvurun.",
    ),
    "error_auth_oidc_discovery": MessageLookupByLibrary.simpleMessage(
      "Kimlik sağlayıcıya ulaşılamadı. Daha sonra yeniden deneyin; sorun sürerse yöneticinize başvurun.",
    ),
    "error_auth_oidc_failed": MessageLookupByLibrary.simpleMessage("Giriş başarısız oldu. Lütfen yeniden deneyin."),
    "error_auth_oidc_logout_incomplete": MessageLookupByLibrary.simpleMessage(
      "Bu uygulamadan çıkış yaptınız, ancak kimlik sağlayıcıdaki oturumunuz hâlâ açık olabilir.",
    ),
    "error_auth_session_persist_failed": MessageLookupByLibrary.simpleMessage("Oturum kaydedilemedi"),
    "error_editor_saved_text_not_stored": MessageLookupByLibrary.simpleMessage(
      "Bu telefon sorgu metnini kaydedemedi. Boş depolama alanını kontrol edip tekrar deneyin.",
    ),
    "error_editor_saved_text_unreadable": MessageLookupByLibrary.simpleMessage(
      "Bu telefonda kayıtlı sorgu metni okunamıyor. Başka bir cihazın yedeğinden gelmiş ya da dosya değiştirilmiş olabilir. Yeni metnin yeniden kaydedilmesi için onu silin.",
    ),
    "error_generic": MessageLookupByLibrary.simpleMessage("Bir şeyler ters gitti"),
    "error_link_open_failed": m18,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "Bağlantının güvenli olduğu doğrulanamadığı için engellendi. Daha sonra ya da başka bir ağda tekrar deneyin.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "İnternet bağlantısı yok. Ağınızı kontrol edip tekrar deneyin.",
    ),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Dil değiştirilemedi"),
    "error_studio_account_has_no_identity": MessageLookupByLibrary.simpleMessage(
      "Studio bu hesabın kim olduğunu belirleyemiyor. Bir yöneticiden hesabın e-posta adresini ve kullanıcı adını kontrol etmesini isteyin.",
    ),
    "error_studio_account_has_no_role": MessageLookupByLibrary.simpleMessage(
      "Bu hesabın Studio\'da bir rolü yok. Bir yöneticiden hesaba rol vermesini isteyin.",
    ),
    "error_studio_account_refused": MessageLookupByLibrary.simpleMessage(
      "Studio bu girişi kabul etmedi. Tekrar deneyin ya da erişim için bir yöneticiye başvurun.",
    ),
    "error_studio_config_error": MessageLookupByLibrary.simpleMessage(
      "Bağlantı doğru yapılandırılmamış. Yöneticinize başvurun.",
    ),
    "error_studio_connection_not_available": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantı sizin kullanımınıza açık değil.",
    ),
    "error_studio_custom_connections_disabled": MessageLookupByLibrary.simpleMessage(
      "Studio yalnızca yöneticinizin tanımladığı bağlantılara izin veriyor.",
    ),
    "error_studio_database_auth": MessageLookupByLibrary.simpleMessage(
      "Veritabanı bağlantının kimlik bilgilerini reddetti. Yöneticinizden bunları kontrol etmesini isteyin.",
    ),
    "error_studio_database_unreachable": MessageLookupByLibrary.simpleMessage(
      "Veritabanına ulaşılamadı. Biraz sonra tekrar deneyin.",
    ),
    "error_studio_governance_unavailable": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda erişiminizi denetleyemiyor. Biraz sonra tekrar deneyin.",
    ),
    "error_studio_identity_provider_unavailable": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda kimlik sağlayıcıya ulaşamıyor. Biraz sonra tekrar deneyin.",
    ),
    "error_studio_permission_denied": MessageLookupByLibrary.simpleMessage(
      "Veritabanı buna izin vermedi. Bu nesne üzerinde bir yetkiniz eksik olabilir.",
    ),
    "error_studio_query_cancelled": MessageLookupByLibrary.simpleMessage("Sorgu iptal edildi."),
    "error_studio_query_error": MessageLookupByLibrary.simpleMessage("Sorgu başarısız oldu."),
    "error_studio_rate_limited": MessageLookupByLibrary.simpleMessage(
      "Kısa sürede çok fazla istek gönderildi. Biraz bekleyip tekrar deneyin.",
    ),
    "error_studio_timeout": MessageLookupByLibrary.simpleMessage("Veritabanı zamanında yanıt vermedi."),
    "error_studio_transaction_credential_changed": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıya erişiminiz değişti, bu yüzden işlem geri alındı.",
    ),
    "error_studio_transaction_not_owned": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıda başka bir oturumun açık bir işlemi var.",
    ),
    "error_studio_unreadable_answer": MessageLookupByLibrary.simpleMessage(
      "Studio bu uygulamanın okuyamadığı bir yanıt gönderdi. Uygulamanın ya da Studio\'nun güncellenmesi gerekebilir.",
    ),
    "error_user_cannot_delete_admin": MessageLookupByLibrary.simpleMessage("Yönetici kullanıcı silinemez"),
    "error_user_no_authorities": MessageLookupByLibrary.simpleMessage("Yetki bulunamadı"),
    "failed": MessageLookupByLibrary.simpleMessage("Başarısız"),
    "force_update_button": MessageLookupByLibrary.simpleMessage("Şimdi Güncelle"),
    "force_update_message": MessageLookupByLibrary.simpleMessage(
      "Yeni bir sürüm mevcut. Uygulamayı kullanmaya devam etmek için lütfen güncelleyin.",
    ),
    "force_update_no_store_link": MessageLookupByLibrary.simpleMessage(
      "En son sürümü yüklemek için uygulama mağazanızı açın.",
    ),
    "force_update_store_link_invalid": MessageLookupByLibrary.simpleMessage(
      "Güncelleme bağlantısı geçersiz. En son sürümü yüklemek için uygulama mağazanızı açın.",
    ),
    "force_update_title": MessageLookupByLibrary.simpleMessage("Güncelleme Gerekli"),
    "force_update_versions": m19,
    "help_resources": MessageLookupByLibrary.simpleMessage("Yardım ve Kaynaklar"),
    "help_resources_subtitle": MessageLookupByLibrary.simpleMessage("GitHub\'daki dokümantasyonu ve rehberleri okuyun"),
    "home": MessageLookupByLibrary.simpleMessage("Ana Sayfa"),
    "idle_timeout_signed_out": MessageLookupByLibrary.simpleMessage("Hareketsizlik nedeniyle oturumunuz kapatıldı."),
    "inactive": MessageLookupByLibrary.simpleMessage("Pasif"),
    "keys_browse": MessageLookupByLibrary.simpleMessage("Anahtarlara göz at"),
    "keys_cap": MessageLookupByLibrary.simpleMessage(
      "Bu ekran en fazla 10.000 anahtar tutar: diğerlerini görmek için deseni daraltın.",
    ),
    "keys_clustered": MessageLookupByLibrary.simpleMessage(
      "Kümelenmiş sunucu: SCAN ve DBSIZE her seferinde tek bir düğüm için yanıt verir, bu yüzden bu sayılar bu düğümündür.",
    ),
    "keys_empty": MessageLookupByLibrary.simpleMessage("Studio burada anahtar bulamadı."),
    "keys_listed": m20,
    "keys_listed_more": m21,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Tümünü yükle"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Desen"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Şununla başlar"),
    "keys_read_incomplete": m22,
    "keys_read_unknown": m23,
    "keys_scanned": m24,
    "keys_scanned_more": m25,
    "keys_scanned_of_database": m26,
    "keys_scanned_of_database_more": m27,
    "keys_scanned_of_walk": m28,
    "keys_scanned_of_walk_more": m29,
    "keys_skipped": m30,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Durdur"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Bu sayfadan sonra duruluyor"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Anahtarlar"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio bu bağlantı için anahtar tarayıcısı sunmuyor."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("Uygulamanın bu tür için bir okuması yok."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Anahtar"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Değeri oku"),
    "keys_value_type": m31,
    "keys_value_unavailable": MessageLookupByLibrary.simpleMessage("Bu motor için anahtar değeri okunamıyor."),
    "keys_value_vanished": MessageLookupByLibrary.simpleMessage(
      "Bu anahtar artık yok. Yeniden okumak için aşağı çekin.",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Dil"),
    "language_select": MessageLookupByLibrary.simpleMessage("Dil Seçimi"),
    "list": MessageLookupByLibrary.simpleMessage("Listele"),
    "loading": MessageLookupByLibrary.simpleMessage("Yükleniyor..."),
    "local_filter_clear": MessageLookupByLibrary.simpleMessage("Filtreyi temizle"),
    "local_filter_hint": MessageLookupByLibrary.simpleMessage("Filtrele"),
    "local_filter_no_match": MessageLookupByLibrary.simpleMessage("Filtreyle eşleşen bir şey yok."),
    "login": MessageLookupByLibrary.simpleMessage("Kullanıcı Adı"),
    "login_brand_description": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio\'nun size açtığı veritabanlarına telefonunuzdan ulaşın.",
    ),
    "login_brand_headline": MessageLookupByLibrary.simpleMessage("Veritabanlarınız\ncebinizde."),
    "login_feature_auth_description": MessageLookupByLibrary.simpleMessage(
      "Kurumunuzun Keycloak\'ta yönettiği hesapla oturum açın.",
    ),
    "login_feature_auth_title": MessageLookupByLibrary.simpleMessage("Kurum hesabıyla giriş"),
    "login_feature_credentials_description": MessageLookupByLibrary.simpleMessage(
      "Her veritabanı kimlik bilgisini Studio tutar, uygulama hiçbirini saklamaz.",
    ),
    "login_feature_credentials_title": MessageLookupByLibrary.simpleMessage("Telefonda parola yok"),
    "login_feature_query_description": MessageLookupByLibrary.simpleMessage(
      "Size verilen bağlantılarda şemalara göz atın ve sorgu çalıştırın.",
    ),
    "login_feature_query_title": MessageLookupByLibrary.simpleMessage("Göz atın ve sorgulayın"),
    "login_sso_button": MessageLookupByLibrary.simpleMessage("SSO ile giriş yap"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Kurumsal hesabınızla giriş yapın."),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Koyu temaya geç"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Açık temaya geç"),
    "login_welcome_title": MessageLookupByLibrary.simpleMessage("Tekrar hoş geldiniz"),
    "logout": MessageLookupByLibrary.simpleMessage("Çıkış Yap"),
    "logout_stored_data_left": MessageLookupByLibrary.simpleMessage(
      "Oturumunuz kapatıldı, ancak kayıtlı verilerin bir kısmı bu cihazdan silinemedi.",
    ),
    "logout_sure": MessageLookupByLibrary.simpleMessage("Çıkış yapmak istediğinize emin misiniz?"),
    "maintenance_estimated_end": m32,
    "maintenance_message": MessageLookupByLibrary.simpleMessage(
      "Planlı bir bakım çalışması yapıyoruz. Lütfen kısa bir süre sonra tekrar deneyin.",
    ),
    "maintenance_retry": MessageLookupByLibrary.simpleMessage("Tekrar Dene"),
    "maintenance_title": MessageLookupByLibrary.simpleMessage("Bakım Yapılıyor"),
    "name": MessageLookupByLibrary.simpleMessage("İsim"),
    "new_item": MessageLookupByLibrary.simpleMessage("Yeni"),
    "next": MessageLookupByLibrary.simpleMessage("Sonraki"),
    "no": MessageLookupByLibrary.simpleMessage("Hayır"),
    "no_data": MessageLookupByLibrary.simpleMessage("Veri Yok"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("İstediğiniz sayfa bulunamadı."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Sayfa Bulunamadı"),
    "offline_action_unavailable": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı gerekiyor"),
    "offline_stale_data": m33,
    "pick_connection_first": MessageLookupByLibrary.simpleMessage("Önce bir bağlantı seçin"),
    "pick_connection_first_description": MessageLookupByLibrary.simpleMessage(
      "Bu sekmeyi kullanmak için Bağlantılar sekmesinden bir bağlantı açın.",
    ),
    "previous": MessageLookupByLibrary.simpleMessage("Önceki"),
    "profile": MessageLookupByLibrary.simpleMessage("Profil"),
    "profile_governed_by_platform": MessageLookupByLibrary.simpleMessage("LibreDB Platform tarafından yönetiliyor"),
    "profile_role_admin": MessageLookupByLibrary.simpleMessage("Yönetici"),
    "profile_role_user": MessageLookupByLibrary.simpleMessage("Kullanıcı"),
    "profile_unknown_user": MessageLookupByLibrary.simpleMessage("Bilinmeyen kullanıcı"),
    "refresh": MessageLookupByLibrary.simpleMessage("Yenile"),
    "required_field": MessageLookupByLibrary.simpleMessage("Zorunlu Alan"),
    "result_affected_rows": m34,
    "result_card_id": m35,
    "result_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "result_copy_failed": m36,
    "result_copy_row": MessageLookupByLibrary.simpleMessage("Satırı JSON olarak kopyala"),
    "result_copy_value": MessageLookupByLibrary.simpleMessage("Değeri kopyala"),
    "result_empty": MessageLookupByLibrary.simpleMessage("Sorgu veri döndürmedi"),
    "result_empty_bounded": MessageLookupByLibrary.simpleMessage(
      "Hiçbir satır gösterilmiyor: sonuç ilk satırından önce kesildi",
    ),
    "result_engine_reported": MessageLookupByLibrary.simpleMessage("Motorun bildirdiği:"),
    "result_limited": MessageLookupByLibrary.simpleMessage("sınırlı"),
    "result_limited_notice": MessageLookupByLibrary.simpleMessage(
      "Studio bu sonucu sınırladı. Sınırın ötesindeki hiçbir şey bu sonuçta yok.",
    ),
    "result_load_more": m37,
    "result_loading_more": m38,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Maskelenmiş değer"),
    "result_more_fields": m39,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "ORDER BY olmadan motor, sayfalar arasında satırları tekrarlayabilir ya da atlayabilir.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "Bu deyim bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı.",
    ),
    "result_row_position": m40,
    "result_row_title": m41,
    "result_stats": m42,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Kartlar"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Tablo"),
    "result_warning_code": m43,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "result_warning_line": m44,
    "result_warnings": m45,
    "retry": MessageLookupByLibrary.simpleMessage("Tekrar Dene"),
    "role": MessageLookupByLibrary.simpleMessage("Rol"),
    "save": MessageLookupByLibrary.simpleMessage("Kaydet"),
    "settings": MessageLookupByLibrary.simpleMessage("Ayarlar"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Görünüm"),
    "settings_licenses": MessageLookupByLibrary.simpleMessage("Lisanslar"),
    "settings_licenses_subtitle": MessageLookupByLibrary.simpleMessage(
      "LibreDB Mobile\'ın ve içerdiği kodun lisansları",
    ),
    "settings_subtitle": MessageLookupByLibrary.simpleMessage("Hesap tercihlerinizi yönetin"),
    "settings_theme_subtitle": MessageLookupByLibrary.simpleMessage("Tercih ettiğiniz tema stilini seçin"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("İfadeyi kopyala"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "Bir yönetici sorunu gidermek için bu ifadeyi çalıştırabilir:",
    ),
    "studio_error_retry_in": m46,
    "studio_error_semantics": m47,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("İfade kopyalandı"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda bağlantı sunamıyor. Bir yöneticinin yönetişim kurulumunu kontrol etmesi gerekiyor.",
    ),
    "studio_governance_detail": m48,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bağlantı erişimi geçici olarak kullanılamıyor. Erişim geri geldiğinde liste kendiliğinden güncellenir.",
    ),
    "studio_unreachable_host": m49,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio yanıt vermiyor. İnternet bağlantınızı kontrol edip tekrar deneyin.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Studio\'ya ulaşılamıyor"),
    "submit": MessageLookupByLibrary.simpleMessage("Gönder"),
    "success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Gözat"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m50,
    "theme": MessageLookupByLibrary.simpleMessage("Tema"),
    "theme_dialog_subtitle": MessageLookupByLibrary.simpleMessage("Tercih ettiğiniz tema stilini seçin"),
    "theme_dialog_title": MessageLookupByLibrary.simpleMessage("Tema Seçin"),
    "theme_palette_classic": MessageLookupByLibrary.simpleMessage("Klasik"),
    "theme_palette_classic_description": MessageLookupByLibrary.simpleMessage("Nötr çinko, sade ve minimal"),
    "theme_palette_nature": MessageLookupByLibrary.simpleMessage("Doğa"),
    "theme_palette_nature_description": MessageLookupByLibrary.simpleMessage("Adaçayı yeşili, sakin ve doğal"),
    "theme_palette_sunset": MessageLookupByLibrary.simpleMessage("Gün Batımı"),
    "theme_palette_sunset_description": MessageLookupByLibrary.simpleMessage("Sıcak taş, zengin ve davetkâr"),
    "turkish": MessageLookupByLibrary.simpleMessage("Türkçe"),
    "unsaved_changes": MessageLookupByLibrary.simpleMessage(
      "Kaydedilmemiş değişiklikleriniz var. Çıkmak istediğinize emin misiniz?",
    ),
    "users": MessageLookupByLibrary.simpleMessage("Kullanıcılar"),
    "warning": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "write_confirm_cancel": MessageLookupByLibrary.simpleMessage("İptal"),
    "write_confirm_name_label": m51,
    "write_confirm_no_name": MessageLookupByLibrary.simpleMessage(
      "Bu üretim bağlantısının yazılacak bir adı yok, bu yüzden deyim burada onaylanamaz.",
    ),
    "write_confirm_production_prompt": MessageLookupByLibrary.simpleMessage(
      "Bu bir üretim bağlantısı. Deyimi çalıştırmak için adını yazın.",
    ),
    "write_confirm_read_grant": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıdaki erişiminiz salt okunur, bu yüzden Studio burada bir yazmayı reddedecek. Bir yönetici erişiminizi yükseltebilir.",
    ),
    "write_confirm_read_only_connection": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantı operatörü tarafından salt okunur yapıldı, bu yüzden Studio veya veritabanı burada bir yazmayı reddedecek.",
    ),
    "write_confirm_reason_may_write": MessageLookupByLibrary.simpleMessage(
      "Veriyi değiştirebilir: uygulama deyimin nasıl başladığını okuyamıyor",
    ),
    "write_confirm_reason_may_write_at": m52,
    "write_confirm_reason_not_sql": MessageLookupByLibrary.simpleMessage(
      "Uygulama bu motorun bir komutunun ne yaptığını okuyamaz",
    ),
    "write_confirm_reason_several": MessageLookupByLibrary.simpleMessage("Birden fazla deyim çalıştırır"),
    "write_confirm_run": MessageLookupByLibrary.simpleMessage("Çalıştır"),
    "write_confirm_text_heading": MessageLookupByLibrary.simpleMessage("Çalışacak olan"),
    "write_confirm_title": MessageLookupByLibrary.simpleMessage("Çalıştırmadan önce onaylayın"),
    "yes": MessageLookupByLibrary.simpleMessage("Evet"),
  };
}
