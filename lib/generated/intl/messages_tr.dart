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

  static String m0(value) => "Varsayılan: ${value}";

  static String m1(code) => "Bu anahtarların hangi tabloları açtığı denetlenemedi (${code})";

  static String m2(table, column) => "Başvurduğu: ${table}.${column}";

  static String m3(type) => "${type} (örneklendi)";

  static String m4(parent) => "Bağlı olduğu nesne: ${parent}";

  static String m5(count, formatted) => "${Intl.plural(count, one: '1 satır', other: '${formatted} satır')}";

  static String m6(count, formatted) => "${Intl.plural(count, one: '1 nesne', other: '${formatted} nesne')}";

  static String m7(matched, total) => "${total} nesneden ${matched} tanesi eşleşiyor";

  static String m8(code) => "Kopyalanamadı (${code})";

  static String m9(code) => "Paylaşılamadı (${code})";

  static String m10(reason) => "Kesildi: ${reason}";

  static String m11(latency) => "Erişilebilir, ${latency} ms";

  static String m12(label) => "Ortam: ${label}";

  static String m13(status) => "Durum: ${status}";

  static String m14(name) => "${name} artık kullanılamıyor";

  static String m15(url) => "${url} açılamadı";

  static String m16(currentVersion, minimumVersion) => "Mevcut: ${currentVersion}  •  Gerekli: ${minimumVersion}";

  static String m17(count) => "${Intl.plural(count, one: '1 öğe listelendi', other: '${count} öğe listelendi')}";

  static String m18(count) =>
      "${Intl.plural(count, one: '1 öğe listelendi; devamı var', other: '${count} öğe listelendi; devamı var')}";

  static String m19(reason) => "Bu liste eksik ve motor nedenini gösterebiliyor: ${reason}";

  static String m20(reason) =>
      "Bu liste okumanın gördüğüdür. Bu motorda her şeyin bu olup olmadığı belirlenemez: ${reason}";

  static String m21(count) => "${Intl.plural(count, one: '1 anahtar tarandı', other: '${count} anahtar tarandı')}";

  static String m22(count) =>
      "${Intl.plural(count, one: '1 anahtar tarandı; devamı var', other: '${count} anahtar tarandı; devamı var')}";

  static String m23(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı";

  static String m24(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m25(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı";

  static String m26(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m27(count, reason) =>
      "${Intl.plural(count, one: 'Bu taramada 1 anahtar dışarıda kaldı: ${reason}', other: 'Bu taramada ${count} anahtar dışarıda kaldı: ${reason}')}";

  static String m28(time) => "Tahmini bitiş: ${time}";

  static String m29(time) => "Çevrimdışı: ${time} itibarıyla yüklenenler gösteriliyor";

  static String m30(seconds) => "${seconds} sn sonra yeniden deneyebilirsiniz.";

  static String m31(message) => "Hata: ${message}";

  static String m32(detail) => "Ayrıntı: ${detail}";

  static String m33(host) => "Studio adresi: ${host}";

  static String m34(count) => "${Intl.plural(count, other: '${count} satır listelendi.')}";

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
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Sütunlar"),
    "browse_detail_default": m0,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Dışlama kısıtlamaları"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Yabancı anahtarlar"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Dizinler"),
    "browse_detail_links_unchecked": m1,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio hiç sütun listelemiyor."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio hiç yabancı anahtar listelemiyor."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio hiç dizin listelemiyor."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Boş olabilir"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Birincil anahtar"),
    "browse_detail_references": m2,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Sütunlar örneklenen belgelerden çıkarıldı"),
    "browse_detail_sampled_type": m3,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Benzersiz"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Ayrıntılar"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio burada hiç nesne saymıyor."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio bu düzeyde bir şey listelemiyor."),
    "browse_object_attached_to": m4,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Adı kopyala"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Ad kopyalandı"),
    "browse_object_rows": m5,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Devre dışı"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Geçersiz"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("Kaynağı görüntüle"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Nesneler"),
    "browse_objects_count": m6,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio burada bu türde nesne listelemiyor."),
    "browse_objects_match": m7,
    "browse_source": MessageLookupByLibrary.simpleMessage("Kaynak"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Tümünü kopyala"),
    "browse_source_copy_failed": m8,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Kısmi"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage(
      "Studio tarafından yeniden oluşturuldu, saklanan metin değil",
    ),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Paylaş"),
    "browse_source_share_failed": m9,
    "browse_source_truncated": m10,
    "browse_source_unavailable": MessageLookupByLibrary.simpleMessage("Bu tanım okunamadı"),
    "cancel": MessageLookupByLibrary.simpleMessage("İptal"),
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
    "connection_check_online": m11,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Erişilebilir"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Veritabanı"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Ortam"),
    "connection_environment_badge": m12,
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
    "connection_status_semantics": m13,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Bağlantı değiştir"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Motor"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Favorilerden çıkar"),
    "connection_vanished": m14,
    "connections": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı yok"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Çevrimdışı: internet bağlantısı yok. Ekrandakiler daha önce yüklendi.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Silmek istediğinize emin misiniz?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "edit": MessageLookupByLibrary.simpleMessage("Düzenle"),
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
    "error_generic": MessageLookupByLibrary.simpleMessage("Bir şeyler ters gitti"),
    "error_link_open_failed": m15,
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
    "force_update_versions": m16,
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
    "keys_listed": m17,
    "keys_listed_more": m18,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Tümünü yükle"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Desen"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Şununla başlar"),
    "keys_read_incomplete": m19,
    "keys_read_unknown": m20,
    "keys_scanned": m21,
    "keys_scanned_more": m22,
    "keys_scanned_of_database": m23,
    "keys_scanned_of_database_more": m24,
    "keys_scanned_of_walk": m25,
    "keys_scanned_of_walk_more": m26,
    "keys_skipped": m27,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Durdur"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Bu sayfadan sonra duruluyor"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Anahtarlar"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio bu bağlantı için anahtar tarayıcısı sunmuyor."),
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
    "maintenance_estimated_end": m28,
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
    "offline_stale_data": m29,
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
    "studio_error_retry_in": m30,
    "studio_error_semantics": m31,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("İfade kopyalandı"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda bağlantı sunamıyor. Bir yöneticinin yönetişim kurulumunu kontrol etmesi gerekiyor.",
    ),
    "studio_governance_detail": m32,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bağlantı erişimi geçici olarak kullanılamıyor. Erişim geri geldiğinde liste kendiliğinden güncellenir.",
    ),
    "studio_unreachable_host": m33,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio yanıt vermiyor. İnternet bağlantınızı kontrol edip tekrar deneyin.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Studio\'ya ulaşılamıyor"),
    "submit": MessageLookupByLibrary.simpleMessage("Gönder"),
    "success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Gözat"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m34,
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
    "yes": MessageLookupByLibrary.simpleMessage("Evet"),
  };
}
