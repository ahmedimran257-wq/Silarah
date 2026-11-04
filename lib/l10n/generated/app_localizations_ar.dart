// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get guide_optional_details => 'تفاصيل إضافية (اختيارية)';

  @override
  String get guide_optional_details_body =>
      'يمكنك إكمال هذه التفاصيل لاحقًا من ملفك الشخصي.';

  @override
  String get guide_profile_ownership =>
      'يصف هذا الملف الشخص الذي يبحث عن الزواج. ويمكن دعوة ولي منفصل لاحقًا للإشراف على المحادثات.';

  @override
  String get about_button_later => 'سأفعل هذا لاحقا';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'صف $relation الخاص بك بأمانة وكرامة.';
  }

  @override
  String get about_hint_bio_self => 'صف نفسك بالصدق والكرامة.';

  @override
  String get about_label_bio_guardian => 'سيرتهم الذاتية';

  @override
  String get about_label_bio_self => 'سيرتك الذاتية';

  @override
  String get about_label_interests => 'الاهتمامات';

  @override
  String get about_label_languages => 'اللغات المنطوقة';

  @override
  String about_label_selected_count(Object current, Object max) {
    return 'تم تحديد $current/$max';
  }

  @override
  String get about_subtitle => 'اكتب بأمانة وكرامة.';

  @override
  String about_title_guardian(Object relation) {
    return 'حول $relation الخاص بك';
  }

  @override
  String get about_title_self => 'عنك';

  @override
  String get appName => 'سيلارا';

  @override
  String get appTagline => 'ابدأ ببسم الله';

  @override
  String get auth_button_resendOtp => 'إعادة إرسال رمز التحقق';

  @override
  String get auth_button_sendCode => 'إرسال رمز التحقق';

  @override
  String get auth_button_sendOtp => 'إرسال رمز التحقق';

  @override
  String get auth_button_verifyOtp => 'يؤكد';

  @override
  String get auth_label_changeNumber => 'رقم خاطئ؟ تغييره';

  @override
  String get auth_label_enterOtp =>
      'أدخل رمز التحقق المكون من 6 أرقام المرسل إليه';

  @override
  String get auth_label_resendCode => 'إعادة إرسال رمز التحقق';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'إعادة إرسال رمز التحقق خلال ${seconds}s';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'إعادة الإرسال خلال $secondsث';
  }

  @override
  String get auth_label_sentCodeTo => 'أرسلنا رمز التحقق المكون من 6 أرقام إلى';

  @override
  String get auth_subtitle_verifyOtp =>
      'سوف نقوم بالتحقق من ذلك باستخدام رمز لمرة واحدة.';

  @override
  String get auth_title_enterCode => 'أدخل رمز التحقق الخاص بك';

  @override
  String get auth_title_yourNumber => 'رقمك';

  @override
  String get background_edu_bachelors => 'درجة البكالوريوس';

  @override
  String get background_edu_below_secondary => 'تحت الثانوي';

  @override
  String get background_edu_diploma => 'دبلوم / مشارك';

  @override
  String get background_edu_doctorate => 'دكتوراه / دكتوراه';

  @override
  String get background_edu_higher_secondary => 'الثانوية العليا / المستوى أ';

  @override
  String get background_edu_masters => 'درجة الماجستير';

  @override
  String get background_edu_secondary => 'الثانوية / المستوى O';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'أخبرنا عن تعليم $relation ومسيرته المهنية.';
  }

  @override
  String get background_edu_subtitle_self =>
      'يساعد في العثور على التطابقات المتوافقة بشكل احترافي.';

  @override
  String get background_edu_title_guardian => 'خلفيتهم';

  @override
  String get background_edu_title_self => 'الخلفية الخاصة بك';

  @override
  String get background_emp_employed => 'موظف';

  @override
  String get background_emp_not_working => 'لا يعمل';

  @override
  String get background_emp_self_employed => 'العاملون لحسابهم الخاص';

  @override
  String get background_emp_student => 'طالب';

  @override
  String get background_income_subtitle =>
      'يتخطّى العديد من الأشخاص هذا الأمر، فهو اختياري تمامًا.';

  @override
  String get background_label_eduLevel => 'المستوى التعليمي';

  @override
  String get background_label_employment => 'حالة التوظيف';

  @override
  String background_label_income_bracket(Object currency) {
    return 'شريحة الدخل ($currency)';
  }

  @override
  String get background_label_income_range => 'نطاق الدخل (اختياري)';

  @override
  String get background_label_profession => 'المهنة (اختياري)';

  @override
  String get background_label_study => 'مجال الدراسة (اختياري)';

  @override
  String get background_label_who_see => 'من يستطيع رؤية هذا؟';

  @override
  String get background_vis_everyone => 'أظهر القوس للجميع';

  @override
  String get background_vis_mutual => 'تظهر فقط بعد المصلحة المتبادلة';

  @override
  String get background_vis_private => 'حافظ على خصوصيتك';

  @override
  String get ceremony_text_blessing => 'جزاكم الله هذا الخير';

  @override
  String get chat_closure_1 =>
      'السلام عليكم. بعد تفكير عميق، أشعر أن هذا قد لا يكون الخيار المناسب لنا. أتمنى لك من كل قلبي كل التوفيق وأدعو الله أن يرزقك بشريك رائع. جزاك الله خيرا.';

  @override
  String get chat_closure_2 =>
      'السلام عليكم. أردت أن أكون صادقًا ومحترمًا معك. لا أعتقد أننا الشخص المناسب، ولكن أدعو الله أن يفتح لك أبوابًا أفضل. أتمنى لكم كل التوفيق.';

  @override
  String get chat_closure_3 =>
      'السلام عليكم. بعد دراسة صادقة، أشعر أننا قد لا نكون متوافقين. أتمنى أن تجد الشخص المناسب لك حقًا. الله يسهل عليك. جزاك الله خيرا على وقتك.';

  @override
  String get chat_closure_4 =>
      'السلام عليكم. لقد فكرت في محادثاتنا وأشعر أنه من الأفضل إنهاء هذا التوافق في الوقت الحالي. ليس لدي سوى الاحترام لك وأدعو الله أن يجزيك الأفضل.';

  @override
  String get chat_closure_5 =>
      'السلام عليكم. أردت أن أكون شفافًا معك بدلاً من التلاشي. لا أرى أن هذا يتقدم أكثر من ذلك، لكنني أقدر حقًا وقتك وأتمنى لك كل السعادة. بارك الله فيكم.';

  @override
  String get chat_endMatch_button => 'إرسال وإنهاء التوافق';

  @override
  String get chat_endMatch_subtitle =>
      'اختر رسالة محترمة لإغلاق هذه المحادثة. سيتم إخطار الشخص الآخر.';

  @override
  String get chat_endMatch_title => 'إنهاء هذا التوافق';

  @override
  String chat_label_probation(int hours) {
    return 'يتم فتح المراسلة خلال $hours ساعة. يمكنك إرسال الاهتمامات الآن.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'اشترك لفتح الرسائل. تراسل النساء دائمًا مجانًا على سيلارا.';

  @override
  String get chat_matchClosed_banner => 'تم إنهاء هذا التوافق باحترام.';

  @override
  String get chat_opener_1 =>
      'السلام عليكم! لقد صادفت ملفك الشخصي وأعجبت به حقًا. هل لي أن أقدم نفسي؟';

  @override
  String get chat_opener_2 =>
      'بسم الله. الملف الشخصي الخاص بك لفت انتباهي. أحب أن أعرف المزيد عنك.';

  @override
  String get chat_opener_3 =>
      'السلام عليكم. أعتقد أننا نتقاسم قيمًا مماثلة. هل ستكون منفتحًا للتعرف على بعضكما البعض؟';

  @override
  String get chat_placeholder_typeMessage => 'اكتب رسالة...';

  @override
  String get common_button_back => 'خلف';

  @override
  String get common_button_cancel => 'يلغي';

  @override
  String get common_button_done => 'منتهي';

  @override
  String get common_button_next => 'التالي';

  @override
  String get common_button_retry => 'حاول ثانية';

  @override
  String get common_button_save => 'يحفظ';

  @override
  String get common_button_skip => 'يتخطى';

  @override
  String get common_button_submit => 'يُقدِّم';

  @override
  String get common_error_generic => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get common_error_noInternet =>
      'لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال الخاص بك.';

  @override
  String get common_label_optional => 'خياري';

  @override
  String get copy_beard_parent => 'هل ابنك له لحية؟';

  @override
  String get copy_beard_self => 'هل لديك لحية؟';

  @override
  String get copy_beard_sibling => 'هل لدى أخيك لحية؟';

  @override
  String get copy_hijab_parent => 'هل تلتزم ابنتك بالحجاب؟';

  @override
  String get copy_hijab_self => 'هل تلتزمين بالحجاب؟';

  @override
  String get copy_hijab_sibling => 'هل أختك ملتزمة بالحجاب؟';

  @override
  String get copy_prayer_parent => 'هل يصلي طفلك خمس مرات يوميا؟';

  @override
  String get copy_prayer_self => 'هل تصلي خمس مرات يوميا؟';

  @override
  String get copy_prayer_sibling => 'هل يصلي أخوك خمس مرات يوميا؟';

  @override
  String get deleteAccount_title => 'حذف الحساب';

  @override
  String discovery_bookmark_removed(Object name) {
    return 'تمت إزالة $name';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return 'تم حفظ $name';
  }

  @override
  String get discovery_button_sendInterest => 'أرسل اهتمامًا';

  @override
  String get discovery_completeness_button => 'الملف الشخصي الكامل';

  @override
  String get discovery_completeness_subtitle =>
      'الملفات الشخصية التي تزيد عن 40% تحصل على 3 أضعاف الاهتمامات.\nأكمل ملفك الشخصي لبدء التصفح.';

  @override
  String get discovery_completeness_title => 'أكمل ملفك الشخصي';

  @override
  String get discovery_empty_subtitle =>
      'ينضم أعضاء جدد إلى سيلارا كل يوم. عُد غدًا لرؤية ملفات جديدة، أو وسّع تفضيلاتك لتتعرّف على المزيد الآن.';

  @override
  String get discovery_empty_filtered_eyebrow => 'حسّن بحثك';

  @override
  String get discovery_empty_filtered_title =>
      'لا أحد يطابق عوامل التصفية هذه حتى الآن';

  @override
  String get discovery_empty_filtered_subtitle =>
      'تفضيلاتك تضيّق الدائرة. غالبًا ما يؤدي تخفيف عامل تصفية واحد فقط إلى ظهور ملفات جديدة على الفور.';

  @override
  String get discovery_empty_clear_filters => 'مسح كل عوامل التصفية';

  @override
  String get discovery_empty_refresh => 'تحديث الملفات';

  @override
  String get discovery_empty_adjust_filters => 'تعديل عوامل التصفية';

  @override
  String get discovery_empty_hint_trust => 'جرّب تخفيف فحوصات الثقة أولًا';

  @override
  String get discovery_empty_hint_deen => 'جرّب توسيع مستوى الدين أولًا';

  @override
  String get discovery_empty_hint_family => 'جرّب توسيع نوع العائلة أولًا';

  @override
  String get discovery_empty_hint_sect => 'جرّب فتح عامل تصفية الطائفة أولًا';

  @override
  String get discovery_empty_hint_location => 'جرّب موقعًا أوسع أولًا';

  @override
  String get discovery_empty_hint_age => 'جرّب نطاقًا عمريًا أوسع أولًا';

  @override
  String get discovery_empty_hint_other =>
      'جرّب تخفيف عامل تصفية واحد في كل مرة';

  @override
  String get discovery_empty_eyebrow => 'لقد اطّلعت على الجميع';

  @override
  String get discovery_empty_title => 'لقد رأيت الجميع لهذا اليوم';

  @override
  String get discovery_handoff_interest_subtitle =>
      'تنتقل الملفات ذات الطلب النشط إلى الاهتمامات أثناء انتظارك أو ردّك.';

  @override
  String get discovery_handoff_interest_title => 'اهتمامك قيد المتابعة';

  @override
  String get discovery_handoff_match_subtitle =>
      'تنتقل الملفات المتطابقة إلى الدردشة، لذلك لن تظهر مرة أخرى في الاستكشاف.';

  @override
  String get discovery_handoff_match_title => 'اتصالك جاهز';

  @override
  String get discovery_handoff_open_chat => 'افتح الدردشة';

  @override
  String get discovery_handoff_open_interests => 'افتح الاهتمامات';

  @override
  String get discovery_header_title => '<العلامة التجارية0/>';

  @override
  String get discovery_label_interestSent => 'تم إرسال الاهتمام ✓';

  @override
  String get discovery_label_outsidePrefs => 'شخص قد تتواصل معه';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count الملفات الشخصية المتبقية اليوم';
  }

  @override
  String get discovery_limit_button => 'الترقية الآن';

  @override
  String get discovery_limit_subtitle =>
      'لقد تصفحت 15 ملفًا شخصيًا اليوم.\nقم بالترقية لفتح تصفح غير محدود.';

  @override
  String get discovery_limit_title => 'تم الوصول إلى الحد اليومي';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count الملفات الشخصية المتبقية';
  }

  @override
  String get discovery_wildcard_label => 'شخص قد تتواصل معه';

  @override
  String get family_children_no => 'لا';

  @override
  String get family_children_yes => 'نعم';

  @override
  String get family_label_children_guardian => 'هل لديهم أطفال؟';

  @override
  String get family_label_children_self => 'هل لديك أطفال؟';

  @override
  String get family_label_how_many => 'كم عدد؟';

  @override
  String get family_label_parents => 'الحالة الاجتماعية للوالدين';

  @override
  String get family_label_polygamy_female_self => 'قبول تعدد الزوجات (اختياري)';

  @override
  String get family_label_polygamy_male_self => 'حالة تعدد الزوجات (اختياري)';

  @override
  String get family_label_prev_married => 'متزوج سابقا؟';

  @override
  String get family_label_relocate => 'على استعداد للانتقال';

  @override
  String get family_label_siblings => 'عدد الأشقاء';

  @override
  String get family_label_type => 'نوع العائلة';

  @override
  String get family_living_title => 'التوقعات المعيشية بعد الزواج';

  @override
  String get family_parents_both_deceased => 'كلا المتوفى';

  @override
  String get family_parents_divorced => 'مُطلّق';

  @override
  String get family_parents_father_deceased => 'الأب متوفى';

  @override
  String get family_parents_mother_deceased => 'الأم متوفاة';

  @override
  String get family_parents_separated => 'منفصل';

  @override
  String get family_parents_together => 'معاً';

  @override
  String get family_polygamy_female_discussion => 'مفتوحة للمناقشة';

  @override
  String get family_polygamy_female_no => 'لا';

  @override
  String get family_polygamy_female_prefer_not => 'يفضل عدم القول';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'هل تفكر $relation في أن تكون زوجة زميلة؟';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'هل تفكرين في أن تكوني زوجة مشتركة؟';

  @override
  String get family_polygamy_female_yes => 'نعم';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'هل $relation متزوج حاليًا ويبحث عن زوج إضافي؟';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'هل أنت متزوج حاليًا وتبحث عن زوج إضافي؟';

  @override
  String get family_polygamy_option_first => 'لا، هذه هي المرة الأولى لي';

  @override
  String get family_polygamy_option_married => 'نعم متزوج حاليا';

  @override
  String get family_polygamy_option_prefer_not => 'يفضل عدم القول';

  @override
  String get family_prev_divorced => 'مُطلّق';

  @override
  String get family_prev_no => 'لا';

  @override
  String get family_prev_widowed => 'أرمل';

  @override
  String get family_relocate_discussion => 'مفتوح للمناقشة';

  @override
  String get family_relocate_no => 'لا';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'هل سينتقل $relation من أجل الزواج؟';
  }

  @override
  String get family_relocate_subtitle_self => 'هل ستنتقل للزواج؟';

  @override
  String get family_relocate_yes => 'نعم';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'أخبرنا عن عائلة $relation.';
  }

  @override
  String get family_subtitle_self => 'التوافق العائلي أمر أساسي للزواج الدائم.';

  @override
  String get family_title_guardian => 'الخلفية العائلية';

  @override
  String get family_title_self => 'الخلفية العائلية';

  @override
  String get family_type_extended => 'ممتد';

  @override
  String get family_type_joint => 'مشترك';

  @override
  String get family_type_nuclear => 'النووية';

  @override
  String get filter_label_community => 'المجتمع / بيراداري';

  @override
  String get filter_label_livingExpectation => 'حياة ما بعد الزواج';

  @override
  String get filter_label_motherTongue => 'اللغة الأم';

  @override
  String get guardian_details_candidate_female => 'مرشحة • رسالة نسائية مجانية';

  @override
  String get guardian_details_candidate_label => 'إنشاء ملف تعريف لـ';

  @override
  String get guardian_details_candidate_male => 'مرشح ذكر';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return '$relation';
  }

  @override
  String get guardian_details_involvement => 'مشاركة الوصي';

  @override
  String get guardian_details_involvement_subtitle =>
      'إلى أي مدى تريد أن تكون مشاركًا في المحادثات؟';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'شاهد الدردشات، ووافق على التطابقات، وأرسل الرسائل نيابةً عن $relation الخاص بك.';
  }

  @override
  String get guardian_details_mode_active_title => 'الوصي النشط';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'شاهد جميع الدردشات في الوقت الفعلي، لكن $relation فقط هو الذي يمكنه إرسال الرسائل.';
  }

  @override
  String get guardian_details_mode_passive_title => 'لاحظ فقط';

  @override
  String get guardian_details_name_hint => 'الاسم الكامل';

  @override
  String get guardian_details_name_subtitle =>
      'اسمك بصفتك وليًّا. يظهر هذا لمن تتوافق معهم.';

  @override
  String guardian_details_notice(Object relation) {
    return 'أنت تقوم بإنشاء ملف تعريف لـ $relation الخاص بك. جميع تفاصيل الملف الشخصي على الشاشات التالية ستصفها، وليس أنت.';
  }

  @override
  String get guardian_details_search_hint => 'يبحث';

  @override
  String get guardian_details_select_code => 'اختر رمز البلد';

  @override
  String get guardian_details_subtitle => 'أخبرنا عن نفسك كوصي.';

  @override
  String get guardian_details_title => 'تفاصيل الوصي الخاص بك';

  @override
  String get guardian_details_your_name => 'اسمك';

  @override
  String get interest_cat_creative => 'مبدع';

  @override
  String get interest_cat_faith => 'إيمان';

  @override
  String get interest_cat_learning => 'تعلُّم';

  @override
  String get interest_cat_lifestyle => 'نمط الحياة';

  @override
  String get interest_cat_social => 'اجتماعي';

  @override
  String get interest_cat_sports => 'الرياضة';

  @override
  String get interest_tag_art => 'فن';

  @override
  String get interest_tag_calligraphy => 'الخط';

  @override
  String get interest_tag_community_work => 'العمل المجتمعي';

  @override
  String get interest_tag_cooking => 'طبخ';

  @override
  String get interest_tag_crafts => 'الحرف اليدوية';

  @override
  String get interest_tag_cricket => 'لعبة الكريكيت';

  @override
  String get interest_tag_cycling => 'ركوب الدراجات';

  @override
  String get interest_tag_dawah => 'الدعوة';

  @override
  String get interest_tag_family_gatherings => 'التجمعات العائلية';

  @override
  String get interest_tag_fitness => 'لياقة بدنية';

  @override
  String get interest_tag_football => 'كرة القدم';

  @override
  String get interest_tag_gardening => 'البستنة';

  @override
  String get interest_tag_graphic_design => 'التصميم الجرافيكي';

  @override
  String get interest_tag_hiking => 'جولة على الأقدام';

  @override
  String get interest_tag_history => 'تاريخ';

  @override
  String get interest_tag_islamic_lectures => 'محاضرات اسلامية';

  @override
  String get interest_tag_languages => 'اللغات';

  @override
  String get interest_tag_martial_arts => 'فنون الدفاع عن النفس';

  @override
  String get interest_tag_mentoring => 'التوجيه';

  @override
  String get interest_tag_photography => 'التصوير الفوتوغرافي';

  @override
  String get interest_tag_poetry => 'شِعر';

  @override
  String get interest_tag_quran_recitation => 'تلاوة القرآن';

  @override
  String get interest_tag_reading => 'قراءة';

  @override
  String get interest_tag_science => 'علوم';

  @override
  String get interest_tag_swimming => 'سباحة';

  @override
  String get interest_tag_tahajjud => 'التهجد';

  @override
  String get interest_tag_teaching => 'تدريس';

  @override
  String get interest_tag_technology => 'تكنولوجيا';

  @override
  String get interest_tag_travel => 'يسافر';

  @override
  String get interest_tag_umrah_hajj => 'العمرة / الحج';

  @override
  String get interest_tag_voluntary_fasting => 'صيام التطوع';

  @override
  String get interest_tag_volunteering => 'التطوع';

  @override
  String get interest_tag_writing => 'كتابة';

  @override
  String get interests_button_accept => 'يقبل';

  @override
  String get interests_button_decline => 'انخفاض';

  @override
  String get interests_tab_received => 'تلقى';

  @override
  String get interests_tab_sent => 'مرسل';

  @override
  String get interests_title => 'الاهتمامات';

  @override
  String get lang_albanian => 'الألبانية';

  @override
  String get lang_amazigh => 'الأمازيغية (البربرية)';

  @override
  String get lang_amharic => 'الأمهرية';

  @override
  String get lang_arabic => 'عربي';

  @override
  String get lang_assamese => 'الأسامية';

  @override
  String get lang_balochi => 'البلوشية';

  @override
  String get lang_bengali => 'البنغالية';

  @override
  String get lang_bosnian => 'البوسنية';

  @override
  String get lang_burmese => 'البورمية';

  @override
  String get lang_chechen => 'الشيشانية';

  @override
  String get lang_chinese => 'الصينية (الماندرين)';

  @override
  String get lang_dari => 'داري';

  @override
  String get lang_dutch => 'هولندي';

  @override
  String get lang_english => 'إنجليزي';

  @override
  String get lang_french => 'فرنسي';

  @override
  String get lang_fulani => 'الفولاني';

  @override
  String get lang_german => 'الألمانية';

  @override
  String get lang_gujarati => 'الغوجاراتية';

  @override
  String get lang_hausa => 'الهوسا';

  @override
  String get lang_hindi => 'الهندية';

  @override
  String get lang_igbo => 'الإيغبو';

  @override
  String get lang_indonesian => 'الاندونيسية';

  @override
  String get lang_italian => 'ايطالي';

  @override
  String get lang_japanese => 'اليابانية';

  @override
  String get lang_javanese => 'الجاوية';

  @override
  String get lang_kannada => 'الكانادا';

  @override
  String get lang_kazakh => 'الكازاخستانية';

  @override
  String get lang_korean => 'كوري';

  @override
  String get lang_kurdish => 'كردي';

  @override
  String get lang_kyrgyz => 'قيرغيزستان';

  @override
  String get lang_malay => 'لغة الملايو';

  @override
  String get lang_malayalam => 'المالايالامية';

  @override
  String get lang_mandinka => 'ماندينكا';

  @override
  String get lang_marathi => 'المهاراتية';

  @override
  String get lang_norwegian => 'النرويجية';

  @override
  String get lang_odia => 'أوديا';

  @override
  String get lang_other => 'آخر';

  @override
  String get lang_pashto => 'الباشتو';

  @override
  String get lang_persian => 'الفارسية';

  @override
  String get lang_portuguese => 'البرتغالية';

  @override
  String get lang_punjabi => 'البنجابية';

  @override
  String get lang_rohingya => 'الروهينجا';

  @override
  String get lang_russian => 'الروسية';

  @override
  String get lang_saraiki => 'ساريكي';

  @override
  String get lang_sindhi => 'السندية';

  @override
  String get lang_somali => 'الصومالية';

  @override
  String get lang_spanish => 'الأسبانية';

  @override
  String get lang_sundanese => 'السودانية';

  @override
  String get lang_swahili => 'السواحلية';

  @override
  String get lang_swedish => 'السويدية';

  @override
  String get lang_tagalog => 'التاغالوغية';

  @override
  String get lang_tajik => 'الطاجيكية';

  @override
  String get lang_tamil => 'التاميل';

  @override
  String get lang_tatar => 'التتار';

  @override
  String get lang_telugu => 'التيلجو';

  @override
  String get lang_thai => 'التايلاندية';

  @override
  String get lang_tigrinya => 'التغرينية';

  @override
  String get lang_turkish => 'تركي';

  @override
  String get lang_urdu => 'الأردية';

  @override
  String get lang_uzbek => 'الأوزبكية';

  @override
  String get lang_wolof => 'الولوف';

  @override
  String get lang_yoruba => 'اليوروبا';

  @override
  String get legal_button_continue => 'يكمل';

  @override
  String get legal_checkbox_age => 'أؤكد أن عمري 18 عامًا أو أكبر';

  @override
  String get legal_checkbox_terms => 'أوافق على شروط الخدمة وسياسة الخصوصية';

  @override
  String get legal_subtitle => 'يرجى القراءة والموافقة على الاستمرار.';

  @override
  String get legal_summary_1 =>
      'يتم تشفير بياناتك ولا يتم بيعها أبدًا لأطراف ثالثة.';

  @override
  String get legal_summary_2 =>
      'تخضع كل صورة لفحص أمان، ويراجع فريقنا الصور الجديدة.';

  @override
  String get legal_summary_3 =>
      'تؤدي المضايقات والملفات الشخصية المزيفة وعمليات الاحتيال إلى الحظر الدائم.';

  @override
  String get legal_summary_4 =>
      'هذه المنصة مخصصة لنوايا الزواج فقط. الكرامة هي المعيار.';

  @override
  String get legal_summary_5 => 'يمكنك حذف حسابك وجميع البيانات في أي وقت.';

  @override
  String get legal_title => 'قبل أن تبدأ';

  @override
  String get notifications_empty_subtitle =>
      'لا توجد إشعارات جديدة في الوقت الحالي.';

  @override
  String get notifications_empty_title => 'أنتم جميعًا محاصرون';

  @override
  String get notifications_markAllRead => 'وضع علامة على كل قراءة';

  @override
  String get notifications_title => 'إشعارات';

  @override
  String get onboarding_about_title => 'عن نفسك';

  @override
  String get onboarding_background_title => 'التعليم والوظيفي';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'أنت تقوم بملء هذا كوصي. هذه التفاصيل تتعلق بـ $relation الخاص بك.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'هذا ما سيراه الآخرون في ملفهم الشخصي.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'هذا ما سيراه الآخرون في ملفك الشخصي.';

  @override
  String get onboarding_basicIdentity_title => 'أخبرنا عن نفسك';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'أخبرنا عن $relation الخاص بك';
  }

  @override
  String get onboarding_debt_manageable => 'الديون التي يمكن التحكم فيها';

  @override
  String get onboarding_debt_none => 'لا الديون';

  @override
  String get onboarding_debt_significant => 'ديون كبيرة';

  @override
  String get onboarding_diet_eatsAnything => 'يأكل أي شيء حلال';

  @override
  String get onboarding_diet_halalOnly => 'حلال فقط';

  @override
  String get onboarding_diet_vegan => 'نباتي';

  @override
  String get onboarding_diet_vegetarian => 'نباتي';

  @override
  String get onboarding_diet_zabihaStrict => 'ذبيحة صارمة';

  @override
  String get onboarding_error_bioContactInfo =>
      'يرجى إزالة معلومات الاتصال من سيرتك الذاتية. لا يُسمح بتفاصيل الاتصال الخارجية حفاظًا على سلامتك.';

  @override
  String get onboarding_error_multipleFaces =>
      'لا يمكن أن تكون الصور الجماعية هي صورتك الأساسية.';

  @override
  String get onboarding_error_noFace =>
      'يرجى استخدام صورة يظهر فيها وجهك بوضوح.';

  @override
  String get onboarding_error_under18 =>
      'سيلارا مخصص لمن يبلغون 18 عامًا أو أكثر. لقد وضعنا هذا المطلب لحماية الجميع في مجتمعنا.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'يجب أن يكون عمر $relation 18 عامًا أو أكثر لاستخدام سيلارا.';
  }

  @override
  String get onboarding_error_under18_self =>
      'يجب أن يكون عمرك 18 عامًا أو أكثر لاستخدام سيلارا. ونحن نتطلع إلى الترحيب بك بعد ذلك.';

  @override
  String get onboarding_habit_frequently => 'مرارًا';

  @override
  String get onboarding_habit_never => 'أبداً';

  @override
  String get onboarding_habit_occasionally => 'أحياناً';

  @override
  String get onboarding_habit_preferNotToSay => 'يفضل عدم القول';

  @override
  String get onboarding_hijab_always => 'دائماً';

  @override
  String get onboarding_hijab_no => 'لا';

  @override
  String get onboarding_hijab_sometimes => 'أحيانا';

  @override
  String get onboarding_hint_bio => 'صف نفسك بالصدق والكرامة.';

  @override
  String get onboarding_hint_profession =>
      'على سبيل المثال مهندس برمجيات، مدرس، دكتور';

  @override
  String get onboarding_hint_searchCity => 'ابحث في مدينتك...';

  @override
  String get onboarding_hint_selectCommunity => 'اختر المجتمع (اختياري)';

  @override
  String get onboarding_hint_selectCountry => 'اختر البلد';

  @override
  String get onboarding_hint_selectDateOfBirth => 'اختر تاريخ الميلاد';

  @override
  String get onboarding_hint_selectLanguage => 'اختر اللغة';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'يساعد هذا في التوفيق بينك وبين شخص متوافق.';

  @override
  String get onboarding_islamicIdentity_title => 'هويتك الإسلامية';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'مدينة';

  @override
  String get onboarding_label_city_guardian => 'مدينتهم';

  @override
  String get onboarding_label_city_self => 'مدينتك';

  @override
  String get onboarding_label_community => 'مجتمعك / بيراداري';

  @override
  String get onboarding_label_community_parent => 'مجتمعهم / بيراداري';

  @override
  String get onboarding_label_complexion => 'البشرة (اختياري)';

  @override
  String get onboarding_label_country_guardian => 'بلادهم';

  @override
  String get onboarding_label_country_self => 'بلدك';

  @override
  String get onboarding_label_cultural => 'مسلم ثقافي';

  @override
  String get onboarding_label_dateOfBirth => 'تاريخ الميلاد';

  @override
  String get onboarding_label_debtStatus => 'حالة الديون';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'التزاماتك المالية الحالية.';

  @override
  String get onboarding_label_deenLevel => 'مستوى الدين';

  @override
  String get onboarding_label_diet => 'نظام عذائي';

  @override
  String get onboarding_label_educationLevel => 'مستوى التعليم';

  @override
  String get onboarding_label_female => 'أنثى';

  @override
  String get onboarding_label_firstName => 'الاسم الأول';

  @override
  String get onboarding_label_firstName_guardian => 'الاسم الأول للمرشح';

  @override
  String get onboarding_label_firstName_self => 'الاسم الأول';

  @override
  String get onboarding_label_gender => 'جنس';

  @override
  String get onboarding_label_gender_guardian => 'جنس المرشح';

  @override
  String get onboarding_label_gender_self => 'جنس';

  @override
  String get onboarding_label_height_guardian => 'ارتفاعهم';

  @override
  String get onboarding_label_height_self => 'طولك';

  @override
  String get onboarding_label_hookah => 'الشيشة / الشيشة';

  @override
  String get onboarding_label_housing => 'السكن';

  @override
  String get onboarding_label_housingQuestion =>
      'هل يمكنك توفير مساحة معيشة منفصلة؟';

  @override
  String get onboarding_label_lastName => 'اسم العائلة';

  @override
  String get onboarding_label_leadership => 'القيادة الدينية';

  @override
  String get onboarding_label_leadershipQuestion =>
      'هل يجوز لك أن تؤم صلاة الجماعة؟';

  @override
  String get onboarding_label_lifestyleDiet => 'نمط الحياة والنظام الغذائي';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'هذه هي مجالات كسر الصفقات للعديد من العائلات. يرجى الإجابة بصدق.';

  @override
  String get onboarding_label_livingExpectation => 'توقعات الحياة بعد الزواج';

  @override
  String get onboarding_label_mahrBudget => 'ميزانية المهر';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'ما هي مجموعة المهر التي أنت على استعداد لتقديمها؟';

  @override
  String get onboarding_label_mahrExpectation => 'توقع المهر';

  @override
  String get onboarding_label_mahrExpectationQuestion => 'ما هي توقعاتك للمهر؟';

  @override
  String get onboarding_label_maintenance => 'الصيانة المالية';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'هل أنت قادر على إعالة الزوج ماليا؟';

  @override
  String get onboarding_label_male => 'ذكر';

  @override
  String get onboarding_label_marriageTimeline => 'الجدول الزمني للزواج';

  @override
  String get onboarding_label_marriageTimelineQuestion => 'متى تتطلع للزواج؟';

  @override
  String get onboarding_label_moderate => 'معتدل';

  @override
  String get onboarding_label_motherTongue => 'اللغة الأم';

  @override
  String get onboarding_label_niqab => 'النقاب';

  @override
  String get onboarding_label_practicing => 'ممارسة';

  @override
  String get onboarding_label_praysFiveDaily => 'أصلي خمس مرات يوميا';

  @override
  String get onboarding_label_preferNotToSay => 'يفضل عدم القول';

  @override
  String get onboarding_label_preferredLiving => 'تفضيل ترتيب المعيشة';

  @override
  String get onboarding_label_profession => 'مهنة';

  @override
  String get onboarding_label_providerReadiness => 'جاهزية المزود';

  @override
  String get onboarding_label_quranMemorization => 'حفظ القرآن';

  @override
  String get onboarding_label_religiousEducation => 'التربية الدينية';

  @override
  String get onboarding_label_residencyStatus => 'حالة الإقامة (اختياري)';

  @override
  String get onboarding_label_revert => 'العودة / التحويل (اختياري)';

  @override
  String get onboarding_label_revertQuestion =>
      'هل أنت من العودة (تحويل) إلى الإسلام؟';

  @override
  String get onboarding_label_sect => 'طائفة';

  @override
  String get onboarding_label_shia => 'الشيعة';

  @override
  String get onboarding_label_smoking => 'تدخين';

  @override
  String get onboarding_label_specialNeeds => 'الاحتياجات الخاصة (اختياري)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onboarding_label_subSect => 'مدرسة الفكر (اختياري)';

  @override
  String get onboarding_label_substanceUse => 'استخدام المادة';

  @override
  String get onboarding_label_sunni => 'سني';

  @override
  String get onboarding_label_vaping =>
      'السجائر الإلكترونية / السجائر الإلكترونية';

  @override
  String get onboarding_label_workAfterMarriage => 'العمل بعد الزواج';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'هل ترغبين في العمل بعد الزواج؟';

  @override
  String get onboarding_leadership_leads => 'يؤدي الصلاة';

  @override
  String get onboarding_leadership_learning => 'تعلُّم';

  @override
  String get onboarding_leadership_notYet => 'ليس بعد';

  @override
  String get onboarding_living_openToDiscussion => 'مفتوح للمناقشة';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'أنا مرن وسعيد لمناقشة ما يصلح لكليهما.';

  @override
  String get onboarding_living_separate => 'منزل منفصل';

  @override
  String get onboarding_living_separateSub =>
      'أفضّل أن يكون لدينا منزل مستقل خاص بنا.';

  @override
  String get onboarding_living_withInlaws => 'مع الأصهار';

  @override
  String get onboarding_living_withInlawsSub =>
      'أتوقع أن أعيش مع زوجتي أو عائلتي.';

  @override
  String get onboarding_location_confirmed => 'الموقع المؤكد';

  @override
  String get onboarding_mahr_generous => 'كريم';

  @override
  String get onboarding_mahr_moderate => 'معتدل';

  @override
  String get onboarding_mahr_modest => 'محتشم';

  @override
  String get onboarding_mahr_noPreference => 'لا يوجد تفضيل';

  @override
  String get onboarding_mahr_toDiscuss => 'للمناقشة';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'لا تظهر هذه التفاصيل في ملفك الشخصي العام. تتم مشاركتها بشكل خاص خلال مرحلة القبول.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'ساعدنا على فهم رحلتك واستعدادك.';

  @override
  String get onboarding_marriageDeen_title => 'الزواج والدين';

  @override
  String get onboarding_niqab_dontWear => 'أنا لا أرتدي النقاب';

  @override
  String get onboarding_niqab_open => 'مفتوح للارتداء';

  @override
  String get onboarding_niqab_wear => 'أرتدي النقاب';

  @override
  String get onboarding_photo_subtitle =>
      'مطلوب صورة واحدة على الأقل. يجب أن تتضمن صورتك الأساسية وجهك بوضوح.';

  @override
  String get onboarding_photo_title => 'أضف صورك';

  @override
  String get onboarding_photo_verifySelfie => 'التحقق من الصورة الشخصية';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'التقط صورة حية للتحقق من أنك حقيقي';

  @override
  String get onboarding_preferredLiving_noPreference => 'لا يوجد تفضيل';

  @override
  String get onboarding_profileForWhom_creatingFor => 'أنا أصنع هذا من أجلي…';

  @override
  String get onboarding_profileForWhom_guardian => 'ابني أو ابنتي';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'أقوم بإنشاء هذا الملف الشخصي لشخص ما';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'الوصي';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'أنا أحد الوالدين أو الوصي';

  @override
  String get onboarding_profileForWhom_myself => 'نفسي';

  @override
  String get onboarding_profileForWhom_myselfSub => 'أبحث عن الزوج';

  @override
  String get onboarding_profileForWhom_relation_brother => 'أخ';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'بنت';

  @override
  String get onboarding_profileForWhom_relation_sister => 'أخت';

  @override
  String get onboarding_profileForWhom_relation_son => 'ابن';

  @override
  String get onboarding_profileForWhom_selectOne => 'اختر واحدًا للمتابعة';

  @override
  String get onboarding_profileForWhom_selectRelation => 'حدد علاقة للمتابعة';

  @override
  String get onboarding_profileForWhom_sibling => 'أخي أو أختي';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'أنا أساعد أخي في العثور على شريك';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'يمكنك تحديث هذا لاحقًا من الإعدادات.';

  @override
  String get onboarding_profileForWhom_title => 'لمن هذا الملف الشخصي؟';

  @override
  String get onboarding_profileForWhom_ward => 'جناحي';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'أنا الوصي الذي يدير هذا الملف الشخصي';

  @override
  String get onboarding_providerQuote =>
      '«خيركم خياركم لنسائكم». - النبي محمد صلي الله عليه وسلم\n\nإن الصدق بشأن استعدادك يساعد في بناء أساس قوي.';

  @override
  String get onboarding_quran_hafiz => 'حافظ / حفيظة';

  @override
  String get onboarding_quran_none => 'لا أحد';

  @override
  String get onboarding_quran_partial => 'حفظ جزئي';

  @override
  String get onboarding_quran_some => 'بعض السور';

  @override
  String get onboarding_religiousEdu_alim => 'دورة عليم';

  @override
  String get onboarding_religiousEdu_islamicUni => 'الجامعة الإسلامية';

  @override
  String get onboarding_religiousEdu_madrasa => 'مدرسة';

  @override
  String get onboarding_religiousEdu_selfTaught => 'العصاميين';

  @override
  String get onboarding_timeline_1year => 'في غضون عام';

  @override
  String get onboarding_timeline_2years => '2+ سنة';

  @override
  String get onboarding_timeline_6months => 'في غضون 6 أشهر';

  @override
  String get onboarding_timeline_asap => 'في أسرع وقت ممكن';

  @override
  String get onboarding_timeline_notSure => 'لست متأكدا بعد';

  @override
  String get onboarding_tooltip_cultural =>
      'يُعرف بأنه مسلم، ويحتفل بالمناسبات، وقد لا يصلي بانتظام';

  @override
  String get onboarding_tooltip_moderate =>
      'يقدّر المبادئ الإسلامية ويصلي، وإن لم يكن دائمًا خمس مرات في اليوم';

  @override
  String get onboarding_tooltip_practicing =>
      'يتبع جميع الركائز الخمس، يصلي بانتظام، وأسلوب الحياة الحلال';

  @override
  String get onboarding_work_no => 'لا، أفضل ألا أفعل ذلك';

  @override
  String get onboarding_work_yes => 'نعم، أخطط للعمل';

  @override
  String get photo_add_main_required => 'أضف الصورة الرئيسية\n(مطلوب)';

  @override
  String get photo_add_photo => 'أضف صورة';

  @override
  String get photo_banner_text => 'لا يُسمح بالصور التي تحتوي على محتوى صريح';

  @override
  String get photo_error_no_face_detected =>
      'لا يوجد وجه مرئي - يرجى إعادة المحاولة باستخدام صورة وجه واضحة';

  @override
  String photo_error_pick_failed(Object error) {
    return 'تعذر اختيار الصورة: $error';
  }

  @override
  String get photo_face_detected => 'تم اكتشاف الوجه ✓';

  @override
  String get photo_label_photo2 => 'الصورة 2';

  @override
  String get photo_label_photo3 => 'الصورة 3';

  @override
  String get photo_label_primary => 'الصورة الأولية';

  @override
  String get photo_label_selfie => 'الصورة 4';

  @override
  String get photo_no_face => 'لا يوجد وجه مرئي';

  @override
  String get photo_privacy_everyone => 'مرئية للجميع';

  @override
  String get photo_privacy_everyone_sub =>
      'يمكن لجميع الأعضاء رؤية الصور الخاصة بك.';

  @override
  String get photo_privacy_label => 'خصوصية الصورة';

  @override
  String get photo_privacy_mutual => 'مرئية بعد الاهتمام المتبادل';

  @override
  String get photo_privacy_mutual_sub =>
      'لا تكشف الصور إلا عندما يعبر الطرفان عن اهتمامهما.';

  @override
  String get photo_privacy_request => 'طلب المشاهدة';

  @override
  String get photo_privacy_request_sub =>
      'تكون الصور غير واضحة حتى توافق على الطلب.';

  @override
  String get photo_sheet_camera => 'آلة تصوير';

  @override
  String get photo_sheet_gallery => 'معرض';

  @override
  String get photo_sheet_title => 'حدد مصدر الصورة';

  @override
  String get photo_slots_help => 'اضغط على فتحات للتحميل';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'أضف صورًا لـ $relation الخاص بك. مطلوب واحد على الأقل.';
  }

  @override
  String get photo_subtitle_self =>
      'مطلوب صورة واحدة على الأقل. الحد الأقصى أربعة.';

  @override
  String get photo_title_guardian => 'أضف صورهم';

  @override
  String get photo_title_self => 'أضف صورك';

  @override
  String get preferences_deen_any => 'أي';

  @override
  String get preferences_deen_cultural => 'مسلم ثقافي';

  @override
  String get preferences_deen_moderate => 'معتدل';

  @override
  String get preferences_deen_practicing => 'ممارسة';

  @override
  String get preferences_edu_any => 'أي';

  @override
  String get preferences_edu_bachelors => 'بكالوريوس+';

  @override
  String get preferences_edu_diploma => 'دبلوم +';

  @override
  String get preferences_edu_masters => 'الماجستير+';

  @override
  String get preferences_edu_phd => 'دكتوراه فقط';

  @override
  String get preferences_edu_secondary => 'الثانوية +';

  @override
  String get preferences_label_age => 'الفئة العمرية';

  @override
  String get preferences_label_age_bounds => '18 - 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max سنة';
  }

  @override
  String get preferences_label_deen => 'تفضيلات مستوى الدين';

  @override
  String get preferences_label_edu => 'الحد الأدنى من التعليم';

  @override
  String get preferences_label_living => 'تفضيل ترتيب المعيشة';

  @override
  String get preferences_label_location => 'موقع';

  @override
  String get preferences_label_openness => 'الانفتاح';

  @override
  String get preferences_label_sect => 'تفضيل الطائفة';

  @override
  String get preferences_living_discussion => 'مفتوح للمناقشة';

  @override
  String get preferences_living_family => 'مع العائلة';

  @override
  String get preferences_living_no_pref => 'لا يوجد تفضيل';

  @override
  String get preferences_living_separate => 'منزل منفصل';

  @override
  String get preferences_location_abroad => 'مفتوحة للخارج';

  @override
  String get preferences_location_diaspora => 'وضع الشتات';

  @override
  String get preferences_location_same_city => 'نفس المدينة';

  @override
  String get preferences_location_same_country => 'نفس البلد';

  @override
  String get preferences_open_children => 'مفتوح لشخص لديه أطفال';

  @override
  String get preferences_open_divorced => 'مفتوحة لشخص مطلق سابقا';

  @override
  String get preferences_open_widowed => 'مفتوحة لشخص أرمل سابقا';

  @override
  String get preferences_sect_any => 'أي';

  @override
  String get preferences_sect_same => 'نفس لي';

  @override
  String get preferences_sect_shia => 'الشيعة';

  @override
  String get preferences_sect_sunni => 'سني';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'قم بتعيين التفضيلات للمطابقة المثالية لجهاز $relation.';
  }

  @override
  String get preferences_subtitle_self => 'هذه تفضيلات، وليست مرشحات صعبة.';

  @override
  String get preferences_title => 'تفضيلات الشريك';

  @override
  String get preview_age_label => 'عمر';

  @override
  String get preview_background => 'خلفية';

  @override
  String get preview_basic_info => 'معلومات أساسية';

  @override
  String get preview_city_label => 'مدينة';

  @override
  String get preview_community_label => 'مجتمع';

  @override
  String get preview_cowife_label => 'قبول الزوجة';

  @override
  String get preview_deen_label => 'مستوى الدين';

  @override
  String get preview_diet_label => 'نظام عذائي';

  @override
  String get preview_edit => 'يحرر';

  @override
  String get preview_education_label => 'تعليم';

  @override
  String get preview_faith => 'إيمان';

  @override
  String get preview_family => 'عائلة';

  @override
  String get preview_family_type_label => 'نوع العائلة';

  @override
  String get preview_gender_label => 'جنس';

  @override
  String get preview_hijab_label => 'الحجاب';

  @override
  String get preview_hookah_label => 'الشيشة';

  @override
  String get preview_leadership_label => 'قيادة';

  @override
  String get preview_marital_label => 'الزوجية';

  @override
  String get preview_marriage_timeline_label => 'الجدول الزمني للزواج';

  @override
  String get preview_mother_tongue_label => 'اللغة الأم';

  @override
  String get preview_name_label => 'اسم';

  @override
  String get preview_notice_guardian =>
      'هذا هو بالضبط كيف سيرى الآخرون ملفهم الشخصي.';

  @override
  String get preview_notice_self =>
      'هذا هو بالضبط كيف سيرى الآخرون ملفك الشخصي.';

  @override
  String get preview_polygamy_label => 'تعدد الزوجات';

  @override
  String get preview_post_marriage_living_label => 'حياة ما بعد الزواج';

  @override
  String get preview_prays_label => 'يصلي 5x';

  @override
  String get preview_profession_label => 'مهنة';

  @override
  String get preview_quran_label => 'القرآن';

  @override
  String get preview_religious_edu_label => 'التربية الدينية';

  @override
  String get preview_residency_label => 'الإقامة';

  @override
  String get preview_revert_label => 'يرجع';

  @override
  String get preview_sect_label => 'طائفة';

  @override
  String get preview_siblings_label => 'إخوة';

  @override
  String get preview_smoking_label => 'تدخين';

  @override
  String get preview_special_needs_label => 'الاحتياجات الخاصة';

  @override
  String get preview_submit_btn => 'إرسال الملف الشخصي';

  @override
  String get preview_title => 'معاينة';

  @override
  String get preview_vaping_label => 'التدخين الإلكتروني';

  @override
  String get preview_willing_relocate_label => 'على استعداد للانتقال';

  @override
  String profile_label_completeness(int percent) {
    return 'اكتمل الملف الشخصي $percent%';
  }

  @override
  String get profile_nudge_completeness =>
      'الملفات الشخصية التي تبلغ نسبة اكتمالها 80%+ تحصل على 3 أضعاف الاهتمامات.';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · في سبيل الله';

  @override
  String get settings_button_deleteAccount => 'حذف الحساب';

  @override
  String get settings_guardian_mirror => 'رسائل المرآة';

  @override
  String get settings_guardian_mirror_sub =>
      'إرسال نسخ من جميع الرسائل إلى ولي الأمر';

  @override
  String get settings_guardian_name_hint => 'اسم الوصي';

  @override
  String get settings_guardian_relationship => 'علاقة';

  @override
  String get settings_guardian_reply => 'السماح للوصي بالرد';

  @override
  String get settings_guardian_reply_sub => 'يجوز للوصي المشاركة في المحادثات';

  @override
  String get settings_guardian_save => 'حفظ إعدادات الجارديان';

  @override
  String get settings_guardian_saved => 'أنقذ';

  @override
  String get settings_guardian_sub => 'تمكين إشراف الوالي على الرسائل';

  @override
  String get settings_guardian_title => 'وضع الجارديان';

  @override
  String get settings_label_blocked => 'الملفات الشخصية المحظورة';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count محظور';
  }

  @override
  String get settings_label_blocked_none => 'لا أحد';

  @override
  String get settings_label_deleteGrace =>
      'سيتم إخفاء ملفك الشخصي على الفور. سيتم حذف بياناتك نهائيًا بعد 30 يومًا.';

  @override
  String get settings_label_editProfile => 'تحرير الملف الشخصي';

  @override
  String get settings_label_language => 'لغة';

  @override
  String get settings_label_photoPrivacy => 'خصوصية الصور';

  @override
  String get settings_label_rate => 'قيّم سيلارا';

  @override
  String get settings_label_rate_snackbar =>
      'سيكون التقييم متاحًا بمجرد إطلاق سيلارا في متجر التطبيقات.';

  @override
  String get settings_label_reports => 'تقرير التاريخ';

  @override
  String settings_label_reports_count(Object count) {
    return '$count التقارير';
  }

  @override
  String get settings_label_reports_none => 'لم يتم تقديم أي تقارير';

  @override
  String get settings_label_selfieChallenge => 'تحدي السيلفي';

  @override
  String get settings_label_verifyProfile => 'التحقق من الملف الشخصي';

  @override
  String get settings_label_version => 'إصدار';

  @override
  String get settings_notify_activityNudges => 'تنبيهات النشاط';

  @override
  String get settings_notify_activityNudgesSub =>
      'نصائح لإكمال الملف وتذكير بعد غياب 7 أيام';

  @override
  String get settings_notify_boostReminders => 'تعزيز التذكيرات';

  @override
  String get settings_notify_boostRemindersSub =>
      'ذكّر عندما يكون التعزيز الأسبوعي الخاص بك جاهزًا';

  @override
  String get settings_notify_interestAccepted => 'تم قبول الاهتمام';

  @override
  String get settings_notify_interestExpiring => 'ينتهي الاهتمام قريبًا';

  @override
  String get settings_notify_newInterest => 'اهتمامات جديدة';

  @override
  String get settings_notify_newMessage => 'رسائل جديدة';

  @override
  String get settings_notify_quietHours => 'ساعات هادئة';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'الاهتمامات المقبولة فقط';

  @override
  String get settings_photo_privacy_after_acceptance => 'بعد القبول';

  @override
  String get settings_photo_privacy_everyone => 'الجميع';

  @override
  String get settings_photo_privacy_public => 'عام';

  @override
  String get settings_photo_privacy_request_only => 'الطلب فقط';

  @override
  String get settings_photo_privacy_request_to_view => 'طلب المشاهدة';

  @override
  String get settings_privacy_download_body =>
      'أنشئ الآن أرشيف ZIP خاصًا يتضمن حسابك وملفك وصورك واهتماماتك ومطابقاتك ورسائلك وإعداداتك وسجل الموافقات والاشتراك. احفظه عبر نافذة المشاركة الآمنة في جهازك.';

  @override
  String get settings_privacy_download_btn => 'إنشاء أرشيف آمن';

  @override
  String get settings_privacy_download_label => 'تنزيل بياناتي';

  @override
  String get settings_privacy_download_sub =>
      'احفظ نسخة قابلة للقراءة آليًا من بيانات Silarah الخاصة بك';

  @override
  String get settings_privacy_export_body =>
      'أرشيفك الخاص جاهز. استخدم نافذة المشاركة لحفظه بأمان.';

  @override
  String get settings_privacy_export_btn_close => 'مفهوم';

  @override
  String get settings_privacy_export_subbody =>
      'قد يحتوي الأرشيف على رسائل خاصة وبيانات اتصال. خزّنه بأمان ولا تشاركه إلا مع من تثق بهم.';

  @override
  String get settings_privacy_export_title => 'الأرشيف جاهز';

  @override
  String get settings_privacy_online_label => 'حالة الاتصال بالإنترنت';

  @override
  String get settings_privacy_online_sub => 'إظهار متى كنت نشطًا آخر مرة';

  @override
  String get settings_privacy_pause_label => 'وقفة الملف الشخصي';

  @override
  String get settings_privacy_pause_sub =>
      'إخفاء ملف التعريف الخاص بك من البحث';

  @override
  String get settings_privacy_pause_warning =>
      'ملفك الشخصي مخفي. لا أحد يستطيع العثور عليك.';

  @override
  String get settings_privacy_photo_label => 'رؤية الصورة';

  @override
  String get settings_privacy_photo_sub => 'من يمكنه رؤية صورك';

  @override
  String get settings_privacy_visibility_all => 'جميع المستخدمين المسجلين';

  @override
  String get settings_privacy_visibility_label => 'من يمكنه رؤية ملفي الشخصي';

  @override
  String get settings_privacy_visibility_sub =>
      'التحكم في من يمكنه تصفح ملفك الشخصي';

  @override
  String get settings_privacy_visibility_subscribers => 'المشتركين فقط';

  @override
  String get settings_relation_brother => 'أخ';

  @override
  String get settings_relation_father => 'أب';

  @override
  String get settings_relation_mother => 'الأم';

  @override
  String get settings_relation_other => 'آخر';

  @override
  String get settings_relation_uncle => 'عم';

  @override
  String get settings_section_account => 'حساب';

  @override
  String get settings_section_app => 'برنامج';

  @override
  String get settings_section_dangerZone => 'إغلاق الحساب';

  @override
  String get settings_section_guardian => 'الوصي';

  @override
  String get settings_section_legal => 'قانوني';

  @override
  String get settings_section_notifications => 'إشعارات';

  @override
  String get settings_section_privacy => 'خصوصية';

  @override
  String get settings_section_safety => 'أمان';

  @override
  String get settings_support_body => 'لأية أسئلة أو استفسارات أو تعليقات:';

  @override
  String get settings_support_btn_close => 'يغلق';

  @override
  String get settings_support_contact => 'اتصل بالدعم';

  @override
  String get settings_support_note => 'ونحن نهدف إلى الرد في غضون 48 ساعة.';

  @override
  String get settings_title => 'إعدادات';

  @override
  String get splash_button_createProfile => 'إنشاء الملف الشخصي';

  @override
  String get splash_button_signIn => 'تسجيل الدخول';

  @override
  String get splash_intention_subtitle =>
      'تعارف خاص، وتوافق مدروس، وتواصل يراعي الأسرة.';

  @override
  String get splash_intention_title => 'الزواج، بنية صادقة.';

  @override
  String get splash_referral_button => 'تطبيق الكود';

  @override
  String get splash_referral_hint => 'على سبيل المثال SILARAHXX';

  @override
  String get splash_referral_invalid => 'الرجاء إدخال رمز صالح مكون من 6 أحرف.';

  @override
  String get splash_referral_question => 'هل لديك رمز الإحالة؟';

  @override
  String get splash_referral_saved =>
      'تم حفظ رمز الإحالة! سيتم تطبيقه بعد تسجيل الدخول.';

  @override
  String get splash_referral_subtitle =>
      'إذا دعاك أحد الأصدقاء إلى سيلارا، فأدخل رمز الإحالة المكون من 6 أحرف أدناه.';

  @override
  String get splash_referral_title => 'أدخل رمز الإحالة';

  @override
  String subscription_button_monthly(String price) {
    return 'الاشتراك - $price/شهر';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'الاشتراك — $price/3 أشهر';
  }

  @override
  String get subscription_label_bestValue => 'أفضل قيمة';

  @override
  String get subscription_subtitle =>
      'رسائل نسائية مجانية. الرجال الاشتراك للاتصال.';

  @override
  String get subscription_title => 'فتح سيلارا';

  @override
  String get startup_connectivity_preparing_title => 'نُهيّئ مساحتك الخاصة';

  @override
  String get startup_connectivity_preparing_body =>
      'جارٍ إنشاء اتصال آمن بسيلارا.';

  @override
  String get startup_connectivity_offline_title => 'في انتظار الاتصال';

  @override
  String get startup_connectivity_offline_body =>
      'ملفك واهتماماتك ومحادثاتك في أمان. سيكمل سيلارا من حيث توقفت فور عودتك إلى الإنترنت.';

  @override
  String get startup_connectivity_verifying => 'جارٍ فحص الاتصال';

  @override
  String get startup_connectivity_waiting => 'في انتظار الشبكة';

  @override
  String get startup_connectivity_still_waiting =>
      'ما زلت غير متصل · نعيد المحاولة';

  @override
  String get startup_connectivity_check => 'إعادة المحاولة';

  @override
  String get startup_connectivity_checking => 'جارٍ الفحص…';

  @override
  String get startup_connectivity_auto =>
      'سنعيد الاتصال تلقائيًا عند عودة الشبكة.';

  @override
  String get startup_connectivity_tip =>
      'تأكد من تشغيل Wi-Fi أو بيانات الجوال.';

  @override
  String get startup_connectivity_protected => 'اتصال محمي';

  @override
  String get settings_label_email => 'البريد الإلكتروني';

  @override
  String get settings_notify_profileViews => 'مشاهدات الملف الشخصي';

  @override
  String get settings_notify_profileViewsSub =>
      'تنبيه خاص عندما يفتح شخص ملفك الشخصي';

  @override
  String get settings_notify_profileLive => 'نشر الملف الشخصي';

  @override
  String get settings_notify_profileLiveSub =>
      'تأكيد عندما يصبح ملفك الشخصي مرئيًا';

  @override
  String get settings_appearance => 'المظهر';

  @override
  String get settings_helpSupport => 'المساعدة والدعم';

  @override
  String get settings_helpCenter => 'مركز المساعدة';

  @override
  String get settings_grievanceOfficer => 'مسؤول الشكاوى';

  @override
  String get settings_grievanceResponse =>
      'تأكيد الاستلام خلال 24 ساعة؛ حل معظم الشكاوى خلال 7 أيام';

  @override
  String get settings_grievanceIndiaNotice =>
      'تتبع معالجة الشكاوى في الهند قواعد تقنية المعلومات (إرشادات الوسطاء ومدونة أخلاقيات الوسائط الرقمية) بصيغتها المعدلة. تخضع شكاوى المحتوى غير القانوني أو الحميم العاجلة للمواعيد القانونية الأقصر.';

  @override
  String get settings_managePhotoRequests => 'إدارة طلبات الصور';

  @override
  String get settings_managePhotoRequestsSub =>
      'الموافقة على الوصول أو رفض الطلبات أو إلغاء المشاركة';

  @override
  String get settings_theme_chooseTitle => 'اختر أجواءك';

  @override
  String get settings_theme_chooseSubtitle =>
      'هوية بصرية متكاملة وليست مجرد مرشح ألوان. تتغير جميع الأسطح والحقول وعناصر النظام معًا.';

  @override
  String get settings_theme_applied => 'يُطبّق فورًا · محفوظ على هذا الجهاز';

  @override
  String get settings_reportPending => 'قيد المراجعة';

  @override
  String get legal_document_terms => 'شروط الخدمة';

  @override
  String get legal_document_privacy => 'سياسة الخصوصية';

  @override
  String get legal_document_community => 'إرشادات المجتمع';

  @override
  String get legal_specialCategoryConsent =>
      'أوافق صراحةً على معالجة Silarah لمعلوماتي الدينية (المذهب والصلاة والهوية الإسلامية) لمطابقة التوافق. يستخدمها مزودو الخدمة المتعاقدون فقط لتشغيل سيلارا، وليس للإعلانات السلوكية.';

  @override
  String get onboarding_complexion_fair => 'فاتحة';

  @override
  String get onboarding_complexion_medium => 'قمحية';

  @override
  String get onboarding_complexion_olive => 'زيتونية';

  @override
  String get onboarding_complexion_dark => 'داكنة';

  @override
  String get onboarding_residency_citizen => 'مواطن';

  @override
  String get onboarding_residency_permanentResident => 'مقيم دائم';

  @override
  String get onboarding_residency_workVisa => 'تأشيرة عمل';

  @override
  String get onboarding_residency_studentVisa => 'تأشيرة طالب';

  @override
  String get onboarding_specialNeeds_none => 'لا يوجد';

  @override
  String get onboarding_specialNeeds_physical => 'إعاقة جسدية';

  @override
  String get onboarding_specialNeeds_hearing => 'ضعف السمع';

  @override
  String get onboarding_specialNeeds_visual => 'ضعف البصر';

  @override
  String get onboarding_label_stateRegion => 'الولاية / المنطقة';

  @override
  String get onboarding_specialNeeds_privacy =>
      'تتم مشاركة هذه المعلومة فقط بعد الاهتمام المتبادل.';

  @override
  String get settings_theme_automatic => 'تلقائي';

  @override
  String get settings_theme_automaticDesc =>
      'عاجي وزمردي نهارًا، وليل OLED عند الوضع الداكن في هاتفك';

  @override
  String get settings_theme_rose => 'وردي وقطيفة';

  @override
  String get settings_theme_roseDesc => 'وردي ناعم مع ورد عميق وذهبي القطيفة';

  @override
  String get settings_theme_oled => 'ليل OLED';

  @override
  String get settings_theme_oledDesc => 'أسود حقيقي مضبوط لشاشات OLED';

  @override
  String get settings_theme_ivory => 'عاجي وزمردي';

  @override
  String get settings_theme_ivoryDesc => 'عاجي دافئ مع زمردي عميق وذهبي عتيق';

  @override
  String get settings_guardian_backendRequired =>
      'تتطلب إعدادات الولي اتصالًا آمنًا.';

  @override
  String get settings_guardian_saveError =>
      'تعذر حفظ إعدادات الولي. حاول مرة أخرى.';

  @override
  String get common_openSettings => 'فتح الإعدادات';

  @override
  String get media_cameraAccessOff => 'الوصول إلى الكاميرا متوقف';

  @override
  String get media_cameraUnavailable => 'الكاميرا غير متاحة';

  @override
  String get media_cameraAccessBody =>
      'اسمح بالوصول إلى الكاميرا من الإعدادات، ثم عد لالتقاط صورة واضحة.';

  @override
  String get media_cameraUnavailableBody => 'تعذر فتح الكاميرا. حاول مرة أخرى.';

  @override
  String get media_photoAccessOff => 'الوصول إلى الصور متوقف';

  @override
  String get media_photoAccessBody =>
      'اسمح بالوصول إلى الكاميرا أو الصور من الإعدادات، ثم عد لإضافة صورتك.';

  @override
  String get chat_searchHint => 'البحث في الرسائل';

  @override
  String get chat_noConversationsFound => 'لم يتم العثور على محادثات';

  @override
  String get chat_noConversationsFoundBody => 'جرّب اسمًا آخر أو امسح البحث.';

  @override
  String get chat_noConversationsYet => 'لا توجد محادثات بعد';

  @override
  String get chat_noConversationsYetBody =>
      'اقبل اهتمامًا أو انتظر قبول اهتمامك لبدء محادثة.';

  @override
  String get referral_title => 'ادعُ صديقًا';

  @override
  String get referral_loading => 'جارٍ تحميل المكافآت';

  @override
  String get referral_heading => 'انشر الخبر واربح المزايا المميزة!';

  @override
  String get referral_body =>
      'ادعُ أي صديق مؤهل إلى سيلاراه. يمكن لكل حساب الحصول على مكافأة إحالة واحدة فقط لمدة 3 أيام. إذا حصلت على مكافأتك بالفعل، فلا يزال بإمكان صديقك الحصول على مكافأته.';

  @override
  String get referral_premiumActiveTitle => 'مكافأة الإحالة المميزة نشطة';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return 'متبقي $daysي $hoursس';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return 'متبقي $hoursس $minutesد';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return 'متبقي $minutesد';
  }

  @override
  String get referral_premiumEndingNow => 'تنتهي المكافأة الآن';

  @override
  String referral_premiumEndsAt(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'جميع المزايا المميزة مفتوحة. لم يتم تحصيل أي مبلغ ولن تتجدد هذه المكافأة تلقائيًا.';

  @override
  String get referral_premiumPlansAfter =>
      'تتوفر خطط الاشتراك بعد انتهاء مكافأتك المجانية حتى لا تفقد أي وقت مجاني متبقٍ.';

  @override
  String get referral_premiumBackToProfile => 'العودة إلى الملف الشخصي';

  @override
  String get referral_premiumFeaturesUnlocked => 'جميع المزايا المميزة مفتوحة';

  @override
  String get referral_premiumViewReward => 'عرض المكافأة';

  @override
  String get referral_codeLabel => 'رمز الإحالة الخاص بك';

  @override
  String get referral_tapToCopy => 'اضغط على الرمز لنسخه';

  @override
  String get referral_totalInvited => 'إجمالي المدعوين';

  @override
  String get referral_rewardsEarned => 'المكافآت المكتسبة';

  @override
  String referral_premiumDays(int count) {
    return '$count أيام مميزة';
  }

  @override
  String get referral_pending => 'التسجيلات المعلقة';

  @override
  String get referral_shareButton => 'مشاركة الرمز مع الأصدقاء';

  @override
  String get referral_copied => 'تم نسخ رمز الإحالة!';

  @override
  String get referral_shareSubject => 'انضم إلى سيلاراه';

  @override
  String referral_shareText(String code) {
    return 'انضم إلى سيلاراه، تطبيق الزواج الإسلامي الموثوق. استخدم رمز إحالتي: $code\n\nالتنزيل: https://silarah.com/r/$code';
  }

  @override
  String get profile_share => 'مشاركة الملف الشخصي';

  @override
  String safety_reportMember(String name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String safety_blockMember(String name) {
    return 'حظر $name';
  }

  @override
  String safety_blockTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String safety_blockBody(String name) {
    return 'سيُخفى $name من الاكتشاف ولن يتمكن من التواصل معك. يُحفظ سجل الدردشة لأغراض السلامة، ولن يعيد إلغاء الحظر فتح المحادثة.';
  }

  @override
  String get safety_blockAction => 'حظر';

  @override
  String safety_blocked(String name) {
    return 'تم حظر $name.';
  }

  @override
  String ui_openProfile(String name) {
    return 'افتح الملف الشخصي $name';
  }

  @override
  String ui_typing(String name) {
    return '$name يكتب';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'فشل حذف الحساب: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'تغيير البلد، حاليًا $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'لم يتم العثور على تطبيق البريد الإلكتروني. تم نسخ $email.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'الرسالة $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'يجدد $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age سنة';
  }

  @override
  String ui_photoNumber(int number) {
    return 'الصورة $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count من 4 صور';
  }

  @override
  String ui_removeLabel(String label) {
    return 'إزالة $label';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label تم التحديد';
  }

  @override
  String ui_addLabel(String label) {
    return 'إضافة $label';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'تم إرسال طلب الصورة إلى $name.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'أمس $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count قبل دقيقة';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count منذ ساعة';
  }

  @override
  String ui_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String ui_renewsAt(String time) {
    return 'يتم التجديد في $time';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'الصورة $number جاهزة للمراجعة المحمية';
  }

  @override
  String get ui_onePhotoUnlock =>
      'سيتم فتح صورة واحدة تلقائيًا بمجرد إبداء اهتمامكما.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return 'سيتم فتح صور $count تلقائيًا بمجرد التعبير عن اهتمامكما.';
  }

  @override
  String get ui_askOnePhoto => 'اطلب من المالك الإذن لعرض صورة واحدة.';

  @override
  String ui_askManyPhotos(int count) {
    return 'اطلب من المالك الإذن لعرض صور $count.';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet قدم $inches بوصة';
  }

  @override
  String ui_minutesShort(int count) {
    return '$countم';
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
    return 'عوامل التصفية ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'تمت المطابقة سابقًا في $date';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'إعادة المطابقة متاحة خلال $count أيام';
  }

  @override
  String get settings_notify_compatibleProfiles =>
      'تنبيهات الملفات الشخصية المتوافقة';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'عندما تظهر نتائج جديدة في صفحة استكشاف كانت فارغة';

  @override
  String get settings_notify_discoveryDigest => 'ملخص الاستكشاف';

  @override
  String get settings_notify_digestHelp =>
      'ملخصات اختيارية؛ تظل تنبيهات ظهور نتائج بعد فراغ الصفحة فورية.';

  @override
  String get settings_notify_digestOff => 'إيقاف';

  @override
  String get settings_notify_digestDaily => 'يومي';

  @override
  String get settings_notify_digestWeekly => 'أسبوعي';

  @override
  String get settings_quietHoursStart => 'بداية ساعات الهدوء';

  @override
  String get settings_quietHoursEnd => 'نهاية ساعات الهدوء';

  @override
  String get settings_notify_festivalGreetings => 'تهاني المناسبات';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'تهاني رمضان والعيد، نحو خمس مرات في السنة';
}
