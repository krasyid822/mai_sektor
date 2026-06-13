# Prinsip Pengembangan
 - langsung connect ke firebase
 - terapkan prinsip riverpood dan satu file satu fitur sejak awal
 - hanya fokus ke web
 - file apapun diubah ke base64 dalam penyimpanan firebase

# Alur dan Kemampuan Aplikasi
## Identitas
 1. Tiap identitas memiliki atribut nama, vektor tanda tangan, murobbi (atribut ini terkoneksi ke nama di identitas yang tertanda sebagai murobbi atau mentor), kontak whatsapp, jenis kelamin, vektor wajah
## Register
 1. Halaman registrasi, dimana aplikasi menanyakan siapa kepala sekolah saat ini dan ditahun kepengurusan berapa (misal 2026/2027)
 2. Setelah kepala sekolah terverifikasi, tampilkan halaman yang mengelola dewan guru dan peserta juga pembawa materi, siapa siapa saja identitasnya (kepala sekolah hanya mengiputkan nama)
 3. Kepala sekolah membagi kelompok peserta ke nama walikelas tertentu, sehingga ada beberapa kelompok berdasarkan walikelas
 4. Setup selesai, aplikasi memasuki dasbor
 5. Aplikasi memiliki fitur absensi peserta, difitur ini kepala sekolah bisa membuat kode qr untuk dibuka peserta, saat peserta membuka link diko