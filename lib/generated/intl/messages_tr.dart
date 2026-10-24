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

  static String m13(code) => "Paylaşılan dosya oturumu kapatana kadar bu telefonda kalır (${code})";

  static String m14(reason) => "Kesildi: ${reason}";

  static String m15(latency) => "Erişilebilir, ${latency} ms";

  static String m16(label) => "Ortam: ${label}";

  static String m17(status) => "Durum: ${status}";

  static String m18(name) => "${name} artık kullanılamıyor";

  static String m19(catalog, used) =>
      "Sunucu ${catalog} veritabanını listelemiyor, bu yüzden düzenleyici ${used} kullanıyor.";

  static String m20(catalog) => "Sunucu ${catalog} veritabanını listelemiyor.";

  static String m21(url) => "${url} açılamadı";

  static String m22(count, formatted) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu', other: 'Eşleşen ${formatted} anahtar bulundu')}";

  static String m23(count, formatted) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; devamı var', other: 'Eşleşen ${formatted} anahtar bulundu; devamı var')}";

  static String m24(count, formatted, total) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; veritabanında ${total} anahtar var', other: 'Eşleşen ${formatted} anahtar bulundu; veritabanında ${total} anahtar var')}";

  static String m25(count, formatted, total) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; veritabanında ${total} anahtar var; devamı var', other: 'Eşleşen ${formatted} anahtar bulundu; veritabanında ${total} anahtar var; devamı var')}";

  static String m26(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi bulundu";

  static String m27(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi bulundu; devamı var";

  static String m28(count, formatted) =>
      "${Intl.plural(count, one: '1 öğe listelendi', other: '${formatted} öğe listelendi')}";

  static String m29(count, formatted) =>
      "${Intl.plural(count, one: '1 öğe listelendi; devamı var', other: '${formatted} öğe listelendi; devamı var')}";

  static String m30(reason) => "Bu liste eksik ve motor nedenini gösterebiliyor: ${reason}";

  static String m31(reason) =>
      "Bu liste okumanın gördüğüdür. Bu motorda her şeyin bu olup olmadığı belirlenemez: ${reason}";

  static String m32(count, formatted) =>
      "${Intl.plural(count, one: '1 anahtar tarandı', other: '${formatted} anahtar tarandı')}";

  static String m33(count, formatted) =>
      "${Intl.plural(count, one: '1 anahtar tarandı; devamı var', other: '${formatted} anahtar tarandı; devamı var')}";

  static String m34(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı";

  static String m35(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m36(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı";

  static String m37(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m38(count, formatted, reason) =>
      "${Intl.plural(count, one: 'Bu taramada 1 anahtar dışarıda kaldı: ${reason}', other: 'Bu taramada ${formatted} anahtar dışarıda kaldı: ${reason}')}";

  static String m39(type) => "Studio\'ya göre bu anahtarın türü: ${type}.";

  static String m40(time) => "Çevrimdışı: ${time} itibarıyla yüklenenler gösteriliyor";

  static String m41(count, rows) => "${Intl.plural(count, one: '1 satır etkilendi', other: '${rows} satır etkilendi')}";

  static String m42(id) => "#${id}";

  static String m43(code) => "Kopyalanamadı (${code})";

  static String m44(count, rows) => "${Intl.plural(count, one: '1 tane daha yükle', other: '${rows} tane daha yükle')}";

  static String m45(count, rows) =>
      "${Intl.plural(count, one: '1 tane daha yükleniyor…', other: '${rows} tane daha yükleniyor…')}";

  static String m46(count) => "${Intl.plural(count, one: '+1 alan daha', other: '+${count} alan daha')}";

  static String m47(index, count) => "Satır ${index} / ${count}";

  static String m48(index) => "Satır ${index}";

  static String m49(count, rows, time) =>
      "${Intl.plural(count, one: '1 satır, ${time} ms', other: '${rows} satır, ${time} ms')}";

  static String m50(code) => "Kod ${code}";

  static String m51(code) => "Uyarı ${code}";

  static String m52(severity, message) => "${severity}: ${message}";

  static String m53(count) => "${Intl.plural(count, one: '1 uyarı', other: '${count} uyarı')}";

  static String m54(label, catalog) => "${label}: ${catalog}";

  static String m55(reason) => "Metin bu telefona kaydedilemedi. ${reason}";

  static String m56(reason) =>
      "Bu bağlantı için kaydedilen metin okunamadı, bu yüzden yeni metin saklanmıyor. ${reason}";

  static String m57(language) => "Dil: ${language}";

  static String m58(reason) => "Bu bağlantının dili okunamadı, bu yüzden metin renklendirilmiyor. ${reason}";

  static String m59(keyword) =>
      "Bu deyim bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı. Korumak için ${keyword} ekleyin.";

  static String m60(time) => "${time} süredir çalışıyor";

  static String m61(time) => "${time} ms";

  static String m62(count) =>
      "${Intl.plural(count, one: '1 deyim çalıştırılmadı', other: '${count} deyim çalıştırılmadı')}";

  static String m63(keyword) =>
      "Betik bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı. Korumak için ${keyword} ekleyin.";

  static String m64(number) => "Deyim ${number}";

  static String m65(milliseconds) => "${milliseconds} ms";

  static String m66(count) => "${Intl.plural(count, one: '1 satır', other: '${count} satır')}";

  static String m67(seconds) => "${seconds} sn sonra yeniden deneyebilirsiniz.";

  static String m68(message) => "Hata: ${message}";

  static String m69(detail) => "Ayrıntı: ${detail}";

  static String m70(host) => "Studio adresi: ${host}";

  static String m71(count) => "${Intl.plural(count, other: '${count} satır listelendi.')}";

  static String m72(name) => "Onaylamak için \"${name}\" yazın";

  static String m73(word, line) => "Veriyi değiştirebilir: ${line}. satırda ${word}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account_refusal_title": MessageLookupByLibrary.simpleMessage("Hesabınızın Studio\'ya erişimi yok"),
    "active": MessageLookupByLibrary.simpleMessage("Aktif"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_lock": MessageLookupByLibrary.simpleMessage("Uygulama kilidi"),
    "app_lock_check_failed": MessageLookupByLibrary.simpleMessage(
      "LibreDB bu cihazın ekran kilidini denetleyemedi. Kilidi açmayı yeniden deneyin veya çıkış yapın.",
    ),
    "app_lock_enable_reason": MessageLookupByLibrary.simpleMessage(
      "Uygulama kilidini açmak için kimliğinizi doğrulayın",
    ),
    "app_lock_failed": MessageLookupByLibrary.simpleMessage("Tanınmadı. Tekrar deneyin."),
    "app_lock_locked_message": MessageLookupByLibrary.simpleMessage(
      "Devam etmek için parmak iziniz, yüzünüz veya ekran kilidinizle kilidi açın.",
    ),
    "app_lock_locked_out": MessageLookupByLibrary.simpleMessage("Çok fazla deneme yapıldı. Daha sonra tekrar deneyin."),
    "app_lock_locked_title": MessageLookupByLibrary.simpleMessage("LibreDB kilitli"),
    "app_lock_no_screen_lock": MessageLookupByLibrary.simpleMessage(
      "LibreDB\'yi kullanmak için bu cihazda bir ekran kilidi ayarlayın veya çıkış yapın.",
    ),
    "app_lock_no_screen_lock_subtitle": MessageLookupByLibrary.simpleMessage(
      "Bunu açmak için bu cihazda bir ekran kilidi ayarlayın",
    ),
    "app_lock_prompt_reason": MessageLookupByLibrary.simpleMessage("LibreDB\'nin kilidini açın"),
    "app_lock_required_subtitle": MessageLookupByLibrary.simpleMessage("Kuruluşunuz tarafından zorunlu tutuluyor"),
    "app_lock_subtitle": MessageLookupByLibrary.simpleMessage(
      "Uygulama açılırken parmak izinizi, yüzünüzü veya ekran kilidinizi iste",
    ),
    "app_lock_timeout": MessageLookupByLibrary.simpleMessage("Kilitleme süresi"),
    "app_lock_timeout_fifteen_minutes": MessageLookupByLibrary.simpleMessage("Arka planda 15 dakika sonra"),
    "app_lock_timeout_five_minutes": MessageLookupByLibrary.simpleMessage("Arka planda 5 dakika sonra"),
    "app_lock_timeout_immediately": MessageLookupByLibrary.simpleMessage("Hemen"),
    "app_lock_timeout_one_minute": MessageLookupByLibrary.simpleMessage("Arka planda 1 dakika sonra"),
    "app_lock_unlock": MessageLookupByLibrary.simpleMessage("Kilidi aç"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Uygula"),
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
    "browse_open_in_editor": MessageLookupByLibrary.simpleMessage("Düzenleyicide aç"),
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
    "browse_source_share_file_left": m13,
    "browse_source_truncated": m14,
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
    "connection_check_online": m15,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Erişilebilir"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Veritabanı"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Ortam"),
    "connection_environment_badge": m16,
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
    "connection_status_semantics": m17,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Bağlantı değiştir"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Motor"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Favorilerden çıkar"),
    "connection_vanished": m18,
    "connections": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı yok"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Çevrimdışı: internet bağlantısı yok. Ekrandakiler daha önce yüklendi.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Silmek istediğinize emin misiniz?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "edit": MessageLookupByLibrary.simpleMessage("Düzenle"),
    "editor_catalog_not_listed": m19,
    "editor_catalog_not_listed_none": m20,
    "editor_open_connection_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantı artık kullanılamıyor, bu yüzden deyim açılmadı.",
    ),
    "editor_replace_message": MessageLookupByLibrary.simpleMessage(
      "Yeni deyim düzenleyicideki metnin yerini alır. Çalıştırılmaz.",
    ),
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
    "error_auth_share_files_not_removed": MessageLookupByLibrary.simpleMessage(
      "Bu telefonda daha önce paylaşılan dosyalar silinemedi, bu yüzden oturum açılmadı. Tekrar deneyin.",
    ),
    "error_browse_rows_interrupted": MessageLookupByLibrary.simpleMessage(
      "Uygulama arka plana geçtiğinde satırları okuma kesildi; Studio onu iptal etti.",
    ),
    "error_editor_page_interrupted": MessageLookupByLibrary.simpleMessage(
      "Uygulama arka plana geçtiğinde daha fazla satır yükleme kesildi; Studio onu iptal etti.",
    ),
    "error_editor_page_outcome_unknown": MessageLookupByLibrary.simpleMessage(
      "Daha fazla satır yükleme arka planda kesildi ve sonucu bilinmiyor: her sayfa ifadenin tamamını yeniden çalıştırır, bu yüzden yeniden çalıştırmadan önce verileri kontrol edin.",
    ),
    "error_editor_saved_text_not_stored": MessageLookupByLibrary.simpleMessage(
      "Bu telefon sorgu metnini kaydedemedi. Boş depolama alanını kontrol edip tekrar deneyin.",
    ),
    "error_editor_saved_text_unreadable": MessageLookupByLibrary.simpleMessage(
      "Bu telefonda kayıtlı sorgu metni okunamıyor. Başka bir cihazın yedeğinden gelmiş ya da dosya değiştirilmiş olabilir. Yeni metnin yeniden kaydedilmesi için onu silin.",
    ),
    "error_generic": MessageLookupByLibrary.simpleMessage("Bir şeyler ters gitti"),
    "error_link_open_failed": m21,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "Bağlantının güvenli olduğu doğrulanamadığı için engellendi. Daha sonra ya da başka bir ağda tekrar deneyin.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "İnternet bağlantısı yok. Ağınızı kontrol edip tekrar deneyin.",
    ),
    "error_settings_app_lock_not_saved": MessageLookupByLibrary.simpleMessage("Uygulama kilidi ayarı kaydedilemedi."),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Dil değiştirilemedi"),
    "error_settings_user_data_not_removed": MessageLookupByLibrary.simpleMessage(
      "Verilerinizin bir kısmı bu telefondan silinemedi, bu yüzden oturumunuz açık.",
    ),
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
    "error_studio_search_pair_limit": MessageLookupByLibrary.simpleMessage(
      "Aranacak yer çok fazla. Aramayı daraltmak için nesne türlerini seçin.",
    ),
    "error_studio_statement_too_large": MessageLookupByLibrary.simpleMessage(
      "Bu deyim çalıştırılamayacak kadar büyük. Kısaltıp tekrar deneyin.",
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
    "failed": MessageLookupByLibrary.simpleMessage("Başarısız"),
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
    "keys_found": m22,
    "keys_found_more": m23,
    "keys_found_of_database": m24,
    "keys_found_of_database_more": m25,
    "keys_found_of_walk": m26,
    "keys_found_of_walk_more": m27,
    "keys_listed": m28,
    "keys_listed_more": m29,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Tümünü yükle"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Desen"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Şununla başlar"),
    "keys_read_incomplete": m30,
    "keys_read_unknown": m31,
    "keys_scanned": m32,
    "keys_scanned_more": m33,
    "keys_scanned_of_database": m34,
    "keys_scanned_of_database_more": m35,
    "keys_scanned_of_walk": m36,
    "keys_scanned_of_walk_more": m37,
    "keys_skipped": m38,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Durdur"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Bu sayfadan sonra duruluyor"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Anahtarlar"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio bu bağlantı için anahtar tarayıcısı sunmuyor."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("Uygulamanın bu tür için bir okuması yok."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Anahtar"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Değeri oku"),
    "keys_value_type": m39,
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
    "name": MessageLookupByLibrary.simpleMessage("İsim"),
    "new_item": MessageLookupByLibrary.simpleMessage("Yeni"),
    "next": MessageLookupByLibrary.simpleMessage("Sonraki"),
    "no": MessageLookupByLibrary.simpleMessage("Hayır"),
    "no_data": MessageLookupByLibrary.simpleMessage("Veri Yok"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("İstediğiniz sayfa bulunamadı."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Sayfa Bulunamadı"),
    "offline_action_unavailable": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı gerekiyor"),
    "offline_stale_data": m40,
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
    "remove_my_data": MessageLookupByLibrary.simpleMessage("Verilerimi sil"),
    "remove_my_data_collapsed_sections": MessageLookupByLibrary.simpleMessage(
      "Bağlantı listesinde daraltılan bölümler",
    ),
    "remove_my_data_confirm": MessageLookupByLibrary.simpleMessage("Sil ve oturumu kapat"),
    "remove_my_data_drafts": MessageLookupByLibrary.simpleMessage("SQL düzenleyici taslakları"),
    "remove_my_data_favorites": MessageLookupByLibrary.simpleMessage("Yıldızlı bağlantılar"),
    "remove_my_data_history": MessageLookupByLibrary.simpleMessage("Sorgu geçmişi"),
    "remove_my_data_kept": MessageLookupByLibrary.simpleMessage("Bu telefonda kalanlar"),
    "remove_my_data_kept_preferences": MessageLookupByLibrary.simpleMessage(
      "Dil, tema, sonuç görünümü ve uygulama kilidi",
    ),
    "remove_my_data_last_connection": MessageLookupByLibrary.simpleMessage("Son açık bağlantı ve veritabanı"),
    "remove_my_data_recents": MessageLookupByLibrary.simpleMessage("Son kullanılan bağlantılar"),
    "remove_my_data_removed": MessageLookupByLibrary.simpleMessage("Bu telefondan silinenler"),
    "remove_my_data_signs_out": MessageLookupByLibrary.simpleMessage("Verileriniz silinince oturumunuz kapatılır."),
    "remove_my_data_subtitle": MessageLookupByLibrary.simpleMessage(
      "Bu uygulamanın bu telefonda sizinle ilgili tuttuklarını silin ve oturumu kapatın",
    ),
    "remove_my_data_title": MessageLookupByLibrary.simpleMessage("Verileriniz silinsin mi?"),
    "required_field": MessageLookupByLibrary.simpleMessage("Zorunlu Alan"),
    "result_affected_rows": m41,
    "result_card_id": m42,
    "result_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "result_copy_failed": m43,
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
    "result_load_more": m44,
    "result_loading_more": m45,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Maskelenmiş değer"),
    "result_more_fields": m46,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "ORDER BY olmadan motor, sayfalar arasında satırları tekrarlayabilir ya da atlayabilir.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "Bu deyim bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı.",
    ),
    "result_row_position": m47,
    "result_row_title": m48,
    "result_stats": m49,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Kartlar"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Tablo"),
    "result_warning_code": m50,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "result_warning_fallback_code": m51,
    "result_warning_line": m52,
    "result_warnings": m53,
    "retry": MessageLookupByLibrary.simpleMessage("Tekrar Dene"),
    "role": MessageLookupByLibrary.simpleMessage("Rol"),
    "save": MessageLookupByLibrary.simpleMessage("Kaydet"),
    "settings": MessageLookupByLibrary.simpleMessage("Ayarlar"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Görünüm"),
    "settings_licenses": MessageLookupByLibrary.simpleMessage("Lisanslar"),
    "settings_licenses_subtitle": MessageLookupByLibrary.simpleMessage(
      "LibreDB Mobile\'ın ve içerdiği kodun lisansları",
    ),
    "settings_privacy": MessageLookupByLibrary.simpleMessage("Gizlilik"),
    "settings_security": MessageLookupByLibrary.simpleMessage("Güvenlik"),
    "settings_subtitle": MessageLookupByLibrary.simpleMessage("Hesap tercihlerinizi yönetin"),
    "settings_theme_subtitle": MessageLookupByLibrary.simpleMessage("Tercih ettiğiniz tema stilini seçin"),
    "sql_editor_cancel": MessageLookupByLibrary.simpleMessage("İptal et"),
    "sql_editor_cancel_not_confirmed": MessageLookupByLibrary.simpleMessage(
      "Studio iptali doğrulayamadı. Deyim sunucuda çalışmaya devam ediyor olabilir.",
    ),
    "sql_editor_cancelled": MessageLookupByLibrary.simpleMessage("İptal edildi"),
    "sql_editor_cancelling": MessageLookupByLibrary.simpleMessage("İptal ediliyor"),
    "sql_editor_catalog_chip": m54,
    "sql_editor_catalog_failed": MessageLookupByLibrary.simpleMessage(
      "Deyimlerin çalışacağı veritabanları listelenemedi.",
    ),
    "sql_editor_catalog_label": MessageLookupByLibrary.simpleMessage("Veritabanı"),
    "sql_editor_catalog_none": MessageLookupByLibrary.simpleMessage(
      "Sunucu, deyimlerin çalışacağı bir veritabanı listelemiyor.",
    ),
    "sql_editor_catalog_picker_title": MessageLookupByLibrary.simpleMessage("Deyimlerin çalışacağı yer"),
    "sql_editor_draft_no_account": MessageLookupByLibrary.simpleMessage(
      "Studio hesabınızı bildirene kadar metin saklanmaz.",
    ),
    "sql_editor_draft_not_kept": MessageLookupByLibrary.simpleMessage(
      "Bu metin 100.000 karakterden uzun olduğu için bu telefonda saklanmıyor ve bu bağlantı için daha önce kaydedilen metin silindi.",
    ),
    "sql_editor_draft_not_saved": m55,
    "sql_editor_draft_read_failed": m56,
    "sql_editor_draft_unreadable_note": MessageLookupByLibrary.simpleMessage(
      "Kaydedilen metni silene kadar yeni metin saklanmaz.",
    ),
    "sql_editor_field_label": MessageLookupByLibrary.simpleMessage("Deyim"),
    "sql_editor_hint": MessageLookupByLibrary.simpleMessage("Bir veya daha fazla deyim yazın"),
    "sql_editor_interrupted_read": MessageLookupByLibrary.simpleMessage(
      "Uygulama arka plana geçtiğinde çalıştırma kesildi; Studio onu iptal etti.",
    ),
    "sql_editor_interrupted_unknown": MessageLookupByLibrary.simpleMessage(
      "Sonuç bilinmiyor: yeniden çalıştırmadan önce verileri kontrol edin.",
    ),
    "sql_editor_language": m57,
    "sql_editor_language_unknown": m58,
    "sql_editor_redo": MessageLookupByLibrary.simpleMessage("Yinele"),
    "sql_editor_rolled_back": m59,
    "sql_editor_run": MessageLookupByLibrary.simpleMessage("Çalıştır"),
    "sql_editor_run_again": MessageLookupByLibrary.simpleMessage("Yeniden çalıştır"),
    "sql_editor_run_selection": MessageLookupByLibrary.simpleMessage("Seçimi çalıştır"),
    "sql_editor_script_elapsed": m60,
    "sql_editor_script_failed": MessageLookupByLibrary.simpleMessage("Başarısız"),
    "sql_editor_script_failed_time": m61,
    "sql_editor_script_not_run": m62,
    "sql_editor_script_rolled_back": MessageLookupByLibrary.simpleMessage(
      "Betik bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı.",
    ),
    "sql_editor_script_rolled_back_keep": m63,
    "sql_editor_script_show_rows": MessageLookupByLibrary.simpleMessage("Satırları göster"),
    "sql_editor_script_statement": m64,
    "sql_editor_script_succeeded": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "sql_editor_stop_waiting": MessageLookupByLibrary.simpleMessage("Beklemeyi bırak"),
    "sql_editor_stopped_waiting": MessageLookupByLibrary.simpleMessage(
      "Beklemeyi bıraktınız. Bu veritabanı bir deyimi iptal edemez; deyim sunucuda çalışmaya devam ediyor olabilir.",
    ),
    "sql_editor_tab": MessageLookupByLibrary.simpleMessage("Sekme"),
    "sql_editor_undo": MessageLookupByLibrary.simpleMessage("Geri al"),
    "sql_history_all_connections": MessageLookupByLibrary.simpleMessage("Tüm bağlantılar"),
    "sql_history_clear_all": MessageLookupByLibrary.simpleMessage("Tümünü temizle"),
    "sql_history_clear_message": MessageLookupByLibrary.simpleMessage(
      "Bu telefondaki geçmişinizde bulunan tüm deyimler silinir. Bu işlem geri alınamaz.",
    ),
    "sql_history_clear_title": MessageLookupByLibrary.simpleMessage("Geçmiş temizlensin mi?"),
    "sql_history_delete": MessageLookupByLibrary.simpleMessage("Sil"),
    "sql_history_duration": m65,
    "sql_history_empty": MessageLookupByLibrary.simpleMessage("Henüz deyim yok"),
    "sql_history_empty_description": MessageLookupByLibrary.simpleMessage(
      "Çalıştırdığınız deyimler burada görünür. Yalnızca bu telefonda kalırlar.",
    ),
    "sql_history_failed": MessageLookupByLibrary.simpleMessage("Başarısız"),
    "sql_history_filter_all": MessageLookupByLibrary.simpleMessage("Tümü"),
    "sql_history_filter_failure": MessageLookupByLibrary.simpleMessage("Başarısız"),
    "sql_history_filter_success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "sql_history_open": MessageLookupByLibrary.simpleMessage("Geçmiş"),
    "sql_history_replace": MessageLookupByLibrary.simpleMessage("Değiştir"),
    "sql_history_replace_title": MessageLookupByLibrary.simpleMessage("Düzenleyicideki metin değiştirilsin mi?"),
    "sql_history_rows": m66,
    "sql_history_search_hint": MessageLookupByLibrary.simpleMessage("Deyimlerde ve bağlantılarda ara"),
    "sql_history_succeeded": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "sql_history_title": MessageLookupByLibrary.simpleMessage("Geçmiş"),
    "sql_history_too_long": MessageLookupByLibrary.simpleMessage("Saklanamayacak kadar uzun"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("İfadeyi kopyala"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "Bir yönetici sorunu gidermek için bu ifadeyi çalıştırabilir:",
    ),
    "studio_error_retry_in": m67,
    "studio_error_semantics": m68,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("İfade kopyalandı"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda bağlantı sunamıyor. Bir yöneticinin yönetişim kurulumunu kontrol etmesi gerekiyor.",
    ),
    "studio_governance_detail": m69,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bağlantı erişimi geçici olarak kullanılamıyor. Erişim geri geldiğinde liste kendiliğinden güncellenir.",
    ),
    "studio_unreachable_host": m70,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio yanıt vermiyor. İnternet bağlantınızı kontrol edip tekrar deneyin.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Studio\'ya ulaşılamıyor"),
    "success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Gözat"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m71,
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
    "warning": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "write_confirm_cancel": MessageLookupByLibrary.simpleMessage("İptal"),
    "write_confirm_name_label": m72,
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
    "write_confirm_reason_may_write_at": m73,
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
