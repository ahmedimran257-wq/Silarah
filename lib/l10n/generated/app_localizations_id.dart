// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get guide_optional_details => 'Detail tambahan (opsional)';

  @override
  String get guide_optional_details_body =>
      'Anda dapat melengkapi detail ini nanti melalui profil Anda.';

  @override
  String get guide_profile_ownership =>
      'Profil ini menjelaskan orang yang ingin menikah. Wali terpisah dapat diundang nanti untuk mengawasi percakapan.';

  @override
  String get about_button_later => 'Aku akan melakukannya nanti';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'Jelaskan $relation Anda dengan jujur ​​dan bermartabat.';
  }

  @override
  String get about_hint_bio_self =>
      'Gambarkan diri Anda dengan jujur ​​dan bermartabat.';

  @override
  String get about_label_bio_guardian => 'BIO MEREKA';

  @override
  String get about_label_bio_self => 'BIO ANDA';

  @override
  String get about_label_interests => 'BUNGA';

  @override
  String get about_label_languages => 'BAHASA YANG DIBICARAKAN';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max dipilih';
  }

  @override
  String get about_subtitle => 'Tulislah dengan jujur ​​dan bermartabat.';

  @override
  String about_title_guardian(Object relation) {
    return 'Tentang $relation Anda';
  }

  @override
  String get about_title_self => 'Tentang kamu';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'Mulailah dengan bismillah';

  @override
  String get auth_button_resendOtp => 'Kirim Ulang Kode Verifikasi';

  @override
  String get auth_button_sendCode => 'Kirim Kode Verifikasi';

  @override
  String get auth_button_sendOtp => 'Kirim Kode Verifikasi';

  @override
  String get auth_button_verifyOtp => 'Memeriksa';

  @override
  String get auth_label_changeNumber => 'Nomor yang salah? Ubah itu';

  @override
  String get auth_label_enterOtp =>
      'Masukkan 6 digit kode verifikasi yang dikirimkan ke';

  @override
  String get auth_label_resendCode => 'Kirim ulang kode verifikasi';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'Kirim ulang kode verifikasi dalam waktu ${seconds}s';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'Kirim ulang dalam waktu ${seconds}s';
  }

  @override
  String get auth_label_sentCodeTo =>
      'Kami mengirimkan kode verifikasi 6 digit ke';

  @override
  String get auth_subtitle_verifyOtp =>
      'Kami akan memverifikasinya dengan kode satu kali.';

  @override
  String get auth_title_enterCode => 'Masukkan kode verifikasi Anda';

  @override
  String get auth_title_yourNumber => 'Nomor Anda';

  @override
  String get background_edu_bachelors => 'Gelar Sarjana';

  @override
  String get background_edu_below_secondary => 'Di bawah Sekunder';

  @override
  String get background_edu_diploma => 'Ijazah / Rekan';

  @override
  String get background_edu_doctorate => 'Doktor/PhD';

  @override
  String get background_edu_higher_secondary =>
      'Sekolah Menengah Atas / A-Level';

  @override
  String get background_edu_masters => 'Gelar Master';

  @override
  String get background_edu_secondary => 'Tingkat Sekunder / O';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'Ceritakan kepada kami tentang pendidikan dan karier $relation Anda.';
  }

  @override
  String get background_edu_subtitle_self =>
      'Membantu menemukan kecocokan yang kompatibel secara profesional.';

  @override
  String get background_edu_title_guardian => 'Latar belakang mereka';

  @override
  String get background_edu_title_self => 'Latar belakang Anda';

  @override
  String get background_emp_employed => 'Bekerja';

  @override
  String get background_emp_not_working => 'Tidak bekerja';

  @override
  String get background_emp_self_employed => 'Wiraswasta';

  @override
  String get background_emp_student => 'Murid';

  @override
  String get background_income_subtitle =>
      'Banyak orang melewatkan ini — ini sepenuhnya opsional.';

  @override
  String get background_label_eduLevel => 'TINGKAT PENDIDIKAN';

  @override
  String get background_label_employment => 'STATUS KETENAGAKERJAAN';

  @override
  String background_label_income_bracket(Object currency) {
    return 'BRACKET PENDAPATAN ($currency)';
  }

  @override
  String get background_label_income_range => 'KIRAN PENDAPATAN (Opsional)';

  @override
  String get background_label_profession => 'Profesi (Opsional)';

  @override
  String get background_label_study => 'Bidang studi (Opsional)';

  @override
  String get background_label_who_see => 'SIAPA YANG DAPAT MELIHAT INI?';

  @override
  String get background_vis_everyone => 'Tunjukkan braket kepada semua orang';

  @override
  String get background_vis_mutual =>
      'Tampilkan hanya setelah kepentingan bersama';

  @override
  String get background_vis_private => 'Tetap pribadi';

  @override
  String get ceremony_text_blessing =>
      'Semoga Allah memberkati ini dengan kebaikan';

  @override
  String get chat_closure_1 =>
      'Assalamu alaikum. Setelah refleksi yang matang, saya merasa ini mungkin bukan pasangan yang tepat untuk kami. Saya dengan tulus mendoakan yang terbaik untuk Anda dan berdoa semoga Allah memberkati Anda dengan pasangan yang luar biasa. Jazakillah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu alaikum. Saya ingin jujur ​​dan menghormati Anda. Menurutku kita bukan pasangan yang cocok, tapi aku berdoa semoga Allah membukakan pintu yang lebih baik untukmu. Semoga Anda mendapatkan yang terbaik.';

  @override
  String get chat_closure_3 =>
      'Assalamu alaikum. Setelah mempertimbangkan dengan tulus, saya merasa kami mungkin tidak cocok. Saya harap Anda menemukan seseorang yang benar-benar tepat untuk Anda. Semoga Allah memudahkanmu. JazakAllah khair atas waktunya.';

  @override
  String get chat_closure_4 =>
      'Assalamu alaikum. Saya telah merenungkan percakapan kami dan merasa yang terbaik adalah menutup pertandingan ini saat ini. Saya hanya menghormati Anda dan saya berdoa agar Allah memberkati Anda dengan yang terbaik.';

  @override
  String get chat_closure_5 =>
      'Assalamu alaikum. Aku ingin bersikap transparan padamu daripada menghilang. Saya tidak melihat kemajuan ini lebih jauh, namun saya sangat menghargai waktu Anda dan mendoakan Anda bahagia. Semoga Allah memberkati Anda.';

  @override
  String get chat_endMatch_button => 'Kirim & Akhiri Pertandingan';

  @override
  String get chat_endMatch_subtitle =>
      'Pilih pesan yang penuh hormat untuk menutup percakapan ini. Orang lain akan diberitahu.';

  @override
  String get chat_endMatch_title => 'Akhiri pertandingan ini';

  @override
  String chat_label_probation(int hours) {
    return 'Pesan akan terbuka dalam waktu $hours jam. Anda dapat mengirimkan Minat sekarang.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Berlangganan untuk membuka kunci perpesanan. Wanita selalu mengirim pesan gratis di Silarah.';

  @override
  String get chat_matchClosed_banner =>
      'Pertandingan ini telah ditutup dengan hormat.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! Saya menemukan profil Anda dan benar-benar terkesan. Bolehkah saya memperkenalkan diri?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Profil Anda menarik perhatian saya. Saya ingin mengetahui lebih banyak tentang Anda.';

  @override
  String get chat_opener_3 =>
      'Assalamu alaikum. Saya yakin kami memiliki nilai-nilai yang sama. Apakah Anda terbuka untuk mengenal satu sama lain?';

  @override
  String get chat_placeholder_typeMessage => 'Ketik pesan…';

  @override
  String get common_button_back => 'Kembali';

  @override
  String get common_button_cancel => 'Membatalkan';

  @override
  String get common_button_done => 'Selesai';

  @override
  String get common_button_next => 'Berikutnya';

  @override
  String get common_button_retry => 'Coba Lagi';

  @override
  String get common_button_save => 'Menyimpan';

  @override
  String get common_button_skip => 'Melewati';

  @override
  String get common_button_submit => 'Kirim';

  @override
  String get common_error_generic => 'Ada yang tidak beres. Silakan coba lagi.';

  @override
  String get common_error_noInternet =>
      'Tidak ada koneksi internet. Silakan periksa koneksi Anda.';

  @override
  String get common_label_optional => 'Opsional';

  @override
  String get copy_beard_parent => 'Apakah anak Anda berjanggut?';

  @override
  String get copy_beard_self => 'Apakah kamu mempunyai janggut?';

  @override
  String get copy_beard_sibling => 'Apakah kakakmu berjanggut?';

  @override
  String get copy_hijab_parent => 'Apakah putri Anda berhijab?';

  @override
  String get copy_hijab_self => 'Apakah Anda memperhatikan hijab?';

  @override
  String get copy_hijab_sibling => 'Apakah adikmu menjalankan hijab?';

  @override
  String get copy_prayer_parent => 'Apakah anak Anda shalat lima waktu sehari?';

  @override
  String get copy_prayer_self => 'Apakah Anda berdoa lima kali sehari?';

  @override
  String get copy_prayer_sibling =>
      'Apakah saudaramu shalat lima waktu sehari?';

  @override
  String get deleteAccount_title => 'Hapus Akun';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name dihapus';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name disimpan';
  }

  @override
  String get discovery_button_sendInterest => 'Kirim Minat';

  @override
  String get discovery_completeness_button => 'Profil Lengkap';

  @override
  String get discovery_completeness_subtitle =>
      'Profil di atas 40% mendapatkan minat 3× lebih banyak.\nLengkapi profil Anda untuk mulai menjelajah.';

  @override
  String get discovery_completeness_title => 'Lengkapi Profil Anda';

  @override
  String get discovery_empty_subtitle =>
      'Anggota baru bergabung dengan Silarah setiap hari. Kembali lagi besok untuk profil baru, atau perluas preferensi Anda untuk bertemu lebih banyak orang sekarang.';

  @override
  String get discovery_empty_filtered_eyebrow => 'PERHALUS PENCARIAN';

  @override
  String get discovery_empty_filtered_title =>
      'Belum ada yang cocok dengan filter ini';

  @override
  String get discovery_empty_filtered_subtitle =>
      'Preferensi Anda mempersempit lingkaran. Melonggarkan satu filter saja biasanya langsung memunculkan profil baru.';

  @override
  String get discovery_empty_clear_filters => 'Hapus semua filter';

  @override
  String get discovery_empty_refresh => 'Muat ulang profil';

  @override
  String get discovery_empty_adjust_filters => 'Atur filter';

  @override
  String get discovery_empty_hint_trust =>
      'Coba longgarkan Pemeriksaan kepercayaan dulu';

  @override
  String get discovery_empty_hint_deen => 'Coba perluas Tingkat Dien dulu';

  @override
  String get discovery_empty_hint_family => 'Coba perluas Tipe Keluarga dulu';

  @override
  String get discovery_empty_hint_sect => 'Coba buka filter Sekte dulu';

  @override
  String get discovery_empty_hint_location =>
      'Coba lokasi yang lebih luas dulu';

  @override
  String get discovery_empty_hint_age =>
      'Coba rentang usia yang lebih luas dulu';

  @override
  String get discovery_empty_hint_other =>
      'Coba longgarkan satu filter setiap kali';

  @override
  String get discovery_empty_eyebrow => 'SEMUA SUDAH DILIHAT';

  @override
  String get discovery_empty_title => 'Anda sudah melihat semua orang hari ini';

  @override
  String get discovery_handoff_interest_subtitle =>
      'Profil dengan permintaan aktif berpindah ke Minat selama Anda menunggu atau merespons.';

  @override
  String get discovery_handoff_interest_title => 'Minat Anda sedang diproses';

  @override
  String get discovery_handoff_match_subtitle =>
      'Profil yang cocok berpindah ke Chat sehingga tidak ditampilkan lagi di Temukan.';

  @override
  String get discovery_handoff_match_title => 'Koneksi Anda sudah siap';

  @override
  String get discovery_handoff_open_chat => 'Buka Chat';

  @override
  String get discovery_handoff_open_interests => 'Buka Minat';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'Bunga Terkirim ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Seseorang yang mungkin terhubung dengan Anda';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profil tersisa hari ini';
  }

  @override
  String get discovery_limit_button => 'Tingkatkan Sekarang';

  @override
  String get discovery_limit_subtitle =>
      'Anda telah menjelajahi 15 profil hari ini.\nTingkatkan untuk membuka kunci penjelajahan tanpa batas.';

  @override
  String get discovery_limit_title => 'Batas harian tercapai';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count profil tersisa';
  }

  @override
  String get discovery_wildcard_label =>
      'Seseorang yang mungkin terhubung dengan Anda';

  @override
  String get family_children_no => 'TIDAK';

  @override
  String get family_children_yes => 'Ya';

  @override
  String get family_label_children_guardian => 'APAKAH MEREKA PUNYA ANAK?';

  @override
  String get family_label_children_self => 'APA ANDA PUNYA ANAK?';

  @override
  String get family_label_how_many => 'BERAPA BANYAK?';

  @override
  String get family_label_parents => 'STATUS PERKAWINAN ORANG TUA';

  @override
  String get family_label_polygamy_female_self =>
      'PENERIMAAN POLIGAMI (Opsional)';

  @override
  String get family_label_polygamy_male_self => 'STATUS POLIGAMI (Opsional)';

  @override
  String get family_label_prev_married => 'SEBELUMNYA MENIKAH?';

  @override
  String get family_label_relocate => 'BERSEDIA UNTUK RELOKASI';

  @override
  String get family_label_siblings => 'JUMLAH SAUDARA';

  @override
  String get family_label_type => 'TIPE KELUARGA';

  @override
  String get family_living_title => 'HARAPAN HIDUP PASCA PERNIKAHAN';

  @override
  String get family_parents_both_deceased => 'Keduanya meninggal';

  @override
  String get family_parents_divorced => 'Cerai';

  @override
  String get family_parents_father_deceased => 'Ayah meninggal';

  @override
  String get family_parents_mother_deceased => 'Ibu meninggal';

  @override
  String get family_parents_separated => 'Terpisah';

  @override
  String get family_parents_together => 'Bersama';

  @override
  String get family_polygamy_female_discussion => 'Terbuka untuk diskusi';

  @override
  String get family_polygamy_female_no => 'TIDAK';

  @override
  String get family_polygamy_female_prefer_not =>
      'Memilih untuk tidak mengatakannya';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'Apakah $relation Anda akan mempertimbangkan untuk menjadi rekan istri?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'Apakah Anda mempertimbangkan untuk menjadi rekan istri?';

  @override
  String get family_polygamy_female_yes => 'Ya';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'Apakah $relation Anda saat ini sudah menikah dan sedang mencari pasangan tambahan?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'Apakah Anda saat ini sudah menikah dan sedang mencari pasangan tambahan?';

  @override
  String get family_polygamy_option_first => 'Tidak, ini yang pertama bagiku';

  @override
  String get family_polygamy_option_married => 'Ya, saat ini sudah menikah';

  @override
  String get family_polygamy_option_prefer_not =>
      'Memilih untuk tidak mengatakannya';

  @override
  String get family_prev_divorced => 'Cerai';

  @override
  String get family_prev_no => 'TIDAK';

  @override
  String get family_prev_widowed => 'Janda';

  @override
  String get family_relocate_discussion => 'Terbuka untuk Diskusi';

  @override
  String get family_relocate_no => 'TIDAK';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'Apakah $relation Anda akan pindah untuk menikah?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'Apakah Anda akan pindah untuk menikah?';

  @override
  String get family_relocate_yes => 'Ya';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'Ceritakan kepada kami tentang keluarga $relation Anda.';
  }

  @override
  String get family_subtitle_self =>
      'Kecocokan keluarga adalah inti dari pernikahan yang langgeng.';

  @override
  String get family_title_guardian => 'Latar belakang keluarga';

  @override
  String get family_title_self => 'Latar belakang keluarga';

  @override
  String get family_type_extended => 'Diperpanjang';

  @override
  String get family_type_joint => 'Persendian';

  @override
  String get family_type_nuclear => 'Nuklir';

  @override
  String get filter_label_community => 'Komunitas / Biradari';

  @override
  String get filter_label_livingExpectation => 'Kehidupan Pasca Pernikahan';

  @override
  String get filter_label_motherTongue => 'Bahasa ibu';

  @override
  String get guardian_details_candidate_female =>
      'Kandidat perempuan • Pesan perempuan gratis';

  @override
  String get guardian_details_candidate_label => 'MEMBUAT PROFIL UNTUK';

  @override
  String get guardian_details_candidate_male => 'Calon laki-laki';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return '$relation saya';
  }

  @override
  String get guardian_details_involvement => 'KETERLIBATAN PENJAGA';

  @override
  String get guardian_details_involvement_subtitle =>
      'Seberapa besar keterlibatan Anda dalam percakapan?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'Lihat chat, setujui kecocokan, dan kirim pesan atas nama $relation Anda.';
  }

  @override
  String get guardian_details_mode_active_title => 'Wali aktif';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'Lihat semua chat secara real-time, namun hanya $relation Anda yang dapat mengirim pesan.';
  }

  @override
  String get guardian_details_mode_passive_title => 'Amati saja';

  @override
  String get guardian_details_name_hint => 'Nama lengkap';

  @override
  String get guardian_details_name_subtitle =>
      'Nama Anda sebagai wali. Ini ditunjukkan pada pertandingan.';

  @override
  String guardian_details_notice(Object relation) {
    return 'Anda sedang membuat profil untuk $relation Anda. Semua detail profil di layar berikutnya akan menjelaskannya, bukan Anda.';
  }

  @override
  String get guardian_details_search_hint => 'Mencari';

  @override
  String get guardian_details_select_code => 'Pilih kode negara';

  @override
  String get guardian_details_subtitle =>
      'Ceritakan kepada kami tentang diri Anda sebagai wali.';

  @override
  String get guardian_details_title => 'Detail wali Anda';

  @override
  String get guardian_details_your_name => 'NAMA ANDA';

  @override
  String get interest_cat_creative => 'Kreatif';

  @override
  String get interest_cat_faith => 'Keyakinan';

  @override
  String get interest_cat_learning => 'Sedang belajar';

  @override
  String get interest_cat_lifestyle => 'Gaya hidup';

  @override
  String get interest_cat_social => 'Sosial';

  @override
  String get interest_cat_sports => 'Olahraga';

  @override
  String get interest_tag_art => 'Seni';

  @override
  String get interest_tag_calligraphy => 'Kaligrafi';

  @override
  String get interest_tag_community_work => 'Kerja komunitas';

  @override
  String get interest_tag_cooking => 'Memasak';

  @override
  String get interest_tag_crafts => 'kerajinan tangan';

  @override
  String get interest_tag_cricket => 'Jangkrik';

  @override
  String get interest_tag_cycling => 'Bersepeda';

  @override
  String get interest_tag_dawah => 'Dakwah';

  @override
  String get interest_tag_family_gatherings => 'Pertemuan keluarga';

  @override
  String get interest_tag_fitness => 'kebugaran';

  @override
  String get interest_tag_football => 'Sepak bola';

  @override
  String get interest_tag_gardening => 'Berkebun';

  @override
  String get interest_tag_graphic_design => 'Desain Grafis';

  @override
  String get interest_tag_hiking => 'Lintas alam';

  @override
  String get interest_tag_history => 'Sejarah';

  @override
  String get interest_tag_islamic_lectures => 'ceramah Islam';

  @override
  String get interest_tag_languages => 'Bahasa';

  @override
  String get interest_tag_martial_arts => 'Seni bela diri';

  @override
  String get interest_tag_mentoring => 'Pendampingan';

  @override
  String get interest_tag_photography => 'Fotografi';

  @override
  String get interest_tag_poetry => 'Puisi';

  @override
  String get interest_tag_quran_recitation => 'Pembacaan Alquran';

  @override
  String get interest_tag_reading => 'Membaca';

  @override
  String get interest_tag_science => 'Sains';

  @override
  String get interest_tag_swimming => 'Renang';

  @override
  String get interest_tag_tahajjud => 'Tahajud';

  @override
  String get interest_tag_teaching => 'Pengajaran';

  @override
  String get interest_tag_technology => 'Teknologi';

  @override
  String get interest_tag_travel => 'Bepergian';

  @override
  String get interest_tag_umrah_hajj => 'Umroh/Haji';

  @override
  String get interest_tag_voluntary_fasting => 'Puasa sukarela';

  @override
  String get interest_tag_volunteering => 'Sukarela';

  @override
  String get interest_tag_writing => 'Menulis';

  @override
  String get interests_button_accept => 'Menerima';

  @override
  String get interests_button_decline => 'Menolak';

  @override
  String get interests_tab_received => 'Diterima';

  @override
  String get interests_tab_sent => 'Terkirim';

  @override
  String get interests_title => 'Minat';

  @override
  String get lang_albanian => 'bahasa Albania';

  @override
  String get lang_amazigh => 'Amazigh (Berber)';

  @override
  String get lang_amharic => 'Amharik';

  @override
  String get lang_arabic => 'Arab';

  @override
  String get lang_assamese => 'orang Assam';

  @override
  String get lang_balochi => 'Balochi';

  @override
  String get lang_bengali => 'Benggala';

  @override
  String get lang_bosnian => 'Bosnia';

  @override
  String get lang_burmese => 'Birma';

  @override
  String get lang_chechen => 'Chechnya';

  @override
  String get lang_chinese => 'Cina (Mandarin)';

  @override
  String get lang_dari => 'Dari';

  @override
  String get lang_dutch => 'Belanda';

  @override
  String get lang_english => 'Bahasa inggris';

  @override
  String get lang_french => 'Perancis';

  @override
  String get lang_fulani => 'Fulani';

  @override
  String get lang_german => 'Jerman';

  @override
  String get lang_gujarati => 'Gujarati';

  @override
  String get lang_hausa => 'rumah';

  @override
  String get lang_hindi => 'Hindi';

  @override
  String get lang_igbo => 'Igbo';

  @override
  String get lang_indonesian => 'Indonesia';

  @override
  String get lang_italian => 'Italia';

  @override
  String get lang_japanese => 'Jepang';

  @override
  String get lang_javanese => 'Jawa';

  @override
  String get lang_kannada => 'Kannada';

  @override
  String get lang_kazakh => 'Kazakh';

  @override
  String get lang_korean => 'Korea';

  @override
  String get lang_kurdish => 'Kurdi';

  @override
  String get lang_kyrgyz => 'Kirgistan';

  @override
  String get lang_malay => 'Melayu';

  @override
  String get lang_malayalam => 'Malayalam';

  @override
  String get lang_mandinka => 'Mandinka';

  @override
  String get lang_marathi => 'Marathi';

  @override
  String get lang_norwegian => 'Norwegia';

  @override
  String get lang_odia => 'Odia';

  @override
  String get lang_other => 'Lainnya';

  @override
  String get lang_pashto => 'pasto';

  @override
  String get lang_persian => 'Persia';

  @override
  String get lang_portuguese => 'Portugis';

  @override
  String get lang_punjabi => 'Punjabi';

  @override
  String get lang_rohingya => 'Rohingya';

  @override
  String get lang_russian => 'Rusia';

  @override
  String get lang_saraiki => 'Saraiki';

  @override
  String get lang_sindhi => 'Sindhi';

  @override
  String get lang_somali => 'Somalia';

  @override
  String get lang_spanish => 'Spanyol';

  @override
  String get lang_sundanese => 'Sunda';

  @override
  String get lang_swahili => 'Swahili';

  @override
  String get lang_swedish => 'Swedia';

  @override
  String get lang_tagalog => 'bahasa Tagalog';

  @override
  String get lang_tajik => 'Tajik';

  @override
  String get lang_tamil => 'Tamil';

  @override
  String get lang_tatar => 'Tatar';

  @override
  String get lang_telugu => 'Telugu';

  @override
  String get lang_thai => 'Thai';

  @override
  String get lang_tigrinya => 'harimaunya';

  @override
  String get lang_turkish => 'Turki';

  @override
  String get lang_urdu => 'bahasa Urdu';

  @override
  String get lang_uzbek => 'Uzbekistan';

  @override
  String get lang_wolof => 'Wolof';

  @override
  String get lang_yoruba => 'Yoruba';

  @override
  String get legal_button_continue => 'Melanjutkan';

  @override
  String get legal_checkbox_age =>
      'Saya mengonfirmasi bahwa saya berusia 18 tahun ke atas';

  @override
  String get legal_checkbox_terms =>
      'Saya menyetujui Ketentuan Layanan dan Kebijakan Privasi';

  @override
  String get legal_subtitle => 'Silakan baca dan setuju untuk melanjutkan.';

  @override
  String get legal_summary_1 =>
      'Data Anda dienkripsi dan tidak pernah dijual kepada pihak ketiga.';

  @override
  String get legal_summary_2 =>
      'Setiap foto diperiksa keamanannya, dan tim kami meninjau foto baru.';

  @override
  String get legal_summary_3 =>
      'Pelecehan, profil palsu, dan penipuan mengakibatkan pemblokiran permanen.';

  @override
  String get legal_summary_4 =>
      'Platform ini hanya untuk niat pernikahan. Martabat adalah standarnya.';

  @override
  String get legal_summary_5 =>
      'Anda dapat menghapus akun dan semua data Anda kapan saja.';

  @override
  String get legal_title => 'Sebelum Anda mulai';

  @override
  String get notifications_empty_subtitle =>
      'Tidak ada pemberitahuan baru saat ini.';

  @override
  String get notifications_empty_title => 'Anda semua terjebak';

  @override
  String get notifications_markAllRead => 'Tandai semua telah dibaca';

  @override
  String get notifications_title => 'Pemberitahuan';

  @override
  String get onboarding_about_title => 'Tentang dirimu sendiri';

  @override
  String get onboarding_background_title => 'Pendidikan & Karir';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'Anda mengisi ini sebagai wali. Detail ini tentang $relation Anda.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'Inilah yang akan dilihat orang lain di profil mereka.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'Inilah yang akan dilihat orang lain di profil Anda.';

  @override
  String get onboarding_basicIdentity_title =>
      'Ceritakan kepada kami tentang diri Anda';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Beritahu kami tentang $relation Anda';
  }

  @override
  String get onboarding_debt_manageable => 'Hutang yang bisa dikelola';

  @override
  String get onboarding_debt_none => 'Tidak ada hutang';

  @override
  String get onboarding_debt_significant => 'Hutang yang signifikan';

  @override
  String get onboarding_diet_eatsAnything => 'Makan apa saja yang halal';

  @override
  String get onboarding_diet_halalOnly => 'Hanya halal';

  @override
  String get onboarding_diet_vegan => 'vegan';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarian';

  @override
  String get onboarding_diet_zabihaStrict => 'Zabiha yang ketat';

  @override
  String get onboarding_error_bioContactInfo =>
      'Harap hapus informasi kontak dari bio Anda. Detail kontak eksternal tidak diperbolehkan demi keselamatan Anda.';

  @override
  String get onboarding_error_multipleFaces =>
      'Foto grup tidak boleh menjadi foto utama Anda.';

  @override
  String get onboarding_error_noFace =>
      'Silakan gunakan foto yang wajah Anda terlihat jelas.';

  @override
  String get onboarding_error_under18 =>
      'Silarah ditujukan untuk mereka yang berusia 18 tahun ke atas. Kami membuat persyaratan ini untuk melindungi semua orang di komunitas kami.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return '$relation Anda harus berusia 18 tahun ke atas untuk menggunakan Silarah.';
  }

  @override
  String get onboarding_error_under18_self =>
      'Anda harus berusia 18 tahun ke atas untuk menggunakan Silarah. Kami menantikan kedatangan Anda pada saat itu.';

  @override
  String get onboarding_habit_frequently => 'Sering';

  @override
  String get onboarding_habit_never => 'Tidak pernah';

  @override
  String get onboarding_habit_occasionally => 'Kadang-kadang';

  @override
  String get onboarding_habit_preferNotToSay =>
      'Memilih untuk tidak mengatakannya';

  @override
  String get onboarding_hijab_always => 'Selalu';

  @override
  String get onboarding_hijab_no => 'TIDAK';

  @override
  String get onboarding_hijab_sometimes => 'Kadang-kadang';

  @override
  String get onboarding_hint_bio =>
      'Gambarkan diri Anda dengan jujur ​​dan bermartabat.';

  @override
  String get onboarding_hint_profession =>
      'misalnya Insinyur Perangkat Lunak, Guru, Dokter';

  @override
  String get onboarding_hint_searchCity => 'Telusuri kota Anda…';

  @override
  String get onboarding_hint_selectCommunity => 'Pilih komunitas (opsional)';

  @override
  String get onboarding_hint_selectCountry => 'Pilih negara';

  @override
  String get onboarding_hint_selectDateOfBirth => 'Pilih tanggal lahir';

  @override
  String get onboarding_hint_selectLanguage => 'Pilih bahasa';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'Ini membantu mencocokkan Anda dengan seseorang yang kompatibel.';

  @override
  String get onboarding_islamicIdentity_title => 'Identitas Islam Anda';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'Kota';

  @override
  String get onboarding_label_city_guardian => 'kota mereka';

  @override
  String get onboarding_label_city_self => 'kotamu';

  @override
  String get onboarding_label_community => 'Komunitas Anda / biradari';

  @override
  String get onboarding_label_community_parent => 'Komunitas mereka / biradari';

  @override
  String get onboarding_label_complexion => 'Warna Kulit (Opsional)';

  @override
  String get onboarding_label_country_guardian => 'Negara mereka';

  @override
  String get onboarding_label_country_self => 'negaramu';

  @override
  String get onboarding_label_cultural => 'Muslim Budaya';

  @override
  String get onboarding_label_dateOfBirth => 'Tanggal lahir';

  @override
  String get onboarding_label_debtStatus => 'Status Hutang';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Kewajiban keuangan Anda saat ini.';

  @override
  String get onboarding_label_deenLevel => 'Tingkat Dien';

  @override
  String get onboarding_label_diet => 'Diet';

  @override
  String get onboarding_label_educationLevel => 'Tingkat Pendidikan';

  @override
  String get onboarding_label_female => 'Perempuan';

  @override
  String get onboarding_label_firstName => 'Nama depan';

  @override
  String get onboarding_label_firstName_guardian => 'Nama depan kandidat';

  @override
  String get onboarding_label_firstName_self => 'Nama depan';

  @override
  String get onboarding_label_gender => 'Jenis kelamin';

  @override
  String get onboarding_label_gender_guardian => 'jenis kelamin kandidat';

  @override
  String get onboarding_label_gender_self => 'Jenis kelamin';

  @override
  String get onboarding_label_height_guardian => 'Tinggi badan mereka';

  @override
  String get onboarding_label_height_self => 'Tinggi badanmu';

  @override
  String get onboarding_label_hookah => 'Hookah / Shisha';

  @override
  String get onboarding_label_housing => 'Perumahan';

  @override
  String get onboarding_label_housingQuestion =>
      'Bisakah Anda menyediakan tempat tinggal terpisah?';

  @override
  String get onboarding_label_lastName => 'Nama belakang';

  @override
  String get onboarding_label_leadership => 'Kepemimpinan Agama';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Bolehkah memimpin salat berjamaah?';

  @override
  String get onboarding_label_lifestyleDiet => 'Gaya Hidup & Pola Makan';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'Ini adalah ladang pelanggar bagi banyak keluarga. Tolong jawab dengan jujur.';

  @override
  String get onboarding_label_livingExpectation =>
      'Harapan hidup pasca menikah';

  @override
  String get onboarding_label_mahrBudget => 'Anggaran Mahr';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'Berapa kisaran mahar yang siap Anda tawarkan?';

  @override
  String get onboarding_label_mahrExpectation => 'Harapan Mahr';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'Apa harapanmu terhadap mahar?';

  @override
  String get onboarding_label_maintenance => 'Pemeliharaan Keuangan';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Apakah Anda mampu menafkahi pasangan secara finansial?';

  @override
  String get onboarding_label_male => 'Pria';

  @override
  String get onboarding_label_marriageTimeline => 'Garis Waktu Pernikahan';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'Kapan Anda ingin menikah?';

  @override
  String get onboarding_label_moderate => 'Sedang';

  @override
  String get onboarding_label_motherTongue => 'Bahasa ibu';

  @override
  String get onboarding_label_niqab => 'Niqab';

  @override
  String get onboarding_label_practicing => 'Berlatih';

  @override
  String get onboarding_label_praysFiveDaily => 'Saya berdoa lima kali sehari';

  @override
  String get onboarding_label_preferNotToSay =>
      'Memilih untuk tidak mengatakannya';

  @override
  String get onboarding_label_preferredLiving =>
      'Preferensi pengaturan tempat tinggal';

  @override
  String get onboarding_label_profession => 'Profesi';

  @override
  String get onboarding_label_providerReadiness => 'Kesiapan Penyedia';

  @override
  String get onboarding_label_quranMemorization => 'Hafalan Alquran';

  @override
  String get onboarding_label_religiousEducation => 'Pendidikan agama';

  @override
  String get onboarding_label_residencyStatus =>
      'Status Tempat Tinggal (Opsional)';

  @override
  String get onboarding_label_revert => 'Kembalikan / Konversi (Opsional)';

  @override
  String get onboarding_label_revertQuestion =>
      'Apakah Anda seorang yang masuk Islam (mualaf)?';

  @override
  String get onboarding_label_sect => 'Sekte';

  @override
  String get onboarding_label_shia => 'Syiah';

  @override
  String get onboarding_label_smoking => 'Merokok';

  @override
  String get onboarding_label_specialNeeds => 'Kebutuhan Khusus (Opsional)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'Langkah $current dari $total';
  }

  @override
  String get onboarding_label_subSect => 'Aliran pemikiran (Opsional)';

  @override
  String get onboarding_label_substanceUse => 'Penggunaan Zat';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_vaping => 'Vaping / Rokok Elektrik';

  @override
  String get onboarding_label_workAfterMarriage => 'Bekerja Setelah Menikah';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Apakah Anda ingin bekerja setelah menikah?';

  @override
  String get onboarding_leadership_leads => 'Memimpin Doa';

  @override
  String get onboarding_leadership_learning => 'Sedang belajar';

  @override
  String get onboarding_leadership_notYet => 'Belum';

  @override
  String get onboarding_living_openToDiscussion => 'Terbuka untuk Diskusi';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Saya fleksibel dan senang mendiskusikan apa yang cocok untuk keduanya.';

  @override
  String get onboarding_living_separate => 'Rumah Terpisah';

  @override
  String get onboarding_living_separateSub =>
      'Saya lebih suka kita memiliki rumah mandiri sendiri.';

  @override
  String get onboarding_living_withInlaws => 'Dengan Mertua';

  @override
  String get onboarding_living_withInlawsSub =>
      'Saya berharap untuk tinggal bersama pasangan saya atau keluarga saya sendiri.';

  @override
  String get onboarding_location_confirmed => 'Lokasi Terkonfirmasi';

  @override
  String get onboarding_mahr_generous => 'Dermawan';

  @override
  String get onboarding_mahr_moderate => 'Sedang';

  @override
  String get onboarding_mahr_modest => 'Sederhana';

  @override
  String get onboarding_mahr_noPreference => 'Tidak ada preferensi';

  @override
  String get onboarding_mahr_toDiscuss => 'Untuk berdiskusi';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'Detail ini tidak ditampilkan di profil publik Anda. Mereka dibagikan secara pribadi selama tahap penerimaan.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Bantu kami memahami perjalanan dan kesiapan Anda.';

  @override
  String get onboarding_marriageDeen_title => 'Pernikahan & Dien';

  @override
  String get onboarding_niqab_dontWear => 'Saya tidak memakai niqab';

  @override
  String get onboarding_niqab_open => 'Terbuka untuk dipakai';

  @override
  String get onboarding_niqab_wear => 'Saya memakai niqab';

  @override
  String get onboarding_photo_subtitle =>
      'Setidaknya satu foto diperlukan. Foto utama Anda harus mencantumkan wajah Anda dengan jelas.';

  @override
  String get onboarding_photo_title => 'Tambahkan foto Anda';

  @override
  String get onboarding_photo_verifySelfie => 'Selfie Verifikasi';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Ambil foto langsung untuk memverifikasi bahwa Anda asli';

  @override
  String get onboarding_preferredLiving_noPreference => 'Tidak Ada Preferensi';

  @override
  String get onboarding_profileForWhom_creatingFor => 'Saya membuat ini untuk…';

  @override
  String get onboarding_profileForWhom_guardian => 'Putra atau putri saya';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'Saya membuat profil ini untuk seseorang';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Wali';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Saya adalah orang tua atau wali';

  @override
  String get onboarding_profileForWhom_myself => 'Saya sendiri';

  @override
  String get onboarding_profileForWhom_myselfSub => 'Saya mencari pasangan';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Saudara laki-laki';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Anak perempuan';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Saudari';

  @override
  String get onboarding_profileForWhom_relation_son => 'Putra';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'Pilih satu untuk melanjutkan';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Pilih hubungan untuk melanjutkan';

  @override
  String get onboarding_profileForWhom_sibling => 'Kakak atau adikku';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Saya membantu saudara saya menemukan kecocokan';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'Anda dapat memperbaruinya nanti dari pengaturan.';

  @override
  String get onboarding_profileForWhom_title => 'Untuk siapa profil ini?';

  @override
  String get onboarding_profileForWhom_ward => 'Bangsal saya';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Saya seorang wali yang mengelola profil ini';

  @override
  String get onboarding_providerQuote =>
      '“Sebaik-baik kalian adalah yang terbaik terhadap istri kalian.” — Nabi Muhammad ﷺ\n\nJujur tentang kesiapan Anda membantu membangun landasan yang kuat.';

  @override
  String get onboarding_quran_hafiz => 'Hafiz / Hafiza';

  @override
  String get onboarding_quran_none => 'Tidak ada';

  @override
  String get onboarding_quran_partial => 'Hifz Parsial';

  @override
  String get onboarding_quran_some => 'Beberapa Surat';

  @override
  String get onboarding_religiousEdu_alim => 'Kursus Alim';

  @override
  String get onboarding_religiousEdu_islamicUni => 'Universitas Islam';

  @override
  String get onboarding_religiousEdu_madrasa => 'Madrasah';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Otodidak';

  @override
  String get onboarding_timeline_1year => 'Dalam setahun';

  @override
  String get onboarding_timeline_2years => '2+ tahun';

  @override
  String get onboarding_timeline_6months => 'Dalam waktu 6 bulan';

  @override
  String get onboarding_timeline_asap => 'Secepat mungkin';

  @override
  String get onboarding_timeline_notSure => 'Belum yakin';

  @override
  String get onboarding_tooltip_cultural =>
      'Mengidentifikasi sebagai Muslim, merayakan acara-acara, mungkin tidak berdoa secara teratur';

  @override
  String get onboarding_tooltip_moderate =>
      'Menjunjung prinsip Islam dan salat, meski tidak selalu lima waktu sehari';

  @override
  String get onboarding_tooltip_practicing =>
      'Mengikuti kelima rukun, shalat teratur, gaya hidup halal';

  @override
  String get onboarding_work_no =>
      'Tidak, saya memilih untuk tidak melakukannya';

  @override
  String get onboarding_work_yes => 'Ya, saya berencana untuk bekerja';

  @override
  String get photo_add_main_required => 'Tambahkan foto utama\n(wajib)';

  @override
  String get photo_add_photo => 'Tambahkan foto';

  @override
  String get photo_banner_text =>
      'Foto dengan konten eksplisit tidak diperbolehkan';

  @override
  String get photo_error_no_face_detected =>
      'Tidak ada wajah yang terlihat — coba lagi dengan foto wajah yang jelas';

  @override
  String photo_error_pick_failed(Object error) {
    return 'Tidak dapat memilih foto: $error';
  }

  @override
  String get photo_face_detected => 'Wajah terdeteksi ✓';

  @override
  String get photo_label_photo2 => 'Foto 2';

  @override
  String get photo_label_photo3 => 'Foto 3';

  @override
  String get photo_label_primary => 'Foto utama';

  @override
  String get photo_label_selfie => 'Foto 4';

  @override
  String get photo_no_face => 'Tidak ada wajah yang terlihat';

  @override
  String get photo_privacy_everyone => 'Terlihat oleh semua orang';

  @override
  String get photo_privacy_everyone_sub =>
      'Semua anggota dapat melihat foto Anda.';

  @override
  String get photo_privacy_label => 'PRIVASI FOTO';

  @override
  String get photo_privacy_mutual => 'Terlihat setelah kepentingan bersama';

  @override
  String get photo_privacy_mutual_sub =>
      'Foto hanya terungkap ketika kedua belah pihak menyatakan minat.';

  @override
  String get photo_privacy_request => 'Permintaan untuk melihat';

  @override
  String get photo_privacy_request_sub =>
      'Foto diburamkan sampai Anda menyetujui permintaan.';

  @override
  String get photo_sheet_camera => 'Kamera';

  @override
  String get photo_sheet_gallery => 'Galeri';

  @override
  String get photo_sheet_title => 'Pilih Sumber Foto';

  @override
  String get photo_slots_help => 'KETUK SLOT UNTUK UPLOAD';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'Tambahkan foto $relation Anda. Setidaknya satu diperlukan.';
  }

  @override
  String get photo_subtitle_self =>
      'Setidaknya satu foto diperlukan. Maksimal empat.';

  @override
  String get photo_title_guardian => 'Tambahkan foto mereka';

  @override
  String get photo_title_self => 'Tambahkan foto Anda';

  @override
  String get preferences_deen_any => 'Setiap';

  @override
  String get preferences_deen_cultural => 'Muslim Budaya';

  @override
  String get preferences_deen_moderate => 'Sedang';

  @override
  String get preferences_deen_practicing => 'Berlatih';

  @override
  String get preferences_edu_any => 'Setiap';

  @override
  String get preferences_edu_bachelors => 'Sarjana +';

  @override
  String get preferences_edu_diploma => 'Ijazah +';

  @override
  String get preferences_edu_masters => '+ Guru';

  @override
  String get preferences_edu_phd => 'PhD saja';

  @override
  String get preferences_edu_secondary => 'Sekunder +';

  @override
  String get preferences_label_age => 'RENTANG USIA';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max tahun';
  }

  @override
  String get preferences_label_deen => 'PREFERENSI TINGKAT DEEN';

  @override
  String get preferences_label_edu => 'PENDIDIKAN MINIMAL';

  @override
  String get preferences_label_living => 'PREFERENSI PENATAAN HIDUP';

  @override
  String get preferences_label_location => 'LOKASI';

  @override
  String get preferences_label_openness => 'KETERBUKAAN';

  @override
  String get preferences_label_sect => 'PREFERENSI SEKTOR';

  @override
  String get preferences_living_discussion => 'Terbuka untuk Diskusi';

  @override
  String get preferences_living_family => 'Dengan Keluarga';

  @override
  String get preferences_living_no_pref => 'Tidak Ada Preferensi';

  @override
  String get preferences_living_separate => 'Rumah Terpisah';

  @override
  String get preferences_location_abroad => 'Terbuka untuk luar negeri';

  @override
  String get preferences_location_diaspora => 'Modus diaspora';

  @override
  String get preferences_location_same_city => 'Kota yang sama';

  @override
  String get preferences_location_same_country => 'Negara yang sama';

  @override
  String get preferences_open_children =>
      'Terbuka untuk seseorang yang memiliki anak';

  @override
  String get preferences_open_divorced =>
      'Terbuka untuk seseorang yang sebelumnya bercerai';

  @override
  String get preferences_open_widowed =>
      'Terbuka untuk seseorang yang sebelumnya menjanda';

  @override
  String get preferences_sect_any => 'Setiap';

  @override
  String get preferences_sect_same => 'Sama seperti milikku';

  @override
  String get preferences_sect_shia => 'Syiah';

  @override
  String get preferences_sect_sunni => 'Sunni';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'Tetapkan preferensi untuk pasangan ideal $relation Anda.';
  }

  @override
  String get preferences_subtitle_self =>
      'Ini adalah preferensi, bukan filter keras.';

  @override
  String get preferences_title => 'Preferensi mitra';

  @override
  String get preview_age_label => 'Usia';

  @override
  String get preview_background => 'Latar belakang';

  @override
  String get preview_basic_info => 'Info Dasar';

  @override
  String get preview_city_label => 'Kota';

  @override
  String get preview_community_label => 'Masyarakat';

  @override
  String get preview_cowife_label => 'Penerimaan Rekan Istri';

  @override
  String get preview_deen_label => 'Tingkat Dien';

  @override
  String get preview_diet_label => 'Diet';

  @override
  String get preview_edit => 'Sunting';

  @override
  String get preview_education_label => 'Pendidikan';

  @override
  String get preview_faith => 'Keyakinan';

  @override
  String get preview_family => 'Keluarga';

  @override
  String get preview_family_type_label => 'Tipe keluarga';

  @override
  String get preview_gender_label => 'Jenis kelamin';

  @override
  String get preview_hijab_label => 'jilbab';

  @override
  String get preview_hookah_label => 'Pipa';

  @override
  String get preview_leadership_label => 'Kepemimpinan';

  @override
  String get preview_marital_label => 'Perkawinan';

  @override
  String get preview_marriage_timeline_label => 'Garis Waktu Pernikahan';

  @override
  String get preview_mother_tongue_label => 'Bahasa ibu';

  @override
  String get preview_name_label => 'Nama';

  @override
  String get preview_notice_guardian =>
      'Ini adalah bagaimana orang lain akan melihat profil mereka.';

  @override
  String get preview_notice_self =>
      'Ini adalah cara orang lain melihat profil Anda.';

  @override
  String get preview_polygamy_label => 'Poligami';

  @override
  String get preview_post_marriage_living_label => 'Kehidupan Pasca Pernikahan';

  @override
  String get preview_prays_label => 'Sholat 5x';

  @override
  String get preview_profession_label => 'Profesi';

  @override
  String get preview_quran_label => 'Alquran';

  @override
  String get preview_religious_edu_label => 'Pendidikan agama';

  @override
  String get preview_residency_label => 'Tempat tinggal';

  @override
  String get preview_revert_label => 'Kembali';

  @override
  String get preview_sect_label => 'Sekte';

  @override
  String get preview_siblings_label => 'Saudara';

  @override
  String get preview_smoking_label => 'Merokok';

  @override
  String get preview_special_needs_label => 'Kebutuhan Khusus';

  @override
  String get preview_submit_btn => 'Kirim Profil';

  @override
  String get preview_title => 'Pratinjau';

  @override
  String get preview_vaping_label => 'menguap';

  @override
  String get preview_willing_relocate_label => 'Bersedia untuk Pindah';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil $percent% selesai';
  }

  @override
  String get profile_nudge_completeness =>
      'Profil dengan kelengkapan 80%+ menerima minat 3× lebih banyak.';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · Demi Allah';

  @override
  String get settings_button_deleteAccount => 'Hapus Akun';

  @override
  String get settings_guardian_mirror => 'Pesan Cermin';

  @override
  String get settings_guardian_mirror_sub =>
      'Kirim salinan semua pesan ke wali';

  @override
  String get settings_guardian_name_hint => 'Nama Wali';

  @override
  String get settings_guardian_relationship => 'Hubungan';

  @override
  String get settings_guardian_reply => 'Izinkan Wali untuk Membalas';

  @override
  String get settings_guardian_reply_sub =>
      'Wali dapat berpartisipasi dalam percakapan';

  @override
  String get settings_guardian_save => 'Simpan Pengaturan Wali';

  @override
  String get settings_guardian_saved => 'Disimpan';

  @override
  String get settings_guardian_sub =>
      'Aktifkan pengawasan Wali untuk pengiriman pesan';

  @override
  String get settings_guardian_title => 'Modus Penjaga';

  @override
  String get settings_label_blocked => 'Profil yang Diblokir';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count diblokir';
  }

  @override
  String get settings_label_blocked_none => 'Tidak ada';

  @override
  String get settings_label_deleteGrace =>
      'Profil Anda akan segera disembunyikan. Data Anda akan dihapus secara permanen setelah 30 hari.';

  @override
  String get settings_label_editProfile => 'Sunting Profil';

  @override
  String get settings_label_language => 'Bahasa';

  @override
  String get settings_label_photoPrivacy => 'Privasi Foto';

  @override
  String get settings_label_rate => 'Nilai Silarah';

  @override
  String get settings_label_rate_snackbar =>
      'Peringkat akan tersedia setelah Silarah diluncurkan di app store.';

  @override
  String get settings_label_reports => 'Laporan Sejarah';

  @override
  String settings_label_reports_count(Object count) {
    return '$count laporan';
  }

  @override
  String get settings_label_reports_none => 'Tidak ada laporan yang diserahkan';

  @override
  String get settings_label_selfieChallenge => 'Tantangan Selfie';

  @override
  String get settings_label_verifyProfile => 'Verifikasi Profil';

  @override
  String get settings_label_version => 'Versi';

  @override
  String get settings_notify_activityNudges => 'Dorongan Aktivitas';

  @override
  String get settings_notify_activityNudgesSub =>
      'Tips profil dan pengingat setelah 7 hari tidak aktif';

  @override
  String get settings_notify_boostReminders => 'Tingkatkan Pengingat';

  @override
  String get settings_notify_boostRemindersSub =>
      'Ingatkan kapan peningkatan mingguan Anda siap';

  @override
  String get settings_notify_interestAccepted => 'Bunga Diterima';

  @override
  String get settings_notify_interestExpiring => 'Bunga Segera Berakhir';

  @override
  String get settings_notify_newInterest => 'Minat Baru';

  @override
  String get settings_notify_newMessage => 'Pesan Baru';

  @override
  String get settings_notify_quietHours => 'Jam Tenang';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'Hanya kepentingan yang diterima';

  @override
  String get settings_photo_privacy_after_acceptance => 'Setelah Penerimaan';

  @override
  String get settings_photo_privacy_everyone => 'Setiap orang';

  @override
  String get settings_photo_privacy_public => 'Publik';

  @override
  String get settings_photo_privacy_request_only => 'Hanya Permintaan';

  @override
  String get settings_photo_privacy_request_to_view =>
      'Permintaan untuk melihat';

  @override
  String get settings_privacy_download_body =>
      'Buat sekarang arsip ZIP pribadi berisi akun, profil, foto, minat, kecocokan, pesan, pengaturan, persetujuan, dan riwayat langganan Anda. Simpan melalui lembar berbagi aman di perangkat.';

  @override
  String get settings_privacy_download_btn => 'Buat arsip aman';

  @override
  String get settings_privacy_download_label => 'Unduh data saya';

  @override
  String get settings_privacy_download_sub =>
      'Simpan salinan data Silarah yang dapat dibaca mesin';

  @override
  String get settings_privacy_export_body =>
      'Arsip pribadi Anda siap. Gunakan lembar berbagi untuk menyimpannya dengan aman.';

  @override
  String get settings_privacy_export_btn_close => 'Dipahami';

  @override
  String get settings_privacy_export_subbody =>
      'Arsip ini mungkin berisi pesan pribadi dan detail kontak. Simpan dengan aman dan bagikan hanya kepada orang yang Anda percaya.';

  @override
  String get settings_privacy_export_title => 'Arsip siap';

  @override
  String get settings_privacy_online_label => 'STATUS ONLINE';

  @override
  String get settings_privacy_online_sub =>
      'Tunjukkan kapan Anda terakhir aktif';

  @override
  String get settings_privacy_pause_label => 'Jeda profil';

  @override
  String get settings_privacy_pause_sub =>
      'Sembunyikan profil Anda dari pencarian';

  @override
  String get settings_privacy_pause_warning =>
      'Profil Anda disembunyikan. Tidak ada yang bisa menemukanmu.';

  @override
  String get settings_privacy_photo_label => 'Visibilitas foto';

  @override
  String get settings_privacy_photo_sub => 'Siapa yang dapat melihat foto Anda';

  @override
  String get settings_privacy_visibility_all => 'Semua pengguna terdaftar';

  @override
  String get settings_privacy_visibility_label =>
      'SIAPA YANG DAPAT MELIHAT PROFIL SAYA';

  @override
  String get settings_privacy_visibility_sub =>
      'Mengontrol siapa yang dapat menelusuri profil Anda';

  @override
  String get settings_privacy_visibility_subscribers => 'Hanya pelanggan';

  @override
  String get settings_relation_brother => 'Saudara laki-laki';

  @override
  String get settings_relation_father => 'Ayah';

  @override
  String get settings_relation_mother => 'Ibu';

  @override
  String get settings_relation_other => 'Lainnya';

  @override
  String get settings_relation_uncle => 'Paman';

  @override
  String get settings_section_account => 'Akun';

  @override
  String get settings_section_app => 'Aplikasi';

  @override
  String get settings_section_dangerZone => 'Tutup akun';

  @override
  String get settings_section_guardian => 'Wali';

  @override
  String get settings_section_legal => 'Legal';

  @override
  String get settings_section_notifications => 'Pemberitahuan';

  @override
  String get settings_section_privacy => 'Pribadi';

  @override
  String get settings_section_safety => 'Keamanan';

  @override
  String get settings_support_body =>
      'Untuk pertanyaan, kekhawatiran, atau masukan apa pun:';

  @override
  String get settings_support_btn_close => 'Menutup';

  @override
  String get settings_support_contact => 'Hubungi Dukungan';

  @override
  String get settings_support_note =>
      'Kami bertujuan untuk merespons dalam waktu 48 jam.';

  @override
  String get settings_title => 'Pengaturan';

  @override
  String get splash_button_createProfile => 'Buat Profil';

  @override
  String get splash_button_signIn => 'Masuk';

  @override
  String get splash_intention_subtitle =>
      'Perkenalan privat, kecocokan yang dipertimbangkan, dan koneksi yang menghargai keluarga.';

  @override
  String get splash_intention_title => 'Pernikahan, dijalani dengan niat.';

  @override
  String get splash_referral_button => 'Terapkan Kode';

  @override
  String get splash_referral_hint => 'misalnya SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'Silakan masukkan kode 6 karakter yang valid.';

  @override
  String get splash_referral_question => 'Punya kode referral?';

  @override
  String get splash_referral_saved =>
      'Kode referensi disimpan! Ini akan diterapkan setelah Anda masuk.';

  @override
  String get splash_referral_subtitle =>
      'Jika seorang teman mengundang Anda ke Silarah, masukkan kode referensi 6 karakter mereka di bawah.';

  @override
  String get splash_referral_title => 'Masukkan Kode Referensi';

  @override
  String subscription_button_monthly(String price) {
    return 'Berlangganan — $price/bulan';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'Berlangganan — $price/3 bulan';
  }

  @override
  String get subscription_label_bestValue => 'Nilai Terbaik';

  @override
  String get subscription_subtitle =>
      'Pesan wanita gratis. Pria berlangganan untuk terhubung.';

  @override
  String get subscription_title => 'Buka kunci Silarah';

  @override
  String get startup_connectivity_preparing_title =>
      'Menyiapkan ruang pribadi Anda';

  @override
  String get startup_connectivity_preparing_body =>
      'Membangun koneksi aman ke Silarah.';

  @override
  String get startup_connectivity_offline_title => 'Menunggu koneksi';

  @override
  String get startup_connectivity_offline_body =>
      'Profil, minat, dan percakapan Anda aman. Silarah akan melanjutkan tepat dari tempat Anda berhenti begitu Anda kembali online.';

  @override
  String get startup_connectivity_verifying => 'MEMERIKSA KONEKSI';

  @override
  String get startup_connectivity_waiting => 'MENUNGGU JARINGAN';

  @override
  String get startup_connectivity_still_waiting =>
      'MASIH OFFLINE · MENCOBA LAGI';

  @override
  String get startup_connectivity_check => 'Coba lagi';

  @override
  String get startup_connectivity_checking => 'Memeriksa…';

  @override
  String get startup_connectivity_auto =>
      'Kami akan tersambung kembali otomatis saat jaringan kembali.';

  @override
  String get startup_connectivity_tip =>
      'Pastikan Wi-Fi atau data seluler aktif.';

  @override
  String get startup_connectivity_protected => 'Koneksi terlindungi';

  @override
  String get settings_label_email => 'Email';

  @override
  String get settings_notify_profileViews => 'Kunjungan profil';

  @override
  String get settings_notify_profileViewsSub =>
      'Pemberitahuan pribadi saat seseorang membuka profil Anda';

  @override
  String get settings_notify_profileLive => 'Profil mulai tayang';

  @override
  String get settings_notify_profileLiveSub =>
      'Konfirmasi saat profil Anda mulai terlihat';

  @override
  String get settings_appearance => 'Tampilan';

  @override
  String get settings_helpSupport => 'Bantuan & Dukungan';

  @override
  String get settings_helpCenter => 'Pusat Bantuan';

  @override
  String get settings_grievanceOfficer => 'Petugas Pengaduan';

  @override
  String get settings_grievanceResponse =>
      'Diterima dalam 24 jam; sebagian besar keluhan selesai dalam 7 hari';

  @override
  String get settings_grievanceIndiaNotice =>
      'Penanganan keluhan di India mengikuti Peraturan Teknologi Informasi (Pedoman Perantara dan Kode Etik Media Digital) sebagaimana diubah. Keluhan mendesak tentang konten melanggar hukum atau intim mengikuti tenggat hukum yang lebih singkat.';

  @override
  String get settings_managePhotoRequests => 'Kelola permintaan foto';

  @override
  String get settings_managePhotoRequestsSub =>
      'Setujui akses, tolak permintaan, atau cabut berbagi';

  @override
  String get settings_theme_chooseTitle => 'Pilih suasana Anda';

  @override
  String get settings_theme_chooseSubtitle =>
      'Identitas visual yang menyeluruh, bukan sekadar filter warna. Semua permukaan, kolom, dan kontrol sistem berubah bersama.';

  @override
  String get settings_theme_applied =>
      'Langsung diterapkan · disimpan di perangkat ini';

  @override
  String get settings_reportPending => 'Menunggu tinjauan';

  @override
  String get legal_document_terms => 'Ketentuan Layanan';

  @override
  String get legal_document_privacy => 'Kebijakan Privasi';

  @override
  String get legal_document_community => 'Pedoman Komunitas';

  @override
  String get legal_specialCategoryConsent =>
      'Saya secara tegas menyetujui Silarah memproses informasi agama saya (mazhab, praktik salat, dan identitas Islam) untuk pencocokan kompatibilitas. Penyedia layanan yang dikontrak hanya menggunakannya untuk mengoperasikan Silarah, bukan untuk iklan berbasis perilaku.';

  @override
  String get onboarding_complexion_fair => 'Cerah';

  @override
  String get onboarding_complexion_medium => 'Sedang';

  @override
  String get onboarding_complexion_olive => 'Zaitun';

  @override
  String get onboarding_complexion_dark => 'Gelap';

  @override
  String get onboarding_residency_citizen => 'Warga negara';

  @override
  String get onboarding_residency_permanentResident => 'Penduduk tetap';

  @override
  String get onboarding_residency_workVisa => 'Visa kerja';

  @override
  String get onboarding_residency_studentVisa => 'Visa pelajar';

  @override
  String get onboarding_specialNeeds_none => 'Tidak ada';

  @override
  String get onboarding_specialNeeds_physical => 'Disabilitas fisik';

  @override
  String get onboarding_specialNeeds_hearing => 'Gangguan pendengaran';

  @override
  String get onboarding_specialNeeds_visual => 'Gangguan penglihatan';

  @override
  String get onboarding_label_stateRegion => 'Provinsi / Wilayah';

  @override
  String get onboarding_specialNeeds_privacy =>
      'Hanya dibagikan setelah ada minat bersama.';

  @override
  String get settings_theme_automatic => 'Otomatis';

  @override
  String get settings_theme_automaticDesc =>
      'Gading & Zamrud di siang hari, Malam OLED saat ponsel dalam mode gelap';

  @override
  String get settings_theme_rose => 'Mawar & Marigold';

  @override
  String get settings_theme_roseDesc =>
      'Merah muda lembut dengan mawar tua dan emas marigold';

  @override
  String get settings_theme_oled => 'Malam OLED';

  @override
  String get settings_theme_oledDesc =>
      'Hitam sejati yang disesuaikan untuk layar OLED';

  @override
  String get settings_theme_ivory => 'Gading & Zamrud';

  @override
  String get settings_theme_ivoryDesc =>
      'Gading hangat, zamrud tua, dan emas antik';

  @override
  String get settings_guardian_backendRequired =>
      'Pengaturan wali memerlukan koneksi aman.';

  @override
  String get settings_guardian_saveError =>
      'Pengaturan wali tidak dapat disimpan. Coba lagi.';

  @override
  String get common_openSettings => 'Buka Pengaturan';

  @override
  String get media_cameraAccessOff => 'Akses kamera dinonaktifkan';

  @override
  String get media_cameraUnavailable => 'Kamera tidak tersedia';

  @override
  String get media_cameraAccessBody =>
      'Izinkan akses kamera di Pengaturan, lalu kembali untuk mengambil foto yang jelas.';

  @override
  String get media_cameraUnavailableBody =>
      'Kamera tidak dapat dibuka. Coba lagi.';

  @override
  String get media_photoAccessOff => 'Akses foto dinonaktifkan';

  @override
  String get media_photoAccessBody =>
      'Izinkan akses kamera atau foto di Pengaturan, lalu kembali untuk menambahkan foto.';

  @override
  String get chat_searchHint => 'Cari pesan';

  @override
  String get chat_noConversationsFound => 'Percakapan tidak ditemukan';

  @override
  String get chat_noConversationsFoundBody =>
      'Coba nama lain atau hapus pencarian.';

  @override
  String get chat_noConversationsYet => 'Belum ada percakapan';

  @override
  String get chat_noConversationsYetBody =>
      'Terima minat atau tunggu minat Anda diterima untuk memulai percakapan.';

  @override
  String get referral_title => 'Ajak Teman';

  @override
  String get referral_loading => 'Memuat hadiah';

  @override
  String get referral_heading => 'Sebarkan kabar, dapatkan Premium!';

  @override
  String get referral_body =>
      'Undang teman mana pun yang memenuhi syarat ke Silarah. Setiap akun hanya dapat menerima satu hadiah Premium referral 3 hari. Jika Anda sudah menerima hadiah, teman Anda tetap dapat menerima hadiahnya.';

  @override
  String get referral_premiumActiveTitle => 'Premium referral aktif';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return 'Tersisa ${days}h ${hours}j';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return 'Tersisa ${hours}j ${minutes}m';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return 'Tersisa ${minutes}m';
  }

  @override
  String get referral_premiumEndingNow => 'Hadiah berakhir sekarang';

  @override
  String referral_premiumEndsAt(String date) {
    return 'Berakhir $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'Semua fitur Premium terbuka. Tidak ada pembayaran dan hadiah ini tidak diperpanjang otomatis.';

  @override
  String get referral_premiumPlansAfter =>
      'Paket langganan tersedia setelah hadiah gratis berakhir agar sisa waktu gratis Anda tidak terbuang.';

  @override
  String get referral_premiumBackToProfile => 'Kembali ke profil';

  @override
  String get referral_premiumFeaturesUnlocked => 'Semua fitur Premium terbuka';

  @override
  String get referral_premiumViewReward => 'Lihat hadiah';

  @override
  String get referral_codeLabel => 'KODE REFERAL ANDA';

  @override
  String get referral_tapToCopy => 'Ketuk kode untuk menyalin';

  @override
  String get referral_totalInvited => 'Total Diundang';

  @override
  String get referral_rewardsEarned => 'Hadiah Diperoleh';

  @override
  String referral_premiumDays(int count) {
    return '$count hari premium';
  }

  @override
  String get referral_pending => 'Pendaftaran Tertunda';

  @override
  String get referral_shareButton => 'Bagikan Kode kepada Teman';

  @override
  String get referral_copied => 'Kode referal disalin!';

  @override
  String get referral_shareSubject => 'Bergabung dengan Silarah';

  @override
  String referral_shareText(String code) {
    return 'Bergabunglah dengan Silarah, aplikasi pernikahan Muslim tepercaya. Gunakan kode referal saya: $code\n\nUnduh: https://silarah.com';
  }

  @override
  String get profile_share => 'Bagikan profil';

  @override
  String safety_reportMember(String name) {
    return 'Laporkan $name';
  }

  @override
  String safety_blockMember(String name) {
    return 'Blokir $name';
  }

  @override
  String safety_blockTitle(String name) {
    return 'Blokir $name?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name akan disembunyikan dari Discovery dan tidak dapat menghubungi Anda. Riwayat chat tetap disimpan demi keamanan. Membuka blokir tidak akan membuka kembali percakapan.';
  }

  @override
  String get safety_blockAction => 'Blokir';

  @override
  String safety_blocked(String name) {
    return '$name diblokir.';
  }

  @override
  String ui_openProfile(String name) {
    return 'Buka profil $name';
  }

  @override
  String ui_typing(String name) {
    return '$name sedang mengetik';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'Gagal menghapus akun: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'Ganti negara, saat ini $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'Tidak ada aplikasi email yang ditemukan. $email telah disalin.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'Pesan $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'Memperbarui $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age tahun';
  }

  @override
  String ui_photoNumber(int number) {
    return 'Foto $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count dari 4 foto';
  }

  @override
  String ui_removeLabel(String label) {
    return 'Hapus $label';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label dipilih';
  }

  @override
  String ui_addLabel(String label) {
    return 'Tambahkan $label';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'Permintaan foto dikirim ke $name.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'Kemarin $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count menit yang lalu';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count jam yang lalu';
  }

  @override
  String ui_daysAgo(int count) {
    return '$count hari yang lalu';
  }

  @override
  String ui_renewsAt(String time) {
    return 'Diperbarui pada $time';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'Foto $number siap untuk dilindungi tinjauan';
  }

  @override
  String get ui_onePhotoUnlock =>
      '1 foto akan terbuka secara otomatis setelah Anda berdua menyatakan minat.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return 'Foto $count akan terbuka secara otomatis setelah Anda berdua menyatakan minat.';
  }

  @override
  String get ui_askOnePhoto =>
      'Minta izin kepada pemilik untuk melihat 1 foto.';

  @override
  String ui_askManyPhotos(int count) {
    return 'Minta izin kepada pemilik untuk melihat foto $count.';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet kaki $inches masuk';
  }

  @override
  String ui_minutesShort(int count) {
    return '${count}m';
  }

  @override
  String ui_hoursShort(int count) {
    return '${count}jam';
  }

  @override
  String ui_daysShort(int count) {
    return '${count}d';
  }

  @override
  String discovery_filters_count(int count) {
    return 'Filter ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'Pernah cocok pada $date';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'Pencocokan ulang tersedia dalam $count hari';
  }

  @override
  String get settings_notify_compatibleProfiles =>
      'Peringatan profil yang cocok';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'Saat umpan Temukan yang kosong memiliki hasil baru';

  @override
  String get settings_notify_discoveryDigest => 'Ringkasan Temukan';

  @override
  String get settings_notify_digestHelp =>
      'Ringkasan opsional; peringatan hasil baru setelah umpan kosong tetap langsung.';

  @override
  String get settings_notify_digestOff => 'Nonaktif';

  @override
  String get settings_notify_digestDaily => 'Harian';

  @override
  String get settings_notify_digestWeekly => 'Mingguan';

  @override
  String get settings_quietHoursStart => 'Jam tenang dimulai';

  @override
  String get settings_quietHoursEnd => 'Jam tenang berakhir';

  @override
  String get settings_notify_festivalGreetings => 'Ucapan hari raya';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'Ucapan Ramadan dan Idulfitri, sekitar lima kali setahun';

  @override
  String get profile_quality_tier_complete => 'Lengkap';

  @override
  String get profile_quality_tier_strong => 'Hampir selesai';

  @override
  String get profile_quality_tier_good => 'Kemajuan baik';

  @override
  String get profile_quality_tier_start => 'Baru mulai';

  @override
  String profile_quality_ring_semantics(int percent) {
    return 'Profil $percent% lengkap';
  }

  @override
  String profile_quality_next_eyebrow(int percent) {
    return 'Langkah berikutnya · capai $percent%';
  }

  @override
  String profile_quality_points(int points) {
    return '+$points%';
  }

  @override
  String get profile_quality_step_photo => 'Tambahkan foto profil';

  @override
  String get profile_quality_step_bio => 'Tambahkan bio';

  @override
  String get profile_quality_step_deen => 'Lengkapi identitas Islam Anda';

  @override
  String get profile_quality_step_education =>
      'Tambahkan pendidikan & pekerjaan';

  @override
  String get profile_quality_step_family => 'Tambahkan latar belakang keluarga';

  @override
  String get profile_quality_step_partner => 'Atur preferensi pasangan';

  @override
  String get profile_quality_step_second_photo => 'Tambahkan foto kedua';

  @override
  String get profile_quality_step_income => 'Tambahkan kisaran penghasilan';

  @override
  String get profile_quality_step_languages => 'Tambahkan bahasa';

  @override
  String get profile_quality_complete_title => 'Profil Anda sudah lengkap';

  @override
  String get profile_quality_complete_body =>
      'Setiap detail sudah lengkap. Anggota melihat kisah Anda seutuhnya.';

  @override
  String get profile_quality_tip_verified_benefit =>
      'Wajah terverifikasi mendapat lebih banyak balasan';

  @override
  String get profile_quality_tip_photos_benefit =>
      'Lebih banyak foto membantu anggota berkata ya';

  @override
  String get profile_quality_tip_bio_benefit =>
      'Kata-kata Anda sendiri membentuk kesan pertama';

  @override
  String get profile_quality_tip_guardian_benefit =>
      'Keluarga menghargai wali yang terhubung';

  @override
  String get profile_quality_done => 'Selesai';

  @override
  String get profile_quality_name_fallback => 'Nama Anda';

  @override
  String get profile_quality_subtitle_fallback =>
      'Lengkapi profil Anda di bawah';
}
