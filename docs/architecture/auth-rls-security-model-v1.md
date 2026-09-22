# COOST Auth and RLS Security Model v1

## Amac

COOST cok isletmeli SaaS yapisinda kullanici kimligi, tenant erisimi ve yetkilendirmeyi birbirinden ayirir.

Temel ilke:

Authentication != Tenant Access != Authorization

Bir kullanicinin COOST'a giris yapabilmesi, herhangi bir tenant verisine erisebilecegi anlamina gelmez.

## 1. Authentication

Kimlik dogrulama Supabase Auth tarafindan yonetilir.

Kaynak:

auth.users

Uygulama tarafinda auth kullanicisinin temel profil bilgileri ayri `profiles` tablosunda tutulacaktir.

`profiles.id`, `auth.users.id` ile bire bir eslesecektir.

## 2. Tenant membership

Bir kullanicinin bir isletmeye erisimi yalnizca `memberships` tablosundaki aktif kayit ile belirlenir.

Gecerli erisim kosulu:

- membership.tenant_id hedef tenant ile ayni olmali
- membership.user_id auth.uid() ile ayni olmali
- membership.status = ACTIVE olmali

Frontend tarafindan gonderilen tenant_id tek basina guvenilir kabul edilmez.

## 3. Active tenant

Kullanicinin secili tenant'i UI state olarak tutulabilir.

Ancak bu secim bir guvenlik kaynagi degildir.

Her veritabani islemi RLS tarafindan yeniden dogrulanir.

## 4. Permissions

Yetki zinciri:

auth.users
-> memberships
-> membership_roles
-> roles
-> role_permissions

Bir islemin izinli olmasi icin:

1. kullanicinin aktif membership kaydi bulunmali
2. membership uygun role sahip olmali
3. role gerekli permission_key degerine sahip olmali

Frontend'deki buton gizleme yalnizca UX amaclidir.

Gercek yetki kontrolu veritabaninda yapilir.

## 5. Tenant modules

Bir permission bulunmasi tek basina modulu kullanmaya yeterli degildir.

Ilgili modul:

tenant_modules.enabled = true

olmalidir.

Boylece bir kullanici teknik olarak yetkiye sahip olsa bile tenant'a kapali bir modulu kullanamaz.

## 6. Security helper functions

RLS policy'lerinde tekrar eden karmasik sorgular yerine kontrollu helper fonksiyonlari kullanilacaktir.

Planlanan fonksiyonlar:

- private.is_tenant_member(uuid)
- private.has_permission(uuid, text)
- private.is_module_enabled(uuid, text)

Bu fonksiyonlar:

- SECURITY DEFINER olarak dikkatle tanimlanacak
- search_path sabitlenecek
- tablo isimleri schema ile tam yazilacak
- RLS recursion olusturmayacak
- sadece boolean sonuc dondurecek

## 7. profiles

Kullanici kendi profilini okuyabilir ve izin verilen alanlarini guncelleyebilir.

Profil tablosunda:

- sifre tutulmaz
- auth token tutulmaz
- hassas Supabase credential tutulmaz

Kimlik dogrulamaya ait gizli bilgiler yalnizca Supabase Auth tarafinda kalir.

## 8. tenants

Bir kullanici sadece aktif membership sahibi oldugu tenant kayitlarini okuyabilir.

Tenant ayarlarini degistirmek icin ayrica:

tenant.settings.manage

yetkisi gerekir.

## 9. locations

Bir tenant uyesi kendi tenant'ina ait izin verilen location kayitlarini okuyabilir.

Farkli tenant'a ait location verisi hicbir sekilde okunamaz veya baglanamaz.

Composite foreign key kurallari RLS'ye ek guvenlik katmani saglar.

## 10. memberships

Normal kullanici kendi membership kaydini okuyabilir.

Diger kullanicilarin membership kayitlarini yonetmek icin:

tenant.users.manage

yetkisi gerekir.

Membership tenant'i sonradan degistirilemez.

Tenant degisikligi yeni membership olusturularak yapilir.

## 11. Invitations

Henuz Supabase Auth hesabi olmayan kisiler icin membership kaydi olusturulmaz.

Davetler ayri:

membership_invitations

tablosunda tutulacaktir.

Davet kabul edilip kullanici kimligi kesinlestikten sonra ACTIVE membership olusturulur.

Bu nedenle nihai semada `memberships.status` icinden `INVITED` durumu kaldirilacaktir.

## 12. Roles and permissions

Role tenant kapsamindadir.

Bir tenant'in rolu baska tenant membership'ine baglanamaz.

Role permission degisiklikleri sadece yetkili kullanici veya kontrollu backend command tarafindan yapilir.

## 13. Audit logs

Audit kayitlari append-only olacaktir.

Normal client:

- audit kaydini update edemez
- audit kaydini delete edemez

Kritik command islemleri audit kaydini ayni transaction icinde olusturmalidir.

Audit gecmisi sonradan sessizce degistirilemez.

## 14. Outbox events

`outbox_events` normal frontend CRUD tablosu degildir.

Browser client dogrudan:

- insert
- update
- delete

yapamaz.

Outbox kayitlari domain command transaction'i tarafindan uretilir ve guvenilir worker/backend tarafindan islenir.

## 15. Direct table writes

Finans, stok, cek, satin alma ve benzeri kritik domainlerde frontend'in birden fazla tabloya bagimsiz write yapmasi yasaktir.

Kritik islemler tek bir command / transaction siniri icinde calisir.

Ornek:

Tedarikci odemesi

tek transaction icinde:

- odeme kaydi
- kasa/banka hareketi
- tedarikci bakiye etkisi
- audit log
- outbox event

uretebilir.

Kismi basari kabul edilmez.

## 16. Service role

Supabase service_role key:

- browser'a konmaz
- Vite environment icine PUBLIC olarak konmaz
- Git'e girmez
- musteri cihazina gitmez

Sadece kontrollu server/worker ortaminda kullanilir.

## 17. RLS default rule

Tenant kapsamindaki her operasyonel tabloda varsayilan guvenlik davranisi:

DENY

olacaktir.

Acikca policy tanimlanmayan islem calismaz.

## 18. Cross-tenant testing

RLS tamamlandiginda otomatik testler en az su senaryolari kanitlamalidir:

- Tenant A kullanicisi Tenant A verisini gorebilir.
- Tenant A kullanicisi Tenant B verisini goremez.
- Tenant A kullanicisi Tenant B verisi yazamaz.
- Yetkisiz kullanici ayni tenant icinde korumali islemi yapamaz.
- Pasif membership erisim saglamaz.
- Kapali modul kullanilamaz.
- Service islemleri kontrollu olarak calisir.
- Audit kaydi normal client tarafindan degistirilemez.

## Sonraki teknik adim

Bu model onaylandiktan sonra:

1. memberships status modeli duzeltilecek
2. profiles semasi eklenecek
3. membership_invitations semasi eklenecek
4. private security helper fonksiyonlari yazilacak
5. RLS enable edilecek
6. tablo bazli policy'ler eklenecek
7. cross-tenant entegrasyon testleri kurulacak

Bu islemler tek buyuk migration yerine kucuk ve geri alinabilir migration'lar halinde yapilacaktir.