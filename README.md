# mac-like-windows

**Bahasa Indonesia** · [English](README.en.md)

Satu skrip [Hammerspoon](https://www.hammerspoon.org) yang membuat macOS terasa seperti Windows. Gratis, tanpa masa percobaan, dan diam sampai ada tombol atau klik yang memicunya.

## Fitur

| Fitur | Cara pakai | Bawaan macOS |
|---|---|---|
| Klik ikon Dock untuk menyembunyikan aplikasi | Klik ikon aplikasi yang sedang di depan; klik lagi untuk memunculkannya | Klik ikon aplikasi aktif tidak melakukan apa-apa |
| Pengalih per jendela (Alt-Tab) | Tahan **Command**, tekan **Tab** (Shift-Tab untuk mundur), lepas untuk memilih, **Escape** untuk batal | Command-Tab berpindah antaraplikasi, jadi dua jendela Chrome dihitung satu |
| Tombol tambahan di pengalih | Selama panel terbuka: **Kiri / Kanan** untuk pindah, **klik** untuk memilih, **W** menutup jendela, **Q** keluar dari aplikasinya, **H** menyembunyikan aplikasinya | Q dan H ada; W dan pemilihan per jendela tidak ada |
| Screenshot masuk ke clipboard | Ambil screenshot, lalu tempel | Screenshot hanya disimpan sebagai berkas |
| Enter membuka di Finder | Pilih berkas atau folder, tekan **Enter** | Enter mengganti nama |
| F2 mengganti nama di Finder | Pilih berkas, tekan **F2** | — |
| Delete membuang ke Tong Sampah di Finder | Pilih berkas, tekan **Delete** | Harus Command-Delete |
| Potong dan tempel berkas di Finder | **Command-X**, lalu **Command-V** di folder tujuan | Finder tidak punya "potong" untuk berkas |
| Tampilkan desktop (Win + D) | **Option-D**, tekan lagi untuk kembali | — |
| Buka Finder (Win + R) | **Option-R** | — |
| Snap jendela (Win + panah) | **Control-Option-Kiri / Kanan** untuk setengah layar, **Atas** untuk memaksimalkan, **Bawah** untuk memulihkan (atau minimize kalau tidak ada yang dipulihkan) | Harus lewat menu Window atau pintasan Globe |
| Tombol hijau memaksimalkan | Klik tombol hijau untuk memenuhi layar, klik lagi untuk memulihkan | Masuk mode layar penuh di Space terpisah |

Pengalih menampilkan semua jendela, termasuk yang di-minimize dan jendela aplikasi yang disembunyikan, lalu membuka jendela yang dipilih. Yang ditampilkan adalah ikon aplikasi dengan judul tiap jendela di bawahnya, bukan pratinjau gambar, jadi tidak perlu izin Perekaman Layar.

Tombol Finder hanya bekerja saat daftar berkas yang aktif. Saat Anda sedang mengganti nama, mengetik di kolom pencarian, atau menjawab dialog, Enter, Delete, dan Command-X/V berfungsi seperti biasa.

## Kebutuhan

- macOS, Apple silicon atau Intel
- [Hammerspoon](https://www.hammerspoon.org) 1.0 atau lebih baru

Diuji dengan Hammerspoon 1.1.1.

## Pemasangan

1. Pasang Hammerspoon:

   ```bash
   brew install --cask hammerspoon
   ```

2. Letakkan skripnya. Kalau Anda belum punya konfigurasi Hammerspoon:

   ```bash
   mkdir -p ~/.hammerspoon && cp init.lua ~/.hammerspoon/init.lua
   ```

   Kalau sudah punya, salin dengan nama lain lalu muat dari konfigurasi Anda:

   ```bash
   cp init.lua ~/.hammerspoon/mac-like-windows.lua
   ```

   ```lua
   require("mac-like-windows")
   ```

3. Buka Hammerspoon dan beri izin **Aksesibilitas** di Pengaturan Sistem → Privasi & Keamanan → Aksesibilitas. Tanpa izin ini tidak ada yang berfungsi.

4. Pengaturan macOS yang disarankan, supaya hasilnya lebih mirip Windows:

   ```bash
   defaults write com.apple.dock minimize-to-application -bool true && killall Dock
   ```

   ```bash
   defaults write com.apple.screencapture show-thumbnail -bool false && killall SystemUIServer
   ```

   Yang pertama membuat jendela yang di-minimize masuk ke ikon aplikasinya. Yang kedua mematikan pratinjau screenshot yang melayang di pojok; kalau dibiarkan, berkasnya (dan salinan ke clipboard) tertunda sekitar lima detik.

Pintasan baru aktif sekitar 15–20 detik setelah login, begitu Hammerspoon selesai menyala.

## Pengaturan

Semua pilihan ada di tabel `config` di bagian atas `init.lua`. Setelah mengubahnya, muat ulang dari konsol Hammerspoon dengan `hs.reload()` atau buka ulang Hammerspoon.

| Pilihan | Bawaan | Arti |
|---|---|---|
| `launchAtLogin` | `true` | Hammerspoon menyala saat login |
| `hideMenuIcon`, `hideDockIcon` | `true` | Sembunyikan ikon Hammerspoon sendiri |
| `dockClickToHide` | `true` | Klik Dock menyembunyikan aplikasi aktif |
| `switcher.enabled` | `true` | Hidupkan atau matikan pengalih jendela |
| `switcher.modifier` | `"cmd"` | `"cmd"` menggantikan Command-Tab bawaan; `"alt"` memakai Option-Tab dan membiarkan yang bawaan |
| `switcher.iconSize` | `96` | Ukuran ikon di panel pengalih |
| `switcher.showAllTitles` | `true` | Judul di bawah setiap ikon; `false` hanya menampilkan judul jendela terpilih, seperti macOS |
| `switcher.extraKeys` | `true` | Panah, klik mouse, W, Q, dan H di panel |
| `screenshotToClipboard` | `true` | Salin screenshot baru ke clipboard |
| `screenshotFolder` | `nil` | Folder yang dipantau; `nil` mengikuti lokasi screenshot macOS |
| `finder.enterOpens`, `f2Renames`, `deleteTrashes`, `cutPaste` | `true` | Tombol Finder satu per satu |
| `showDesktop` | `{ mods = { "alt" }, key = "d" }` | Pintasan tampilkan desktop; `nil` untuk mematikan |
| `openFinder` | `{ mods = { "alt" }, key = "r" }` | Pintasan buka Finder; `nil` untuk mematikan |
| `snap.enabled`, `snap.mods` | `true`, `{ "ctrl", "alt" }` | Snap jendela dan tombol pengubahnya |
| `greenButtonMaximizes` | `true` | Tombol hijau memaksimalkan, bukan layar penuh |
| `shortcutExcludedApps` | `{}` | Bundle ID aplikasi tempat dua pintasan global dilewatkan |

### Catatan tentang nilai bawaan

- **Option adalah tombol Windows.** Di keyboard Mac, tombol Option berada di posisi tombol Windows, jadi Win + D menjadi Option-D. Ini mengambil alih karakter yang biasanya diketik Option-D dan Option-R (`∂` dan `®` di tata letak US). Pilih pintasan lain kalau Anda memerlukan karakter itu.
- **Kalau Anda memetakan ulang tombol pengubah**, atur pintasan sesuai sinyal yang benar-benar dikirim tombol Anda. Misalnya, kalau tombol Option Anda mengirim Control, pakai `mods = { "ctrl" }` dan masukkan aplikasi terminal ke `shortcutExcludedApps`, karena Control-D dan Control-R punya arti sendiri di sana:

  ```lua
  showDesktop = { mods = { "ctrl" }, key = "d" },
  openFinder  = { mods = { "ctrl" }, key = "r" },
  shortcutExcludedApps = { "com.apple.Terminal", "com.microsoft.VSCode" },
  ```

- **Snap memakai Control-Option, bukan Option saja**, karena Option-Kiri dan Option-Kanan sudah dipakai untuk memindahkan kursor per kata di teks.
- **Untuk layar penuh yang asli**, tahan tombol pengubah apa pun (misalnya Shift) sambil mengeklik tombol hijau.
- **F2 di MacBook** biasanya mengatur kecerahan, jadi tekan bersama Fn, atau aktifkan "Gunakan tombol F1, F2, dst. sebagai tombol fungsi standar" di Pengaturan Sistem → Papan Ketik.
- **Delete memindahkan berkas ke Tong Sampah.** Berkas tidak dihapus permanen.

## Kinerja

Saat diam, Hammerspoon dengan skrip ini memakai CPU sekitar 0,0–0,1% dan memori 70–100 MB di MacBook Air 8 GB. Tidak ada yang berjalan terus di latar belakang, selain pengecekan tiap sepuluh detik bahwa event tap masih aktif.

## Mematikan

Keluar dari Hammerspoon, dan macOS kembali berperilaku seperti semula. Untuk membuang sepenuhnya, hapus `~/.hammerspoon/init.lua` dan copot Hammerspoon.

## Keterbatasan

- Panel pengalih meniru tampilan Command-Tab bawaan, tapi digambar oleh skrip, jadi tidak punya efek buram.
- **Q di pengalih langsung mengeluarkan aplikasinya**; aplikasi yang punya perubahan belum disimpan mungkin masih bertanya dulu sebelum tertutup.
- "Klik ikon Dock untuk menyembunyikan" hanya berlaku untuk aplikasi yang sedang di depan, sama seperti taskbar Windows untuk jendela aktif.
- Desktop Finder tidak selalu tercakup oleh tombol Enter dan Delete.

## Lisensi

[MIT](LICENSE)
