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

  static String m0(url) => "${url} açılamadı";

  static String m1(currentVersion, minimumVersion) => "Mevcut: ${currentVersion}  •  Gerekli: ${minimumVersion}";

  static String m2(time) => "Tahmini bitiş: ${time}";

  static String m3(email) => "OTP kodu ${email} adresine gönderildi";

  static String m4(max) => "Şifre en fazla ${max} karakter uzunluğunda olmalıdır";

  static String m5(min) => "Şifre en az ${min} karakter uzunluğunda olmalıdır";

  static String m6(count) => "${Intl.plural(count, other: '${count} satır listelendi.')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account": MessageLookupByLibrary.simpleMessage("Hesabım"),
    "active": MessageLookupByLibrary.simpleMessage("Aktif"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Uygula"),
    "authorities": MessageLookupByLibrary.simpleMessage("Roller"),
    "back": MessageLookupByLibrary.simpleMessage("Geri"),
    "cancel": MessageLookupByLibrary.simpleMessage("İptal"),
    "change_password": MessageLookupByLibrary.simpleMessage("Şifre Değiştir"),
    "change_password_description": MessageLookupByLibrary.simpleMessage(
      "Hesabınızın güvende kalması için uzun ve rastgele bir şifre kullandığınızdan emin olun.",
    ),
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
    "connection_environment": MessageLookupByLibrary.simpleMessage("Ortam"),
    "connection_list_empty": MessageLookupByLibrary.simpleMessage("Studio size henüz bir bağlantı sunmuyor"),
    "connection_list_load_failed": MessageLookupByLibrary.simpleMessage("Bağlantılar yüklenemedi"),
    "connection_list_subtitle": MessageLookupByLibrary.simpleMessage("Studio\'nun size sunduğu veritabanları"),
    "connection_name": MessageLookupByLibrary.simpleMessage("Ad"),
    "connection_target": MessageLookupByLibrary.simpleMessage("Hedef"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Motor"),
    "connections": MessageLookupByLibrary.simpleMessage("Bağlantılar"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("İnternet bağlantısı yok"),
    "current_password": MessageLookupByLibrary.simpleMessage("Mevcut Şifre"),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Silmek istediğinize emin misiniz?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Dokümantasyon"),
    "edit": MessageLookupByLibrary.simpleMessage("Düzenle"),
    "email": MessageLookupByLibrary.simpleMessage("E-posta"),
    "email_pattern": MessageLookupByLibrary.simpleMessage("E-posta adresi geçerli değil"),
    "email_send": MessageLookupByLibrary.simpleMessage("E-posta Gönder"),
    "english": MessageLookupByLibrary.simpleMessage("İngilizce"),
    "error_account_password_required": MessageLookupByLibrary.simpleMessage("Mevcut ve yeni şifre alanları zorunludur"),
    "error_account_passwords_same": MessageLookupByLibrary.simpleMessage("Yeni şifre mevcut şifreden farklı olmalıdır"),
    "error_auth_invalid_access_token": MessageLookupByLibrary.simpleMessage("Geçersiz erişim belirteci"),
    "error_auth_login_failed": MessageLookupByLibrary.simpleMessage("Giriş başarısız"),
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
    "error_auth_oidc_no_role": MessageLookupByLibrary.simpleMessage(
      "Hesabınızın bu uygulamaya erişim veren bir rolü yok. Yöneticinize başvurun.",
    ),
    "error_auth_otp_validation": MessageLookupByLibrary.simpleMessage("OTP doğrulaması başarısız"),
    "error_auth_send_otp_failed": MessageLookupByLibrary.simpleMessage("OTP kodu gönderilemedi"),
    "error_auth_session_persist_failed": MessageLookupByLibrary.simpleMessage("Oturum kaydedilemedi"),
    "error_generic": MessageLookupByLibrary.simpleMessage("Bir şeyler ters gitti"),
    "error_link_open_failed": m0,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "Bağlantının güvenli olduğu doğrulanamadığı için engellendi. Daha sonra ya da başka bir ağda tekrar deneyin.",
    ),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Dil değiştirilemedi"),
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
    "first_name": MessageLookupByLibrary.simpleMessage("İsim"),
    "forbidden_back_home": MessageLookupByLibrary.simpleMessage("Ana sayfaya dön"),
    "forbidden_message": MessageLookupByLibrary.simpleMessage("Bu sayfayı görüntüleme yetkiniz yok."),
    "forbidden_title": MessageLookupByLibrary.simpleMessage("Erişim engellendi"),
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
    "force_update_versions": m1,
    "forgot_password_description": MessageLookupByLibrary.simpleMessage(
      "E-posta adresinizi girin, şifrenizi sıfırlamanız için size bir bağlantı gönderelim.",
    ),
    "help_resources": MessageLookupByLibrary.simpleMessage("Yardım ve Kaynaklar"),
    "help_resources_subtitle": MessageLookupByLibrary.simpleMessage("GitHub\'daki dokümantasyonu ve rehberleri okuyun"),
    "home": MessageLookupByLibrary.simpleMessage("Ana Sayfa"),
    "idle_timeout_signed_out": MessageLookupByLibrary.simpleMessage("Hareketsizlik nedeniyle oturumunuz kapatıldı."),
    "inactive": MessageLookupByLibrary.simpleMessage("Pasif"),
    "invalid_email": MessageLookupByLibrary.simpleMessage("Geçersiz e-posta adresi"),
    "language": MessageLookupByLibrary.simpleMessage("Dil"),
    "language_select": MessageLookupByLibrary.simpleMessage("Dil Seçimi"),
    "last_name": MessageLookupByLibrary.simpleMessage("Soyisim"),
    "list": MessageLookupByLibrary.simpleMessage("Listele"),
    "loading": MessageLookupByLibrary.simpleMessage("Yükleniyor..."),
    "login": MessageLookupByLibrary.simpleMessage("Kullanıcı Adı"),
    "login_brand_description": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio\'nun size açtığı veritabanlarına telefonunuzdan ulaşın.",
    ),
    "login_brand_headline": MessageLookupByLibrary.simpleMessage("Veritabanlarınız\ncebinizde."),
    "login_button": MessageLookupByLibrary.simpleMessage("Giriş Yap"),
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
    "login_no_account": MessageLookupByLibrary.simpleMessage("Hesabınız yok mu? "),
    "login_or": MessageLookupByLibrary.simpleMessage("veya"),
    "login_otp_email_instructions": MessageLookupByLibrary.simpleMessage(
      "OTP kodunu almak için e-posta adresinizi girin",
    ),
    "login_password": MessageLookupByLibrary.simpleMessage("Şifre"),
    "login_sso_button": MessageLookupByLibrary.simpleMessage("SSO ile giriş yap"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Kurumsal hesabınızla giriş yapın."),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Koyu temaya geç"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Açık temaya geç"),
    "login_user_name": MessageLookupByLibrary.simpleMessage("Kullanıcı adı"),
    "login_welcome_subtitle": MessageLookupByLibrary.simpleMessage("Hesabınıza erişmek için bilgilerinizi girin"),
    "login_welcome_title": MessageLookupByLibrary.simpleMessage("Tekrar hoş geldiniz"),
    "login_with_email": MessageLookupByLibrary.simpleMessage("E-posta ile Giriş"),
    "logout": MessageLookupByLibrary.simpleMessage("Çıkış Yap"),
    "logout_stored_data_left": MessageLookupByLibrary.simpleMessage(
      "Oturumunuz kapatıldı, ancak kayıtlı verilerin bir kısmı bu cihazdan silinemedi.",
    ),
    "logout_sure": MessageLookupByLibrary.simpleMessage("Çıkış yapmak istediğinize emin misiniz?"),
    "maintenance_estimated_end": m2,
    "maintenance_message": MessageLookupByLibrary.simpleMessage(
      "Planlı bir bakım çalışması yapıyoruz. Lütfen kısa bir süre sonra tekrar deneyin.",
    ),
    "maintenance_retry": MessageLookupByLibrary.simpleMessage("Tekrar Dene"),
    "maintenance_title": MessageLookupByLibrary.simpleMessage("Bakım Yapılıyor"),
    "max_length_100": MessageLookupByLibrary.simpleMessage("Maksimum 100 karakter uzunluğunda olmalıdır"),
    "max_length_20": MessageLookupByLibrary.simpleMessage("Maksimum 20 karakter uzunluğunda olmalıdır"),
    "min_length_2": MessageLookupByLibrary.simpleMessage("Minimum 2 karakter uzunluğunda olmalıdır"),
    "min_length_4": MessageLookupByLibrary.simpleMessage("Minimum 4 karakter uzunluğunda olmalıdır"),
    "name": MessageLookupByLibrary.simpleMessage("İsim"),
    "new_item": MessageLookupByLibrary.simpleMessage("Yeni"),
    "new_password": MessageLookupByLibrary.simpleMessage("Yeni Şifre"),
    "next": MessageLookupByLibrary.simpleMessage("Sonraki"),
    "no": MessageLookupByLibrary.simpleMessage("Hayır"),
    "no_changes_made": MessageLookupByLibrary.simpleMessage("Değişiklik yapılmadı"),
    "no_data": MessageLookupByLibrary.simpleMessage("Veri Yok"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("İstediğiniz sayfa bulunamadı."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Sayfa Bulunamadı"),
    "only_numbers": MessageLookupByLibrary.simpleMessage("Sadece sayılar kullanılabilir"),
    "otp_code": MessageLookupByLibrary.simpleMessage("OTP Kodu"),
    "otp_length": MessageLookupByLibrary.simpleMessage("OTP 6 haneli olmalıdır"),
    "otp_sent_to_email": m3,
    "password_forgot": MessageLookupByLibrary.simpleMessage("Şifremi unuttum"),
    "password_hide": MessageLookupByLibrary.simpleMessage("Şifreyi gizle"),
    "password_max_length": m4,
    "password_min_length": m5,
    "password_show": MessageLookupByLibrary.simpleMessage("Şifreyi göster"),
    "previous": MessageLookupByLibrary.simpleMessage("Önceki"),
    "refresh": MessageLookupByLibrary.simpleMessage("Yenile"),
    "register": MessageLookupByLibrary.simpleMessage("Kayıt Ol"),
    "register_subtitle": MessageLookupByLibrary.simpleMessage("Hesabınızı oluşturun"),
    "required_field": MessageLookupByLibrary.simpleMessage("Zorunlu Alan"),
    "resend_otp_code": MessageLookupByLibrary.simpleMessage("OTP Kodu Tekrar Gönder"),
    "retry": MessageLookupByLibrary.simpleMessage("Tekrar Dene"),
    "role": MessageLookupByLibrary.simpleMessage("Rol"),
    "save": MessageLookupByLibrary.simpleMessage("Kaydet"),
    "send_otp_code": MessageLookupByLibrary.simpleMessage("OTP Kodu Gönder"),
    "settings": MessageLookupByLibrary.simpleMessage("Ayarlar"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Görünüm"),
    "settings_change_password_subtitle": MessageLookupByLibrary.simpleMessage("Şifrenizi güvenle güncelleyin"),
    "settings_licenses": MessageLookupByLibrary.simpleMessage("Lisanslar"),
    "settings_licenses_subtitle": MessageLookupByLibrary.simpleMessage(
      "LibreDB Mobile\'ın ve içerdiği kodun lisansları",
    ),
    "settings_subtitle": MessageLookupByLibrary.simpleMessage("Hesap tercihlerinizi yönetin"),
    "settings_theme_subtitle": MessageLookupByLibrary.simpleMessage("Tercih ettiğiniz tema stilini seçin"),
    "submit": MessageLookupByLibrary.simpleMessage("Gönder"),
    "success": MessageLookupByLibrary.simpleMessage("Başarılı"),
    "table_rows_listed": m6,
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
    "verify_otp_code": MessageLookupByLibrary.simpleMessage("OTP Kodu Doğrula"),
    "warning": MessageLookupByLibrary.simpleMessage("Uyarı"),
    "yes": MessageLookupByLibrary.simpleMessage("Evet"),
  };
}
