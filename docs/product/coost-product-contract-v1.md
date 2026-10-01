# COOST Product Contract v1

## 1. Ürünün amacı

COOST, restoran işletmecisinin yalnızca veri girdiği bir ERP değildir.

COOST'un görevi:

veri -> kontrol -> eksik/anomali -> finansal etki -> öncelik -> aksiyon -> takip -> sonuç

zincirini işletmeci adına sürekli çalıştırmaktır.

Ana kullanıcı sorusu:

> Bugün işletmemde ne oluyor ve benim ne yapmam gerekiyor?

Modüller bu sorunun arkasındaki veri ve işlem motorlarıdır.

## 2. Yönetici Masası ürünün merkezidir

COOST'un ana ekranı modül menüsü değil, Yönetici Masasıdır.

Yönetici Masası en az şu sınıfları üretmelidir:

- KRİTİK
- BUGÜN
- BU HAFTA
- İZLE

Her konu mümkün olduğunda şu bilgileri taşımalıdır:

- ne oldu
- neden önemli
- finansal / operasyonel etkisi
- önerilen aksiyon
- son tarih veya takip zamanı
- çözülüp çözülmediği

## 3. Temel restoran veri zinciri

COOST'un ana operasyon zinciri:

Satınalma / Fatura
-> Stok
-> Alış maliyeti
-> Reçete
-> Menü ürünü
-> Satış fiyatı
-> POS satışı
-> Teorik tüketim
-> Fiili stok / sayım
-> Fire / ikram / personel tüketimi
-> Gerçek maliyet
-> Food Cost
-> Katkı payı
-> Ürün kârlılığı
-> İşletme kârlılığı

Bir halkadaki eksik veri sonraki halkalarda sahte kesinlik üretmemelidir.

## 4. Source of truth kuralları

Alış maliyetinin esas kaynağı satınalma ve faturadır.

Satış miktarının esas kaynağı POS / satış uygulamasıdır.

Stok miktarının esas kaynağı stok hareketleri ve sayımdır.

Reçete maliyeti gerçek malzeme maliyetlerinden hesaplanır.

Sistem bilinmeyen maliyet, miktar, yoğunluk, verim veya dönüşüm değerini tahmin ederek source of truth oluşturmaz.

## 5. Eksik veri davranışı

Eksik veri varsa COOST:

1. eksikliği açıkça gösterir
2. hangi hesaplamayı engellediğini gösterir
3. hangi veriyle çözüleceğini söyler
4. önemini / etkilediği alanı gösterir
5. mümkünse kullanıcıyı doğru işlem noktasına yönlendirir

Eksik değer sıfır kabul edilmez.

Bilinmeyen değer sessizce türetilmez.

## 6. Birim ve dönüşüm kuralları

g, ml, adet ve benzeri birimler arasında yalnızca gerçek dönüşüm verisi varsa dönüşüm yapılır.

Örnek:

- yoğunluk
- adet başına ağırlık
- paket içeriği
- porsiyon verimi
- üretim verimi

Bu veriler kalıcı master data olarak saklanmalıdır.

Tahmini yoğunluk veya tahmini adet ağırlığı maliyet hesabında kullanılamaz.

## 7. Alt reçeteler

Alt reçeteler ayrı maliyet düğümleridir.

Alt reçete maliyetinin kullanılabilmesi için gerektiğinde:

- kendi reçete maliyeti
- üretim verimi
- verim birimi
- ana reçetedeki kullanım miktarı
- kullanım birimi

bilinmelidir.

Eksik bilgi varsa ana reçete incomplete kalır.

## 8. Maliyet Hazırlık Merkezi

Maliyet Hazırlık Merkezi bağımsız bir ürün değildir.

Görevi maliyet zincirinin veri kalite ve hazırlık sensörü olmaktır.

Şunları görünür kılar:

- alış maliyeti bulunmayan malzemeler
- bu eksiklerin etkilediği reçete sayısı
- birim dönüşümü bekleyen satırlar
- alt reçete kullanım / verim sorunları
- maliyeti tamamlanan ve tamamlanmayan reçeteler

Önceliklendirme, işletmeye en fazla etki eden eksikten başlamalıdır.

## 9. Menü ve fiyatlandırma

Menü ürünü ancak gerçek reçete maliyetiyle anlamlı şekilde analiz edilir.

Hesaplanacak temel değerler:

- KDV hariç satış
- porsiyon maliyeti
- Food Cost %
- katkı payı
- hedef Food Cost farkı
- hedefe göre satış fiyatı
- daha sonra genel gider sonrası faaliyet marjı

Eksik reçete maliyeti varsa kârlılık değeri üretilmez.

## 10. POS ve teorik tüketim

POS entegrasyonunun amacı yalnız satış raporlamak değildir.

Satılan ürün:

POS satışı
-> menü ürünü
-> reçete
-> teorik malzeme tüketimi

zincirine bağlanmalıdır.

Böylece teorik tüketim ile fiili stok hareketleri karşılaştırılabilir.

## 11. Gerçek maliyet ve kayıp kontrolü

Gerçek maliyet analizi için en az şu hareketler ayrıştırılmalıdır:

- normal satış tüketimi
- fire
- ikram
- personel tüketimi
- stok düzeltme
- sayım farkı

Sistem teorik ve fiili tüketim farkını görünür hale getirmelidir.

## 12. AI Asistanın rolü

AI source of truth değildir.

AI:

- deterministik hesapların sonuçlarını açıklar
- önemli değişiklikleri özetler
- eksikleri önceliklendirir
- olası nedenleri kullanıcıya sunar
- aksiyon planı oluşturur
- takip edilmesi gereken işleri hatırlatır

AI:

- muhasebe bakiyesi üretmez
- stok miktarı uydurmaz
- maliyet uydurmaz
- yoğunluk veya dönüşüm uydurmaz
- transaction mantığının yerine geçmez

## 13. Deterministik motorlar

Aşağıdaki işler veritabanı / domain motorları tarafından yapılmalıdır:

- finans hesapları
- stok hesapları
- satınalma etkileri
- reçete maliyeti
- menü maliyeti
- POS eşleştirmesi
- teorik tüketim
- kârlılık hesapları
- invariant kontrolleri

AI bu hesapların üzerinde çalışır.

## 14. SaaS ve tenant modeli

COOST çok işletmeli SaaS'tır.

Her işletme tenant'tır.

Galata Alacarte COOST'un kendisi değil, COOST içindeki bir tenant'tır.

Tenant izolasyonu:

- RLS
- membership
- permissions
- module enablement
- tenant-safe foreign keys

ile korunur.

## 15. Co-Asist sınırı

Co-Asist mevcut ve ayrı uygulamadır.

COOST geliştirilirken:

- Co-Asist reposu değiştirilmez
- Co-Asist veritabanı kullanılmaz
- Co-Asist production ortamına migration uygulanmaz
- COOST staging ile production ortamları karıştırılmaz

## 16. Kritik işlemler

Finans, stok, satınalma, çek, ödeme ve benzeri kritik işlemlerde frontend tarafından bağımsız çoklu tablo yazımı yapılmaz.

Kritik domain değişiklikleri kontrollü RPC / command / transaction sınırında gerçekleşir.

Kısmi başarı kabul edilmez.

## 17. Güvenlik

Temel ilkeler:

- default deny
- RLS
- aktif membership
- permission kontrolü
- module enablement
- cross-tenant invariant
- append-only audit
- service_role browser'a verilmez
- secrets Git'e girmez

## 18. Geliştirme ve promotion kuralı

Yeni scope:

feature branch
-> local verify
-> gerekiyorsa staging target kontrolü
-> migration dry-run
-> COOST-STAGING
-> staging testleri
-> diff kontrolü
-> commit
-> push
-> PR
-> merge
-> main senkronu

Production schema deneyi yapılmaz.

## 19. Feature kabul testi

Her yeni geliştirme başlamadan önce şu soru cevaplanmalıdır:

> Bu özellik veri -> karar -> aksiyon zincirinde hangi problemi çözüyor?

Net cevap yoksa özellik geliştirilmez veya yeniden tasarlanır.

Ayrıca şu dört soru kontrol edilir:

1. Source of truth nedir?
2. Eksik veri halinde sistem ne yapar?
3. Bu sonuç işletmeci için hangi kararı veya aksiyonu üretir?
4. Tenant güvenliği ve transaction sınırı doğru mu?

## 20. Ürün yönü

Öncelik sırası:

1. güvenilir temel veri
2. domain invariantları
3. otomatik hesap motorları
4. veri kalite / eksik veri motoru
5. restoran operasyon zincirlerinin birbirine bağlanması
6. Yönetici Masası
7. aksiyon / takip motoru
8. AI Asistan
9. ileri tahmin ve optimizasyon

COOST'un başarısı ekran veya modül sayısıyla değil, işletmecinin daha az manuel kontrol yaparak daha doğru ve zamanında karar almasıyla ölçülür.
