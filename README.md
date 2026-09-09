# Family App Tracking

Aplikasi Android untuk koordinasi harian keluarga — dipakai bertiga (Bunda, Aku, Adek) di HP masing-masing.

Dibuat karena hal-hal kecil sehari-hari ("kamu di mana?", "token listrik habis", "minggu ini siapa yang piket?", "tolong beliin susu") selalu berujung buka WhatsApp, ngetik, lalu nunggu dibalas. Di app ini semuanya sudah kelihatan tanpa perlu bertanya.

## Get it

| Target | Cara dapat |
|---|---|
| Android | APK, debug signed — [latest release](../../releases/latest), file `family-app-tracking.apk` |

Install langsung dari file APK-nya (perlu izinkan "install dari sumber tidak dikenal" sekali di HP).

## Tampilan

Hangat dan lembut, bukan formulir: kartu membulat berbayang halus di atas latar krem, palet koral–kuning–tosca, dan satu warna khas per anggota yang dipakai konsisten di semua layar — jadi warna saja sudah memberi tahu ini punya siapa.

Satu detail yang paling berguna sehari-hari: **status menua sendiri**. Yang baru diisi tampil pekat, yang sudah lebih dari 12 jam memudar dan waktunya berubah merah, supaya kabar semalam tidak dikira masih berlaku.

| Keluarga | Kalender | Piket rumah |
|---|---|---|
| ![Keluarga](test/preview/02-kartu-keluarga.png) | ![Kalender](test/preview/03-kalender.png) | ![Piket](test/preview/05-piket.png) |

| Pengumuman | Titip beli | Mode gelap |
|---|---|---|
| ![Pengumuman](test/preview/04-pengumuman.png) | ![Titip beli](test/preview/06-titip-beli.png) | ![Gelap](test/preview/09-kartu-keluarga-gelap.png) |

Gambar-gambar itu bukan mockup — semuanya dirender langsung dari widget aplikasi lewat `flutter test --update-goldens test/design_preview_test.dart`, memakai data contoh.

## Fitur

- **Kalender** — tiap anggota mengisi jadwalnya di tanggal tertentu, yang lain bisa lihat.
- **Status** — di rumah / di kampus / di kantor / tidur, plus keterangan singkat opsional (misal "OTW pulang, telat 30 menit").
- **Papan Pengumuman** — catatan singkat yang langsung terlihat semua anggota.
- **Tugas** — daftar piket rumah yang rolling tiap minggu, plus daftar titip beli bersama.
- **Peta** — posisi anggota yang mengaktifkan berbagi lokasi.
- **Admin** — satu profil bertindak sebagai admin: bisa membatalkan jadwal orang lain dan mengatur rotasi piket.

Tidak ada login akun — tiap HP cukup memilih "kamu siapa" sekali, lalu diingat secara lokal.

## Stack

Flutter (Android) · Cloud Firestore · OpenStreetMap lewat `flutter_map` · Firebase Cloud Messaging

Peta sengaja memakai OpenStreetMap, bukan Google Maps: tidak butuh API key dan tidak butuh akun penagihan, jadi APK yang dibagikan tidak membawa kredensial apa pun yang bisa disalahgunakan.

## Menjalankan sendiri

App ini terhubung ke project Firebase pribadi, jadi konfigurasinya tidak ikut di repo ini. Untuk menjalankan:

1. Buat project Firebase, tambahkan app Android dengan package `com.keluarga.family_app`, lalu simpan `google-services.json` ke `android/app/`.
2. Aktifkan Cloud Firestore, lalu deploy aturan dari `firestore.rules`.
3. `flutter pub get` lalu `flutter run`.

Tidak ada kunci peta yang perlu diisi.

> Catatan keamanan: karena app ini tanpa autentikasi, aturan Firestore-nya memang longgar — cocok untuk 3 anggota keluarga yang saling percaya, bukan untuk data yang perlu dijaga dari publik. Karena itu `google-services.json` sengaja tidak dimasukkan ke repo.
