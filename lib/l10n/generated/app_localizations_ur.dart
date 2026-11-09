// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get guide_optional_details => 'اضافی تفصیلات (اختیاری)';

  @override
  String get guide_optional_details_body =>
      'آپ یہ تفصیلات بعد میں اپنی پروفائل سے مکمل کر سکتے ہیں۔';

  @override
  String get guide_profile_ownership =>
      'یہ پروفائل شادی کے خواہش مند شخص کا تعارف کراتی ہے۔ گفتگو کی نگرانی کے لیے بعد میں ایک الگ سرپرست کو مدعو کیا جا سکتا ہے۔';

  @override
  String get about_button_later => 'میں یہ بعد میں کروں گا۔';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'اپنی $relation کو ایمانداری اور وقار کے ساتھ بیان کریں۔';
  }

  @override
  String get about_hint_bio_self =>
      'اپنے آپ کو ایمانداری اور وقار کے ساتھ بیان کریں۔';

  @override
  String get about_label_bio_guardian => 'ان کا بائیو';

  @override
  String get about_label_bio_self => 'آپ کا بائیو';

  @override
  String get about_label_interests => 'دلچسپیاں';

  @override
  String get about_label_languages => 'بولی جانے والی زبانیں';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max منتخب کیا گیا۔';
  }

  @override
  String get about_subtitle => 'ایمانداری اور وقار کے ساتھ لکھیں۔';

  @override
  String about_title_guardian(Object relation) {
    return 'آپ کے $relation کے بارے میں';
  }

  @override
  String get about_title_self => 'آپ کے بارے میں';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'بسم اللہ سے شروع کریں۔';

  @override
  String get auth_button_resendOtp => 'تصدیقی کوڈ دوبارہ بھیجیں۔';

  @override
  String get auth_button_sendCode => 'تصدیقی کوڈ بھیجیں۔';

  @override
  String get auth_button_sendOtp => 'تصدیقی کوڈ بھیجیں۔';

  @override
  String get auth_button_verifyOtp => 'تصدیق کریں۔';

  @override
  String get auth_label_changeNumber => 'غلط نمبر؟ اسے تبدیل کریں۔';

  @override
  String get auth_label_enterOtp =>
      '6 ہندسوں کا تصدیقی کوڈ درج کریں جس پر بھیجا گیا ہے۔';

  @override
  String get auth_label_resendCode => 'تصدیقی کوڈ دوبارہ بھیجیں۔';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'تصدیقی کوڈ کو ${seconds}s میں دوبارہ بھیجیں۔';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return '${seconds}s میں دوبارہ بھیجیں۔';
  }

  @override
  String get auth_label_sentCodeTo => 'ہم نے 6 ہندسوں کا توثیقی کوڈ بھیجا ہے۔';

  @override
  String get auth_subtitle_verifyOtp =>
      'ہم ایک بار کے کوڈ کے ساتھ اس کی تصدیق کریں گے۔';

  @override
  String get auth_title_enterCode => 'اپنا تصدیقی کوڈ درج کریں۔';

  @override
  String get auth_title_yourNumber => 'آپ کا نمبر';

  @override
  String get background_edu_bachelors => 'بیچلر ڈگری';

  @override
  String get background_edu_below_secondary => 'ثانوی سے نیچے';

  @override
  String get background_edu_diploma => 'ڈپلومہ / ایسوسی ایٹ';

  @override
  String get background_edu_doctorate => 'ڈاکٹریٹ/پی ایچ ڈی';

  @override
  String get background_edu_higher_secondary => 'ہائر سیکنڈری / اے لیول';

  @override
  String get background_edu_masters => 'ماسٹر ڈگری';

  @override
  String get background_edu_secondary => 'سیکنڈری / او لیول';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'ہمیں اپنی $relation کی تعلیم اور کیریئر کے بارے میں بتائیں۔';
  }

  @override
  String get background_edu_subtitle_self =>
      'پیشہ ورانہ طور پر ہم آہنگ میچوں کو تلاش کرنے میں مدد کرتا ہے۔';

  @override
  String get background_edu_title_guardian => 'ان کا پس منظر';

  @override
  String get background_edu_title_self => 'آپ کا پس منظر';

  @override
  String get background_emp_employed => 'ملازم';

  @override
  String get background_emp_not_working => 'کام نہیں کر رہا۔';

  @override
  String get background_emp_self_employed => 'سیلف ایمپلائیڈ';

  @override
  String get background_emp_student => 'طالب علم';

  @override
  String get background_income_subtitle =>
      'بہت سے لوگ اسے چھوڑ دیتے ہیں - یہ مکمل طور پر اختیاری ہے۔';

  @override
  String get background_label_eduLevel => 'تعلیم کی سطح';

  @override
  String get background_label_employment => 'ملازمت کی حیثیت';

  @override
  String background_label_income_bracket(Object currency) {
    return 'انکم بریکٹ ($currency)';
  }

  @override
  String get background_label_income_range => 'آمدنی کی حد (اختیاری)';

  @override
  String get background_label_profession => 'پیشہ (اختیاری)';

  @override
  String get background_label_study => 'مطالعہ کا میدان (اختیاری)';

  @override
  String get background_label_who_see => 'یہ کون دیکھ سکتا ہے؟';

  @override
  String get background_vis_everyone => 'ہر کسی کو بریکٹ دکھائیں۔';

  @override
  String get background_vis_mutual => 'باہمی دلچسپی کے بعد ہی دکھائیں۔';

  @override
  String get background_vis_private => 'نجی رکھیں';

  @override
  String get ceremony_text_blessing => 'اللہ تعالیٰ اس میں برکت عطا فرمائے';

  @override
  String get chat_closure_1 =>
      'السلام علیکم۔ سوچ سمجھ کر سوچنے کے بعد، مجھے لگتا ہے کہ یہ ہمارے لیے صحیح میچ نہیں ہے۔ میں آپ کے لیے نیک خواہشات کا اظہار کرتا ہوں اور دعا کرتا ہوں کہ اللہ آپ کو ایک بہترین ساتھی سے نوازے۔ جزاک اللہ خیر۔';

  @override
  String get chat_closure_2 =>
      'السلام علیکم۔ میں آپ کے ساتھ ایماندار اور عزت دار بننا چاہتا تھا۔ مجھے نہیں لگتا کہ ہم صحیح میچ ہیں، لیکن میری دعا ہے کہ اللہ آپ کے لیے بہتر دروازے کھولے۔ آپ کے لیے نیک خواہشات۔';

  @override
  String get chat_closure_3 =>
      'السلام علیکم۔ مخلصانہ غور و فکر کے بعد، مجھے لگتا ہے کہ شاید ہم مطابقت نہیں رکھتے۔ مجھے امید ہے کہ آپ کسی کو اپنے لیے صحیح معنوں میں تلاش کریں گے۔ اللہ آپ کے لیے آسانیاں پیدا کرے۔ جزاک اللہ خیر آپ کا وقت۔';

  @override
  String get chat_closure_4 =>
      'السلام علیکم۔ میں نے اپنی بات چیت پر غور کیا ہے اور محسوس کیا ہے کہ اس وقت اس میچ کو بند کرنا ہی بہتر ہے۔ میرے پاس آپ کے احترام کے سوا کچھ نہیں ہے اور میں دعا کرتا ہوں کہ اللہ آپ کو بہترین سے نوازے۔';

  @override
  String get chat_closure_5 =>
      'السلام علیکم۔ میں دھندلا ہونے کی بجائے آپ کے ساتھ شفاف ہونا چاہتا تھا۔ میں اسے آگے بڑھتا ہوا نہیں دیکھ رہا ہوں، لیکن میں واقعی آپ کے وقت کی تعریف کرتا ہوں اور آپ کو ہر خوشی کی خواہش کرتا ہوں۔ اللہ آپ کو جزائے خیر دے۔';

  @override
  String get chat_endMatch_button => 'بھیجیں اور میچ ختم کریں۔';

  @override
  String get chat_endMatch_subtitle =>
      'اس گفتگو کو بند کرنے کے لیے ایک قابل احترام پیغام کا انتخاب کریں۔ دوسرے شخص کو مطلع کیا جائے گا۔';

  @override
  String get chat_endMatch_title => 'یہ میچ ختم کرو';

  @override
  String chat_label_probation(int hours) {
    return 'پیغام رسانی $hours گھنٹے میں کھل جاتی ہے۔ آپ ابھی دلچسپیاں بھیج سکتے ہیں۔';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'پیغام رسانی کو غیر مقفل کرنے کے لیے سبسکرائب کریں۔ خواتین ہمیشہ Silarah پر مفت پیغام بھیجتی ہیں۔';

  @override
  String get chat_matchClosed_banner =>
      'یہ میچ احترام کے ساتھ بند کر دیا گیا ہے۔';

  @override
  String get chat_opener_1 =>
      'السلام علیکم! میں آپ کے پروفائل پر آیا اور حقیقی طور پر متاثر ہوا۔ کیا میں اپنا تعارف کروا سکتا ہوں؟';

  @override
  String get chat_opener_2 =>
      'بسم اللہ۔ آپ کے پروفائل نے میری توجہ حاصل کی۔ میں آپ کے بارے میں مزید جاننا پسند کروں گا۔';

  @override
  String get chat_opener_3 =>
      'السلام علیکم۔ مجھے یقین ہے کہ ہم ایک جیسی اقدار کا اشتراک کرتے ہیں۔ کیا آپ ایک دوسرے کو جاننے کے لیے تیار ہوں گے؟';

  @override
  String get chat_placeholder_typeMessage => 'ایک پیغام ٹائپ کریں…';

  @override
  String get common_button_back => 'پیچھے';

  @override
  String get common_button_cancel => 'منسوخ کریں۔';

  @override
  String get common_button_done => 'ہو گیا';

  @override
  String get common_button_next => 'اگلا';

  @override
  String get common_button_retry => 'دوبارہ کوشش کریں۔';

  @override
  String get common_button_save => 'محفوظ کریں۔';

  @override
  String get common_button_skip => 'چھوڑیں۔';

  @override
  String get common_button_submit => 'جمع کروائیں۔';

  @override
  String get common_error_generic =>
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get common_error_noInternet =>
      'انٹرنیٹ کنکشن نہیں ہے۔ براہ کرم اپنا کنکشن چیک کریں۔';

  @override
  String get common_label_optional => 'اختیاری';

  @override
  String get copy_beard_parent => 'کیا آپ کے بیٹے کی داڑھی ہے؟';

  @override
  String get copy_beard_self => 'کیا آپ کی داڑھی ہے؟';

  @override
  String get copy_beard_sibling => 'کیا آپ کے بھائی کی داڑھی ہے؟';

  @override
  String get copy_hijab_parent => 'کیا آپ کی بیٹی حجاب کی پابندی کرتی ہے؟';

  @override
  String get copy_hijab_self => 'کیا آپ حجاب کی پابندی کرتے ہیں؟';

  @override
  String get copy_hijab_sibling => 'کیا آپ کی بہن حجاب کی پابندی کرتی ہے؟';

  @override
  String get copy_prayer_parent =>
      'کیا آپ کا بچہ روزانہ پانچ وقت کی نماز پڑھتا ہے؟';

  @override
  String get copy_prayer_self => 'کیا آپ روزانہ پانچ وقت کی نماز پڑھتے ہیں؟';

  @override
  String get copy_prayer_sibling =>
      'کیا آپ کا بھائی روزانہ پانچ وقت کی نماز پڑھتا ہے؟';

  @override
  String get deleteAccount_title => 'اکاؤنٹ حذف کریں۔';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name کو ہٹا دیا گیا۔';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name محفوظ ہو گیا۔';
  }

  @override
  String get discovery_button_sendInterest => 'دلچسپی بھیجیں۔';

  @override
  String get discovery_completeness_button => 'مکمل پروفائل';

  @override
  String get discovery_completeness_subtitle =>
      '40% سے زیادہ پروفائلز کو 3× زیادہ دلچسپیاں ملتی ہیں۔\nبراؤزنگ شروع کرنے کے لیے اپنا پروفائل مکمل کریں۔';

  @override
  String get discovery_completeness_title => 'اپنا پروفائل مکمل کریں۔';

  @override
  String get discovery_empty_subtitle =>
      'سلارہ پر ہر روز نئے ممبر شامل ہوتے ہیں۔ نئی پروفائلز کے لیے کل دوبارہ دیکھیں، یا ابھی مزید لوگوں سے ملنے کے لیے اپنی ترجیحات کا دائرہ بڑھائیں۔';

  @override
  String get discovery_empty_filtered_eyebrow => 'اپنی تلاش کو بہتر بنائیں';

  @override
  String get discovery_empty_filtered_title =>
      'ان فلٹرز سے ابھی کوئی میل نہیں کھاتا';

  @override
  String get discovery_empty_filtered_subtitle =>
      'آپ کی ترجیحات دائرہ تنگ کر رہی ہیں۔ صرف ایک فلٹر میں نرمی سے عموماً فوراً نئی پروفائلز نظر آنے لگتی ہیں۔';

  @override
  String get discovery_empty_clear_filters => 'تمام فلٹرز ہٹائیں';

  @override
  String get discovery_empty_refresh => 'پروفائلز ریفریش کریں';

  @override
  String get discovery_empty_adjust_filters => 'فلٹرز تبدیل کریں';

  @override
  String get discovery_empty_hint_trust =>
      'پہلے اعتماد کی جانچ میں نرمی کر کے دیکھیں';

  @override
  String get discovery_empty_hint_deen =>
      'پہلے دین کی سطح کا دائرہ بڑھا کر دیکھیں';

  @override
  String get discovery_empty_hint_family =>
      'پہلے خاندانی قسم کا دائرہ بڑھا کر دیکھیں';

  @override
  String get discovery_empty_hint_sect => 'پہلے فرقہ کا فلٹر کھول کر دیکھیں';

  @override
  String get discovery_empty_hint_location =>
      'پہلے وسیع علاقہ منتخب کر کے دیکھیں';

  @override
  String get discovery_empty_hint_age => 'پہلے عمر کی حد بڑھا کر دیکھیں';

  @override
  String get discovery_empty_hint_other =>
      'ایک وقت میں ایک فلٹر میں نرمی کر کے دیکھیں';

  @override
  String get discovery_empty_eyebrow => 'آپ نے سب دیکھ لیا';

  @override
  String get discovery_empty_title => 'آج کے لیے آپ سب کو دیکھ چکے ہیں';

  @override
  String get discovery_handoff_interest_subtitle =>
      'فعال درخواست والے پروفائلز آپ کے انتظار یا جواب تک دلچسپیوں میں منتقل ہو جاتے ہیں۔';

  @override
  String get discovery_handoff_interest_title => 'آپ کی دلچسپی زیرِ عمل ہے';

  @override
  String get discovery_handoff_match_subtitle =>
      'میچ شدہ پروفائلز چیٹ میں منتقل ہو جاتے ہیں، اس لیے وہ ڈسکور میں دوبارہ نہیں دکھتے۔';

  @override
  String get discovery_handoff_match_title => 'آپ کا رابطہ تیار ہے';

  @override
  String get discovery_handoff_open_chat => 'چیٹ کھولیں';

  @override
  String get discovery_handoff_open_interests => 'دلچسپیاں کھولیں';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'دلچسپی بھیجی گئی ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'کوئی ایسا شخص جس سے آپ جڑ سکتے ہیں۔';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count پروفائلز آج باقی ہیں۔';
  }

  @override
  String get discovery_limit_button => 'ابھی اپ گریڈ کریں۔';

  @override
  String get discovery_limit_subtitle =>
      'آپ نے آج 15 پروفائلز براؤز کیے ہیں۔\nلامحدود براؤزنگ کو غیر مقفل کرنے کے لیے اپ گریڈ کریں۔';

  @override
  String get discovery_limit_title => 'روزانہ کی حد تک پہنچ گئی۔';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count پروفائلز باقی ہیں۔';
  }

  @override
  String get discovery_wildcard_label => 'کوئی ایسا شخص جس سے آپ جڑ سکتے ہیں۔';

  @override
  String get family_children_no => 'نہیں';

  @override
  String get family_children_yes => 'جی ہاں';

  @override
  String get family_label_children_guardian => 'کیا ان کے بچے ہیں؟';

  @override
  String get family_label_children_self => 'کیا آپ کے بچے ہیں؟';

  @override
  String get family_label_how_many => 'کتنے؟';

  @override
  String get family_label_parents => 'والدین کی ازدواجی حیثیت';

  @override
  String get family_label_polygamy_female_self =>
      'کثیر ازدواجی قبولیت (اختیاری)';

  @override
  String get family_label_polygamy_male_self => 'کثیر ازدواجی حیثیت (اختیاری)';

  @override
  String get family_label_prev_married => 'پہلے شادی شدہ؟';

  @override
  String get family_label_relocate => 'منتقل کرنے کے لئے تیار';

  @override
  String get family_label_siblings => 'بہن بھائیوں کی تعداد';

  @override
  String get family_label_type => 'فیملی کی قسم';

  @override
  String get family_living_title => 'شادی کے بعد زندگی کی توقعات';

  @override
  String get family_parents_both_deceased => 'دونوں فوت ہوگئے۔';

  @override
  String get family_parents_divorced => 'طلاق ہو گئی۔';

  @override
  String get family_parents_father_deceased => 'والد مرحوم';

  @override
  String get family_parents_mother_deceased => 'والدہ فوت ہوگئیں۔';

  @override
  String get family_parents_separated => 'الگ';

  @override
  String get family_parents_together => 'ایک ساتھ';

  @override
  String get family_polygamy_female_discussion => 'بحث کے لیے کھلا۔';

  @override
  String get family_polygamy_female_no => 'نہیں';

  @override
  String get family_polygamy_female_prefer_not => 'نہ کہنے کو ترجیح دیں۔';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'کیا آپ کی $relation شریک بیوی ہونے پر غور کریں گے؟';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'کیا آپ شریک بیوی ہونے پر غور کریں گے؟';

  @override
  String get family_polygamy_female_yes => 'جی ہاں';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'کیا آپ کا $relation فی الحال شادی شدہ ہے اور ایک اضافی شریک حیات کی تلاش ہے؟';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'کیا آپ فی الحال شادی شدہ ہیں اور ایک اضافی شریک حیات کی تلاش میں ہیں؟';

  @override
  String get family_polygamy_option_first => 'نہیں، یہ میرا پہلا ہے۔';

  @override
  String get family_polygamy_option_married => 'ہاں ابھی شادی شدہ ہے۔';

  @override
  String get family_polygamy_option_prefer_not => 'نہ کہنے کو ترجیح دیں۔';

  @override
  String get family_prev_divorced => 'طلاق ہو گئی۔';

  @override
  String get family_prev_no => 'نہیں';

  @override
  String get family_prev_widowed => 'بیوہ';

  @override
  String get family_relocate_discussion => 'بحث کے لیے کھولیں۔';

  @override
  String get family_relocate_no => 'نہیں';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'کیا آپ کی $relation شادی کے لیے دوسری جگہ منتقل ہوگی؟';
  }

  @override
  String get family_relocate_subtitle_self =>
      'کیا آپ شادی کے لیے نقل مکانی کریں گے؟';

  @override
  String get family_relocate_yes => 'جی ہاں';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'ہمیں اپنے $relation کے خاندان کے بارے میں بتائیں۔';
  }

  @override
  String get family_subtitle_self =>
      'خاندانی مطابقت پائیدار شادیوں کے لیے مرکزی حیثیت رکھتی ہے۔';

  @override
  String get family_title_guardian => 'خاندانی پس منظر';

  @override
  String get family_title_self => 'خاندانی پس منظر';

  @override
  String get family_type_extended => 'توسیع شدہ';

  @override
  String get family_type_joint => 'مشترکہ';

  @override
  String get family_type_nuclear => 'جوہری';

  @override
  String get filter_label_community => 'برادری/برادری۔';

  @override
  String get filter_label_livingExpectation => 'شادی کے بعد کی زندگی';

  @override
  String get filter_label_motherTongue => 'مادری زبان';

  @override
  String get guardian_details_candidate_female =>
      'خواتین امیدوار • خواتین کا پیغام مفت';

  @override
  String get guardian_details_candidate_label => 'کے لیے پروفائل بنانا';

  @override
  String get guardian_details_candidate_male => 'مرد امیدوار';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'میرا $relation';
  }

  @override
  String get guardian_details_involvement => 'گارڈین کی شمولیت';

  @override
  String get guardian_details_involvement_subtitle =>
      'آپ بات چیت میں کتنا شامل ہونا چاہتے ہیں؟';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'اپنے $relation کی جانب سے چیٹس دیکھیں، میچوں کی منظوری دیں، اور پیغامات بھیجیں۔';
  }

  @override
  String get guardian_details_mode_active_title => 'فعال سرپرست';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'تمام چیٹس کو حقیقی وقت میں دیکھیں، لیکن صرف آپ کا $relation پیغامات بھیج سکتا ہے۔';
  }

  @override
  String get guardian_details_mode_passive_title => 'صرف مشاہدہ کریں۔';

  @override
  String get guardian_details_name_hint => 'پورا نام';

  @override
  String get guardian_details_name_subtitle =>
      'آپ کا نام بطور سرپرست۔ یہ مماثلتوں کو دکھایا گیا ہے۔';

  @override
  String guardian_details_notice(Object relation) {
    return 'آپ اپنے $relation کے لیے ایک پروفائل بنا رہے ہیں۔ اگلی اسکرینوں پر پروفائل کی تمام تفصیلات ان کی وضاحت کریں گی، آپ کی نہیں۔';
  }

  @override
  String get guardian_details_search_hint => 'تلاش کریں۔';

  @override
  String get guardian_details_select_code => 'ملک کا کوڈ منتخب کریں۔';

  @override
  String get guardian_details_subtitle =>
      'اپنے بارے میں بطور سرپرست ہمیں بتائیں۔';

  @override
  String get guardian_details_title => 'آپ کے سرپرست کی تفصیلات';

  @override
  String get guardian_details_your_name => 'آپ کا نام';

  @override
  String get interest_cat_creative => 'تخلیقی';

  @override
  String get interest_cat_faith => 'ایمان';

  @override
  String get interest_cat_learning => 'سیکھنا';

  @override
  String get interest_cat_lifestyle => 'طرز زندگی';

  @override
  String get interest_cat_social => 'سماجی';

  @override
  String get interest_cat_sports => 'کھیل';

  @override
  String get interest_tag_art => 'فن';

  @override
  String get interest_tag_calligraphy => 'خطاطی۔';

  @override
  String get interest_tag_community_work => 'کمیونٹی کا کام';

  @override
  String get interest_tag_cooking => 'کھانا پکانا';

  @override
  String get interest_tag_crafts => 'دستکاری';

  @override
  String get interest_tag_cricket => 'کرکٹ';

  @override
  String get interest_tag_cycling => 'سائیکلنگ';

  @override
  String get interest_tag_dawah => 'دعوۃ';

  @override
  String get interest_tag_family_gatherings => 'خاندانی اجتماعات';

  @override
  String get interest_tag_fitness => 'فٹنس';

  @override
  String get interest_tag_football => 'فٹ بال';

  @override
  String get interest_tag_gardening => 'باغبانی';

  @override
  String get interest_tag_graphic_design => 'گرافک ڈیزائن';

  @override
  String get interest_tag_hiking => 'پیدل سفر';

  @override
  String get interest_tag_history => 'تاریخ';

  @override
  String get interest_tag_islamic_lectures => 'اسلامی لیکچرز';

  @override
  String get interest_tag_languages => 'زبانیں';

  @override
  String get interest_tag_martial_arts => 'مارشل آرٹس';

  @override
  String get interest_tag_mentoring => 'رہنمائی کرنا';

  @override
  String get interest_tag_photography => 'فوٹوگرافی';

  @override
  String get interest_tag_poetry => 'شاعری';

  @override
  String get interest_tag_quran_recitation => 'تلاوت قرآن';

  @override
  String get interest_tag_reading => 'پڑھنا';

  @override
  String get interest_tag_science => 'سائنس';

  @override
  String get interest_tag_swimming => 'تیراکی';

  @override
  String get interest_tag_tahajjud => 'تہجد';

  @override
  String get interest_tag_teaching => 'پڑھانا';

  @override
  String get interest_tag_technology => 'ٹیکنالوجی';

  @override
  String get interest_tag_travel => 'سفر';

  @override
  String get interest_tag_umrah_hajj => 'عمرہ/ حج';

  @override
  String get interest_tag_voluntary_fasting => 'رضاکارانہ روزہ';

  @override
  String get interest_tag_volunteering => 'رضاکارانہ';

  @override
  String get interest_tag_writing => 'تحریر';

  @override
  String get interests_button_accept => 'قبول کریں۔';

  @override
  String get interests_button_decline => 'رد کرنا';

  @override
  String get interests_tab_received => 'موصول ہوا۔';

  @override
  String get interests_tab_sent => 'بھیجا';

  @override
  String get interests_title => 'دلچسپیاں';

  @override
  String get lang_albanian => 'البانوی';

  @override
  String get lang_amazigh => 'Amazigh (بربر)';

  @override
  String get lang_amharic => 'امہاری';

  @override
  String get lang_arabic => 'عربی';

  @override
  String get lang_assamese => 'آسامی';

  @override
  String get lang_balochi => 'بلوچی۔';

  @override
  String get lang_bengali => 'بنگالی';

  @override
  String get lang_bosnian => 'بوسنیائی';

  @override
  String get lang_burmese => 'برمی';

  @override
  String get lang_chechen => 'چیچن';

  @override
  String get lang_chinese => 'چینی (مینڈارن)';

  @override
  String get lang_dari => 'دری';

  @override
  String get lang_dutch => 'ڈچ';

  @override
  String get lang_english => 'انگریزی';

  @override
  String get lang_french => 'فرانسیسی';

  @override
  String get lang_fulani => 'فلانی';

  @override
  String get lang_german => 'جرمن';

  @override
  String get lang_gujarati => 'گجراتی';

  @override
  String get lang_hausa => 'ہاؤسا';

  @override
  String get lang_hindi => 'ہندی';

  @override
  String get lang_igbo => 'اگبو';

  @override
  String get lang_indonesian => 'انڈونیشین';

  @override
  String get lang_italian => 'اطالوی';

  @override
  String get lang_japanese => 'جاپانی';

  @override
  String get lang_javanese => 'جاوانی';

  @override
  String get lang_kannada => 'کنڑ';

  @override
  String get lang_kazakh => 'قازق';

  @override
  String get lang_korean => 'کورین';

  @override
  String get lang_kurdish => 'کرد';

  @override
  String get lang_kyrgyz => 'کرغیز';

  @override
  String get lang_malay => 'مالائی';

  @override
  String get lang_malayalam => 'ملیالم';

  @override
  String get lang_mandinka => 'مینڈنکا';

  @override
  String get lang_marathi => 'مراٹھی';

  @override
  String get lang_norwegian => 'ناروے';

  @override
  String get lang_odia => 'اوڈیا';

  @override
  String get lang_other => 'دیگر';

  @override
  String get lang_pashto => 'پشتو';

  @override
  String get lang_persian => 'فارسی';

  @override
  String get lang_portuguese => 'پرتگالی';

  @override
  String get lang_punjabi => 'پنجابی';

  @override
  String get lang_rohingya => 'روہنگیا';

  @override
  String get lang_russian => 'روسی';

  @override
  String get lang_saraiki => 'سرائیکی';

  @override
  String get lang_sindhi => 'سندھی';

  @override
  String get lang_somali => 'صومالی';

  @override
  String get lang_spanish => 'ہسپانوی';

  @override
  String get lang_sundanese => 'سنڈانی';

  @override
  String get lang_swahili => 'سواحلی';

  @override
  String get lang_swedish => 'سویڈش';

  @override
  String get lang_tagalog => 'ٹیگالوگ';

  @override
  String get lang_tajik => 'تاجک';

  @override
  String get lang_tamil => 'تامل';

  @override
  String get lang_tatar => 'تاتار';

  @override
  String get lang_telugu => 'تیلگو';

  @override
  String get lang_thai => 'تھائی';

  @override
  String get lang_tigrinya => 'ٹگرینیا';

  @override
  String get lang_turkish => 'ترکی';

  @override
  String get lang_urdu => 'اردو';

  @override
  String get lang_uzbek => 'ازبک';

  @override
  String get lang_wolof => 'وولف';

  @override
  String get lang_yoruba => 'یوروبا';

  @override
  String get legal_button_continue => 'جاری رکھیں';

  @override
  String get legal_checkbox_age =>
      'میں تصدیق کرتا ہوں کہ میری عمر 18 سال یا اس سے زیادہ ہے۔';

  @override
  String get legal_checkbox_terms =>
      'میں سروس کی شرائط اور رازداری کی پالیسی سے اتفاق کرتا ہوں۔';

  @override
  String get legal_subtitle => 'براہ کرم پڑھیں اور جاری رکھنے سے اتفاق کریں۔';

  @override
  String get legal_summary_1 =>
      'آپ کا ڈیٹا انکرپٹڈ ہے اور تیسرے فریق کو کبھی فروخت نہیں کیا جاتا۔';

  @override
  String get legal_summary_2 =>
      'ہر تصویر کی حفاظتی جانچ ہوتی ہے اور ہماری ٹیم نئی تصاویر کا جائزہ لیتی ہے۔';

  @override
  String get legal_summary_3 =>
      'ہراساں کرنا، جعلی پروفائلز، اور گھوٹالوں کے نتیجے میں مستقل پابندی لگتی ہے۔';

  @override
  String get legal_summary_4 =>
      'یہ پلیٹ فارم صرف شادی کے ارادوں کے لیے ہے۔ وقار معیار ہے۔';

  @override
  String get legal_summary_5 =>
      'آپ کسی بھی وقت اپنا اکاؤنٹ اور تمام ڈیٹا حذف کر سکتے ہیں۔';

  @override
  String get legal_title => 'اس سے پہلے کہ آپ شروع کریں۔';

  @override
  String get notifications_empty_subtitle => 'ابھی کوئی نئی اطلاعات نہیں ہیں۔';

  @override
  String get notifications_empty_title => 'آپ سب پکڑے گئے ہیں۔';

  @override
  String get notifications_markAllRead => 'سب کو پڑھا ہوا نشان زد کریں۔';

  @override
  String get notifications_title => 'اطلاعات';

  @override
  String get onboarding_about_title => 'اپنے بارے میں';

  @override
  String get onboarding_background_title => 'تعلیم اور کیریئر';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'آپ اسے بطور سرپرست بھر رہے ہیں۔ یہ تفصیلات آپ کے $relation کے بارے میں ہیں۔';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'یہ وہی ہے جو دوسرے ان کے پروفائل پر دیکھیں گے۔';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'یہ وہی ہے جو دوسرے آپ کے پروفائل پر دیکھیں گے۔';

  @override
  String get onboarding_basicIdentity_title => 'ہمیں اپنے بارے میں بتائیں';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'ہمیں اپنے $relation کے بارے میں بتائیں';
  }

  @override
  String get onboarding_debt_manageable => 'قابل انتظام قرض';

  @override
  String get onboarding_debt_none => 'کوئی قرض نہیں۔';

  @override
  String get onboarding_debt_significant => 'اہم قرض';

  @override
  String get onboarding_diet_eatsAnything => 'کچھ بھی حلال کھاتا ہے۔';

  @override
  String get onboarding_diet_halalOnly => 'صرف حلال';

  @override
  String get onboarding_diet_vegan => 'ویگن';

  @override
  String get onboarding_diet_vegetarian => 'سبزی خور';

  @override
  String get onboarding_diet_zabihaStrict => 'سخت ذبیحہ';

  @override
  String get onboarding_error_bioContactInfo =>
      'براہ کرم اپنے بائیو سے رابطے کی معلومات کو ہٹا دیں۔ آپ کی حفاظت کے لیے بیرونی رابطے کی تفصیلات کی اجازت نہیں ہے۔';

  @override
  String get onboarding_error_multipleFaces =>
      'گروپ فوٹو آپ کی بنیادی تصویر نہیں ہو سکتی۔';

  @override
  String get onboarding_error_noFace =>
      'براہ کرم ایسی تصویر استعمال کریں جہاں آپ کا چہرہ واضح طور پر نظر آ رہا ہو۔';

  @override
  String get onboarding_error_under18 =>
      'Silarah 18 سال اور اس سے زیادہ عمر والوں کے لیے ہے۔ ہم نے یہ تقاضا اپنی کمیونٹی میں ہر ایک کی حفاظت کے لیے کیا ہے۔';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Silarah استعمال کرنے کے لیے آپ کی $relation کی عمر 18 یا اس سے زیادہ ہونی چاہیے۔';
  }

  @override
  String get onboarding_error_under18_self =>
      'Silarah استعمال کرنے کے لیے آپ کی عمر 18 سال یا اس سے زیادہ ہونی چاہیے۔ تب ہم آپ کا استقبال کرنے کے منتظر ہیں۔';

  @override
  String get onboarding_habit_frequently => 'کثرت سے';

  @override
  String get onboarding_habit_never => 'کبھی نہیں۔';

  @override
  String get onboarding_habit_occasionally => 'کبھی کبھار';

  @override
  String get onboarding_habit_preferNotToSay => 'نہ کہنے کو ترجیح دیں۔';

  @override
  String get onboarding_hijab_always => 'ہمیشہ';

  @override
  String get onboarding_hijab_no => 'نہیں';

  @override
  String get onboarding_hijab_sometimes => 'کبھی کبھی';

  @override
  String get onboarding_hint_bio =>
      'اپنے آپ کو ایمانداری اور وقار کے ساتھ بیان کریں۔';

  @override
  String get onboarding_hint_profession =>
      'جیسے سافٹ ویئر انجینئر، استاد، ڈاکٹر';

  @override
  String get onboarding_hint_searchCity => 'اپنا شہر تلاش کریں…';

  @override
  String get onboarding_hint_selectCommunity => 'کمیونٹی منتخب کریں (اختیاری)';

  @override
  String get onboarding_hint_selectCountry => 'ملک منتخب کریں۔';

  @override
  String get onboarding_hint_selectDateOfBirth => 'تاریخ پیدائش منتخب کریں۔';

  @override
  String get onboarding_hint_selectLanguage => 'زبان منتخب کریں۔';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'یہ آپ کو کسی ہم آہنگ کے ساتھ ملانے میں مدد کرتا ہے۔';

  @override
  String get onboarding_islamicIdentity_title => 'آپ کی اسلامی شناخت';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'شہر';

  @override
  String get onboarding_label_city_guardian => 'ان کا شہر';

  @override
  String get onboarding_label_city_self => 'آپ کا شہر';

  @override
  String get onboarding_label_community => 'آپ کی برادری/بیرادری۔';

  @override
  String get onboarding_label_community_parent => 'ان کی برادری/برادری';

  @override
  String get onboarding_label_complexion => 'رنگت (اختیاری)';

  @override
  String get onboarding_label_country_guardian => 'ان کا ملک';

  @override
  String get onboarding_label_country_self => 'آپ کا ملک';

  @override
  String get onboarding_label_cultural => 'ثقافتی مسلمان';

  @override
  String get onboarding_label_dateOfBirth => 'تاریخ پیدائش';

  @override
  String get onboarding_label_debtStatus => 'قرض کی حیثیت';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'آپ کی موجودہ مالی ذمہ داریاں۔';

  @override
  String get onboarding_label_deenLevel => 'دین کی سطح';

  @override
  String get onboarding_label_diet => 'خوراک';

  @override
  String get onboarding_label_educationLevel => 'تعلیم کی سطح';

  @override
  String get onboarding_label_female => 'خاتون';

  @override
  String get onboarding_label_firstName => 'پہلا نام';

  @override
  String get onboarding_label_firstName_guardian => 'امیدوار کا پہلا نام';

  @override
  String get onboarding_label_firstName_self => 'پہلا نام';

  @override
  String get onboarding_label_gender => 'جنس';

  @override
  String get onboarding_label_gender_guardian => 'امیدوار کی جنس';

  @override
  String get onboarding_label_gender_self => 'جنس';

  @override
  String get onboarding_label_height_guardian => 'ان کا قد';

  @override
  String get onboarding_label_height_self => 'آپ کا قد';

  @override
  String get onboarding_label_hookah => 'ہُکّہ/شیشہ';

  @override
  String get onboarding_label_housing => 'ہاؤسنگ';

  @override
  String get onboarding_label_housingQuestion =>
      'کیا آپ علیحدہ رہنے کی جگہ فراہم کر سکتے ہیں؟';

  @override
  String get onboarding_label_lastName => 'آخری نام';

  @override
  String get onboarding_label_leadership => 'مذہبی قیادت';

  @override
  String get onboarding_label_leadershipQuestion =>
      'کیا آپ باجماعت نماز پڑھ سکتے ہیں؟';

  @override
  String get onboarding_label_lifestyleDiet => 'طرز زندگی اور غذا';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'یہ بہت سے خاندانوں کے لیے ڈیل بریکر فیلڈز ہیں۔ براہ کرم ایمانداری سے جواب دیں۔';

  @override
  String get onboarding_label_livingExpectation =>
      'شادی کے بعد زندگی کی توقعات';

  @override
  String get onboarding_label_mahrBudget => 'مہر بجٹ';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'آپ مہر کی کون سی حد پیش کرنے کے لیے تیار ہیں؟';

  @override
  String get onboarding_label_mahrExpectation => 'مہر کی توقع';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'مہر سے آپ کی کیا توقع ہے؟';

  @override
  String get onboarding_label_maintenance => 'مالی دیکھ بھال';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'کیا آپ شریک حیات کو مالی طور پر فراہم کرنے کے قابل ہیں؟';

  @override
  String get onboarding_label_male => 'مرد';

  @override
  String get onboarding_label_marriageTimeline => 'شادی کی ٹائم لائن';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'آپ شادی کب کرنا چاہتے ہیں؟';

  @override
  String get onboarding_label_moderate => 'اعتدال پسند';

  @override
  String get onboarding_label_motherTongue => 'مادری زبان';

  @override
  String get onboarding_label_niqab => 'نقاب';

  @override
  String get onboarding_label_practicing => 'مشق کرنا';

  @override
  String get onboarding_label_praysFiveDaily =>
      'میں روزانہ پانچ وقت کی نماز پڑھتا ہوں۔';

  @override
  String get onboarding_label_preferNotToSay => 'نہ کہنے کو ترجیح دیں۔';

  @override
  String get onboarding_label_preferredLiving => 'رہائش کے انتظام کی ترجیح';

  @override
  String get onboarding_label_profession => 'پیشہ';

  @override
  String get onboarding_label_providerReadiness => 'فراہم کنندہ کی تیاری';

  @override
  String get onboarding_label_quranMemorization => 'حفظ قرآن';

  @override
  String get onboarding_label_religiousEducation => 'مذہبی تعلیم';

  @override
  String get onboarding_label_residencyStatus => 'رہائش کی حیثیت (اختیاری)';

  @override
  String get onboarding_label_revert => 'واپس / تبدیل کریں (اختیاری)';

  @override
  String get onboarding_label_revertQuestion =>
      'کیا آپ اسلام قبول کرنے والے ہیں؟';

  @override
  String get onboarding_label_sect => 'فرقہ';

  @override
  String get onboarding_label_shia => 'شیعہ';

  @override
  String get onboarding_label_smoking => 'تمباکو نوشی';

  @override
  String get onboarding_label_specialNeeds => 'خصوصی ضروریات (اختیاری)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'مرحلہ $current از $total';
  }

  @override
  String get onboarding_label_subSect => 'مکتب فکر (اختیاری)';

  @override
  String get onboarding_label_substanceUse => 'مادہ کا استعمال';

  @override
  String get onboarding_label_sunni => 'سنی';

  @override
  String get onboarding_label_vaping => 'ویپنگ / ای سگریٹ';

  @override
  String get onboarding_label_workAfterMarriage => 'شادی کے بعد کام';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'کیا آپ شادی کے بعد کام کرنا پسند کریں گے؟';

  @override
  String get onboarding_leadership_leads => 'نماز کی امامت کرتا ہے۔';

  @override
  String get onboarding_leadership_learning => 'سیکھنا';

  @override
  String get onboarding_leadership_notYet => 'ابھی تک نہیں۔';

  @override
  String get onboarding_living_openToDiscussion => 'بحث کے لیے کھولیں۔';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'میں لچکدار ہوں اور اس بات پر خوش ہوں کہ دونوں کے لیے کیا کام کرتا ہے۔';

  @override
  String get onboarding_living_separate => 'الگ گھر';

  @override
  String get onboarding_living_separateSub =>
      'میں ترجیح دیتا ہوں کہ ہمارا اپنا خود مختار گھر ہو۔';

  @override
  String get onboarding_living_withInlaws => 'سسرال والوں کے ساتھ';

  @override
  String get onboarding_living_withInlawsSub =>
      'میں اپنے شریک حیات یا اپنے خاندان کے ساتھ رہنے کی توقع رکھتا ہوں۔';

  @override
  String get onboarding_location_confirmed => 'تصدیق شدہ مقام';

  @override
  String get onboarding_mahr_generous => 'فیاض';

  @override
  String get onboarding_mahr_moderate => 'اعتدال پسند';

  @override
  String get onboarding_mahr_modest => 'معمولی';

  @override
  String get onboarding_mahr_noPreference => 'کوئی ترجیح نہیں۔';

  @override
  String get onboarding_mahr_toDiscuss => 'بحث کرنا';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'یہ تفصیلات آپ کے عوامی پروفائل پر نہیں دکھائی جاتی ہیں۔ قبولیت کے مرحلے کے دوران ان کا اشتراک نجی طور پر کیا جاتا ہے۔';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'اپنے سفر اور تیاری کو سمجھنے میں ہماری مدد کریں۔';

  @override
  String get onboarding_marriageDeen_title => 'نکاح اور دین';

  @override
  String get onboarding_niqab_dontWear => 'میں نقاب نہیں پہنتا';

  @override
  String get onboarding_niqab_open => 'پہننے کے لیے کھلا۔';

  @override
  String get onboarding_niqab_wear => 'میں نقاب پہنتا ہوں۔';

  @override
  String get onboarding_photo_subtitle =>
      'کم از کم ایک تصویر درکار ہے۔ آپ کی بنیادی تصویر میں آپ کا چہرہ واضح طور پر شامل ہونا چاہیے۔';

  @override
  String get onboarding_photo_title => 'اپنی تصاویر شامل کریں۔';

  @override
  String get onboarding_photo_verifySelfie => 'تصدیقی سیلفی';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'اس بات کی تصدیق کرنے کے لیے ایک لائیو تصویر لیں کہ آپ حقیقی ہیں۔';

  @override
  String get onboarding_preferredLiving_noPreference => 'کوئی ترجیح نہیں۔';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'میں اسے اپنے لیے بنا رہا ہوں…';

  @override
  String get onboarding_profileForWhom_guardian => 'میرا بیٹا یا بیٹی';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'میں یہ پروفائل کسی کے لیے بنا رہا ہوں۔';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'گارڈین';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'میں والدین یا سرپرست ہوں۔';

  @override
  String get onboarding_profileForWhom_myself => 'میں خود';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'میں شریک حیات کی تلاش میں ہوں۔';

  @override
  String get onboarding_profileForWhom_relation_brother => 'بھائی';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'بیٹی';

  @override
  String get onboarding_profileForWhom_relation_sister => 'بہن';

  @override
  String get onboarding_profileForWhom_relation_son => 'بیٹا';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'جاری رکھنے کے لیے ایک کو منتخب کریں۔';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'جاری رکھنے کے لیے ایک رشتہ منتخب کریں۔';

  @override
  String get onboarding_profileForWhom_sibling => 'میرا بھائی یا بہن';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'میں اپنے بہن بھائی کی میچ تلاش کرنے میں مدد کر رہا ہوں۔';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'آپ اسے بعد میں ترتیبات سے اپ ڈیٹ کر سکتے ہیں۔';

  @override
  String get onboarding_profileForWhom_title => 'یہ پروفائل کس کے لیے ہے؟';

  @override
  String get onboarding_profileForWhom_ward => 'میرا وارڈ';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'میں اس پروفائل کا انتظام کرنے والا ایک سرپرست ہوں۔';

  @override
  String get onboarding_providerQuote =>
      '’’تم میں سے بہترین وہ ہے جو اپنی بیویوں کے لیے بہترین ہو۔‘‘ - رسول اللہ صلی اللہ علیہ وسلم\n\nاپنی تیاری کے بارے میں ایماندار ہونا ایک مضبوط بنیاد بنانے میں مدد کرتا ہے۔';

  @override
  String get onboarding_quran_hafiz => 'حافظہ/ حافظہ';

  @override
  String get onboarding_quran_none => 'کوئی نہیں۔';

  @override
  String get onboarding_quran_partial => 'جزوی حفظ';

  @override
  String get onboarding_quran_some => 'کچھ سورتیں۔';

  @override
  String get onboarding_religiousEdu_alim => 'علیم کورس';

  @override
  String get onboarding_religiousEdu_islamicUni => 'اسلامی یونیورسٹی';

  @override
  String get onboarding_religiousEdu_madrasa => 'مدرسہ';

  @override
  String get onboarding_religiousEdu_selfTaught => 'خود سکھایا';

  @override
  String get onboarding_timeline_1year => 'ایک سال کے اندر اندر';

  @override
  String get onboarding_timeline_2years => '2+ سال';

  @override
  String get onboarding_timeline_6months => '6 ماہ کے اندر';

  @override
  String get onboarding_timeline_asap => 'جتنی جلدی ممکن ہو';

  @override
  String get onboarding_timeline_notSure => 'ابھی تک یقین نہیں ہے۔';

  @override
  String get onboarding_tooltip_cultural =>
      'مسلمان کے طور پر شناخت کرتا ہے، مواقع مناتا ہے، باقاعدگی سے نماز نہیں پڑھ سکتا';

  @override
  String get onboarding_tooltip_moderate =>
      'اسلامی اصولوں کو اہمیت دیتے ہیں اور نماز پڑھتے ہیں، اگرچہ ہمیشہ دن میں پانچ وقت نہیں';

  @override
  String get onboarding_tooltip_practicing =>
      'پانچوں ستونوں کی پیروی کرتا ہے، باقاعدگی سے نماز پڑھتا ہے، حلال طرز زندگی';

  @override
  String get onboarding_work_no => 'نہیں، میں نہیں کرنا پسند کرتا ہوں۔';

  @override
  String get onboarding_work_yes => 'ہاں، میں کام کرنے کا ارادہ رکھتا ہوں۔';

  @override
  String get photo_add_main_required => 'مرکزی تصویر شامل کریں۔\n(ضروری)';

  @override
  String get photo_add_photo => 'تصویر شامل کریں۔';

  @override
  String get photo_banner_text => 'واضح مواد والی تصاویر کی اجازت نہیں ہے';

  @override
  String get photo_error_no_face_detected =>
      'کوئی چہرہ نظر نہیں آتا — براہ کرم ایک صاف چہرے کی تصویر کے ساتھ دوبارہ کوشش کریں۔';

  @override
  String photo_error_pick_failed(Object error) {
    return 'تصویر نہیں اٹھا سکی: $error';
  }

  @override
  String get photo_face_detected => 'چہرے کا پتہ چلا ✓';

  @override
  String get photo_label_photo2 => 'تصویر 2';

  @override
  String get photo_label_photo3 => 'تصویر 3';

  @override
  String get photo_label_primary => 'بنیادی تصویر';

  @override
  String get photo_label_selfie => 'تصویر 4';

  @override
  String get photo_no_face => 'کوئی چہرہ نظر نہیں آتا';

  @override
  String get photo_privacy_everyone => 'سب کے لیے مرئی';

  @override
  String get photo_privacy_everyone_sub =>
      'تمام ممبران آپ کی تصاویر دیکھ سکتے ہیں۔';

  @override
  String get photo_privacy_label => 'تصویر کی رازداری';

  @override
  String get photo_privacy_mutual => 'باہمی دلچسپی کے بعد نظر آتا ہے۔';

  @override
  String get photo_privacy_mutual_sub =>
      'تصاویر صرف اس وقت ظاہر کرتی ہیں جب دونوں فریق دلچسپی کا اظہار کرتے ہیں۔';

  @override
  String get photo_privacy_request => 'دیکھنے کی درخواست کریں۔';

  @override
  String get photo_privacy_request_sub =>
      'تصاویر اس وقت تک دھندلی رہتی ہیں جب تک آپ درخواست منظور نہیں کر لیتے۔';

  @override
  String get photo_sheet_camera => 'کیمرہ';

  @override
  String get photo_sheet_gallery => 'گیلری';

  @override
  String get photo_sheet_title => 'تصویر کا ماخذ منتخب کریں۔';

  @override
  String get photo_slots_help => 'اپ لوڈ کرنے کے لیے سلاٹس پر ٹیپ کریں۔';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'اپنی $relation کی تصاویر شامل کریں۔ کم از کم ایک کی ضرورت ہے۔';
  }

  @override
  String get photo_subtitle_self =>
      'کم از کم ایک تصویر درکار ہے۔ زیادہ سے زیادہ چار۔';

  @override
  String get photo_title_guardian => 'ان کی تصاویر شامل کریں۔';

  @override
  String get photo_title_self => 'اپنی تصاویر شامل کریں۔';

  @override
  String get preferences_deen_any => 'کوئی بھی';

  @override
  String get preferences_deen_cultural => 'ثقافتی مسلمان';

  @override
  String get preferences_deen_moderate => 'اعتدال پسند';

  @override
  String get preferences_deen_practicing => 'مشق کرنا';

  @override
  String get preferences_edu_any => 'کوئی بھی';

  @override
  String get preferences_edu_bachelors => 'بیچلر +';

  @override
  String get preferences_edu_diploma => 'ڈپلومہ +';

  @override
  String get preferences_edu_masters => 'ماسٹرز +';

  @override
  String get preferences_edu_phd => 'صرف پی ایچ ڈی';

  @override
  String get preferences_edu_secondary => 'ثانوی +';

  @override
  String get preferences_label_age => 'عمر کی حد';

  @override
  String get preferences_label_age_bounds => '18 - 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max سال';
  }

  @override
  String get preferences_label_deen => 'دین کی سطح کی ترجیح';

  @override
  String get preferences_label_edu => 'کم از کم تعلیم';

  @override
  String get preferences_label_living => 'رہائش کے انتظام کی ترجیح';

  @override
  String get preferences_label_location => 'LOCATION';

  @override
  String get preferences_label_openness => 'کھلا پن';

  @override
  String get preferences_label_sect => 'فرقہ کی ترجیح';

  @override
  String get preferences_living_discussion => 'بحث کے لیے کھولیں۔';

  @override
  String get preferences_living_family => 'فیملی کے ساتھ';

  @override
  String get preferences_living_no_pref => 'کوئی ترجیح نہیں۔';

  @override
  String get preferences_living_separate => 'الگ گھر';

  @override
  String get preferences_location_abroad => 'بیرون ملک کے لیے کھلا ہے۔';

  @override
  String get preferences_location_diaspora => 'ڈاسپورا موڈ';

  @override
  String get preferences_location_same_city => 'ایک ہی شہر';

  @override
  String get preferences_location_same_country => 'ایک ہی ملک';

  @override
  String get preferences_open_children => 'بچوں کے ساتھ کسی کے لئے کھولیں۔';

  @override
  String get preferences_open_divorced => 'پہلے سے طلاق یافتہ کسی کے لیے کھلا۔';

  @override
  String get preferences_open_widowed => 'کسی کے لئے کھلا جو پہلے بیوہ ہو۔';

  @override
  String get preferences_sect_any => 'کوئی بھی';

  @override
  String get preferences_sect_same => 'میرے جیسا ہی';

  @override
  String get preferences_sect_shia => 'شیعہ';

  @override
  String get preferences_sect_sunni => 'سنی';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'اپنے $relation کے مثالی میچ کے لیے ترجیحات سیٹ کریں۔';
  }

  @override
  String get preferences_subtitle_self => 'یہ ترجیحات ہیں، سخت فلٹرز نہیں۔';

  @override
  String get preferences_title => 'ساتھی کی ترجیحات';

  @override
  String get preview_age_label => 'عمر';

  @override
  String get preview_background => 'پس منظر';

  @override
  String get preview_basic_info => 'بنیادی معلومات';

  @override
  String get preview_city_label => 'شہر';

  @override
  String get preview_community_label => 'برادری';

  @override
  String get preview_cowife_label => 'شریک بیوی کی قبولیت';

  @override
  String get preview_deen_label => 'دین کی سطح';

  @override
  String get preview_diet_label => 'خوراک';

  @override
  String get preview_edit => 'ترمیم کریں۔';

  @override
  String get preview_education_label => 'تعلیم';

  @override
  String get preview_faith => 'ایمان';

  @override
  String get preview_family => 'خاندان';

  @override
  String get preview_family_type_label => 'خاندانی قسم';

  @override
  String get preview_gender_label => 'جنس';

  @override
  String get preview_hijab_label => 'حجاب';

  @override
  String get preview_hookah_label => 'ہکا';

  @override
  String get preview_leadership_label => 'قیادت';

  @override
  String get preview_marital_label => 'ازدواجی';

  @override
  String get preview_marriage_timeline_label => 'شادی کی ٹائم لائن';

  @override
  String get preview_mother_tongue_label => 'مادری زبان';

  @override
  String get preview_name_label => 'نام';

  @override
  String get preview_notice_guardian =>
      'بالکل اسی طرح دوسرے لوگ ان کا پروفائل دیکھیں گے۔';

  @override
  String get preview_notice_self =>
      'بالکل اسی طرح دوسرے لوگ آپ کا پروفائل دیکھیں گے۔';

  @override
  String get preview_polygamy_label => 'تعدد ازدواج';

  @override
  String get preview_post_marriage_living_label => 'شادی کے بعد کی زندگی';

  @override
  String get preview_prays_label => '5 بار نماز پڑھتا ہے۔';

  @override
  String get preview_profession_label => 'پیشہ';

  @override
  String get preview_quran_label => 'قرآن';

  @override
  String get preview_religious_edu_label => 'مذہبی تعلیم';

  @override
  String get preview_residency_label => 'رہائش گاہ';

  @override
  String get preview_revert_label => 'واپس لوٹنا';

  @override
  String get preview_sect_label => 'فرقہ';

  @override
  String get preview_siblings_label => 'بہن بھائی';

  @override
  String get preview_smoking_label => 'تمباکو نوشی';

  @override
  String get preview_special_needs_label => 'خصوصی ضروریات';

  @override
  String get preview_submit_btn => 'پروفائل جمع کروائیں۔';

  @override
  String get preview_title => 'پیش نظارہ';

  @override
  String get preview_vaping_label => 'ویپنگ';

  @override
  String get preview_willing_relocate_label => 'نقل مکانی پر آمادہ';

  @override
  String profile_label_completeness(int percent) {
    return 'پروفائل $percent% مکمل';
  }

  @override
  String get profile_nudge_completeness =>
      '80%+ مکمل ہونے والے پروفائلز 3× مزید دلچسپیاں حاصل کرتے ہیں۔';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · اللہ کی خاطر';

  @override
  String get settings_button_deleteAccount => 'اکاؤنٹ حذف کریں۔';

  @override
  String get settings_guardian_mirror => 'آئینہ پیغامات';

  @override
  String get settings_guardian_mirror_sub =>
      'تمام پیغامات کی کاپیاں سرپرست کو بھیجیں۔';

  @override
  String get settings_guardian_name_hint => 'سرپرست کا نام';

  @override
  String get settings_guardian_relationship => 'رشتہ';

  @override
  String get settings_guardian_reply => 'گارڈین کو جواب دینے کی اجازت دیں۔';

  @override
  String get settings_guardian_reply_sub =>
      'سرپرست بات چیت میں حصہ لے سکتا ہے۔';

  @override
  String get settings_guardian_save => 'گارڈین کی ترتیبات کو محفوظ کریں۔';

  @override
  String get settings_guardian_saved => 'محفوظ کیا گیا۔';

  @override
  String get settings_guardian_sub =>
      'پیغام رسانی کے لیے ولی نگرانی کو فعال کریں۔';

  @override
  String get settings_guardian_title => 'گارڈین موڈ';

  @override
  String get settings_label_blocked => 'بلاک شدہ پروفائلز';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count مسدود';
  }

  @override
  String get settings_label_blocked_none => 'کوئی نہیں۔';

  @override
  String get settings_label_deleteGrace =>
      'آپ کا پروفائل فوری طور پر چھپا دیا جائے گا۔ آپ کا ڈیٹا 30 دنوں کے بعد مستقل طور پر حذف ہو جائے گا۔';

  @override
  String get settings_label_editProfile => 'پروفائل میں ترمیم کریں۔';

  @override
  String get settings_label_language => 'زبان';

  @override
  String get settings_label_photoPrivacy => 'تصویر کی رازداری';

  @override
  String get settings_label_rate => 'Silarah کی درجہ بندی کریں۔';

  @override
  String get settings_label_rate_snackbar =>
      'ایپ اسٹور پر Silarah کے لانچ ہونے کے بعد درجہ بندی دستیاب ہوگی۔';

  @override
  String get settings_label_reports => 'رپورٹ کی تاریخ';

  @override
  String settings_label_reports_count(Object count) {
    return '$count رپورٹس';
  }

  @override
  String get settings_label_reports_none => 'کوئی رپورٹ پیش نہیں کی گئی۔';

  @override
  String get settings_label_selfieChallenge => 'سیلفی چیلنج';

  @override
  String get settings_label_verifyProfile => 'پروفائل کی تصدیق کریں۔';

  @override
  String get settings_label_version => 'ورژن';

  @override
  String get settings_notify_activityNudges => 'سرگرمی کی طرف اشارہ کرتا ہے۔';

  @override
  String get settings_notify_activityNudgesSub =>
      'پروفائل مکمل کرنے کی تجاویز اور 7 دن غیر فعال رہنے پر یاد دہانی';

  @override
  String get settings_notify_boostReminders => 'یاد دہانیوں کو فروغ دیں۔';

  @override
  String get settings_notify_boostRemindersSub =>
      'یاد دلائیں جب آپ کا ہفتہ وار فروغ تیار ہو۔';

  @override
  String get settings_notify_interestAccepted => 'دلچسپی قبول کر لی گئی';

  @override
  String get settings_notify_interestExpiring =>
      'دلچسپی کی میعاد جلد ختم ہو رہی ہے۔';

  @override
  String get settings_notify_newInterest => 'نئی دلچسپیاں';

  @override
  String get settings_notify_newMessage => 'نئے پیغامات';

  @override
  String get settings_notify_quietHours => 'خاموشی کے اوقات';

  @override
  String get settings_photo_privacy_accepted_interests => 'صرف قبول شدہ مفادات';

  @override
  String get settings_photo_privacy_after_acceptance => 'قبولیت کے بعد';

  @override
  String get settings_photo_privacy_everyone => 'ہر کوئی';

  @override
  String get settings_photo_privacy_public => 'عوامی';

  @override
  String get settings_photo_privacy_request_only => 'صرف درخواست کریں۔';

  @override
  String get settings_photo_privacy_request_to_view =>
      'دیکھنے کی درخواست کریں۔';

  @override
  String get settings_privacy_download_body =>
      'اپنے اکاؤنٹ، پروفائل، تصاویر، دلچسپیوں، میچز، پیغامات، ترتیبات، رضامندیوں اور سبسکرپشن ہسٹری کا نجی ZIP آرکائیو ابھی بنائیں۔ اسے اپنے آلے کی محفوظ شیئر شیٹ سے محفوظ کریں۔';

  @override
  String get settings_privacy_download_btn => 'محفوظ آرکائیو بنائیں';

  @override
  String get settings_privacy_download_label => 'میرا ڈیٹا ڈاؤن لوڈ کریں';

  @override
  String get settings_privacy_download_sub =>
      'اپنے Silarah ڈیٹا کی مشین ریڈیبل کاپی محفوظ کریں';

  @override
  String get settings_privacy_export_body =>
      'آپ کا نجی آرکائیو تیار ہے۔ اسے محفوظ کرنے کے لیے شیئر شیٹ استعمال کریں۔';

  @override
  String get settings_privacy_export_btn_close => 'سمجھ گیا';

  @override
  String get settings_privacy_export_subbody =>
      'اس آرکائیو میں نجی پیغامات اور رابطے کی معلومات ہو سکتی ہیں۔ اسے محفوظ رکھیں اور صرف قابلِ اعتماد افراد سے شیئر کریں۔';

  @override
  String get settings_privacy_export_title => 'آرکائیو تیار ہے';

  @override
  String get settings_privacy_online_label => 'آن لائن اسٹیٹس';

  @override
  String get settings_privacy_online_sub =>
      'دکھائیں کہ آپ آخری بار کب فعال تھے۔';

  @override
  String get settings_privacy_pause_label => 'پروفائل توقف';

  @override
  String get settings_privacy_pause_sub => 'تلاش سے اپنا پروفائل چھپائیں۔';

  @override
  String get settings_privacy_pause_warning =>
      'آپ کا پروفائل چھپا ہوا ہے۔ آپ کو کوئی نہیں ڈھونڈ سکتا۔';

  @override
  String get settings_privacy_photo_label => 'تصویر کی مرئیت';

  @override
  String get settings_privacy_photo_sub => 'آپ کی تصاویر کون دیکھ سکتا ہے۔';

  @override
  String get settings_privacy_visibility_all => 'تمام رجسٹرڈ صارفین';

  @override
  String get settings_privacy_visibility_label =>
      'میری پروفائل کون دیکھ سکتا ہے۔';

  @override
  String get settings_privacy_visibility_sub =>
      'کنٹرول کرتا ہے کہ آپ کا پروفائل کون براؤز کر سکتا ہے۔';

  @override
  String get settings_privacy_visibility_subscribers => 'صرف سبسکرائبرز';

  @override
  String get settings_relation_brother => 'بھائی';

  @override
  String get settings_relation_father => 'باپ';

  @override
  String get settings_relation_mother => 'ماں';

  @override
  String get settings_relation_other => 'دیگر';

  @override
  String get settings_relation_uncle => 'چچا';

  @override
  String get settings_section_account => 'اکاؤنٹ';

  @override
  String get settings_section_app => 'ایپ';

  @override
  String get settings_section_dangerZone => 'اکاؤنٹ بند کریں';

  @override
  String get settings_section_guardian => 'گارڈین';

  @override
  String get settings_section_legal => 'قانونی';

  @override
  String get settings_section_notifications => 'اطلاعات';

  @override
  String get settings_section_privacy => 'رازداری';

  @override
  String get settings_section_safety => 'حفاظت';

  @override
  String get settings_support_body => 'کسی بھی سوال، خدشات، یا تاثرات کے لیے:';

  @override
  String get settings_support_btn_close => 'بند';

  @override
  String get settings_support_contact => 'سپورٹ سے رابطہ کریں۔';

  @override
  String get settings_support_note =>
      'ہمارا مقصد 48 گھنٹوں کے اندر جواب دینا ہے۔';

  @override
  String get settings_title => 'ترتیبات';

  @override
  String get splash_button_createProfile => 'پروفائل بنائیں';

  @override
  String get splash_button_signIn => 'سائن ان کریں۔';

  @override
  String get splash_intention_subtitle =>
      'نجی تعارف، سوچا سمجھا باہمی میل اور خاندان کا لحاظ رکھنے والا تعلق۔';

  @override
  String get splash_intention_title => 'شادی، خلوصِ نیت کے ساتھ۔';

  @override
  String get splash_referral_button => 'کوڈ کا اطلاق کریں۔';

  @override
  String get splash_referral_hint => 'جیسے SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'براہ کرم ایک درست 6 حروف کا کوڈ درج کریں۔';

  @override
  String get splash_referral_question => 'ایک ریفرل کوڈ ہے؟';

  @override
  String get splash_referral_saved =>
      'ریفرل کوڈ محفوظ ہو گیا! آپ کے سائن ان کرنے کے بعد اس کا اطلاق ہوگا۔';

  @override
  String get splash_referral_subtitle =>
      'اگر کسی دوست نے آپ کو Silarah میں مدعو کیا، تو ذیل میں ان کا 6-حروف کا حوالہ کوڈ درج کریں۔';

  @override
  String get splash_referral_title => 'ریفرل کوڈ درج کریں۔';

  @override
  String subscription_button_monthly(String price) {
    return 'سبسکرائب کریں — $price/مہینہ';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'سبسکرائب کریں — $price/3 ماہ';
  }

  @override
  String get subscription_label_bestValue => 'بہترین قدر';

  @override
  String get subscription_subtitle =>
      'خواتین کا پیغام مفت۔ مرد رابطہ قائم کرنے کے لیے سبسکرائب کریں۔';

  @override
  String get subscription_title => 'Silarah کو غیر مقفل کریں۔';

  @override
  String get startup_connectivity_preparing_title =>
      'آپ کی نجی جگہ تیار ہو رہی ہے';

  @override
  String get startup_connectivity_preparing_body =>
      'سلارہ سے محفوظ رابطہ قائم کیا جا رہا ہے۔';

  @override
  String get startup_connectivity_offline_title => 'کنکشن کا انتظار ہے';

  @override
  String get startup_connectivity_offline_body =>
      'آپ کی پروفائل، دلچسپیاں اور گفتگو محفوظ ہیں۔ جیسے ہی آپ دوبارہ آن لائن ہوں گے، سلارہ وہیں سے شروع کرے گا جہاں آپ نے چھوڑا تھا۔';

  @override
  String get startup_connectivity_verifying => 'کنکشن کی جانچ ہو رہی ہے';

  @override
  String get startup_connectivity_waiting => 'نیٹ ورک کا انتظار';

  @override
  String get startup_connectivity_still_waiting =>
      'ابھی بھی آف لائن · دوبارہ کوشش جاری';

  @override
  String get startup_connectivity_check => 'دوبارہ کوشش کریں';

  @override
  String get startup_connectivity_checking => 'جانچ ہو رہی ہے…';

  @override
  String get startup_connectivity_auto =>
      'نیٹ ورک واپس آتے ہی ہم خود بخود دوبارہ جڑ جائیں گے۔';

  @override
  String get startup_connectivity_tip =>
      'دیکھ لیں کہ Wi-Fi یا موبائل ڈیٹا آن ہے۔';

  @override
  String get startup_connectivity_protected => 'محفوظ کنکشن';

  @override
  String get settings_label_email => 'ای میل';

  @override
  String get settings_notify_profileViews => 'پروفائل دیکھے جانے کی اطلاع';

  @override
  String get settings_notify_profileViewsSub =>
      'جب کوئی آپ کا پروفائل کھولے تو نجی اطلاع';

  @override
  String get settings_notify_profileLive => 'پروفائل شائع ہو گیا';

  @override
  String get settings_notify_profileLiveSub => 'آپ کا پروفائل نظر آنے پر تصدیق';

  @override
  String get settings_appearance => 'ظاہری شکل';

  @override
  String get settings_helpSupport => 'مدد اور معاونت';

  @override
  String get settings_helpCenter => 'مدد مرکز';

  @override
  String get settings_grievanceOfficer => 'شکایات افسر';

  @override
  String get settings_grievanceResponse =>
      '24 گھنٹوں میں تصدیق؛ زیادہ تر شکایات 7 دن میں حل';

  @override
  String get settings_grievanceIndiaNotice =>
      'بھارت میں شکایات کا ازالہ ترمیم شدہ انفارمیشن ٹیکنالوجی (انٹرمیڈیری گائیڈ لائنز اور ڈیجیٹل میڈیا ایتھکس کوڈ) رولز کے مطابق ہوتا ہے۔ فوری غیر قانونی یا نجی مواد کی شکایات پر کم قانونی مدت لاگو ہوتی ہے۔';

  @override
  String get settings_managePhotoRequests => 'تصویر کی درخواستیں منظم کریں';

  @override
  String get settings_managePhotoRequestsSub =>
      'رسائی منظور کریں، درخواست مسترد کریں یا اشتراک واپس لیں';

  @override
  String get settings_theme_chooseTitle => 'اپنا ماحول منتخب کریں';

  @override
  String get settings_theme_chooseSubtitle =>
      'یہ صرف رنگوں کا فلٹر نہیں بلکہ مکمل بصری شناخت ہے۔ ہر سطح، فیلڈ اور سسٹم کنٹرول ایک ساتھ بدلتا ہے۔';

  @override
  String get settings_theme_applied => 'فوراً لاگو · اس ڈیوائس پر محفوظ';

  @override
  String get settings_reportPending => 'جائزہ زیر التوا';

  @override
  String get legal_document_terms => 'سروس کی شرائط';

  @override
  String get legal_document_privacy => 'رازداری کی پالیسی';

  @override
  String get legal_document_community => 'کمیونٹی رہنما اصول';

  @override
  String get legal_specialCategoryConsent =>
      'میں مطابقتی میچنگ کے لیے Silarah کو اپنی مذہبی معلومات (مسلک، نماز کی پابندی اور اسلامی شناخت) پر کارروائی کی واضح رضامندی دیتا/دیتی ہوں۔ معاہدہ شدہ سروس فراہم کنندگان اسے صرف سلارہ چلانے کے لیے استعمال کرتے ہیں، رویّے پر مبنی اشتہارات کے لیے نہیں۔';

  @override
  String get onboarding_complexion_fair => 'گوری';

  @override
  String get onboarding_complexion_medium => 'درمیانی';

  @override
  String get onboarding_complexion_olive => 'گندمی';

  @override
  String get onboarding_complexion_dark => 'سانولی';

  @override
  String get onboarding_residency_citizen => 'شہری';

  @override
  String get onboarding_residency_permanentResident => 'مستقل رہائشی';

  @override
  String get onboarding_residency_workVisa => 'ورک ویزا';

  @override
  String get onboarding_residency_studentVisa => 'اسٹوڈنٹ ویزا';

  @override
  String get onboarding_specialNeeds_none => 'کوئی نہیں';

  @override
  String get onboarding_specialNeeds_physical => 'جسمانی معذوری';

  @override
  String get onboarding_specialNeeds_hearing => 'سماعت کی کمزوری';

  @override
  String get onboarding_specialNeeds_visual => 'بصارت کی کمزوری';

  @override
  String get onboarding_label_stateRegion => 'ریاست / علاقہ';

  @override
  String get onboarding_specialNeeds_privacy =>
      'یہ صرف باہمی دلچسپی کے بعد شیئر کیا جاتا ہے۔';

  @override
  String get settings_theme_automatic => 'خودکار';

  @override
  String get settings_theme_automaticDesc =>
      'دن میں ہاتھی دانت اور زمرد، فون ڈارک موڈ میں ہو تو OLED رات';

  @override
  String get settings_theme_rose => 'گلاب اور گیندا';

  @override
  String get settings_theme_roseDesc =>
      'نرم گلابی رنگت، گہرا گلاب اور گیندے جیسا سنہرا';

  @override
  String get settings_theme_oled => 'OLED رات';

  @override
  String get settings_theme_oledDesc => 'OLED اسکرین کے لیے حقیقی سیاہ';

  @override
  String get settings_theme_ivory => 'ہاتھی دانت اور زمرد';

  @override
  String get settings_theme_ivoryDesc =>
      'گرم ہاتھی دانت، گہرا زمرد اور قدیم سنہرا';

  @override
  String get settings_guardian_backendRequired =>
      'سرپرست کی ترتیبات کے لیے محفوظ کنکشن درکار ہے۔';

  @override
  String get settings_guardian_saveError =>
      'سرپرست کی ترتیبات محفوظ نہیں ہو سکیں۔ دوبارہ کوشش کریں۔';

  @override
  String get common_openSettings => 'ترتیبات کھولیں';

  @override
  String get media_cameraAccessOff => 'کیمرے کی رسائی بند ہے';

  @override
  String get media_cameraUnavailable => 'کیمرہ دستیاب نہیں';

  @override
  String get media_cameraAccessBody =>
      'ترتیبات میں کیمرے کی اجازت دیں، پھر واضح تصویر لینے کے لیے واپس آئیں۔';

  @override
  String get media_cameraUnavailableBody =>
      'کیمرہ نہیں کھل سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get media_photoAccessOff => 'تصاویر کی رسائی بند ہے';

  @override
  String get media_photoAccessBody =>
      'ترتیبات میں کیمرے یا تصاویر کی اجازت دیں، پھر تصویر شامل کرنے کے لیے واپس آئیں۔';

  @override
  String get chat_searchHint => 'پیغامات تلاش کریں';

  @override
  String get chat_noConversationsFound => 'کوئی گفتگو نہیں ملی';

  @override
  String get chat_noConversationsFoundBody =>
      'کوئی دوسرا نام آزمائیں یا تلاش صاف کریں۔';

  @override
  String get chat_noConversationsYet => 'ابھی کوئی گفتگو نہیں';

  @override
  String get chat_noConversationsYetBody =>
      'گفتگو شروع کرنے کے لیے دلچسپی قبول کریں یا اپنی دلچسپی قبول ہونے دیں۔';

  @override
  String get referral_title => 'دوست کو دعوت دیں';

  @override
  String get referral_loading => 'انعامات لوڈ ہو رہے ہیں';

  @override
  String get referral_heading => 'خبر پھیلائیں، پریمیم حاصل کریں!';

  @override
  String get referral_body =>
      'کسی بھی اہل دوست کو Silarah پر مدعو کریں۔ ہر اکاؤنٹ زندگی میں صرف ایک بار 3 دن کا ریفرل پریمیم حاصل کر سکتا ہے۔ اگر آپ اپنا انعام لے چکے ہیں تو بھی آپ کے دوست کو ان کا انعام مل سکتا ہے۔';

  @override
  String get referral_premiumActiveTitle => 'ریفرل پریمیم فعال ہے';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '$days دن $hours گھنٹے باقی';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '$hours گھنٹے $minutes منٹ باقی';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '$minutes منٹ باقی';
  }

  @override
  String get referral_premiumEndingNow => 'انعام اب ختم ہو رہا ہے';

  @override
  String referral_premiumEndsAt(String date) {
    return '$date کو ختم ہوگا';
  }

  @override
  String get referral_premiumNoPayment =>
      'تمام پریمیم خصوصیات کھلی ہیں۔ کوئی ادائیگی نہیں لی گئی اور یہ انعام خودکار طور پر تجدید نہیں ہوگا۔';

  @override
  String get referral_premiumPlansAfter =>
      'مفت انعام ختم ہونے کے بعد سبسکرپشن پلان دستیاب ہوں گے تاکہ باقی مفت وقت ضائع نہ ہو۔';

  @override
  String get referral_premiumBackToProfile => 'پروفائل پر واپس جائیں';

  @override
  String get referral_premiumFeaturesUnlocked => 'تمام پریمیم خصوصیات کھلی ہیں';

  @override
  String get referral_premiumViewReward => 'انعام دیکھیں';

  @override
  String get referral_codeLabel => 'آپ کا ریفرل کوڈ';

  @override
  String get referral_tapToCopy => 'کاپی کرنے کے لیے کوڈ دبائیں';

  @override
  String get referral_totalInvited => 'کل مدعو افراد';

  @override
  String get referral_rewardsEarned => 'حاصل کردہ انعامات';

  @override
  String referral_premiumDays(int count) {
    return '$count پریمیم دن';
  }

  @override
  String get referral_pending => 'زیر التوا رجسٹریشن';

  @override
  String get referral_shareButton => 'دوستوں کے ساتھ کوڈ شیئر کریں';

  @override
  String get referral_copied => 'ریفرل کوڈ کاپی ہو گیا!';

  @override
  String get referral_shareSubject => 'Silarah میں شامل ہوں';

  @override
  String referral_shareText(String code) {
    return 'قابل اعتماد مسلم شادی ایپ Silarah میں شامل ہوں۔ میرا ریفرل کوڈ استعمال کریں: $code\n\nڈاؤن لوڈ: https://silarah.com';
  }

  @override
  String get profile_share => 'پروفائل شیئر کریں';

  @override
  String safety_reportMember(String name) {
    return '$name کی رپورٹ کریں';
  }

  @override
  String safety_blockMember(String name) {
    return '$name کو بلاک کریں';
  }

  @override
  String safety_blockTitle(String name) {
    return '$name کو بلاک کریں؟';
  }

  @override
  String safety_blockBody(String name) {
    return '$name ڈسکوری سے چھپ جائے گا اور آپ سے رابطہ نہیں کر سکے گا۔ حفاظت کے لیے چیٹ کی تاریخ محفوظ رہے گی۔ ان بلاک کرنے سے گفتگو دوبارہ نہیں کھلے گی۔';
  }

  @override
  String get safety_blockAction => 'بلاک کریں';

  @override
  String safety_blocked(String name) {
    return '$name کو بلاک کر دیا گیا۔';
  }

  @override
  String ui_openProfile(String name) {
    return '$name پروفائل کھولیں۔';
  }

  @override
  String ui_typing(String name) {
    return '$name ٹائپ کر رہا ہے۔';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'اکاؤنٹ حذف کرنے میں ناکام: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'ملک تبدیل کریں، فی الحال $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'کوئی ای میل ایپ نہیں ملی۔ $email کاپی کیا گیا تھا۔';
  }

  @override
  String ui_messagePerson(String name) {
    return 'پیغام $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'تجدید $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age سال';
  }

  @override
  String ui_photoNumber(int number) {
    return 'تصویر $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count از 4 تصاویر';
  }

  @override
  String ui_removeLabel(String label) {
    return '$label کو ہٹائیں';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label کو منتخب کیا گیا۔';
  }

  @override
  String ui_addLabel(String label) {
    return '$label شامل کریں';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'تصویر کی درخواست $name کو بھیجی گئی۔';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'کل $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count منٹ پہلے';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count گھنٹہ پہلے';
  }

  @override
  String ui_daysAgo(int count) {
    return '$count دن پہلے';
  }

  @override
  String ui_renewsAt(String time) {
    return '$time پر تجدید';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'تصویر $number محفوظ جائزے کے لیے تیار ہے۔';
  }

  @override
  String get ui_onePhotoUnlock =>
      'جب آپ دونوں کی دلچسپی کا اظہار کریں گے تو 1 تصویر خود بخود کھل جائے گی۔';

  @override
  String ui_manyPhotosUnlock(int count) {
    return '$count تصاویر خود بخود غیر مقفل ہو جائیں گی جب آپ دونوں کی دلچسپی کا اظہار کریں گے۔';
  }

  @override
  String get ui_askOnePhoto => '1 تصویر دیکھنے کے لیے مالک سے اجازت طلب کریں۔';

  @override
  String ui_askManyPhotos(int count) {
    return '$count تصاویر دیکھنے کے لیے مالک سے اجازت طلب کریں۔';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet فٹ $inches انچ';
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
    return 'فلٹرز ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'پہلے $date کو میچ ہوا تھا';
  }

  @override
  String discovery_rematch_days(int count) {
    return '$count دنوں میں دوبارہ میچ دستیاب ہوگا';
  }

  @override
  String get settings_notify_compatibleProfiles => 'موزوں پروفائل کی اطلاعات';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'جب خالی ڈسکوری فیڈ میں نئے نتائج آئیں';

  @override
  String get settings_notify_discoveryDigest => 'ڈسکوری خلاصہ';

  @override
  String get settings_notify_digestHelp =>
      'اختیاری خلاصے؛ خالی فیڈ میں نئے نتائج کی اطلاع فوراً ملے گی۔';

  @override
  String get settings_notify_digestOff => 'بند';

  @override
  String get settings_notify_digestDaily => 'روزانہ';

  @override
  String get settings_notify_digestWeekly => 'ہفتہ وار';

  @override
  String get settings_quietHoursStart => 'خاموش اوقات کا آغاز';

  @override
  String get settings_quietHoursEnd => 'خاموش اوقات کا اختتام';

  @override
  String get settings_notify_festivalGreetings => 'تہوار کی مبارکباد';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'رمضان اور عید کی مبارکباد، سال میں تقریباً پانچ بار';

  @override
  String get profile_quality_tier_complete => 'مکمل';

  @override
  String get profile_quality_tier_strong => 'تقریباً مکمل';

  @override
  String get profile_quality_tier_good => 'اچھی پیش رفت';

  @override
  String get profile_quality_tier_start => 'آغاز';

  @override
  String profile_quality_ring_semantics(int percent) {
    return 'پروفائل $percent% مکمل';
  }

  @override
  String profile_quality_next_eyebrow(int percent) {
    return 'اگلا قدم · $percent% تک پہنچیں';
  }

  @override
  String profile_quality_points(int points) {
    return '+$points%';
  }

  @override
  String get profile_quality_step_photo => 'پروفائل تصویر شامل کریں';

  @override
  String get profile_quality_step_bio => 'تعارف شامل کریں';

  @override
  String get profile_quality_step_deen => 'اپنی اسلامی شناخت مکمل کریں';

  @override
  String get profile_quality_step_education => 'تعلیم اور پیشہ شامل کریں';

  @override
  String get profile_quality_step_family => 'خاندانی پس منظر شامل کریں';

  @override
  String get profile_quality_step_partner => 'شریکِ حیات کی ترجیحات طے کریں';

  @override
  String get profile_quality_step_second_photo => 'دوسری تصویر شامل کریں';

  @override
  String get profile_quality_step_income => 'آمدنی کی حد شامل کریں';

  @override
  String get profile_quality_step_languages => 'زبانیں شامل کریں';

  @override
  String get profile_quality_complete_title => 'آپ کی پروفائل مکمل ہے';

  @override
  String get profile_quality_complete_body =>
      'ہر تفصیل اپنی جگہ پر ہے۔ اراکین آپ کی پوری کہانی دیکھتے ہیں۔';

  @override
  String get profile_quality_tip_verified_benefit =>
      'قابلِ اعتماد چہرے کو زیادہ جواب ملتے ہیں';

  @override
  String get profile_quality_tip_photos_benefit =>
      'زیادہ تصاویر سے اراکین کے لیے ہاں کہنا آسان ہوتا ہے';

  @override
  String get profile_quality_tip_bio_benefit =>
      'آپ کے اپنے الفاظ پہلا تاثر بناتے ہیں';

  @override
  String get profile_quality_tip_guardian_benefit =>
      'خاندان منسلک سرپرست کو اہمیت دیتے ہیں';

  @override
  String get profile_quality_done => 'ہو گیا';

  @override
  String get profile_quality_name_fallback => 'آپ کا نام';

  @override
  String get profile_quality_subtitle_fallback => 'نیچے اپنی پروفائل مکمل کریں';
}
