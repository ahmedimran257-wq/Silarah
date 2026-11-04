// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get guide_optional_details => 'Ek bilgiler (isteğe bağlı)';

  @override
  String get guide_optional_details_body =>
      'Bu bilgileri daha sonra profilinizden tamamlayabilirsiniz.';

  @override
  String get guide_profile_ownership =>
      'Bu profil evlenmek isteyen kişiyi tanıtır. Görüşmelere nezaret etmesi için daha sonra ayrı bir Vasi davet edilebilir.';

  @override
  String get about_button_later => 'Bunu daha sonra yapacağım';

  @override
  String about_hint_bio_guardian(Object relation) {
    return '$relation\'nizi dürüstlük ve itibarla tanımlayın.';
  }

  @override
  String get about_hint_bio_self => 'Kendinizi dürüstlük ve onurla tanımlayın.';

  @override
  String get about_label_bio_guardian => 'ONLARIN BİYOLOJİKLERİ';

  @override
  String get about_label_bio_self => 'BİYOLOJİNİZ';

  @override
  String get about_label_interests => 'İLGİ ALANLARI';

  @override
  String get about_label_languages => 'KONUŞULAN DİLLER';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max seçildi';
  }

  @override
  String get about_subtitle => 'Dürüstlük ve onurla yazın.';

  @override
  String about_title_guardian(Object relation) {
    return '$relation cihazınız hakkında';
  }

  @override
  String get about_title_self => 'senin hakkında';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'Bismillah ile başla';

  @override
  String get auth_button_resendOtp => 'Doğrulama Kodunu Yeniden Gönder';

  @override
  String get auth_button_sendCode => 'Doğrulama Kodunu Gönder';

  @override
  String get auth_button_sendOtp => 'Doğrulama Kodunu Gönder';

  @override
  String get auth_button_verifyOtp => 'Doğrulamak';

  @override
  String get auth_label_changeNumber => 'Yanlış numara mı? Değiştir onu';

  @override
  String get auth_label_enterOtp =>
      'Gönderilen 6 haneli doğrulama kodunu girin';

  @override
  String get auth_label_resendCode => 'Doğrulama kodunu yeniden gönder';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'Doğrulama kodunu ${seconds}s içinde yeniden gönder';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return '${seconds}s içinde yeniden gönder';
  }

  @override
  String get auth_label_sentCodeTo =>
      '6 haneli doğrulama kodunu şu adrese gönderdik:';

  @override
  String get auth_subtitle_verifyOtp =>
      'Tek seferlik bir kodla doğrulayacağız.';

  @override
  String get auth_title_enterCode => 'Doğrulama kodunuzu girin';

  @override
  String get auth_title_yourNumber => 'Numaranız';

  @override
  String get background_edu_bachelors => 'Lisans';

  @override
  String get background_edu_below_secondary => 'İkincil Altında';

  @override
  String get background_edu_diploma => 'Diploma / Önlisans';

  @override
  String get background_edu_doctorate => 'Doktora / Doktora';

  @override
  String get background_edu_higher_secondary =>
      'Daha Yüksek Ortaokul / A-Seviyesi';

  @override
  String get background_edu_masters => 'Yüksek lisans';

  @override
  String get background_edu_secondary => 'İkincil / O-Seviyesi';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'Bize $relation çocuğunuzun eğitimi ve kariyeri hakkında bilgi verin.';
  }

  @override
  String get background_edu_subtitle_self =>
      'Profesyonel olarak uyumlu eşleşmeler bulmanıza yardımcı olur.';

  @override
  String get background_edu_title_guardian => 'Geçmişleri';

  @override
  String get background_edu_title_self => 'Geçmişiniz';

  @override
  String get background_emp_employed => 'Çalışan';

  @override
  String get background_emp_not_working => 'Çalışmıyor';

  @override
  String get background_emp_self_employed => 'Serbest meslek';

  @override
  String get background_emp_student => 'Öğrenci';

  @override
  String get background_income_subtitle =>
      'Pek çok kişi bunu atlıyor; bu tamamen isteğe bağlı.';

  @override
  String get background_label_eduLevel => 'EĞİTİM SEVİYESİ';

  @override
  String get background_label_employment => 'İSTİHDAM DURUMU';

  @override
  String background_label_income_bracket(Object currency) {
    return 'GELİR BRAKETİ ($currency)';
  }

  @override
  String get background_label_income_range => 'GELİR ARALIĞI (Opsiyonel)';

  @override
  String get background_label_profession => 'Meslek (İsteğe bağlı)';

  @override
  String get background_label_study => 'Çalışma alanı (İsteğe bağlı)';

  @override
  String get background_label_who_see => 'BUNU KİM GÖREBİLİR?';

  @override
  String get background_vis_everyone => 'Braketi herkese göster';

  @override
  String get background_vis_mutual =>
      'Yalnızca karşılıklı ilgiden sonra göster';

  @override
  String get background_vis_private => 'Gizli kal';

  @override
  String get ceremony_text_blessing => 'Allah bunu hayırla mübarek kılsın';

  @override
  String get chat_closure_1 =>
      'Selamun Aleyküm. Düşündükten sonra bunun bizim için doğru eşleşme olmayabileceğini hissettim. Size içtenlikle başarılar diliyor ve Allah\'ın size harika bir ortak vermesini diliyorum. CezakAllah hayr.';

  @override
  String get chat_closure_2 =>
      'Selamun Aleyküm. Sana karşı dürüst ve saygılı olmak istedim. Doğru eşleşme olduğumuzu düşünmüyorum ama Allah\'ın size daha iyi kapılar açmasını diliyorum. Size en iyisini diliyorum.';

  @override
  String get chat_closure_3 =>
      'Selamun Aleyküm. Samimi bir değerlendirmeden sonra uyumlu olamayacağımızı hissediyorum. Umarım senin için gerçekten doğru birini bulursun. Allah işlerinizi kolaylaştırsın. Zaman ayırdığınız için JazakAllah hayr.';

  @override
  String get chat_closure_4 =>
      'Selamun Aleyküm. Konuşmalarımızı düşündüm ve bu maçı şu anda bitirmenin en iyisi olduğunu düşünüyorum. Size saygıdan başka bir şeyim yok ve Allah\'ın sizi en iyi şekilde kutsaması için dua ediyorum.';

  @override
  String get chat_closure_5 =>
      'Selamun Aleyküm. Seninle kaybolmak yerine şeffaf olmak istedim. Bunun daha fazla ilerlediğini görmüyorum, ancak zaman ayırdığınız için gerçekten minnettarım ve size mutluluklar diliyorum. Allah sizden razı olsun.';

  @override
  String get chat_endMatch_button => 'Eşleşmeyi Gönder ve Bitir';

  @override
  String get chat_endMatch_subtitle =>
      'Bu konuşmayı kapatmak için saygılı bir mesaj seçin. Diğer kişiye bilgi verilecektir.';

  @override
  String get chat_endMatch_title => 'Bu maçı bitir';

  @override
  String chat_label_probation(int hours) {
    return 'Mesajlaşmanın kilidi $hours saat içinde açılacak. Şimdi İlgi Alanlarını gönderebilirsiniz.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Mesajlaşmanın kilidini açmak için abone olun. Kadınlar Silarah üzerinden her zaman ücretsiz mesaj atar.';

  @override
  String get chat_matchClosed_banner => 'Bu maç saygıyla kapatıldı.';

  @override
  String get chat_opener_1 =>
      'Selamun Aleyküm! Profilinize rastladım ve gerçekten etkilendim. Kendimi tanıtabilir miyim?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Profiliniz dikkatimi çekti. Senin hakkında daha fazlasını öğrenmeyi çok isterim.';

  @override
  String get chat_opener_3 =>
      'Selamun Aleyküm. Benzer değerleri paylaştığımıza inanıyorum. Birbirinizi tanımaya açık mısınız?';

  @override
  String get chat_placeholder_typeMessage => 'Bir mesaj yazın…';

  @override
  String get common_button_back => 'Geri';

  @override
  String get common_button_cancel => 'İptal etmek';

  @override
  String get common_button_done => 'Tamamlamak';

  @override
  String get common_button_next => 'Sonraki';

  @override
  String get common_button_retry => 'Tekrar deneyin';

  @override
  String get common_button_save => 'Kaydetmek';

  @override
  String get common_button_skip => 'Atlamak';

  @override
  String get common_button_submit => 'Göndermek';

  @override
  String get common_error_generic =>
      'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get common_error_noInternet =>
      'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.';

  @override
  String get common_label_optional => 'İsteğe bağlı';

  @override
  String get copy_beard_parent => 'Oğlunuzun sakalı var mı?';

  @override
  String get copy_beard_self => 'Sakalın var mı?';

  @override
  String get copy_beard_sibling => 'Kardeşinin sakalı var mı?';

  @override
  String get copy_hijab_parent => 'Kızınız başörtüsüne uyuyor mu?';

  @override
  String get copy_hijab_self => 'Başörtüsüne dikkat ediyor musun?';

  @override
  String get copy_hijab_sibling => 'Kız kardeşiniz başörtüsüne uyuyor mu?';

  @override
  String get copy_prayer_parent =>
      'Çocuğunuz günde beş vakit namaz kılıyor mu?';

  @override
  String get copy_prayer_self => 'Günde beş vakit namaz kılıyor musunuz?';

  @override
  String get copy_prayer_sibling =>
      'Kardeşiniz günde beş vakit namaz kılıyor mu?';

  @override
  String get deleteAccount_title => 'Hesabı Sil';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name kaldırıldı';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name kaydedildi';
  }

  @override
  String get discovery_button_sendInterest => 'İlgi Gönder';

  @override
  String get discovery_completeness_button => 'Profili Tamamla';

  @override
  String get discovery_completeness_subtitle =>
      '%40\'ın üzerindeki profiller 3 kat daha fazla ilgi görüyor.\nGöz atmaya başlamak için profilinizi tamamlayın.';

  @override
  String get discovery_completeness_title => 'Profilinizi Tamamlayın';

  @override
  String get discovery_empty_subtitle =>
      'Silarah\'a her gün yeni üyeler katılıyor. Yeni profiller için yarın tekrar bakın ya da şimdi daha fazla kişiyle tanışmak için tercihlerinizi genişletin.';

  @override
  String get discovery_empty_filtered_eyebrow => 'ARAMANIZI İNCELTİN';

  @override
  String get discovery_empty_filtered_title =>
      'Bu filtrelere henüz kimse uymuyor';

  @override
  String get discovery_empty_filtered_subtitle =>
      'Tercihleriniz çevreyi daraltıyor. Tek bir filtreyi gevşetmek genellikle hemen yeni profiller getirir.';

  @override
  String get discovery_empty_clear_filters => 'Tüm filtreleri temizle';

  @override
  String get discovery_empty_refresh => 'Profilleri yenile';

  @override
  String get discovery_empty_adjust_filters => 'Filtreleri düzenle';

  @override
  String get discovery_empty_hint_trust =>
      'Önce Güven kontrollerini gevşetmeyi deneyin';

  @override
  String get discovery_empty_hint_deen =>
      'Önce Din Seviyesini genişletmeyi deneyin';

  @override
  String get discovery_empty_hint_family =>
      'Önce Aile Tipini genişletmeyi deneyin';

  @override
  String get discovery_empty_hint_sect =>
      'Önce Mezhep filtresini açmayı deneyin';

  @override
  String get discovery_empty_hint_location =>
      'Önce daha geniş bir konum deneyin';

  @override
  String get discovery_empty_hint_age =>
      'Önce daha geniş bir yaş aralığı deneyin';

  @override
  String get discovery_empty_hint_other =>
      'Filtreleri birer birer gevşetmeyi deneyin';

  @override
  String get discovery_empty_eyebrow => 'HEPSİNİ GÖRDÜNÜZ';

  @override
  String get discovery_empty_title => 'Bugünlük herkesi gördünüz';

  @override
  String get discovery_handoff_interest_subtitle =>
      'Aktif isteği olan profiller, beklerken veya yanıt verirken İlgiler bölümüne taşınır.';

  @override
  String get discovery_handoff_interest_title => 'İlginiz devam ediyor';

  @override
  String get discovery_handoff_match_subtitle =>
      'Eşleşen profiller Sohbet\'e taşınır ve Keşfet\'te tekrar gösterilmez.';

  @override
  String get discovery_handoff_match_title => 'Bağlantınız hazır';

  @override
  String get discovery_handoff_open_chat => 'Sohbeti aç';

  @override
  String get discovery_handoff_open_interests => 'İlgileri aç';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'İlgi Gönderildi ✓';

  @override
  String get discovery_label_outsidePrefs => 'Bağlantı kurabileceğiniz biri';

  @override
  String discovery_label_profilesRemaining(int count) {
    return 'Bugün $count profil kaldı';
  }

  @override
  String get discovery_limit_button => 'Şimdi Yükselt';

  @override
  String get discovery_limit_subtitle =>
      'Bugün 15 profile göz attınız.\nSınırsız taramanın kilidini açmak için yükseltin.';

  @override
  String get discovery_limit_title => 'Günlük sınıra ulaşıldı';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count profil kaldı';
  }

  @override
  String get discovery_wildcard_label => 'Bağlantı kurabileceğiniz biri';

  @override
  String get family_children_no => 'HAYIR';

  @override
  String get family_children_yes => 'Evet';

  @override
  String get family_label_children_guardian => 'ÇOCUKLARI VAR MI?';

  @override
  String get family_label_children_self => 'ÇOCUKLARINIZ VAR MI?';

  @override
  String get family_label_how_many => 'KAÇ TANE?';

  @override
  String get family_label_parents => 'EBEVEYNLERİN MEDENİ DURUMU';

  @override
  String get family_label_polygamy_female_self =>
      'ÇOK eşliliğin kabulü (İsteğe bağlı)';

  @override
  String get family_label_polygamy_male_self =>
      'ÇOKEŞLİLİK DURUMU (İsteğe Bağlı)';

  @override
  String get family_label_prev_married => 'DAHA ÖNCE EVLİ MİYDİNİZ?';

  @override
  String get family_label_relocate => 'TAŞINMAYA İSTEKLİ';

  @override
  String get family_label_siblings => 'KARDEŞ SAYISI';

  @override
  String get family_label_type => 'AİLE TİPİ';

  @override
  String get family_living_title => 'EVLİLİK SONRASI YAŞAM BEKLENTİLERİ';

  @override
  String get family_parents_both_deceased => 'Her ikisi de merhum';

  @override
  String get family_parents_divorced => 'Boşanmış';

  @override
  String get family_parents_father_deceased => 'Baba vefat etti';

  @override
  String get family_parents_mother_deceased => 'Anne vefat etti';

  @override
  String get family_parents_separated => 'ayrılmış';

  @override
  String get family_parents_together => 'Birlikte';

  @override
  String get family_polygamy_female_discussion => 'Tartışmaya açık';

  @override
  String get family_polygamy_female_no => 'HAYIR';

  @override
  String get family_polygamy_female_prefer_not => 'Söylememeyi tercih ederim';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return '$relation eşiniz eş olmayı düşünür müydü?';
  }

  @override
  String get family_polygamy_female_sub_self => 'Eş-eş olmayı düşünür müsün?';

  @override
  String get family_polygamy_female_yes => 'Evet';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return '$relation çocuğunuz şu anda evli ve başka bir eş mi arıyor?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'Şu anda evli misiniz ve ek bir eş mi arıyorsunuz?';

  @override
  String get family_polygamy_option_first => 'Hayır, bu benim ilkim';

  @override
  String get family_polygamy_option_married => 'Evet şu anda evli';

  @override
  String get family_polygamy_option_prefer_not => 'Söylememeyi tercih ederim';

  @override
  String get family_prev_divorced => 'Boşanmış';

  @override
  String get family_prev_no => 'HAYIR';

  @override
  String get family_prev_widowed => 'Dul';

  @override
  String get family_relocate_discussion => 'Tartışmaya Açık';

  @override
  String get family_relocate_no => 'HAYIR';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return '$relation çocuğunuz evlilik için başka bir yere taşınır mı?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'Evlilik için şehir değiştirir misiniz?';

  @override
  String get family_relocate_yes => 'Evet';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'Bize $relation çocuğunuzun ailesinden bahsedin.';
  }

  @override
  String get family_subtitle_self =>
      'Aile uyumu kalıcı evliliklerin merkezinde yer alır.';

  @override
  String get family_title_guardian => 'Aile geçmişi';

  @override
  String get family_title_self => 'Aile geçmişi';

  @override
  String get family_type_extended => 'Uzatılmış';

  @override
  String get family_type_joint => 'Eklem yeri';

  @override
  String get family_type_nuclear => 'Nükleer';

  @override
  String get filter_label_community => 'Topluluk / Biradari';

  @override
  String get filter_label_livingExpectation => 'Evlilik Sonrası Yaşam';

  @override
  String get filter_label_motherTongue => 'Ana dil';

  @override
  String get guardian_details_candidate_female =>
      'Kadın aday • Kadınlara mesaj ücretsiz';

  @override
  String get guardian_details_candidate_label => 'PROFİL OLUŞTURUYORUZ';

  @override
  String get guardian_details_candidate_male => 'Erkek aday';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'Benim $relation';
  }

  @override
  String get guardian_details_involvement => 'KORUYUCU KATILIMI';

  @override
  String get guardian_details_involvement_subtitle =>
      'Konuşmalara ne kadar dahil olmak istiyorsunuz?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return '$relation adına sohbetleri görün, eşleşmeleri onaylayın ve mesaj gönderin.';
  }

  @override
  String get guardian_details_mode_active_title => 'Aktif koruyucu';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'Tüm sohbetleri gerçek zamanlı olarak görün, ancak yalnızca $relation cihazınız mesaj gönderebilir.';
  }

  @override
  String get guardian_details_mode_passive_title => 'Yalnızca gözlemle';

  @override
  String get guardian_details_name_hint => 'Ad Soyad';

  @override
  String get guardian_details_name_subtitle =>
      'Koruyucu olarak adınız. Bu eşleşmelere gösterilir.';

  @override
  String guardian_details_notice(Object relation) {
    return '$relation cihazınız için bir profil oluşturuyorsunuz. Sonraki ekranlardaki tüm profil detayları sizi değil onları anlatacaktır.';
  }

  @override
  String get guardian_details_search_hint => 'Aramak';

  @override
  String get guardian_details_select_code => 'Ülke kodunu seçin';

  @override
  String get guardian_details_subtitle =>
      'Bize koruyucu olarak kendinizden bahsedin.';

  @override
  String get guardian_details_title => 'Vasi ayrıntılarınız';

  @override
  String get guardian_details_your_name => 'ADINIZ';

  @override
  String get interest_cat_creative => 'Yaratıcı';

  @override
  String get interest_cat_faith => 'İnanç';

  @override
  String get interest_cat_learning => 'Öğrenme';

  @override
  String get interest_cat_lifestyle => 'Yaşam Tarzı';

  @override
  String get interest_cat_social => 'Sosyal';

  @override
  String get interest_cat_sports => 'Spor';

  @override
  String get interest_tag_art => 'Sanat';

  @override
  String get interest_tag_calligraphy => 'Kaligrafi';

  @override
  String get interest_tag_community_work => 'Topluluk çalışması';

  @override
  String get interest_tag_cooking => 'Yemek pişirmek';

  @override
  String get interest_tag_crafts => 'El sanatları';

  @override
  String get interest_tag_cricket => 'Kriket';

  @override
  String get interest_tag_cycling => 'Bisikletçilik';

  @override
  String get interest_tag_dawah => 'Davet';

  @override
  String get interest_tag_family_gatherings => 'Aile toplantıları';

  @override
  String get interest_tag_fitness => 'Fitness';

  @override
  String get interest_tag_football => 'Futbol';

  @override
  String get interest_tag_gardening => 'Bahçıvanlık';

  @override
  String get interest_tag_graphic_design => 'Grafik tasarım';

  @override
  String get interest_tag_hiking => 'Doğa yürüyüşü';

  @override
  String get interest_tag_history => 'Tarih';

  @override
  String get interest_tag_islamic_lectures => 'İslami dersler';

  @override
  String get interest_tag_languages => 'Diller';

  @override
  String get interest_tag_martial_arts => 'Dövüş sanatları';

  @override
  String get interest_tag_mentoring => 'Mentorluk';

  @override
  String get interest_tag_photography => 'Fotoğrafçılık';

  @override
  String get interest_tag_poetry => 'Şiir';

  @override
  String get interest_tag_quran_recitation => 'Kuran tilaveti';

  @override
  String get interest_tag_reading => 'Okuma';

  @override
  String get interest_tag_science => 'Bilim';

  @override
  String get interest_tag_swimming => 'Yüzme';

  @override
  String get interest_tag_tahajjud => 'Teheccüd';

  @override
  String get interest_tag_teaching => 'Öğretim';

  @override
  String get interest_tag_technology => 'Teknoloji';

  @override
  String get interest_tag_travel => 'Seyahat';

  @override
  String get interest_tag_umrah_hajj => 'Umre/Hac';

  @override
  String get interest_tag_voluntary_fasting => 'Gönüllü oruç';

  @override
  String get interest_tag_volunteering => 'Gönüllülük';

  @override
  String get interest_tag_writing => 'Yazma';

  @override
  String get interests_button_accept => 'Kabul etmek';

  @override
  String get interests_button_decline => 'Reddetmek';

  @override
  String get interests_tab_received => 'Kabul edilmiş';

  @override
  String get interests_tab_sent => 'Gönderilmiş';

  @override
  String get interests_title => 'İlgi alanları';

  @override
  String get lang_albanian => 'Arnavut';

  @override
  String get lang_amazigh => 'Amazigh (Berberi)';

  @override
  String get lang_amharic => 'Amharca';

  @override
  String get lang_arabic => 'Arapça';

  @override
  String get lang_assamese => 'Assam dili';

  @override
  String get lang_balochi => 'Beluci';

  @override
  String get lang_bengali => 'Bengalce';

  @override
  String get lang_bosnian => 'Boşnakça';

  @override
  String get lang_burmese => 'Birmanya';

  @override
  String get lang_chechen => 'Çeçen';

  @override
  String get lang_chinese => 'Çince (Mandarin)';

  @override
  String get lang_dari => 'Dari';

  @override
  String get lang_dutch => 'Flemenkçe';

  @override
  String get lang_english => 'İngilizce';

  @override
  String get lang_french => 'Fransızca';

  @override
  String get lang_fulani => 'Fulani';

  @override
  String get lang_german => 'Almanca';

  @override
  String get lang_gujarati => 'Gujarati dili';

  @override
  String get lang_hausa => 'Hausa';

  @override
  String get lang_hindi => 'Hintçe';

  @override
  String get lang_igbo => 'İbo';

  @override
  String get lang_indonesian => 'Endonezya dili';

  @override
  String get lang_italian => 'İtalyan';

  @override
  String get lang_japanese => 'Japonca';

  @override
  String get lang_javanese => 'Cava';

  @override
  String get lang_kannada => 'Kannadaca';

  @override
  String get lang_kazakh => 'Kazak';

  @override
  String get lang_korean => 'Korece';

  @override
  String get lang_kurdish => 'Kürt';

  @override
  String get lang_kyrgyz => 'Kırgız';

  @override
  String get lang_malay => 'Malayca';

  @override
  String get lang_malayalam => 'Malayalamca';

  @override
  String get lang_mandinka => 'Mandinka';

  @override
  String get lang_marathi => 'Marathi';

  @override
  String get lang_norwegian => 'Norveççe';

  @override
  String get lang_odia => 'Odia';

  @override
  String get lang_other => 'Diğer';

  @override
  String get lang_pashto => 'Peştuca';

  @override
  String get lang_persian => 'Farsça';

  @override
  String get lang_portuguese => 'Portekizce';

  @override
  String get lang_punjabi => 'Pencap';

  @override
  String get lang_rohingya => 'Rohingya';

  @override
  String get lang_russian => 'Rusça';

  @override
  String get lang_saraiki => 'Saraiki';

  @override
  String get lang_sindhi => 'Sindhi';

  @override
  String get lang_somali => 'Somalili';

  @override
  String get lang_spanish => 'İspanyol';

  @override
  String get lang_sundanese => 'Sundan dili';

  @override
  String get lang_swahili => 'Svahili';

  @override
  String get lang_swedish => 'İsveççe';

  @override
  String get lang_tagalog => 'Tagalogca';

  @override
  String get lang_tajik => 'Tacikçe';

  @override
  String get lang_tamil => 'Tamilce';

  @override
  String get lang_tatar => 'Tatar';

  @override
  String get lang_telugu => 'Telugu dili';

  @override
  String get lang_thai => 'Tay dili';

  @override
  String get lang_tigrinya => 'Tigrinya';

  @override
  String get lang_turkish => 'Türkçe';

  @override
  String get lang_urdu => 'Urduca';

  @override
  String get lang_uzbek => 'Özbekçe';

  @override
  String get lang_wolof => 'Wolof';

  @override
  String get lang_yoruba => 'Yoruba';

  @override
  String get legal_button_continue => 'Devam etmek';

  @override
  String get legal_checkbox_age =>
      '18 yaşında veya daha büyük olduğumu onaylıyorum';

  @override
  String get legal_checkbox_terms =>
      'Hizmet Şartlarını ve Gizlilik Politikasını kabul ediyorum';

  @override
  String get legal_subtitle => 'Lütfen okuyun ve devam etmeyi kabul edin.';

  @override
  String get legal_summary_1 =>
      'Verileriniz şifrelenir ve asla üçüncü şahıslara satılmaz.';

  @override
  String get legal_summary_2 =>
      'Her fotoğraf güvenlik kontrolünden geçer ve ekibimiz yeni fotoğrafları inceler.';

  @override
  String get legal_summary_3 =>
      'Taciz, sahte profiller ve dolandırıcılık, kalıcı yasaklamalarla sonuçlanır.';

  @override
  String get legal_summary_4 =>
      'Bu platform yalnızca evlilik niyetleri içindir. Onur standarttır.';

  @override
  String get legal_summary_5 =>
      'Hesabınızı ve tüm verilerinizi istediğiniz zaman silebilirsiniz.';

  @override
  String get legal_title => 'Başlamadan önce';

  @override
  String get notifications_empty_subtitle => 'Şu anda yeni bildirim yok.';

  @override
  String get notifications_empty_title => 'Hepiniz yakalandınız';

  @override
  String get notifications_markAllRead => 'Tümünü okundu olarak işaretle';

  @override
  String get notifications_title => 'Bildirimler';

  @override
  String get onboarding_about_title => 'Kendin hakkında';

  @override
  String get onboarding_background_title => 'Eğitim ve Kariyer';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'Bunu bir vasi olarak dolduruyorsunuz. Bu ayrıntılar $relation cihazınızla ilgilidir.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'Başkalarının profillerinde göreceği şey budur.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'Bu, başkalarının profilinizde göreceği şeydir.';

  @override
  String get onboarding_basicIdentity_title => 'Bize kendinizden bahsedin';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Bize $relation\'ınızdan bahsedin';
  }

  @override
  String get onboarding_debt_manageable => 'Yönetilebilir borç';

  @override
  String get onboarding_debt_none => 'Borç yok';

  @override
  String get onboarding_debt_significant => 'Önemli borç';

  @override
  String get onboarding_diet_eatsAnything => 'Helal olan her şeyi yer';

  @override
  String get onboarding_diet_halalOnly => 'Yalnızca Helal';

  @override
  String get onboarding_diet_vegan => 'vegan';

  @override
  String get onboarding_diet_vegetarian => 'Vejetaryen';

  @override
  String get onboarding_diet_zabihaStrict => 'Katı Zabiha';

  @override
  String get onboarding_error_bioContactInfo =>
      'Lütfen iletişim bilgilerinizi biyografinizden kaldırın. Güvenliğiniz için harici iletişim bilgilerine izin verilmez.';

  @override
  String get onboarding_error_multipleFaces =>
      'Grup fotoğrafları birincil fotoğrafınız olamaz.';

  @override
  String get onboarding_error_noFace =>
      'Lütfen yüzünüzün açıkça görülebileceği bir fotoğraf kullanın.';

  @override
  String get onboarding_error_under18 =>
      'Silarah 18 yaş ve üzeri içindir. Topluluğumuzdaki herkesi korumak için bu zorunluluğu getirdik.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Silarah\'ı kullanabilmek için $relation\'niz 18 yaşında veya daha büyük olmalıdır.';
  }

  @override
  String get onboarding_error_under18_self =>
      'Silarah\'ı kullanabilmek için 18 yaşında veya daha büyük olmanız gerekir. O zaman sizi ağırlamayı sabırsızlıkla bekliyoruz.';

  @override
  String get onboarding_habit_frequently => 'Sıklıkla';

  @override
  String get onboarding_habit_never => 'Asla';

  @override
  String get onboarding_habit_occasionally => 'Ara sıra';

  @override
  String get onboarding_habit_preferNotToSay => 'Söylememeyi tercih ederim';

  @override
  String get onboarding_hijab_always => 'Her zaman';

  @override
  String get onboarding_hijab_no => 'HAYIR';

  @override
  String get onboarding_hijab_sometimes => 'Bazen';

  @override
  String get onboarding_hint_bio => 'Kendinizi dürüstlük ve onurla tanımlayın.';

  @override
  String get onboarding_hint_profession =>
      'örneğin Yazılım Mühendisi, Öğretmen, Doktor';

  @override
  String get onboarding_hint_searchCity => 'Şehrinizi arayın…';

  @override
  String get onboarding_hint_selectCommunity =>
      'Topluluğu seçin (isteğe bağlı)';

  @override
  String get onboarding_hint_selectCountry => 'Ülke seçin';

  @override
  String get onboarding_hint_selectDateOfBirth => 'Doğum tarihini seçin';

  @override
  String get onboarding_hint_selectLanguage => 'Dil seçin';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'Bu, uyumlu biriyle eşleşmenize yardımcı olur.';

  @override
  String get onboarding_islamicIdentity_title => 'İslami Kimliğiniz';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'Şehir';

  @override
  String get onboarding_label_city_guardian => 'Onların şehri';

  @override
  String get onboarding_label_city_self => 'Şehriniz';

  @override
  String get onboarding_label_community => 'Topluluğunuz / biradari';

  @override
  String get onboarding_label_community_parent => 'Toplulukları / biradari';

  @override
  String get onboarding_label_complexion => 'Cilt (İsteğe bağlı)';

  @override
  String get onboarding_label_country_guardian => 'Onların ülkesi';

  @override
  String get onboarding_label_country_self => 'Ülkeniz';

  @override
  String get onboarding_label_cultural => 'Kültürel Müslüman';

  @override
  String get onboarding_label_dateOfBirth => 'Doğum Tarihi';

  @override
  String get onboarding_label_debtStatus => 'Borç Durumu';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Mevcut mali yükümlülükleriniz.';

  @override
  String get onboarding_label_deenLevel => 'Din Seviyesi';

  @override
  String get onboarding_label_diet => 'Diyet';

  @override
  String get onboarding_label_educationLevel => 'Eğitim Düzeyi';

  @override
  String get onboarding_label_female => 'Dişi';

  @override
  String get onboarding_label_firstName => 'İlk adı';

  @override
  String get onboarding_label_firstName_guardian => 'Adayın adı';

  @override
  String get onboarding_label_firstName_self => 'İlk adı';

  @override
  String get onboarding_label_gender => 'Cinsiyet';

  @override
  String get onboarding_label_gender_guardian => 'Adayın cinsiyeti';

  @override
  String get onboarding_label_gender_self => 'Cinsiyet';

  @override
  String get onboarding_label_height_guardian => 'Boyları';

  @override
  String get onboarding_label_height_self => 'Boyunuz';

  @override
  String get onboarding_label_hookah => 'Nargile / Nargile';

  @override
  String get onboarding_label_housing => 'Konut';

  @override
  String get onboarding_label_housingQuestion =>
      'Ayrı bir yaşam alanı sağlayabilir misiniz?';

  @override
  String get onboarding_label_lastName => 'Soy isim';

  @override
  String get onboarding_label_leadership => 'Dini Liderlik';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Cemaatle namaz kıldırabilir misiniz?';

  @override
  String get onboarding_label_lifestyleDiet => 'Yaşam Tarzı ve Diyet';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'Bunlar birçok aile için anlaşmayı bozan alanlardır. Lütfen dürüstçe cevap verin.';

  @override
  String get onboarding_label_livingExpectation =>
      'Evlilik sonrası yaşam beklentileri';

  @override
  String get onboarding_label_mahrBudget => 'Mahr Bütçesi';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'Hangi mahr serisini sunmaya hazırsınız?';

  @override
  String get onboarding_label_mahrExpectation => 'Mahr Beklentisi';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'Mahr\'dan beklentiniz nedir?';

  @override
  String get onboarding_label_maintenance => 'Finansal Bakım';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Eşinizin geçimini maddi olarak sağlayabiliyor musunuz?';

  @override
  String get onboarding_label_male => 'Erkek';

  @override
  String get onboarding_label_marriageTimeline => 'Evlilik Zaman Çizelgesi';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'Ne zaman evlenmeyi düşünüyorsun?';

  @override
  String get onboarding_label_moderate => 'Ilıman';

  @override
  String get onboarding_label_motherTongue => 'Ana dil';

  @override
  String get onboarding_label_niqab => 'Peçe';

  @override
  String get onboarding_label_practicing => 'pratik yapmak';

  @override
  String get onboarding_label_praysFiveDaily => 'Günde beş defa dua ediyorum';

  @override
  String get onboarding_label_preferNotToSay => 'Söylememeyi tercih ederim';

  @override
  String get onboarding_label_preferredLiving => 'Yaşam düzeni tercihi';

  @override
  String get onboarding_label_profession => 'Meslek';

  @override
  String get onboarding_label_providerReadiness => 'Sağlayıcı Hazırlığı';

  @override
  String get onboarding_label_quranMemorization => 'Kuran Ezberleme';

  @override
  String get onboarding_label_religiousEducation => 'Din Eğitimi';

  @override
  String get onboarding_label_residencyStatus => 'İkamet Durumu (İsteğe Bağlı)';

  @override
  String get onboarding_label_revert => 'Geri Döndür / Dönüştür (İsteğe bağlı)';

  @override
  String get onboarding_label_revertQuestion => 'İslam\'a dönenlerden misiniz?';

  @override
  String get onboarding_label_sect => 'Mezhep';

  @override
  String get onboarding_label_shia => 'Şii';

  @override
  String get onboarding_label_smoking => 'Sigara içmek';

  @override
  String get onboarding_label_specialNeeds => 'Özel İhtiyaçlar (İsteğe Bağlı)';

  @override
  String onboarding_label_step(int current, int total) {
    return '$total adımının $current adımı';
  }

  @override
  String get onboarding_label_subSect => 'Düşünce okulu (İsteğe bağlı)';

  @override
  String get onboarding_label_substanceUse => 'Madde Kullanımı';

  @override
  String get onboarding_label_sunni => 'Sünni';

  @override
  String get onboarding_label_vaping => 'Vaping / E-Sigaralar';

  @override
  String get onboarding_label_workAfterMarriage => 'Evlendikten Sonra Çalışmak';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Evlendikten sonra çalışmak ister misiniz?';

  @override
  String get onboarding_leadership_leads => 'Duaya Yol Açar';

  @override
  String get onboarding_leadership_learning => 'Öğrenme';

  @override
  String get onboarding_leadership_notYet => 'Henüz değil';

  @override
  String get onboarding_living_openToDiscussion => 'Tartışmaya Açık';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Esnekim ve her ikisi için de neyin işe yaradığını tartışmaktan mutluyum.';

  @override
  String get onboarding_living_separate => 'Ayrı Ev';

  @override
  String get onboarding_living_separateSub =>
      'Kendi bağımsız evimizin olmasını tercih ederim.';

  @override
  String get onboarding_living_withInlaws => 'Kayınvalidem ile';

  @override
  String get onboarding_living_withInlawsSub =>
      'Eşimin ya da kendi ailemin yanında yaşamayı düşünüyorum.';

  @override
  String get onboarding_location_confirmed => 'Onaylanmış Konum';

  @override
  String get onboarding_mahr_generous => 'Cömert';

  @override
  String get onboarding_mahr_moderate => 'Ilıman';

  @override
  String get onboarding_mahr_modest => 'Mütevazı';

  @override
  String get onboarding_mahr_noPreference => 'Tercih yok';

  @override
  String get onboarding_mahr_toDiscuss => 'tartışmak';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'Bu ayrıntılar genel profilinizde gösterilmez. Kabul aşamasında özel olarak paylaşılır.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Yolculuğunuzu ve hazırlık durumunuzu anlamamıza yardımcı olun.';

  @override
  String get onboarding_marriageDeen_title => 'Evlilik ve Din';

  @override
  String get onboarding_niqab_dontWear => 'Peçe takmıyorum';

  @override
  String get onboarding_niqab_open => 'Giymeye açık';

  @override
  String get onboarding_niqab_wear => 'Peçe takıyorum';

  @override
  String get onboarding_photo_subtitle =>
      'En az bir fotoğraf gereklidir. Ana fotoğrafınız yüzünüzü açıkça içermelidir.';

  @override
  String get onboarding_photo_title => 'Fotoğraflarınızı ekleyin';

  @override
  String get onboarding_photo_verifySelfie => 'Doğrulama Selfisi';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Gerçek olduğunuzu doğrulamak için canlı bir fotoğraf çekin';

  @override
  String get onboarding_preferredLiving_noPreference => 'Tercih Yok';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'Bunu benim için yaratıyorum…';

  @override
  String get onboarding_profileForWhom_guardian => 'Oğlum veya kızım';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'Bu profili birisi için oluşturuyorum';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Gardiyan';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Ben bir ebeveynim veya vasiyim';

  @override
  String get onboarding_profileForWhom_myself => 'Kendim';

  @override
  String get onboarding_profileForWhom_myselfSub => 'bir eş arıyorum';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Erkek kardeş';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Kız çocuğu';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Kız kardeş';

  @override
  String get onboarding_profileForWhom_relation_son => 'Oğul';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'Devam etmek için birini seçin';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Devam etmek için bir ilişki seçin';

  @override
  String get onboarding_profileForWhom_sibling => 'Kardeşim veya kız kardeşim';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Kardeşimin eş bulmasına yardım ediyorum';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'Bunu daha sonra ayarlardan güncelleyebilirsiniz.';

  @override
  String get onboarding_profileForWhom_title => 'Bu profil kimin için?';

  @override
  String get onboarding_profileForWhom_ward => 'Benim koğuşum';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Bu profili yöneten bir vasiyim';

  @override
  String get onboarding_providerQuote =>
      '\"Sizin en hayırlınız, eşlerinize karşı en hayırlı olanınızdır.\" — Hz.Muhammed ﷺ\n\nHazır olup olmadığınız konusunda dürüst olmak, güçlü bir temel oluşturmanıza yardımcı olur.';

  @override
  String get onboarding_quran_hafiz => 'Hafız / Hafıza';

  @override
  String get onboarding_quran_none => 'Hiçbiri';

  @override
  String get onboarding_quran_partial => 'Kısmi Hifz';

  @override
  String get onboarding_quran_some => 'Bazı Sureler';

  @override
  String get onboarding_religiousEdu_alim => 'Alim Kursu';

  @override
  String get onboarding_religiousEdu_islamicUni => 'İslam Üniversitesi';

  @override
  String get onboarding_religiousEdu_madrasa => 'Medrese';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Kendi Kendine Öğretilmiş';

  @override
  String get onboarding_timeline_1year => 'Bir yıl içinde';

  @override
  String get onboarding_timeline_2years => '2+ yıl';

  @override
  String get onboarding_timeline_6months => '6 ay içinde';

  @override
  String get onboarding_timeline_asap => 'Mümkün olan en kısa sürede';

  @override
  String get onboarding_timeline_notSure => 'Henüz emin değilim';

  @override
  String get onboarding_tooltip_cultural =>
      'Kendini Müslüman olarak tanımlar, etkinlikleri kutlar, düzenli olarak dua etmeyebilir';

  @override
  String get onboarding_tooltip_moderate =>
      'İslami ilkelere değer verir ve namaz kılar, ancak her zaman günde beş vakit değil';

  @override
  String get onboarding_tooltip_practicing =>
      'Beş şartın hepsine uyuyor, düzenli olarak dua ediyor, helal yaşam tarzı';

  @override
  String get onboarding_work_no => 'Hayır, yapmamayı tercih ederim';

  @override
  String get onboarding_work_yes => 'Evet çalışmayı planlıyorum';

  @override
  String get photo_add_main_required => 'Ana fotoğraf ekle\n(gerekli)';

  @override
  String get photo_add_photo => 'Fotoğraf ekle';

  @override
  String get photo_banner_text => 'Açık içerikli fotoğraflara izin verilmez';

  @override
  String get photo_error_no_face_detected =>
      'Yüz görünmüyor — lütfen net bir yüz fotoğrafıyla tekrar deneyin';

  @override
  String photo_error_pick_failed(Object error) {
    return 'Fotoğraf seçilemedi: $error';
  }

  @override
  String get photo_face_detected => 'Yüz algılandı ✓';

  @override
  String get photo_label_photo2 => 'Fotoğraf 2';

  @override
  String get photo_label_photo3 => 'Fotoğraf 3';

  @override
  String get photo_label_primary => 'Birincil fotoğraf';

  @override
  String get photo_label_selfie => 'Fotoğraf 4';

  @override
  String get photo_no_face => 'Yüz görünmüyor';

  @override
  String get photo_privacy_everyone => 'Herkes görebilir';

  @override
  String get photo_privacy_everyone_sub =>
      'Fotoğraflarınızı tüm üyeler görebilir.';

  @override
  String get photo_privacy_label => 'FOTOĞRAF GİZLİLİĞİ';

  @override
  String get photo_privacy_mutual => 'Karşılıklı ilgiden sonra görünür';

  @override
  String get photo_privacy_mutual_sub =>
      'Fotoğraflar yalnızca her iki taraf da ilgi gösterdiğinde ortaya çıkar.';

  @override
  String get photo_privacy_request => 'Görüntüleme isteği';

  @override
  String get photo_privacy_request_sub =>
      'Siz bir isteği onaylayana kadar fotoğraflar bulanıklaştırılır.';

  @override
  String get photo_sheet_camera => 'Kamera';

  @override
  String get photo_sheet_gallery => 'Galeri';

  @override
  String get photo_sheet_title => 'Fotoğraf Kaynağını Seçin';

  @override
  String get photo_slots_help => 'YÜKLEMEK İÇİN YUVALARA DOKUNUN';

  @override
  String photo_subtitle_guardian(Object relation) {
    return '$relation cihazınızın fotoğraflarını ekleyin. En az bir tane gereklidir.';
  }

  @override
  String get photo_subtitle_self =>
      'En az bir fotoğraf gereklidir. Maksimum dört.';

  @override
  String get photo_title_guardian => 'Fotoğraflarını ekleyin';

  @override
  String get photo_title_self => 'Fotoğraflarınızı ekleyin';

  @override
  String get preferences_deen_any => 'Herhangi';

  @override
  String get preferences_deen_cultural => 'Kültürel Müslüman';

  @override
  String get preferences_deen_moderate => 'Ilıman';

  @override
  String get preferences_deen_practicing => 'pratik yapmak';

  @override
  String get preferences_edu_any => 'Herhangi';

  @override
  String get preferences_edu_bachelors => 'Lisans +';

  @override
  String get preferences_edu_diploma => 'Diploma +';

  @override
  String get preferences_edu_masters => 'Yüksek Lisans +';

  @override
  String get preferences_edu_phd => 'Yalnızca doktora';

  @override
  String get preferences_edu_secondary => 'İkincil +';

  @override
  String get preferences_label_age => 'YAŞ ARALIĞI';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max yıl';
  }

  @override
  String get preferences_label_deen => 'DEEN SEVİYESİ TERCİHİ';

  @override
  String get preferences_label_edu => 'ASGARİ EĞİTİM';

  @override
  String get preferences_label_living => 'YAŞAM DÜZENİ TERCİHİ';

  @override
  String get preferences_label_location => 'KONUM';

  @override
  String get preferences_label_openness => 'AÇIKLIK';

  @override
  String get preferences_label_sect => 'MEZHEP TERCİHİ';

  @override
  String get preferences_living_discussion => 'Tartışmaya Açık';

  @override
  String get preferences_living_family => 'Aile ile';

  @override
  String get preferences_living_no_pref => 'Tercih Yok';

  @override
  String get preferences_living_separate => 'Ayrı Ev';

  @override
  String get preferences_location_abroad => 'Yurt dışına açık';

  @override
  String get preferences_location_diaspora => 'Diaspora modu';

  @override
  String get preferences_location_same_city => 'Aynı şehir';

  @override
  String get preferences_location_same_country => 'Aynı ülke';

  @override
  String get preferences_open_children => 'Çocuğu olan birine açık';

  @override
  String get preferences_open_divorced => 'Daha önce boşanmış birine açık';

  @override
  String get preferences_open_widowed => 'Daha önce dul kalmış birine açık';

  @override
  String get preferences_sect_any => 'Herhangi';

  @override
  String get preferences_sect_same => 'Benimkinin aynısı';

  @override
  String get preferences_sect_shia => 'Şii';

  @override
  String get preferences_sect_sunni => 'Sünni';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return '$relation\'nizin ideal eşleşmesi için tercihleri ​​ayarlayın.';
  }

  @override
  String get preferences_subtitle_self =>
      'Bunlar tercihlerdir, sert filtreler değil.';

  @override
  String get preferences_title => 'İş ortağı tercihleri';

  @override
  String get preview_age_label => 'Yaş';

  @override
  String get preview_background => 'Arka plan';

  @override
  String get preview_basic_info => 'Temel Bilgiler';

  @override
  String get preview_city_label => 'Şehir';

  @override
  String get preview_community_label => 'Toplum';

  @override
  String get preview_cowife_label => 'Eş Eşinin Kabulü';

  @override
  String get preview_deen_label => 'Din Seviyesi';

  @override
  String get preview_diet_label => 'Diyet';

  @override
  String get preview_edit => 'Düzenlemek';

  @override
  String get preview_education_label => 'Eğitim';

  @override
  String get preview_faith => 'İnanç';

  @override
  String get preview_family => 'Aile';

  @override
  String get preview_family_type_label => 'Aile türü';

  @override
  String get preview_gender_label => 'Cinsiyet';

  @override
  String get preview_hijab_label => 'başörtüsü';

  @override
  String get preview_hookah_label => 'Nargile';

  @override
  String get preview_leadership_label => 'Liderlik';

  @override
  String get preview_marital_label => 'evlilik';

  @override
  String get preview_marriage_timeline_label => 'Evlilik Zaman Çizelgesi';

  @override
  String get preview_mother_tongue_label => 'Ana dil';

  @override
  String get preview_name_label => 'İsim';

  @override
  String get preview_notice_guardian =>
      'Başkaları da profillerini tam olarak bu şekilde görecek.';

  @override
  String get preview_notice_self =>
      'Başkaları profilinizi tam olarak bu şekilde görecek.';

  @override
  String get preview_polygamy_label => 'Çok eşlilik';

  @override
  String get preview_post_marriage_living_label => 'Evlilik Sonrası Yaşam';

  @override
  String get preview_prays_label => '5x dua eder';

  @override
  String get preview_profession_label => 'Meslek';

  @override
  String get preview_quran_label => 'Kuran';

  @override
  String get preview_religious_edu_label => 'Din Eğitimi';

  @override
  String get preview_residency_label => 'İkamet';

  @override
  String get preview_revert_label => 'Geri al';

  @override
  String get preview_sect_label => 'Mezhep';

  @override
  String get preview_siblings_label => 'Kardeşler';

  @override
  String get preview_smoking_label => 'Sigara içmek';

  @override
  String get preview_special_needs_label => 'Özel İhtiyaçlar';

  @override
  String get preview_submit_btn => 'Profili Gönder';

  @override
  String get preview_title => 'Önizleme';

  @override
  String get preview_vaping_label => 'elektronik sigara';

  @override
  String get preview_willing_relocate_label => 'Taşınmaya istekli';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil %$percent tamamlandı';
  }

  @override
  String get profile_nudge_completeness =>
      '%80+ tamlığa sahip profiller 3 kat daha fazla ilgi görür.';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · Allah rızası için';

  @override
  String get settings_button_deleteAccount => 'Hesabı Sil';

  @override
  String get settings_guardian_mirror => 'Ayna Mesajları';

  @override
  String get settings_guardian_mirror_sub =>
      'Tüm mesajların kopyalarını veliye gönder';

  @override
  String get settings_guardian_name_hint => 'Veli Adı';

  @override
  String get settings_guardian_relationship => 'İlişki';

  @override
  String get settings_guardian_reply => 'Guardian\'ın Yanıt Vermesine İzin Ver';

  @override
  String get settings_guardian_reply_sub => 'Vasi görüşmelere katılabilir';

  @override
  String get settings_guardian_save => 'Gözetmen Ayarlarını Kaydet';

  @override
  String get settings_guardian_saved => 'Kaydedildi';

  @override
  String get settings_guardian_sub =>
      'Mesajlaşma için Wali gözetimini etkinleştirin';

  @override
  String get settings_guardian_title => 'Gözetmen Modu';

  @override
  String get settings_label_blocked => 'Engellenen Profiller';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count engellendi';
  }

  @override
  String get settings_label_blocked_none => 'Hiçbiri';

  @override
  String get settings_label_deleteGrace =>
      'Profiliniz hemen gizlenecek. Verileriniz 30 gün sonra kalıcı olarak silinecektir.';

  @override
  String get settings_label_editProfile => 'Profili Düzenle';

  @override
  String get settings_label_language => 'Dil';

  @override
  String get settings_label_photoPrivacy => 'Fotoğraf Gizliliği';

  @override
  String get settings_label_rate => 'Değerlendir Silarah';

  @override
  String get settings_label_rate_snackbar =>
      'Derecelendirme, Silarah uygulama mağazasında kullanıma sunulduğunda kullanıma sunulacak.';

  @override
  String get settings_label_reports => 'Rapor Geçmişi';

  @override
  String settings_label_reports_count(Object count) {
    return '$count raporlar';
  }

  @override
  String get settings_label_reports_none => 'Rapor gönderilmedi';

  @override
  String get settings_label_selfieChallenge => 'Selfie Mücadelesi';

  @override
  String get settings_label_verifyProfile => 'Profili Doğrula';

  @override
  String get settings_label_version => 'Sürüm';

  @override
  String get settings_notify_activityNudges => 'Etkinlik Dürtülemeleri';

  @override
  String get settings_notify_activityNudgesSub =>
      'Profil ipuçları ve 7 gün uzak kaldığında hatırlatma';

  @override
  String get settings_notify_boostReminders => 'Hatırlatıcıları Artırın';

  @override
  String get settings_notify_boostRemindersSub =>
      'Haftalık takviyeniz hazır olduğunda hatırlatın';

  @override
  String get settings_notify_interestAccepted => 'İlgi Kabul Edildi';

  @override
  String get settings_notify_interestExpiring =>
      'İlginin Süresi Yakında Doluyor';

  @override
  String get settings_notify_newInterest => 'Yeni İlgi Alanları';

  @override
  String get settings_notify_newMessage => 'Yeni Mesajlar';

  @override
  String get settings_notify_quietHours => 'Sessiz Saatler';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'Yalnızca kabul edilen ilgi alanları';

  @override
  String get settings_photo_privacy_after_acceptance => 'Kabul Sonrası';

  @override
  String get settings_photo_privacy_everyone => 'Herkes';

  @override
  String get settings_photo_privacy_public => 'Halk';

  @override
  String get settings_photo_privacy_request_only => 'Yalnızca Talep Et';

  @override
  String get settings_photo_privacy_request_to_view => 'Görüntüleme isteği';

  @override
  String get settings_privacy_download_body =>
      'Hesabınızı, profilinizi, fotoğraflarınızı, ilgi alanlarınızı, eşleşmelerinizi, mesajlarınızı, ayarlarınızı, onaylarınızı ve abonelik geçmişinizi içeren özel bir ZIP arşivini şimdi oluşturun. Cihazınızın güvenli paylaşım sayfasıyla kaydedin.';

  @override
  String get settings_privacy_download_btn => 'Güvenli arşiv oluştur';

  @override
  String get settings_privacy_download_label => 'Verilerimi indir';

  @override
  String get settings_privacy_download_sub =>
      'Silarah verilerinizin makine tarafından okunabilir bir kopyasını kaydedin';

  @override
  String get settings_privacy_export_body =>
      'Özel arşiviniz hazır. Güvenle kaydetmek için paylaşım sayfasını kullanın.';

  @override
  String get settings_privacy_export_btn_close => 'Anlaşıldı';

  @override
  String get settings_privacy_export_subbody =>
      'Bu arşiv özel mesajlar ve iletişim bilgileri içerebilir. Güvenle saklayın ve yalnızca güvendiğiniz kişilerle paylaşın.';

  @override
  String get settings_privacy_export_title => 'Arşiv hazır';

  @override
  String get settings_privacy_online_label => 'ÇEVRİMİÇİ DURUM';

  @override
  String get settings_privacy_online_sub =>
      'En son ne zaman aktif olduğunuzu gösterin';

  @override
  String get settings_privacy_pause_label => 'Profili duraklat';

  @override
  String get settings_privacy_pause_sub => 'Profilinizi aramadan gizleyin';

  @override
  String get settings_privacy_pause_warning =>
      'Profiliniz gizlendi. Kimse seni bulamaz.';

  @override
  String get settings_privacy_photo_label => 'Fotoğraf görünürlüğü';

  @override
  String get settings_privacy_photo_sub => 'Fotoğraflarınızı kimler görebilir?';

  @override
  String get settings_privacy_visibility_all => 'Tüm kayıtlı kullanıcılar';

  @override
  String get settings_privacy_visibility_label => 'PROFİLİMİ KİMLER GÖREBİLİR';

  @override
  String get settings_privacy_visibility_sub =>
      'Profilinize kimlerin göz atabileceğini kontrol eder';

  @override
  String get settings_privacy_visibility_subscribers => 'Yalnızca aboneler';

  @override
  String get settings_relation_brother => 'Erkek kardeş';

  @override
  String get settings_relation_father => 'Baba';

  @override
  String get settings_relation_mother => 'Anne';

  @override
  String get settings_relation_other => 'Diğer';

  @override
  String get settings_relation_uncle => 'Amca';

  @override
  String get settings_section_account => 'Hesap';

  @override
  String get settings_section_app => 'Uygulama';

  @override
  String get settings_section_dangerZone => 'Hesabı kapat';

  @override
  String get settings_section_guardian => 'Gardiyan';

  @override
  String get settings_section_legal => 'Yasal';

  @override
  String get settings_section_notifications => 'Bildirimler';

  @override
  String get settings_section_privacy => 'Mahremiyet';

  @override
  String get settings_section_safety => 'Emniyet';

  @override
  String get settings_support_body =>
      'Her türlü soru, endişe veya geri bildirim için:';

  @override
  String get settings_support_btn_close => 'Kapalı';

  @override
  String get settings_support_contact => 'Destek Ekibiyle İletişime Geçin';

  @override
  String get settings_support_note =>
      '48 saat içinde yanıt vermeyi hedefliyoruz.';

  @override
  String get settings_title => 'Ayarlar';

  @override
  String get splash_button_createProfile => 'Profil Oluştur';

  @override
  String get splash_button_signIn => 'Oturum aç';

  @override
  String get splash_intention_subtitle =>
      'Özel tanışmalar, özenle değerlendirilen uyum ve aileyi gözeten bağlar.';

  @override
  String get splash_intention_title => 'Evliliğe, niyetle yaklaşın.';

  @override
  String get splash_referral_button => 'Kodu Uygula';

  @override
  String get splash_referral_hint => 'örneğin SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'Lütfen 6 karakterlik geçerli bir kod girin.';

  @override
  String get splash_referral_question => 'Referans kodunuz var mı?';

  @override
  String get splash_referral_saved =>
      'Tavsiye kodu kaydedildi! Giriş yaptıktan sonra uygulanacaktır.';

  @override
  String get splash_referral_subtitle =>
      'Bir arkadaşınız sizi Silarah\'a davet ettiyse 6 karakterli tavsiye kodunu aşağıya girin.';

  @override
  String get splash_referral_title => 'Referans Kodunu Girin';

  @override
  String subscription_button_monthly(String price) {
    return 'Abone ol — $price/ay';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'Abone ol — $price/3 ay';
  }

  @override
  String get subscription_label_bestValue => 'En İyi Değer';

  @override
  String get subscription_subtitle =>
      'Kadınlar ücretsiz mesaj atar. Erkekler bağlanmak için abone olurlar.';

  @override
  String get subscription_title => 'Silarah kilidini açın';

  @override
  String get startup_connectivity_preparing_title =>
      'Özel alanınız hazırlanıyor';

  @override
  String get startup_connectivity_preparing_body =>
      'Silarah ile güvenli bağlantı kuruluyor.';

  @override
  String get startup_connectivity_offline_title => 'Bağlantı bekleniyor';

  @override
  String get startup_connectivity_offline_body =>
      'Profiliniz, ilgileriniz ve sohbetleriniz güvende. Tekrar çevrimiçi olduğunuzda Silarah kaldığınız yerden devam edecek.';

  @override
  String get startup_connectivity_verifying => 'BAĞLANTI KONTROL EDİLİYOR';

  @override
  String get startup_connectivity_waiting => 'AĞ BEKLENİYOR';

  @override
  String get startup_connectivity_still_waiting =>
      'HÂLÂ ÇEVRİMDIŞI · TEKRAR DENENİYOR';

  @override
  String get startup_connectivity_check => 'Tekrar dene';

  @override
  String get startup_connectivity_checking => 'Kontrol ediliyor…';

  @override
  String get startup_connectivity_auto =>
      'Ağ geri geldiğinde otomatik olarak yeniden bağlanacağız.';

  @override
  String get startup_connectivity_tip =>
      'Wi-Fi veya mobil verinin açık olduğundan emin olun.';

  @override
  String get startup_connectivity_protected => 'Korumalı bağlantı';

  @override
  String get settings_label_email => 'E-posta';

  @override
  String get settings_notify_profileViews => 'Profil görüntülemeleri';

  @override
  String get settings_notify_profileViewsSub =>
      'Birisi profilinizi açtığında özel bildirim';

  @override
  String get settings_notify_profileLive => 'Profil yayına alındı';

  @override
  String get settings_notify_profileLiveSub =>
      'Profiliniz görünür olduğunda onay';

  @override
  String get settings_appearance => 'Görünüm';

  @override
  String get settings_helpSupport => 'Yardım ve Destek';

  @override
  String get settings_helpCenter => 'Yardım Merkezi';

  @override
  String get settings_grievanceOfficer => 'Şikâyet Sorumlusu';

  @override
  String get settings_grievanceResponse =>
      '24 saat içinde alındı onayı; çoğu şikâyet 7 gün içinde çözülür';

  @override
  String get settings_grievanceIndiaNotice =>
      'Hindistan\'daki şikâyet işlemleri, değiştirildiği şekliyle Bilgi Teknolojileri (Aracı Kuruluş Yönergeleri ve Dijital Medya Etik Kodu) Kurallarına tabidir. Acil yasa dışı veya mahrem içerik şikâyetlerinde daha kısa yasal süreler uygulanır.';

  @override
  String get settings_managePhotoRequests => 'Fotoğraf isteklerini yönet';

  @override
  String get settings_managePhotoRequestsSub =>
      'Erişimi onaylayın, istekleri reddedin veya paylaşımı kaldırın';

  @override
  String get settings_theme_chooseTitle => 'Atmosferini seç';

  @override
  String get settings_theme_chooseSubtitle =>
      'Yalnızca bir renk filtresi değil, eksiksiz bir görsel kimlik. Tüm yüzeyler, alanlar ve sistem kontrolleri birlikte değişir.';

  @override
  String get settings_theme_applied =>
      'Anında uygulandı · bu cihaza kaydedildi';

  @override
  String get settings_reportPending => 'İnceleme bekliyor';

  @override
  String get legal_document_terms => 'Hizmet Şartları';

  @override
  String get legal_document_privacy => 'Gizlilik Politikası';

  @override
  String get legal_document_community => 'Topluluk Kuralları';

  @override
  String get legal_specialCategoryConsent =>
      'Uyumluluk eşleştirmesi için Silarah’ın dini bilgilerimi (mezhep, namaz uygulaması ve İslami kimlik) işlemesine açıkça izin veriyorum. Sözleşmeli hizmet sağlayıcılar bu bilgileri yalnızca Silarah’ı işletmek için kullanır; davranışsal reklamcılık için kullanmaz.';

  @override
  String get onboarding_complexion_fair => 'Açık';

  @override
  String get onboarding_complexion_medium => 'Orta';

  @override
  String get onboarding_complexion_olive => 'Buğday';

  @override
  String get onboarding_complexion_dark => 'Koyu';

  @override
  String get onboarding_residency_citizen => 'Vatandaş';

  @override
  String get onboarding_residency_permanentResident => 'Daimî ikamet sahibi';

  @override
  String get onboarding_residency_workVisa => 'Çalışma vizesi';

  @override
  String get onboarding_residency_studentVisa => 'Öğrenci vizesi';

  @override
  String get onboarding_specialNeeds_none => 'Yok';

  @override
  String get onboarding_specialNeeds_physical => 'Fiziksel engel';

  @override
  String get onboarding_specialNeeds_hearing => 'İşitme engeli';

  @override
  String get onboarding_specialNeeds_visual => 'Görme engeli';

  @override
  String get onboarding_label_stateRegion => 'Eyalet / Bölge';

  @override
  String get onboarding_specialNeeds_privacy =>
      'Yalnızca karşılıklı ilgi sonrasında paylaşılır.';

  @override
  String get settings_theme_automatic => 'Otomatik';

  @override
  String get settings_theme_automaticDesc =>
      'Gündüz Fildişi ve Zümrüt, telefon karanlık moddayken OLED Gece';

  @override
  String get settings_theme_rose => 'Gül ve Kadife';

  @override
  String get settings_theme_roseDesc =>
      'Yumuşak pembe, koyu gül ve kadife çiçeği altını';

  @override
  String get settings_theme_oled => 'OLED Gece';

  @override
  String get settings_theme_oledDesc =>
      'OLED ekranlar için ayarlanmış gerçek siyah';

  @override
  String get settings_theme_ivory => 'Fildişi ve Zümrüt';

  @override
  String get settings_theme_ivoryDesc =>
      'Sıcak fildişi, derin zümrüt ve antik altın';

  @override
  String get settings_guardian_backendRequired =>
      'Veli ayarları için güvenli bağlantı gerekir.';

  @override
  String get settings_guardian_saveError =>
      'Veli ayarları kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get common_openSettings => 'Ayarları Aç';

  @override
  String get media_cameraAccessOff => 'Kamera erişimi kapalı';

  @override
  String get media_cameraUnavailable => 'Kamera kullanılamıyor';

  @override
  String get media_cameraAccessBody =>
      'Ayarlardan kamera erişimine izin verin, ardından net bir fotoğraf çekmek için geri dönün.';

  @override
  String get media_cameraUnavailableBody =>
      'Kamera açılamadı. Lütfen tekrar deneyin.';

  @override
  String get media_photoAccessOff => 'Fotoğraf erişimi kapalı';

  @override
  String get media_photoAccessBody =>
      'Ayarlardan kamera veya fotoğraf erişimine izin verin, ardından fotoğraf eklemek için geri dönün.';

  @override
  String get chat_searchHint => 'Mesajlarda ara';

  @override
  String get chat_noConversationsFound => 'Konuşma bulunamadı';

  @override
  String get chat_noConversationsFoundBody =>
      'Başka bir ad deneyin veya aramayı temizleyin.';

  @override
  String get chat_noConversationsYet => 'Henüz konuşma yok';

  @override
  String get chat_noConversationsYetBody =>
      'Bir konuşma başlatmak için bir ilgiyi kabul edin veya ilginizin kabul edilmesini bekleyin.';

  @override
  String get referral_title => 'Arkadaşını Davet Et';

  @override
  String get referral_loading => 'Ödüller yükleniyor';

  @override
  String get referral_heading => 'Haberi yay, Premium kazan!';

  @override
  String get referral_body =>
      'Uygun olan herhangi bir arkadaşını Silarah’a davet et. Her hesap ömür boyu bir kez 3 günlük referans Premium ödülü alabilir. Sen ödülünü aldıysan arkadaşın yine de kendi ödülünü alabilir.';

  @override
  String get referral_premiumActiveTitle => 'Referans Premium etkin';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '${days}g ${hours}sa kaldı';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '${hours}sa ${minutes}dk kaldı';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '${minutes}dk kaldı';
  }

  @override
  String get referral_premiumEndingNow => 'Ödül şimdi sona eriyor';

  @override
  String referral_premiumEndsAt(String date) {
    return '$date tarihinde sona erer';
  }

  @override
  String get referral_premiumNoPayment =>
      'Tüm Premium özellikler açık. Ödeme alınmadı ve bu ödül otomatik yenilenmez.';

  @override
  String get referral_premiumPlansAfter =>
      'Kalan ücretsiz süreniz boşa gitmesin diye abonelik planları ödülünüz bittikten sonra açılır.';

  @override
  String get referral_premiumBackToProfile => 'Profile dön';

  @override
  String get referral_premiumFeaturesUnlocked => 'Tüm Premium özellikler açık';

  @override
  String get referral_premiumViewReward => 'Ödülü gör';

  @override
  String get referral_codeLabel => 'DAVET KODUN';

  @override
  String get referral_tapToCopy => 'Kopyalamak için koda dokun';

  @override
  String get referral_totalInvited => 'Toplam Davet';

  @override
  String get referral_rewardsEarned => 'Kazanılan Ödüller';

  @override
  String referral_premiumDays(int count) {
    return '$count Premium gün';
  }

  @override
  String get referral_pending => 'Bekleyen Kayıtlar';

  @override
  String get referral_shareButton => 'Kodu Arkadaşlarınla Paylaş';

  @override
  String get referral_copied => 'Davet kodu kopyalandı!';

  @override
  String get referral_shareSubject => 'Silarah’a Katıl';

  @override
  String referral_shareText(String code) {
    return 'Güvenilir Müslüman evlilik uygulaması Silarah’a katıl. Davet kodumu kullan: $code\n\nİndir: https://silarah.com/r/$code';
  }

  @override
  String get profile_share => 'Profili paylaş';

  @override
  String safety_reportMember(String name) {
    return '$name adlı kişiyi bildir';
  }

  @override
  String safety_blockMember(String name) {
    return '$name adlı kişiyi engelle';
  }

  @override
  String safety_blockTitle(String name) {
    return '$name engellensin mi?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name Discovery’de gizlenir ve sizinle iletişim kuramaz. Sohbet geçmişi güvenlik için korunur. Engeli kaldırmak konuşmayı yeniden açmaz.';
  }

  @override
  String get safety_blockAction => 'Engelle';

  @override
  String safety_blocked(String name) {
    return '$name engellendi.';
  }

  @override
  String ui_openProfile(String name) {
    return '$name profilini aç';
  }

  @override
  String ui_typing(String name) {
    return '$name yazıyor';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'Hesap silinemedi: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'Ülkeyi değiştir, şu anda $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'E-posta uygulaması bulunamadı. $email kopyalandı.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'Mesaj $name';
  }

  @override
  String ui_renewsDate(String date) {
    return '$date yenilenir';
  }

  @override
  String ui_ageYears(int age) {
    return '$age yıl';
  }

  @override
  String ui_photoNumber(int number) {
    return 'Fotoğraf $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count / 4 fotoğraf';
  }

  @override
  String ui_removeLabel(String label) {
    return '$label öğesini kaldır';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label seçildi';
  }

  @override
  String ui_addLabel(String label) {
    return '$label ekle';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'Fotoğraf isteği $name adresine gönderildi.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'Dün $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count dakika önce';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count saat önce';
  }

  @override
  String ui_daysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String ui_renewsAt(String time) {
    return '$time tarihinde yenilenir';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'Fotoğraf $number korumalı incelemeye hazır';
  }

  @override
  String get ui_onePhotoUnlock =>
      'İkiniz de ilgilendiğinizi ifade ettiğinizde 1 fotoğrafın kilidi otomatik olarak açılacaktır.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return '$count fotoğrafların kilidi, ikiniz de ilgilendiğinizi belirttiğinizde otomatik olarak açılacaktır.';
  }

  @override
  String get ui_askOnePhoto =>
      '1 fotoğrafı görüntülemek için sahibinden izin isteyin.';

  @override
  String ui_askManyPhotos(int count) {
    return '$count fotoğraflarını görüntülemek için sahibinden izin isteyin.';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet ft $inches inç';
  }

  @override
  String ui_minutesShort(int count) {
    return '${count}m';
  }

  @override
  String ui_hoursShort(int count) {
    return '${count}h';
  }

  @override
  String ui_daysShort(int count) {
    return '${count}d';
  }

  @override
  String discovery_filters_count(int count) {
    return 'Filtreler ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'Daha önce $date tarihinde eşleştiniz';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'Yeniden eşleşme $count gün içinde kullanılabilir';
  }

  @override
  String get settings_notify_compatibleProfiles => 'Uyumlu profil bildirimleri';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'Boş Keşfet akışına yeni sonuçlar geldiğinde';

  @override
  String get settings_notify_discoveryDigest => 'Keşfet özeti';

  @override
  String get settings_notify_digestHelp =>
      'İsteğe bağlı özetler; boş akışa gelen yeni sonuç bildirimleri anında kalır.';

  @override
  String get settings_notify_digestOff => 'Kapalı';

  @override
  String get settings_notify_digestDaily => 'Günlük';

  @override
  String get settings_notify_digestWeekly => 'Haftalık';

  @override
  String get settings_quietHoursStart => 'Sessiz saatlerin başlangıcı';

  @override
  String get settings_quietHoursEnd => 'Sessiz saatlerin sonu';

  @override
  String get settings_notify_festivalGreetings => 'Bayram tebrikleri';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'Ramazan ve bayram tebrikleri, yılda yaklaşık beş kez';
}
