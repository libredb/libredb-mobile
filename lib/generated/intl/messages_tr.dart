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

  static String m1(reason) => "Satırlar sayılamadı: ${reason}";

  static String m2(value) => "Varsayılan: ${value}";

  static String m3(code) => "Bu anahtarların hangi tabloları açtığı denetlenemedi (${code})";

  static String m4(reason) => "Bu anahtarların hangi tabloları açtığı denetlenemedi: ${reason}";

  static String m5(table, column) => "Başvurduğu: ${table}.${column}";

  static String m6(type) => "${type} (örneklendi)";

  static String m7(parent) => "Bağlı olduğu nesne: ${parent}";

  static String m8(count, formatted) => "${Intl.plural(count, one: '1 satır', other: '${formatted} satır')}";

  static String m9(count, formatted) => "${Intl.plural(count, one: '1 nesne', other: '${formatted} nesne')}";

  static String m10(matched, total) => "${total} nesneden ${matched} tanesi eşleşiyor";

  static String m11(count) => "Aramak için en az ${count} karakter yazın.";

  static String m12(term) => "Adında \"${term}\" geçen nesne yok.";

  static String m13(code) => "Kopyalanamadı (${code})";

  static String m14(code) => "Paylaşılamadı (${code})";

  static String m15(reason) => "Paylaşılamadı: ${reason}";

  static String m16(reason) => "Paylaşılan dosya oturumu kapatana kadar bu telefonda kalır: ${reason}";

  static String m17(reason) => "Kesildi: ${reason}";

  static String m18(latency) => "Erişilebilir, ${latency} ms";

  static String m19(label) => "Ortam: ${label}";

  static String m20(status) => "Durum: ${status}";

  static String m21(name) => "${name} artık kullanılamıyor";

  static String m22(catalog, used) =>
      "Sunucu ${catalog} veritabanını listelemiyor, bu yüzden düzenleyici ${used} kullanıyor.";

  static String m23(catalog) => "Sunucu ${catalog} veritabanını listelemiyor.";

  static String m24(url) => "${url} açılamadı";

  static String m25(count, formatted) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu', other: 'Eşleşen ${formatted} anahtar bulundu')}";

  static String m26(count, formatted) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; devamı var', other: 'Eşleşen ${formatted} anahtar bulundu; devamı var')}";

  static String m27(count, formatted, total) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; veritabanında ${total} anahtar var', other: 'Eşleşen ${formatted} anahtar bulundu; veritabanında ${total} anahtar var')}";

  static String m28(count, formatted, total) =>
      "${Intl.plural(count, one: 'Eşleşen 1 anahtar bulundu; veritabanında ${total} anahtar var; devamı var', other: 'Eşleşen ${formatted} anahtar bulundu; veritabanında ${total} anahtar var; devamı var')}";

  static String m29(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi bulundu";

  static String m30(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi bulundu; devamı var";

  static String m31(count, formatted) =>
      "${Intl.plural(count, one: '1 öğe listelendi', other: '${formatted} öğe listelendi')}";

  static String m32(count, formatted) =>
      "${Intl.plural(count, one: '1 öğe listelendi; devamı var', other: '${formatted} öğe listelendi; devamı var')}";

  static String m33(reason) => "Bu liste eksik ve motor nedenini gösterebiliyor: ${reason}";

  static String m34(reason) =>
      "Bu liste okumanın gördüğüdür. Bu motorda her şeyin bu olup olmadığı belirlenemez: ${reason}";

  static String m35(count, formatted) =>
      "${Intl.plural(count, one: '1 anahtar tarandı', other: '${formatted} anahtar tarandı')}";

  static String m36(count, formatted) =>
      "${Intl.plural(count, one: '1 anahtar tarandı; devamı var', other: '${formatted} anahtar tarandı; devamı var')}";

  static String m37(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı";

  static String m38(count, total) => "Bu veritabanının tuttuğu ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m39(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı";

  static String m40(count, total) => "Bu taramanın kapsadığı ${total} anahtardan ${count} tanesi tarandı; devamı var";

  static String m41(count, formatted, reason) =>
      "${Intl.plural(count, one: 'Bu taramada 1 anahtar dışarıda kaldı: ${reason}', other: 'Bu taramada ${formatted} anahtar dışarıda kaldı: ${reason}')}";

  static String m42(type) => "Studio\'ya göre bu anahtarın türü: ${type}.";

  static String m43(time) => "Çevrimdışı: ${time} itibarıyla yüklenenler gösteriliyor";

  static String m44(connection) => "Bağlantı: ${connection}";

  static String m45(date) => "Başlangıç ${date}";

  static String m46(text) => "Metin: ${text}";

  static String m47(value) => "Kaynak: ${value}";

  static String m48(value) => "Tür: ${value}";

  static String m49(value) => "Durum: ${value}";

  static String m50(date) => "Bitiş ${date}";

  static String m51(user) => "Kullanıcı: ${user}";

  static String m52(ms) => "${ms} ms";

  static String m53(count) => "Satır: ${count}";

  static String m54(count) => "${count} sa önce";

  static String m55(count) => "${count} dk önce";

  static String m56(connection) =>
      "${connection} bağlantısı yaklaşık 30 saniye içinde tüm Studio kullanıcılarına kapanır. Çalışmakta olan sorgular durdurulmaz. Erişimleri korunur.";

  static String m57(connection) =>
      "${connection} bağlantısı, üzerinde erişimi olan herkese yeniden açılır. Bu erişimler lisansın kullanıcı koltuklarını kullanabilir.";

  static String m58(date) => "${date} tarihinde sona erer";

  static String m59(connection) => "${connection} için erişimi değiştir";

  static String m60(connection) => "${connection} için erişim ver";

  static String m61(date) => "${date} tarihinde sona erdi";

  static String m62(date) => "${date} tarihinde sona eriyor";

  static String m63(name, date) => "Veren: ${name}, ${date}";

  static String m64(username, level, connection) =>
      "${username} kullanıcısının ${connection} bağlantısındaki ${level} erişimi kaldırılacak.";

  static String m65(host) => "Platform adresi: ${host}";

  static String m66(count, rows) => "${Intl.plural(count, one: '1 satır etkilendi', other: '${rows} satır etkilendi')}";

  static String m67(id) => "#${id}";

  static String m68(code) => "Kopyalanamadı (${code})";

  static String m69(count, rows) => "${Intl.plural(count, one: '1 tane daha yükle', other: '${rows} tane daha yükle')}";

  static String m70(count, rows) =>
      "${Intl.plural(count, one: '1 tane daha yükleniyor…', other: '${rows} tane daha yükleniyor…')}";

  static String m71(count) => "${Intl.plural(count, one: '+1 alan daha', other: '+${count} alan daha')}";

  static String m72(index, count) => "Satır ${index} / ${count}";

  static String m73(index) => "Satır ${index}";

  static String m74(count, rows, time) =>
      "${Intl.plural(count, one: '1 satır, ${time} ms', other: '${rows} satır, ${time} ms')}";

  static String m75(code) => "Kod ${code}";

  static String m76(code) => "Uyarı ${code}";

  static String m77(severity, message) => "${severity}: ${message}";

  static String m78(count) => "${Intl.plural(count, one: '1 uyarı', other: '${count} uyarı')}";

  static String m79(label, catalog) => "${label}: ${catalog}";

  static String m80(reason) => "Metin bu telefona kaydedilemedi. ${reason}";

  static String m81(reason) =>
      "Bu bağlantı için kaydedilen metin okunamadı, bu yüzden yeni metin saklanmıyor. ${reason}";

  static String m82(language) => "Dil: ${language}";

  static String m83(reason) => "Bu bağlantının dili okunamadı, bu yüzden metin renklendirilmiyor. ${reason}";

  static String m84(keyword) =>
      "Bu deyim bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı. Korumak için ${keyword} ekleyin.";

  static String m85(time) => "${time} süredir çalışıyor";

  static String m86(time) => "${time} ms";

  static String m87(count) =>
      "${Intl.plural(count, one: '1 deyim çalıştırılmadı', other: '${count} deyim çalıştırılmadı')}";

  static String m88(keyword) =>
      "Betik bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı. Korumak için ${keyword} ekleyin.";

  static String m89(number) => "Deyim ${number}";

  static String m90(milliseconds) => "${milliseconds} ms";

  static String m91(count) => "${Intl.plural(count, one: '1 satır', other: '${count} satır')}";

  static String m92(seconds) => "${seconds} sn sonra yeniden deneyebilirsiniz.";

  static String m93(message) => "Hata: ${message}";

  static String m94(detail) => "Ayrıntı: ${detail}";

  static String m95(host) => "Studio adresi: ${host}";

  static String m96(count) => "${Intl.plural(count, other: '${count} satır listelendi.')}";

  static String m97(name) => "Onaylamak için \"${name}\" yazın";

  static String m98(word, line) => "Veriyi değiştirebilir: ${line}. satırda ${word}";

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
    "browse_count_failed_reason": m1,
    "browse_count_rows": MessageLookupByLibrary.simpleMessage("Satırları say"),
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Sütunlar"),
    "browse_detail_default": m2,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Dışlama kısıtlamaları"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Yabancı anahtarlar"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Dizinler"),
    "browse_detail_links_unchecked": m3,
    "browse_detail_links_unchecked_reason": m4,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio hiç sütun listelemiyor."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio hiç yabancı anahtar listelemiyor."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio hiç dizin listelemiyor."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Boş olabilir"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Birincil anahtar"),
    "browse_detail_references": m5,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Sütunlar örneklenen belgelerden çıkarıldı"),
    "browse_detail_sampled_type": m6,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Benzersiz"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Ayrıntılar"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio burada hiç nesne saymıyor."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio bu düzeyde bir şey listelemiyor."),
    "browse_object_attached_to": m7,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Adı kopyala"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Ad kopyalandı"),
    "browse_object_rows": m8,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Devre dışı"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Geçersiz"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("Kaynağı görüntüle"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Nesneler"),
    "browse_objects_count": m9,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio burada bu türde nesne listelemiyor."),
    "browse_objects_match": m10,
    "browse_open_in_editor": MessageLookupByLibrary.simpleMessage("Düzenleyicide aç"),
    "browse_preview_unavailable": MessageLookupByLibrary.simpleMessage("Bu motor için önizleme henüz kullanılamıyor"),
    "browse_rows_database_says": MessageLookupByLibrary.simpleMessage("Veritabanının yanıtı"),
    "browse_search_action": MessageLookupByLibrary.simpleMessage("Nesnelerde ara"),
    "browse_search_clear": MessageLookupByLibrary.simpleMessage("Aramayı temizle"),
    "browse_search_hint": MessageLookupByLibrary.simpleMessage("Ada göre ara"),
    "browse_search_min_length": m11,
    "browse_search_no_results": m12,
    "browse_search_not_available": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıda arama yapılamaz; bunun yerine göz atın",
    ),
    "browse_search_title": MessageLookupByLibrary.simpleMessage("Ara"),
    "browse_source": MessageLookupByLibrary.simpleMessage("Kaynak"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Tümünü kopyala"),
    "browse_source_copy_failed": m13,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Kısmi"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage(
      "Studio tarafından yeniden oluşturuldu, saklanan metin değil",
    ),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Paylaş"),
    "browse_source_share_failed": m14,
    "browse_source_share_failed_reason": m15,
    "browse_source_share_file_left": m16,
    "browse_source_truncated": m17,
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
    "connection_check_online": m18,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Erişilebilir"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Veritabanı"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Ortam"),
    "connection_environment_badge": m19,
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
    "connection_status_semantics": m20,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Bağlantı değiştir"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Motor"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Favorilerden çıkar"),
    "connection_vanished": m21,
    "connections": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı yok"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Çevrimdışı: internet bağlantısı yok. Ekrandakiler daha önce yüklendi.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Silmek istediğinize emin misiniz?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "edit": MessageLookupByLibrary.simpleMessage("Düzenle"),
    "editor_catalog_not_listed": m22,
    "editor_catalog_not_listed_none": m23,
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
    "error_link_open_failed": m24,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "Bağlantının güvenli olduğu doğrulanamadığı için engellendi. Daha sonra ya da başka bir ağda tekrar deneyin.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "İnternet bağlantısı yok. Ağınızı kontrol edip tekrar deneyin.",
    ),
    "error_platform_account_refused": MessageLookupByLibrary.simpleMessage(
      "Platform bu girişi kabul etmedi. Bu uygulamanın Platform için ayarlandığını yöneticinize kontrol ettirin ya da Studio\'ya giriş yapın.",
    ),
    "error_platform_admin_role_required": MessageLookupByLibrary.simpleMessage(
      "Bu hesap bir Platform yöneticisi değil. Bunun yerine Studio ile oturum açın.",
    ),
    "error_platform_api_disabled": MessageLookupByLibrary.simpleMessage(
      "Bu Platform kurulumu mobil uygulamayı kabul etmiyor.",
    ),
    "error_platform_directory_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform şu anda kullanıcı dizinini okuyamıyor. Biraz sonra tekrar deneyin.",
    ),
    "error_platform_grant_expiry_refused": MessageLookupByLibrary.simpleMessage("Bitiş zamanı gelecekte olmalı."),
    "error_platform_grant_level_refused": MessageLookupByLibrary.simpleMessage(
      "Yazma erişimi, yazma kimlik bilgisi olan bir bağlantı gerektirir.",
    ),
    "error_platform_grant_subject_refused": MessageLookupByLibrary.simpleMessage(
      "Keycloak bu kullanıcıyı tanımıyor ya da devre dışı bırakmış.",
    ),
    "error_platform_identity_provider_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform şu anda kimlik sağlayıcıya ulaşamıyor. Biraz sonra tekrar deneyin.",
    ),
    "error_platform_internal_error": MessageLookupByLibrary.simpleMessage(
      "Platform isteği tamamlayamadı. Daha sonra tekrar deneyin.",
    ),
    "error_platform_keycloak_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform şu anda Keycloak\'a ulaşamıyor. Biraz sonra tekrar deneyin.",
    ),
    "error_platform_license_admin_seats": MessageLookupByLibrary.simpleMessage(
      "Platform lisansında bu hesap için boş yönetici koltuğu yok.",
    ),
    "error_platform_license_expired": MessageLookupByLibrary.simpleMessage("Platform lisansının süresi doldu."),
    "error_platform_license_invalid": MessageLookupByLibrary.simpleMessage("Platform lisansı geçerli değil."),
    "error_platform_license_user_seats": MessageLookupByLibrary.simpleMessage(
      "Platform lisansında bu yetki için boş kullanıcı koltuğu yok.",
    ),
    "error_platform_not_configured": MessageLookupByLibrary.simpleMessage(
      "Platform modu uygulamanın bu sürümünde yok. Studio ile oturum açın.",
    ),
    "error_platform_not_found": MessageLookupByLibrary.simpleMessage("Bu öğe Platform\'da artık yok."),
    "error_platform_permission_denied": MessageLookupByLibrary.simpleMessage(
      "Platform bu hesabın bunu yapmasına izin vermiyor.",
    ),
    "error_platform_plan_feature_required": MessageLookupByLibrary.simpleMessage(
      "Bu Platform kurulumunun planı bu özelliği içermiyor.",
    ),
    "error_platform_unreadable_answer": MessageLookupByLibrary.simpleMessage(
      "Platform bu uygulamanın okuyamadığı bir yanıt gönderdi. Uygulamanın güncellenmesi gerekebilir.",
    ),
    "error_platform_validation_failed": MessageLookupByLibrary.simpleMessage("Platform isteği kabul etmedi."),
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
    "keys_found": m25,
    "keys_found_more": m26,
    "keys_found_of_database": m27,
    "keys_found_of_database_more": m28,
    "keys_found_of_walk": m29,
    "keys_found_of_walk_more": m30,
    "keys_listed": m31,
    "keys_listed_more": m32,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Tümünü yükle"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Desen"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Şununla başlar"),
    "keys_read_incomplete": m33,
    "keys_read_unknown": m34,
    "keys_scanned": m35,
    "keys_scanned_more": m36,
    "keys_scanned_of_database": m37,
    "keys_scanned_of_database_more": m38,
    "keys_scanned_of_walk": m39,
    "keys_scanned_of_walk_more": m40,
    "keys_skipped": m41,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Durdur"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Bu sayfadan sonra duruluyor"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Anahtarlar"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio bu bağlantı için anahtar tarayıcısı sunmuyor."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("Uygulamanın bu tür için bir okuması yok."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Anahtar"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Değeri oku"),
    "keys_value_type": m42,
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
    "login_platform_button": MessageLookupByLibrary.simpleMessage("Platform\'a giriş yap"),
    "login_platform_helper": MessageLookupByLibrary.simpleMessage(
      "Platform yöneticileri için. İlk Platform girişiniz lisansın bir yönetici koltuğunu kullanır.",
    ),
    "login_sso_button": MessageLookupByLibrary.simpleMessage("SSO ile giriş yap"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Kurumsal hesabınızla giriş yapın."),
    "login_studio_button": MessageLookupByLibrary.simpleMessage("Studio\'ya giriş yap"),
    "login_studio_helper": MessageLookupByLibrary.simpleMessage(
      "Studio\'nun size açtığı veritabanlarına göz atın ve sorgu çalıştırın.",
    ),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Koyu temaya geç"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Açık temaya geç"),
    "login_unreachable_platform": MessageLookupByLibrary.simpleMessage("Platform yanıt vermiyor."),
    "login_unreachable_studio": MessageLookupByLibrary.simpleMessage("Studio yanıt vermiyor."),
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
    "offline_stale_data": m43,
    "pick_connection_first": MessageLookupByLibrary.simpleMessage("Önce bir bağlantı seçin"),
    "pick_connection_first_description": MessageLookupByLibrary.simpleMessage(
      "Bu sekmeyi kullanmak için Bağlantılar sekmesinden bir bağlantı açın.",
    ),
    "platform_account_refusal_title": MessageLookupByLibrary.simpleMessage("LibreDB Platform hesabınızı reddetti"),
    "platform_audit_any": MessageLookupByLibrary.simpleMessage("Hepsi"),
    "platform_audit_capture_full": MessageLookupByLibrary.simpleMessage("Tam"),
    "platform_audit_capture_none": MessageLookupByLibrary.simpleMessage("Yok"),
    "platform_audit_capture_redacted": MessageLookupByLibrary.simpleMessage("Maskelenmiş"),
    "platform_audit_chip_connection": m44,
    "platform_audit_chip_from": m45,
    "platform_audit_chip_remove": MessageLookupByLibrary.simpleMessage("Bu filtreyi kaldır"),
    "platform_audit_chip_search": m46,
    "platform_audit_chip_source": m47,
    "platform_audit_chip_statement_type": m48,
    "platform_audit_chip_status": m49,
    "platform_audit_chip_to": m50,
    "platform_audit_chip_user": m51,
    "platform_audit_clear_filters": MessageLookupByLibrary.simpleMessage("Filtreleri temizle"),
    "platform_audit_duration": m52,
    "platform_audit_empty_description": MessageLookupByLibrary.simpleMessage(
      "Studio\'nun Platform bağlantılarında çalıştırdığı sorgular burada görünür.",
    ),
    "platform_audit_empty_title": MessageLookupByLibrary.simpleMessage("Henüz yönetilen sorgu yok"),
    "platform_audit_field_access_level": MessageLookupByLibrary.simpleMessage("Erişim düzeyi"),
    "platform_audit_field_capture": MessageLookupByLibrary.simpleMessage("Komut kaydı"),
    "platform_audit_field_connection": MessageLookupByLibrary.simpleMessage("Bağlantı"),
    "platform_audit_field_connection_id": MessageLookupByLibrary.simpleMessage("Bağlantı kimliği"),
    "platform_audit_field_duration": MessageLookupByLibrary.simpleMessage("Süre"),
    "platform_audit_field_engine": MessageLookupByLibrary.simpleMessage("Motor"),
    "platform_audit_field_error_code": MessageLookupByLibrary.simpleMessage("Hata kodu"),
    "platform_audit_field_error_message": MessageLookupByLibrary.simpleMessage("Hata mesajı"),
    "platform_audit_field_event_id": MessageLookupByLibrary.simpleMessage("Olay kimliği"),
    "platform_audit_field_explain": MessageLookupByLibrary.simpleMessage("Explain"),
    "platform_audit_field_finished": MessageLookupByLibrary.simpleMessage("Bitti"),
    "platform_audit_field_rows": MessageLookupByLibrary.simpleMessage("Satırlar"),
    "platform_audit_field_session_role": MessageLookupByLibrary.simpleMessage("Oturum rolü"),
    "platform_audit_field_source": MessageLookupByLibrary.simpleMessage("Kaynak"),
    "platform_audit_field_started": MessageLookupByLibrary.simpleMessage("Başladı"),
    "platform_audit_field_statement": MessageLookupByLibrary.simpleMessage("Komut"),
    "platform_audit_field_statement_type": MessageLookupByLibrary.simpleMessage("Komut türü"),
    "platform_audit_field_status": MessageLookupByLibrary.simpleMessage("Durum"),
    "platform_audit_field_subject": MessageLookupByLibrary.simpleMessage("Keycloak kimliği"),
    "platform_audit_field_transaction": MessageLookupByLibrary.simpleMessage("İşlem sonucu"),
    "platform_audit_field_user": MessageLookupByLibrary.simpleMessage("Kullanıcı"),
    "platform_audit_filter_any_day": MessageLookupByLibrary.simpleMessage("Herhangi bir gün"),
    "platform_audit_filter_clear_date": MessageLookupByLibrary.simpleMessage("Tarihi temizle"),
    "platform_audit_filter_done": MessageLookupByLibrary.simpleMessage("Tamam"),
    "platform_audit_filter_from": MessageLookupByLibrary.simpleMessage("Başlangıç"),
    "platform_audit_filter_search": MessageLookupByLibrary.simpleMessage("Komut metni"),
    "platform_audit_filter_search_hint": MessageLookupByLibrary.simpleMessage(
      "Komuttaki metin, büyük küçük harf fark etmez",
    ),
    "platform_audit_filter_source": MessageLookupByLibrary.simpleMessage("Kaynak"),
    "platform_audit_filter_statement_type": MessageLookupByLibrary.simpleMessage("Komut türü"),
    "platform_audit_filter_status": MessageLookupByLibrary.simpleMessage("Durum"),
    "platform_audit_filter_to": MessageLookupByLibrary.simpleMessage("Bitiş"),
    "platform_audit_filtered_empty_description": MessageLookupByLibrary.simpleMessage(
      "Bir filtreyi kaldırın ya da başka birini seçin.",
    ),
    "platform_audit_filtered_empty_title": MessageLookupByLibrary.simpleMessage("Filtrelere uyan olay yok"),
    "platform_audit_filters": MessageLookupByLibrary.simpleMessage("Filtreler"),
    "platform_audit_load_failed": MessageLookupByLibrary.simpleMessage("Denetim kaydı yüklenemedi"),
    "platform_audit_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "platform_audit_load_more_failed": MessageLookupByLibrary.simpleMessage("Daha fazla olay yüklenemedi"),
    "platform_audit_not_recorded": MessageLookupByLibrary.simpleMessage("Kaydedilmedi"),
    "platform_audit_only_this_connection": MessageLookupByLibrary.simpleMessage("Yalnızca bu bağlantı"),
    "platform_audit_only_this_user": MessageLookupByLibrary.simpleMessage("Yalnızca bu kullanıcı"),
    "platform_audit_permission_refused_description": MessageLookupByLibrary.simpleMessage(
      "Bir Platform yöneticisi bu hesaba denetim iznini verebilir.",
    ),
    "platform_audit_permission_refused_title": MessageLookupByLibrary.simpleMessage(
      "Platform bu hesabın denetim kaydını okumasına izin vermiyor",
    ),
    "platform_audit_plan_refused_description": MessageLookupByLibrary.simpleMessage(
      "Denetim kaydı içeren bir plan Platform lisansında seçilir.",
    ),
    "platform_audit_plan_refused_title": MessageLookupByLibrary.simpleMessage(
      "Denetim kaydı bu kurulumun planında yok",
    ),
    "platform_audit_refresh_failed": MessageLookupByLibrary.simpleMessage("Denetim kaydı yenilenemedi"),
    "platform_audit_row_count": m53,
    "platform_audit_statement_none": MessageLookupByLibrary.simpleMessage("Kaydedilmedi"),
    "platform_audit_statement_not_captured": MessageLookupByLibrary.simpleMessage("Komut kaydedilmedi"),
    "platform_audit_statement_redacted": MessageLookupByLibrary.simpleMessage(
      "Bağlantının kayıt ayarı tarafından maskelendi",
    ),
    "platform_audit_statement_truncated": MessageLookupByLibrary.simpleMessage("Studio tarafından kısaltıldı"),
    "platform_audit_status_cancelled": MessageLookupByLibrary.simpleMessage("İptal edildi"),
    "platform_audit_status_error": MessageLookupByLibrary.simpleMessage("Hata"),
    "platform_audit_status_refused": MessageLookupByLibrary.simpleMessage("Reddedildi"),
    "platform_audit_status_success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "platform_audit_tab": MessageLookupByLibrary.simpleMessage("Denetim"),
    "platform_audit_time_hours_ago": m54,
    "platform_audit_time_just_now": MessageLookupByLibrary.simpleMessage("Az önce"),
    "platform_audit_time_minutes_ago": m55,
    "platform_audit_unknown_connection": MessageLookupByLibrary.simpleMessage("Bilinmeyen bağlantı"),
    "platform_connections_active_actions": MessageLookupByLibrary.simpleMessage("Bağlantı işlemleri"),
    "platform_connections_active_disable": MessageLookupByLibrary.simpleMessage("Bağlantıyı devre dışı bırak"),
    "platform_connections_active_disable_confirm": MessageLookupByLibrary.simpleMessage("Devre dışı bırak"),
    "platform_connections_active_disable_message": m56,
    "platform_connections_active_disabled": MessageLookupByLibrary.simpleMessage("Bağlantı devre dışı bırakıldı"),
    "platform_connections_active_enable": MessageLookupByLibrary.simpleMessage("Bağlantıyı etkinleştir"),
    "platform_connections_active_enable_confirm": MessageLookupByLibrary.simpleMessage("Etkinleştir"),
    "platform_connections_active_enable_message": m57,
    "platform_connections_active_enabled": MessageLookupByLibrary.simpleMessage("Bağlantı etkinleştirildi"),
    "platform_connections_active_gone": MessageLookupByLibrary.simpleMessage("Bu bağlantı artık yok"),
    "platform_connections_active_user_seats": MessageLookupByLibrary.simpleMessage(
      "Platform lisansında bu bağlantının erişimleri için yeterli kullanıcı koltuğu yok.",
    ),
    "platform_connections_active_user_seats_title": MessageLookupByLibrary.simpleMessage(
      "Yeterli kullanıcı koltuğu yok",
    ),
    "platform_connections_empty_description": MessageLookupByLibrary.simpleMessage(
      "Bağlantılar Platform web konsolunda eklenir.",
    ),
    "platform_connections_empty_title": MessageLookupByLibrary.simpleMessage("Bu kurulumda henüz bağlantı yok"),
    "platform_connections_filter_hint": MessageLookupByLibrary.simpleMessage("Ada veya motora göre filtrele"),
    "platform_connections_load_failed": MessageLookupByLibrary.simpleMessage("Bağlantılar yüklenemedi"),
    "platform_connections_read_grants_only": MessageLookupByLibrary.simpleMessage("Yalnızca okuma yetkisi verilebilir"),
    "platform_connections_read_grants_only_semantics": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantının yazma kimlik bilgisi yok, bu yüzden yalnızca okuma erişimi verilebilir.",
    ),
    "platform_connections_refresh_failed": MessageLookupByLibrary.simpleMessage("Bağlantılar yenilenemedi"),
    "platform_connections_search_empty_description": MessageLookupByLibrary.simpleMessage(
      "Başka bir ad veya motor deneyin.",
    ),
    "platform_connections_search_empty_title": MessageLookupByLibrary.simpleMessage("Filtreyle eşleşen bağlantı yok"),
    "platform_connections_status_unknown": MessageLookupByLibrary.simpleMessage("Bilinmeyen durum"),
    "platform_grants_actions": MessageLookupByLibrary.simpleMessage("Erişim işlemleri"),
    "platform_grants_add": MessageLookupByLibrary.simpleMessage("Erişim ver"),
    "platform_grants_already_removed": MessageLookupByLibrary.simpleMessage("Zaten kaldırılmış"),
    "platform_grants_back_to_connections": MessageLookupByLibrary.simpleMessage("Bağlantılara dön"),
    "platform_grants_connection_gone_description": MessageLookupByLibrary.simpleMessage(
      "Platform web konsolunda silinmiş olabilir.",
    ),
    "platform_grants_connection_gone_title": MessageLookupByLibrary.simpleMessage("Bu bağlantı artık yok"),
    "platform_grants_edit": MessageLookupByLibrary.simpleMessage("Erişimi değiştir"),
    "platform_grants_editor_change_user": MessageLookupByLibrary.simpleMessage("Başka bir kullanıcı seçin"),
    "platform_grants_editor_expiry": MessageLookupByLibrary.simpleMessage("Bitiş"),
    "platform_grants_editor_expiry_local_time": MessageLookupByLibrary.simpleMessage("Bu cihazın saat diliminde."),
    "platform_grants_editor_expiry_never": MessageLookupByLibrary.simpleMessage("Süresiz"),
    "platform_grants_editor_expiry_not_in_future": MessageLookupByLibrary.simpleMessage(
      "Gelecekte bir zaman seçin ya da süresiz bırakın.",
    ),
    "platform_grants_editor_expiry_on": m58,
    "platform_grants_editor_expiry_pick": MessageLookupByLibrary.simpleMessage("Tarih ve saat seçin"),
    "platform_grants_editor_level": MessageLookupByLibrary.simpleMessage("Erişim düzeyi"),
    "platform_grants_editor_level_missing": MessageLookupByLibrary.simpleMessage("Bir erişim düzeyi seçin."),
    "platform_grants_editor_license_title": MessageLookupByLibrary.simpleMessage("Lisans bu yetkiye izin vermiyor"),
    "platform_grants_editor_no_role_note": MessageLookupByLibrary.simpleMessage(
      "Bu kullanıcının Studio rolü yok; bir Keycloak yöneticisi rol verene kadar Studio\'ya giriş yapamaz.",
    ),
    "platform_grants_editor_retry_title": MessageLookupByLibrary.simpleMessage("Platform kullanıcıyı denetleyemedi"),
    "platform_grants_editor_save": MessageLookupByLibrary.simpleMessage("Kaydet"),
    "platform_grants_editor_saved": MessageLookupByLibrary.simpleMessage("Erişim kaydedildi"),
    "platform_grants_editor_title_edit": m59,
    "platform_grants_editor_title_new": m60,
    "platform_grants_editor_write_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantının yazma kimlik bilgisi yok, bu yüzden yalnızca okuma erişimi verilebilir.",
    ),
    "platform_grants_empty_description": MessageLookupByLibrary.simpleMessage(
      "Bu bağlantıda kimseye erişim verilmemiş.",
    ),
    "platform_grants_empty_title": MessageLookupByLibrary.simpleMessage("Henüz kimsenin erişimi yok"),
    "platform_grants_expired": m61,
    "platform_grants_expires": m62,
    "platform_grants_granted_by": m63,
    "platform_grants_level_read": MessageLookupByLibrary.simpleMessage("Okuma"),
    "platform_grants_level_read_in_sentence": MessageLookupByLibrary.simpleMessage("okuma"),
    "platform_grants_level_write": MessageLookupByLibrary.simpleMessage("Yazma"),
    "platform_grants_level_write_in_sentence": MessageLookupByLibrary.simpleMessage("yazma"),
    "platform_grants_load_failed": MessageLookupByLibrary.simpleMessage("Erişimler yüklenemedi"),
    "platform_grants_no_expiry": MessageLookupByLibrary.simpleMessage("Süresiz"),
    "platform_grants_picker_clear": MessageLookupByLibrary.simpleMessage("Aramayı temizle"),
    "platform_grants_picker_disabled": MessageLookupByLibrary.simpleMessage("Keycloak\'ta devre dışı"),
    "platform_grants_picker_empty_description": MessageLookupByLibrary.simpleMessage(
      "Bu aramayla eşleşen bir Keycloak kullanıcısı yok.",
    ),
    "platform_grants_picker_empty_title": MessageLookupByLibrary.simpleMessage("Kullanıcı bulunamadı"),
    "platform_grants_picker_load_failed": MessageLookupByLibrary.simpleMessage("Dizinde arama yapılamadı"),
    "platform_grants_picker_load_more": MessageLookupByLibrary.simpleMessage("Daha fazla yükle"),
    "platform_grants_picker_load_more_failed": MessageLookupByLibrary.simpleMessage("Daha fazla kullanıcı yüklenemedi"),
    "platform_grants_picker_query_too_long": MessageLookupByLibrary.simpleMessage(
      "Arama metni çok uzun. En fazla 255 karakter kullanın.",
    ),
    "platform_grants_picker_role_admin": MessageLookupByLibrary.simpleMessage("Studio yöneticisi"),
    "platform_grants_picker_role_none": MessageLookupByLibrary.simpleMessage(
      "Studio rolü yok, Studio\'ya giriş yapamaz",
    ),
    "platform_grants_picker_role_user": MessageLookupByLibrary.simpleMessage("Studio kullanıcısı"),
    "platform_grants_picker_search_hint": MessageLookupByLibrary.simpleMessage(
      "Kullanıcı adı, ad veya e-posta ile arayın",
    ),
    "platform_grants_picker_takes_seat": MessageLookupByLibrary.simpleMessage("Bir kullanıcı koltuğu kullanır"),
    "platform_grants_picker_takes_seat_inactive": MessageLookupByLibrary.simpleMessage(
      "Bağlantı yeniden etkin olduğunda bir kullanıcı koltuğu kullanır",
    ),
    "platform_grants_picker_title": MessageLookupByLibrary.simpleMessage("Bir kullanıcı seçin"),
    "platform_grants_refresh_failed": MessageLookupByLibrary.simpleMessage("Erişimler yenilenemedi"),
    "platform_grants_remove_access": MessageLookupByLibrary.simpleMessage("Erişimi kaldır"),
    "platform_grants_remove_confirm": MessageLookupByLibrary.simpleMessage("Kaldır"),
    "platform_grants_remove_message": m64,
    "platform_grants_removed": MessageLookupByLibrary.simpleMessage("Erişim kaldırıldı"),
    "platform_home_admin_label": MessageLookupByLibrary.simpleMessage("Platform yöneticisi"),
    "platform_home_connections_shortcut": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "platform_home_connections_shortcut_description": MessageLookupByLibrary.simpleMessage(
      "Bu kurulumun tüm bağlantılarını görün.",
    ),
    "platform_home_identity_load_failed": MessageLookupByLibrary.simpleMessage("Platform hesabınız yüklenemedi"),
    "platform_home_signed_in_as": MessageLookupByLibrary.simpleMessage("Oturum açan"),
    "platform_home_tenant_label": MessageLookupByLibrary.simpleMessage("Kuruluş"),
    "platform_status_unreachable_host": m65,
    "platform_status_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Platform yanıt vermiyor. İnternet bağlantınızı kontrol edip tekrar deneyin.",
    ),
    "platform_status_unreachable_title": MessageLookupByLibrary.simpleMessage("Platform\'a ulaşılamıyor"),
    "previous": MessageLookupByLibrary.simpleMessage("Önceki"),
    "profile": MessageLookupByLibrary.simpleMessage("Profil"),
    "profile_governed_by_platform": MessageLookupByLibrary.simpleMessage("LibreDB Platform tarafından yönetiliyor"),
    "profile_mode_platform": MessageLookupByLibrary.simpleMessage("Platform yöneticisi"),
    "profile_mode_studio": MessageLookupByLibrary.simpleMessage("Studio"),
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
    "result_affected_rows": m66,
    "result_card_id": m67,
    "result_copied": MessageLookupByLibrary.simpleMessage("Kopyalandı"),
    "result_copy_failed": m68,
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
    "result_load_more": m69,
    "result_loading_more": m70,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Maskelenmiş değer"),
    "result_more_fields": m71,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "ORDER BY olmadan motor, sayfalar arasında satırları tekrarlayabilir ya da atlayabilir.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "Bu deyim bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı.",
    ),
    "result_row_position": m72,
    "result_row_title": m73,
    "result_stats": m74,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Kartlar"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Tablo"),
    "result_warning_code": m75,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "result_warning_fallback_code": m76,
    "result_warning_line": m77,
    "result_warnings": m78,
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
    "sql_editor_catalog_chip": m79,
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
    "sql_editor_draft_not_saved": m80,
    "sql_editor_draft_read_failed": m81,
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
    "sql_editor_language": m82,
    "sql_editor_language_unknown": m83,
    "sql_editor_redo": MessageLookupByLibrary.simpleMessage("Yinele"),
    "sql_editor_rolled_back": m84,
    "sql_editor_run": MessageLookupByLibrary.simpleMessage("Çalıştır"),
    "sql_editor_run_again": MessageLookupByLibrary.simpleMessage("Yeniden çalıştır"),
    "sql_editor_run_selection": MessageLookupByLibrary.simpleMessage("Seçimi çalıştır"),
    "sql_editor_script_elapsed": m85,
    "sql_editor_script_failed": MessageLookupByLibrary.simpleMessage("Başarısız"),
    "sql_editor_script_failed_time": m86,
    "sql_editor_script_not_run": m87,
    "sql_editor_script_rolled_back": MessageLookupByLibrary.simpleMessage(
      "Betik bir işlemi açık bıraktı ve Studio işlemi geri aldı; değişiklikleri atıldı.",
    ),
    "sql_editor_script_rolled_back_keep": m88,
    "sql_editor_script_show_rows": MessageLookupByLibrary.simpleMessage("Satırları göster"),
    "sql_editor_script_statement": m89,
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
    "sql_history_duration": m90,
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
    "sql_history_rows": m91,
    "sql_history_search_hint": MessageLookupByLibrary.simpleMessage("Deyimlerde ve bağlantılarda ara"),
    "sql_history_succeeded": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "sql_history_title": MessageLookupByLibrary.simpleMessage("Geçmiş"),
    "sql_history_too_long": MessageLookupByLibrary.simpleMessage("Saklanamayacak kadar uzun"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("İfadeyi kopyala"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "Bir yönetici sorunu gidermek için bu ifadeyi çalıştırabilir:",
    ),
    "studio_error_retry_in": m92,
    "studio_error_semantics": m93,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("İfade kopyalandı"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio şu anda bağlantı sunamıyor. Bir yöneticinin yönetişim kurulumunu kontrol etmesi gerekiyor.",
    ),
    "studio_governance_detail": m94,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Bağlantı erişimi geçici olarak kullanılamıyor. Erişim geri geldiğinde liste kendiliğinden güncellenir.",
    ),
    "studio_unreachable_host": m95,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio yanıt vermiyor. İnternet bağlantınızı kontrol edip tekrar deneyin.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Studio\'ya ulaşılamıyor"),
    "success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Gözat"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m96,
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
    "write_confirm_name_label": m97,
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
    "write_confirm_reason_may_write_at": m98,
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
