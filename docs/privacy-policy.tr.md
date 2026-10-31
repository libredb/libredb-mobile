# LibreDB Mobile gizlilik politikası

Son güncelleme: 29 Ekim 2026.

Bu politika, LibreDB Mobile'ın Android ve iOS üzerinde verilerinizle ne yaptığını anlatır.
İki platformun davranışı ayrıldığı yerde bu sayfa bunu söyler; birini anlatıp ötekini sessiz geçmez.
LibreDB Mobile, LibreDB Studio'nun bir istemcisidir: Keycloak üzerinden oturumunuzu açar ve Studio'nun size sunduğu veritabanlarını gösterir.
Bu politikayla ilgili sorularınızı [info@libredb.org](mailto:info@libredb.org) adresine yazabilirsiniz.

## Uygulamayı kim yayınlıyor

LibreDB Mobile'ı Google Play ve App Store'da **Sekoya Tech** yayınlar; bu, Türkiye'de kayıtlı **Sekoya Grup Bilişim ve Teknoloji Ltd. Şti.**'nin ticari adıdır ve burada anlatılan işleme faaliyetinin veri sorumlusudur.

| | |
| --- | --- |
| Ticaret unvanı | Sekoya Grup Bilişim ve Teknoloji Ltd. Şti. |
| Ticari ad | Sekoya Tech |
| Kayıtlı adres | İnkılap Mah. Haşim İşcan Sok. Kent Sitesi F Blok No: 4/33, 34768 Ümraniye / İstanbul |
| Vergi kimlik no (VKN) | 7591146987 |
| MERSİS No | 0759114698700001 |
| Ticaret sicil no | 1015843 |

Şirketin tüm bilgileri [sekoya.tech](https://sekoya.tech) adresinde yayınlanmıştır.

Bu politika uygulamayı kapsar. Web sitesinin politikası ayrıdır: [libredb.org/privacy-policy](https://libredb.org/privacy-policy).

## Uygulamanın konuştuğu sunucular

Uygulama dört tür sunucuyla konuşur, kendiliğinden başka hiçbir sunucuyla konuşmaz:

- **Keycloak**, uygulamanın derlenirken bağlandığı LibreDB kurulumunun oturum açma sunucusu.
  Oturumu Keycloak'un kendi sayfasında, cihazın tarayıcısında açarsınız; bu yüzden uygulama parolanızı hiç görmez.
  Keycloak uygulamaya sizi tanıtan belirteçler verir.
- Aynı kurulumun **LibreDB Studio**'su.
  Uygulama isteklerinde Studio'ya Keycloak erişim belirtecinizi gönderir; böylece Studio kim olduğunuzu ve neyi kullanabileceğinizi bilir.
  Erişim belirteci, Keycloak'un içine koyduklarını taşır: örneğin kullanıcı adınızı, e-posta adresinizi ve adınızı.
  Uygulama Studio'ya ondan istediklerinizi de gönderir: açtığınız bağlantıyı, baktığınız nesneleri ve çalıştırdığınız deyimleri.
- Aynı kurulumun **LibreDB Platform**'u; ancak yalnızca Platform modunu içeren bir sürümde.
  Böyle bir sürümde uygulama, oturum açma sayfasında Platform girişini seçtikten ya da profilde Platform'a geçtikten sonra Platform'la konuşur; ayrıca Studio'dayken, sizde olmayan bir bağlantı için erişim istediğinizde de konuşur.
  Uygulama isteklerinde Platform'a Keycloak erişim belirtecinizi gönderir ve Platform kimliğinizi alır: Platform kullanıcı kimliğinizi, e-posta adresinizi, adınızı ve kuruluşunuzu.
  Uygulama bu kimliği oturumunuz açıkken bellekte tutar ve cihazda hiç saklamaz.
  Platform'un hesabınıza ilk yanıtı, Platform kullanıcı kaydınızı oluşturur ve lisansın yönetici koltuklarından birini kullanır.
  Bu, Platform'a giriş yaptığınızda olur; Studio'dan erişim istemek Platform kullanıcı kaydı oluşturmaz ve koltuk kullanmaz.
  Platform modunda uygulama bir bağlantıya kimlerin erişimi olduğunu gösterir: kullanıcı adlarını ve e-posta adreslerini, ayrıca erişimi veren yöneticinin adını ya da e-posta adresini.
  Bunları sayfa açıkken bellekte tutar ve cihazda hiç saklamaz; Platform'a da kaldırmak istediğiniz erişimleri gönderir.
  Birine erişim vermek için dizinde arama yaptığınızda arama metni Platform'a gider, Platform da Keycloak'ta arar; uygulama bulunan kullanıcıların kullanıcı adlarını, adlarını, e-posta adreslerini, etkin olup olmadıklarını ve Studio rollerini gösterir.
  Bunları yalnızca ekran açıkken bellekte tutar, arama geçmişi tutmaz ve hiçbirini saklamaz; Platform'a da verdiğiniz ya da değiştirdiğiniz erişimi gönderir: kullanıcıyı, düzeyi ve bitiş zamanını.
  Platform modunda uygulama Platform'a istediğiniz bir bağlantının etkinleştirilmesini ya da devre dışı bırakılmasını da gönderir; o bağlantı hakkında başka bir şey göndermez.
  Platform modunda uygulama yönetilen sorguların denetim kaydını gösterir: onları çalıştıran kullanıcıları (kullanıcı adlarını ve Keycloak kimliklerini), bağlantıları, veritabanlarından veri taşıyabilen deyim metnini, veritabanı hata mesajlarını ve zamanları.
  Bunları denetim sayfası açıkken bellekte tutar ve cihazda hiç saklamaz; Platform'a da belirlediğiniz filtreleri, deyim arama metni dahil, gönderir.
  Bir bağlantı için erişim istediğinizde uygulama Platform'a bağlantıyı, seçtiğiniz erişim düzeyini ve yazdığınız gerekçeyi, kullanıcı adınızı ve e-posta adresinizi taşıyan Keycloak erişim belirtecinizle birlikte gönderir; Platform yöneticileri isteği kullanıcı adınız ve e-posta adresinizle görür.
  Uygulama isteklerinizi ve onlara ne olduğunu sayfa açıkken bellekte tutar, cihazda hiç saklamaz.
  Platform modunda uygulama yöneticilere her isteğin kullanıcı adını, e-posta adresini ve gerekçesini gösterir; yöneticinin verdiği kararı da Platform'a gönderir: onaylamada düzeyi ve bitiş zamanını, reddetmede gerekçeyi.
- **Sentry**, bir çökme raporlama hizmeti; ancak yalnızca uygulama bir Sentry proje anahtarıyla derlendiyse.
  Ayrıntılar aşağıdaki Çökme raporları bölümünde.

Keycloak'u, Studio'yu ve Platform'u kurulumu işleten kuruluş çalıştırır ve bu sunucuların neyi kaydedeceğine o kuruluş karar verir.
Örneğin Studio, oturum açma ve kapatmaların bir denetim kaydını ve ayarlarına göre çalıştırdığınız deyimlerin bir kaydını tutabilir.
Bu sunucuların tuttuklarına o kuruluşun kendi gizlilik koşulları uygulanır.

Uygulama Keycloak'a, Studio'ya, Platform'a ve Sentry'ye trafiği şifreleyen HTTPS üzerinden ulaşır.

## Uygulamanın yapmadıkları

- Uygulama hiçbir veritabanı parolası ya da başka bir veritabanı kimlik bilgisi tutmaz: bunları Studio saklar ve her veritabanı bağlantısını Studio açar.
- Uygulama reklam göstermez, hiçbir reklam, üçüncü taraf analiz ya da izleme SDK'sı içermez ve uygulamayı nasıl kullandığınıza dair aşağıdaki Çökme raporları bölümünde anlatılan çökme raporları, oturum kayıtları ve süre bilgisinin ötesinde hiçbir şey göndermez.
- Uygulama kişilerinizi, konumunuzu, fotoğraflarınızı, dosyalarınızı ya da başka uygulamaların verilerini okumaz.
- Uygulama verilerinizi satmaz ve reklam amacıyla kimseyle paylaşmaz.

## Uygulamanın cihazda tuttukları

- **Oturum belirteçleriniz**, cihazın güvenli depolamasında: Android'de Android Keystore'un tuttuğu bir anahtarla şifrelenmiş olarak, iOS'ta Keychain'de, yalnızca cihazın ilk kilit açımından sonra okunabilecek ve bu cihazdan hiç çıkmayacak biçimde işaretlenmiş olarak.
  Oturumu kapatmak onları siler.
- **Taslaklarınız ve deyim geçmişiniz**: düzenleyicinin her bağlantı için taslağı ve çalıştırdığınız deyimler, cihazda yalnızca hesabınıza ait bir anahtarla şifrelenmiş olarak.
  Oturumu kapattıktan sonra da kalırlar; böylece aynı hesapla yeniden oturum açtığınızda onları bulursunuz ve cihazdaki başka bir hesap onları okuyamaz.
- **Bağlantı seçimleriniz**: yıldızladığınız ya da son açtığınız bağlantılar, en son açık olan bağlantı ve onda en son kullandığınız veritabanı, bağlantı listesinde daralttığınız bölümler.
- **Cihaz tercihleri**: dil, tema ve sonuçların kart mı tablo mu gösterileceği.

Uygulama kapandıktan sonra sorgu sonuçlarının hiçbir satırını tutmaz.
Uygulama çalışırken bir bağlantının nesnelerinin listelerini, sayılarını ve tanımlarını, geri dönüldüğünde Studio'ya yeniden sorulmasın diye en çok 10 dakika bellekte tutar.
Nesne aramasına yazdıklarınız yalnızca Studio'ya gider ve uygulama arama geçmişi tutmaz.
Android'de uygulamanın bulut yedeklemesi kapalıdır; tercihleri, taslakları ve geçmişi cihazdan cihaza aktarımların dışında bırakılır.
iOS'ta uygulama varsayılanı korur; bu yüzden bir yedek, taslaklarınızı ve geçmişinizi tutan dosyaları taşıyabilir, ama onları açan anahtarı asla taşımaz: o anahtar Keychain'dedir ve cihazdan çıkmaz.
Başka bir cihaza geri yüklendiğinde o dosyalar ne sizin ne de bir başkasının okuyabileceği hâldedir.

## Paylaşma ve kopyalama

Uygulama veriyi başka bir uygulamaya yalnızca siz istediğinizde verir.
Bir sonucun bir değerini kopyaladığınızda uygulama ekranda görüneni kopyalar; maskelenmiş bir değer maskesiyle kopyalanır.
Bir nesnenin kaynağını, örneğin bir görünümün tanımını paylaştığınızda sistemin paylaşım penceresi onu seçtiğiniz uygulamaya gönderir.
100.000 karakterden uzun bir kaynak dosya olarak paylaşılır ve bu dosya, sistem temizleyene ya da uygulamayı kaldırana kadar uygulamanın geçici depolamasında kalabilir.

## Çökme raporları

Bir Sentry proje anahtarıyla derlenmiş uygulama, bir hatayla karşılaştığında Sentry'ye bir rapor gönderir.
Bir rapor şunları içerir: hatayı ve uygulamanın neresinde olduğunu, uygulamanın sürümünü, cihazın modeli, işletim sistemi sürümü, dili, boş belleği ve pil düzeyi gibi teknik ayrıntılarını, kuruluma ait rastgele bir tanımlayıcıyı ve hatadan önceki olayların bir izini, örneğin açtığınız ekranları ve uygulamanın arka plana geçişini.
Bir Sentry proje anahtarıyla derlenmiş uygulama ayrıca uygulamayı her kullanışınızda bir oturum kaydı gönderir: oturumun ne zaman başlayıp bittiği, ne kadar sürdüğü, bir çökmeyle bitip bitmediği ve kurulum tanımlayıcısı.
Ayrıca, uygulamanın nerede yavaş olduğunu göstermek için uygulama açılışlarının ve ekran değişikliklerinin yaklaşık beşte biri için süre bilgisi gönderir.
Bir rapor cihazdan çıkmadan önce uygulama içinden e-posta adreslerini, belirteçleri, parolaları ve diğer kimlik bilgilerini çıkarır.
Bir rapor ekran görüntüsü, ekran düzeni, istek gövdesi ya da oturumun ekran kaydını (görüntü kaydı) taşımaz.
Sentry, her sunucu bağlantısında olduğu gibi, her raporla birlikte cihazınızın IP adresini alır.
Sentry projesi IP adreslerini saklamayacak şekilde ayarlanmadıkça Sentry bu adresten şehir ve ülke gibi yaklaşık bir konum çıkarır.
Sentry proje anahtarı olmadan derlenmiş bir uygulama rapor göndermez.

## Cihazdaki korumalar

- Sorgu sonuçlarını, bir satırın ayrıntısını, bir anahtarın değerini, bir nesnenin kaynağını, denetim kaydı listesini ya da bir denetim olayının deyimini ve hata mesajını gösteren ekranlar ekran görüntülerinin, ekran kayıtlarının ve son uygulamalar görünümünün dışında tutulur.
- Adı hassas görünen sütunlar, örneğin e-posta, parola ya da kart numarası, ekranda maskelenir.
- Uygulama 15 dakika işlem yapılmadığında oturumunuzu kapatır.

## Verilerinizi silmek

- Ayarlar'ın Gizlilik bölümündeki **Verilerimi sil**, uygulamanın oturum açmış hesap için tuttuklarını (taslakları, geçmişi ve bağlantı seçimlerini) siler, ardından oturumunuzu kapatır.
  Cihaza ait olan dili, temayı ve sonuç görünümü tercihini korur.
- **Uygulamayı kaldırmak** cihazda tuttuğu her şeyi siler.
- Gönderilmiş çökme raporları süreleri dolana kadar Sentry'de kalır; daha önce silinmeleri için [info@libredb.org](mailto:info@libredb.org) adresine yazın.
- Keycloak'un ya da Studio'nun sizinle ilgili tuttuğu verileri onları işleten kuruluş tutar; silinmeleri için o kuruluşa başvurun.

## Çocuklar

Uygulama veritabanlarıyla çalışan kişiler için bir araçtır ve çocuklara yönelik değildir.

## Bu politikadaki değişiklikler

Uygulama veriyi yeni bir şekilde işlemeye başladığında bu politika o sürüm yayımlanmadan önce güncellenir ve en üstteki tarih değişir.
