# Prinsip Pengembangan
 - langsung connect ke firebase
 - terapkan prinsip riverpood dan satu file satu fitur sejak awal
 - hanya fokus ke web
 - file apapun diubah ke base64 dalam penyimpanan firebase, dan ditarik lagi file aslinya saat ditampilkan kembali atau digunakan
 - kompresi file agar tidak melebihi 1mb sebelum diupload ke firebase

# Alur dan Kemampuan Aplikasi
## Identitas
 1. Tiap identitas memiliki atribut nama, vektor tanda tangan, murobbi (atribut ini terkoneksi ke nama di identitas yang tertanda sebagai murobbi atau mentor), kontak whatsapp, jenis kelamin, vektor wajah
## Register
 1. Halaman registrasi, dimana aplikasi menanyakan siapa kepala sekolah saat ini dan ditahun kepengurusan berapa (misal 2026/2027)
 2. Setelah kepala sekolah terverifikasi (artinya semua atribut identitas telah diisi), tampilkan halaman yang mengelola dewan guru dan peserta juga pembawa materi, siapa siapa saja identitasnya (kepala sekolah hanya mengiputkan nama)
 3. Kepala sekolah membagi kelompok peserta ke nama walikelas tertentu, sehingga ada beberapa kelompok berdasarkan walikelas
 4. Setup selesai, aplikasi memasuki dasbor
 5. Aplikasi memiliki fitur absensi 
 6. Absensi peserta, difitur ini kepala sekolah bisa membuat kode qr untuk dibuka peserta, saat peserta membuka link dikode qr tersebut yang ditampilkan adalah kolom penginputan nama (memilih dari nama yang sudah dibuat kepala sekolah), nama murobbi (disisi sistem otomatis mencocokkan jika ada nama yang sama persis, jika ditemukan sistem akan bertanya ke peserta apakah nama tersebut yang dimaksud), kontak whatsapp (sistem memiliki mekanisme verifikasi untuk memastikan itu memang nomor whatsapp), jenis kelamin (ikhwan [laki laki]/akhwat [perempuan]), vektor tanda tangan (sediakan pad untuk menggambar tanda tangan), vektor wajah (kalau ini otomatis sistem akan ontime memantau wajah peserta dan menyimpan datanya, tapi yang disimpan adalah vektor wajahnya, bukan foto wajahnya), paling bawah ada fitur laporkan kesalahan (kolom opsional yang diisi peserta apa yang salah disistem dan apa yang benarnya, jika peserta merasa ada yang salah disistem)
 7. Absensi dewan guru, yaitu walikelas sama seperti peserta
 8. Absensi tamu, sama
 9. Kepala sekolah bisa mengelola data peserta untuk memasukkan file pdf tugas resume peserta ke data peserta masing masing
 10. Kepala sekolah bisa memasukkan file materi pdf dan cvnya ke data pembawa materi

 ## Fitur fitur teknis lainnya dan diperlukan
 11. Untuk fitur pad penggambar tanda tangan tambahkan mode komvert dari kertas, yaitu menggunakan kamera ponsel untuk memfoto tanda tangan yang sudah digambar di kertas, lalu sistem akan mengubahnya menjadi vektor tanda tangan, tapi kecilkan tombol mode untuk ini karena tidak diprioritaskan untuk digunakan user
 12. Fitur pretest dan postest
 13. Pertanyaan untuk pretest adalah: Uraikan Kembali Materi tersebut dengan singkat dan jelas; Sebutkan dalil aqli ( Logika ) dari materi tersebut yang disampaikan tadi?; Sebutkan dalil naqli ( Al-Qur’an dan Sunnah ) dari materi tersebut yang disampaikan tadi?; Coba antum uraikan bagaimana sikap aplikasi atau implementasi yang bisa antum lakukan sesuai materi tersebut; Coba antum uraikan khazanah baru yang antum peroleh dan rencana strategi setelah memperoleh materi tersebut dalam rangka berorganisasi, berdakwah, & bermasyarakat; Berikan penilaian 1-5 untuk pemateri
 14. Pertanyaan untuk posttest adalah: Apakah Antum sudah pernah mendengar materi tersebut?; ika sudah, coba antum sebutkan point-point penting mengenai materi!; ika belum, coba antum uraikan sejauh apa pentingnya materi tersebut!; Jika sudah, bagian mana dari materi tersebut yang belum antum pahami?; Jika belum, apa kesan dan ekspektasi antum terhadap pemberi materi?
 15. Untuk pretest dan posttest Wajib menginputkan Nama (nama peserta); Materi	(judul/tema materi, biasa ada waktu slide awal presentasi, bisa tanyakan ke instruktur); Pemateri (nama pembawa materi yang bersama dengan instruktur); Instruktur (nama yang pertama speakup yaitu yang mendampingi pembawa materi)
 16. Untuk pretest dan posttest Tambahkan placeholder di tiap kolom pengisian untuk memudahkan user memahami apa yang harus diisi di kolom tersebut
 17. Fitur kontrak belajar, kepala sekolah bisa membuat kode qr untuk dibuka peserta, saat peserta membuka link dikode qr tersebut yang ditampilkan adalah kontrak perjanjian antara peserta dan program sekolah dan peserta diwajibkan menandatanganinya (memakai pad) dan sistem akan mencocokkan dengan vektor tanda tangan peserta yang sudah terdaftar, jika ada ketidaksesuaian maka tidak bisa melanjutkan ke tahap selanjutnya (beri toleransi ketidakmiripan yang wajar dari tanda tangan, karena orang bisa saja sedikit berbeda menandatangani)
 18. Fitur live dashboard dengan musik latar sesi menunggu untuk absesnsi, pre/post test, kontrak belajar. berisi pemantauan langsung siapa saja yang telah menginputkan dan yang belum untuk ditampilkan ke proyektor saat acara berlangsung, yang bisa mengakses ini adalah kepala sekolah, dan kepala sekolah bisa memilih mode (apakah saat ini sedang sesi absensi, ataukah pretest, dan sebagainya)
 19. Tapi peserta harus cukup dengan satu kode qr untuk semua sesi, artinya kepala sekolah bisa mengubah mode kode qr yang buka peserta, apakah mengarah ke absensi, test, atau lainnya
 20. Ada sistem rekap penilaian yang menentukan kelulusan peserta, terpisah antara peserta ikhwan dan akhwat, atribut rekap penialiannya adalah nama peserta, nilai materi selama kelas besar 1 dan 2 (ada 4 materi), nilai di kelas kecil (room qudwah), nilai tugas resume, total nilai dan ketentuan nilai minimum, status (lulus, tidak lulus, atau ada catatan tertentu)
 21. Kepala sekolah bisa mengatur bobot nilai kelas besar, bobot nilai room qudwah, bobot nilai tugas. dengan bobot total adalah 100%, kebijakan bobot ditampilkan di rekap penilaian. Nilai minimum juga bisa diatur oleh kepala sekolah
 22. Rekap penilaian harus ditandatangani kepala sekolah dan bisa dicetak
 23. Format penilaian room qudwah (kelas kecil) adalah: penampilan (suara, cara berpakaian, gaya atau sikap), kemampuan mengelola forum (mengantisipasi reaksi peserta, memancing reaksi peserta, menjaga ketenangan forum, ice breaking), bahasa (kejelasan vokal, kemudahan dipahami, perbendaharaan kata, intonasi), materi (sistematika, penguasaan materi, relevansi). Setiap jenis penilaian menggunakan range skor 1 sampai 100, dan harus memiliki keterangan yang mewakili pemberian nilai tersebut. Artinya ada 14 penilaian, karena dinilai subjenis penilaian. Format ini yang mengisi adalah wali kelas dan harus ditandatangani wali kelas. Wali kelas uuga harus menginput Nama Wali Kelas, Nama Peserta, Materi (ada 12 materi silabus yaitu: Urgensi Mentoring; Konsekuensi Syahadatain; Ma’rifatul Islam (Mengenal Hakikat Islam); Ma’rifatul Insan (Mengenal Hakikat Manusia); Ma'rifatullah (Mengenal Allah); Ma'rifatur Rasul (Mengenal Rasulullah); Ma’rifatul Qur’an (Mengenal Al-Qur'an); Ukhuwah Islamiyah (Persaudaraan Sesama Muslim); Invasi Pemikiran (Ghazwul Fikri); Peran Pemuda/i Islam; Pentingnya Pendidikan Islam; Pentingnya Akhlak Islam), Pertemuan Ke (ada 12 pertemuan, tiap seminggu sekali). Jadi intinya tiap peserta dan tiap pertemuan ada penilaian dari wali kelasnya munggunakan format ini
 24. Artinya kepala sekolah bisa membuat kode qr khusus agar tiap wali kelas bisa mengakses roomnya sendiri untuk menginput penilaian, tiap kode qr otomatis mengarahkan ke room khusus kelompok walikelas tersebut
 25. Jika rekap penilaian sudah muncul dan ditandatangani oleh kepala sekolah, sistem otomatis membuat sertifikat bagi masing masing peserta, dan harus ditanda tangani oleh kepala sekolah, wali kelas yang bersangkutan, dan kepala divisi MAI. Jika sudah ditandatangani oleh ketiganya maka akan muncul link yang bisa dibagikan kepeserta berformat pdf untuk didownload dan dicetak
 26. Untuk data vektor, jika sudah ada, lalu sistem meminta data itu lagi, artinya data vektor sebelumnya berfungsi sebagai pembanding untuk memastikan bahwa yang saat ini adalah orang yang sama, tapi tetap ada toleransi ketidakmiripan yang wajar
 27. Kepala sekolah memiliki wewenang untuk membypass jika toleransi vektor salah
 28. Izinkan mengganti tanda tangan atas izin kepala sekolah

 # Catatan
 perbaiki hardware resources usage agar mematikan kamera misal saat tidak diperlukan

 nama yang ada di wayground live seringkali tidak muat dan menjadi .. , tolong perbaiki dengan menjadikannya text running