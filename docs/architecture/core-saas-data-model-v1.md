# COOST Core SaaS Data Model v1.1

## Amac

COOST'un cok isletmeli SaaS mimarisinin cekirdek veri modelidir.

Bu asamada veritabanina uygulanmayacaktir. Once iliskiler, tenant izolasyonu ve yetki modeli dogrulanacaktir.

## Temel kurallar

1. Her isletme bir `tenant` olarak temsil edilir.
2. Bir tenant bir veya daha fazla `location` icerebilir.
3. Kullanici ile isletme iliskisi `membership` uzerinden kurulur.
4. Roller kullaniciya dogrudan degil, membership'e atanir.
5. Roller ve izinler iliskisel tablolarda tutulur.
6. Aktif moduller `tenant_modules` ile tenant bazinda yonetilir.
7. Kritik islemler `audit_logs` ile izlenebilir olmalidir.
8. Domain olaylari `outbox_events` uzerinden guvenli bicimde yayinlanmalidir.
9. Is verileri JSON listeleri icinde source-of-truth olarak tutulmamalidir.
10. Tenant kapsamindaki operasyonel tablolarda `tenant_id` temel izolasyon anahtaridir.
11. Cross-tenant iliskiler sadece RLS'ye birakilmaz; uygun yerlerde composite foreign key ile veritabani seviyesinde de engellenir.
12. `membership_roles` ve `role_permissions` tenant bilgisini dogrudan tasir.
13. Audit kayitlarinin bagli oldugu location ayni tenant'a ait olmak zorundadir.
14. Tenant ve location fiziksel silme yerine normal kosullarda durum degisikligi ile arsivlenmelidir.

## Ana tablolar

- tenants
- locations
- memberships
- roles
- membership_roles
- role_permissions
- tenant_modules
- audit_logs
- outbox_events

## Bilincli olarak sonraya birakilanlar

- Supabase Auth `auth.users` foreign key
- profiles
- Row Level Security policies
- tenant context cozumleme
- permission catalog
- module catalog
- default roller
- default permissions
- default modules
- updated_at trigger
- audit helper
- outbox helper

Bunlar cekirdek sema onaylandiktan sonra ayri ve geri alinabilir migration'lar halinde eklenecektir.