// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get guide_optional_details => 'अतिरिक्त जानकारी (वैकल्पिक)';

  @override
  String get guide_optional_details_body =>
      'आप बाद में अपनी प्रोफ़ाइल से यह जानकारी पूरी कर सकते हैं।';

  @override
  String get guide_profile_ownership =>
      'यह प्रोफ़ाइल विवाह के इच्छुक व्यक्ति का परिचय देती है। बातचीत की निगरानी के लिए बाद में एक अलग अभिभावक को आमंत्रित किया जा सकता है।';

  @override
  String get about_button_later => 'मैं यह बाद में करूंगा';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'अपने $relation का ईमानदारी और गरिमा के साथ वर्णन करें।';
  }

  @override
  String get about_hint_bio_self => 'अपना वर्णन ईमानदारी और गरिमा के साथ करें।';

  @override
  String get about_label_bio_guardian => 'उनका बायो';

  @override
  String get about_label_bio_self => 'आपका बायो';

  @override
  String get about_label_interests => 'रुचियाँ';

  @override
  String get about_label_languages => 'बोली जाने वाली भाषाएं';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max चयनित';
  }

  @override
  String get about_subtitle => 'ईमानदारी और गरिमा के साथ लिखें.';

  @override
  String about_title_guardian(Object relation) {
    return 'आपके $relation के बारे में';
  }

  @override
  String get about_title_self => 'आपके बारे में';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'शुरुआत बिस्मिल्लाह से करें';

  @override
  String get auth_button_resendOtp => 'सत्यापन कोड पुनः भेजें';

  @override
  String get auth_button_sendCode => 'सत्यापन कोड भेजें';

  @override
  String get auth_button_sendOtp => 'सत्यापन कोड भेजें';

  @override
  String get auth_button_verifyOtp => 'सत्यापित करें';

  @override
  String get auth_label_changeNumber => 'गलत संख्या? बदल दें';

  @override
  String get auth_label_enterOtp => 'भेजे गए 6-अंकीय सत्यापन कोड को दर्ज करें';

  @override
  String get auth_label_resendCode => 'सत्यापन कोड पुनः भेजें';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return '${seconds}s में सत्यापन कोड पुनः भेजें';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return '${seconds}s में पुनः भेजें';
  }

  @override
  String get auth_label_sentCodeTo => 'हमने 6 अंकों का सत्यापन कोड भेजा';

  @override
  String get auth_subtitle_verifyOtp =>
      'हम इसे एक बार के कोड से सत्यापित करेंगे।';

  @override
  String get auth_title_enterCode => 'अपना सत्यापन कोड दर्ज करें';

  @override
  String get auth_title_yourNumber => 'तुम्हारी संख्या';

  @override
  String get background_edu_bachelors => 'स्नातक की डिग्री';

  @override
  String get background_edu_below_secondary => 'माध्यमिक से नीचे';

  @override
  String get background_edu_diploma => 'डिप्लोमा/एसोसिएट';

  @override
  String get background_edu_doctorate => 'डॉक्टरेट/पीएचडी';

  @override
  String get background_edu_higher_secondary => 'हायर सेकेंडरी / ए-लेवल';

  @override
  String get background_edu_masters => 'स्नातकोत्तर उपाधि';

  @override
  String get background_edu_secondary => 'माध्यमिक/ओ-स्तर';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'हमें अपनी $relation की शिक्षा और करियर के बारे में बताएं।';
  }

  @override
  String get background_edu_subtitle_self =>
      'पेशेवर रूप से अनुकूल मिलान ढूंढने में मदद करता है।';

  @override
  String get background_edu_title_guardian => 'उनकी पृष्ठभूमि';

  @override
  String get background_edu_title_self => 'आपकी पृष्ठभूमि';

  @override
  String get background_emp_employed => 'कार्यरत';

  @override
  String get background_emp_not_working => 'काम नहीं कर';

  @override
  String get background_emp_self_employed => 'स्वनियोजित';

  @override
  String get background_emp_student => 'विद्यार्थी';

  @override
  String get background_income_subtitle =>
      'बहुत से लोग इसे छोड़ देते हैं - यह पूरी तरह से वैकल्पिक है।';

  @override
  String get background_label_eduLevel => 'शिक्षा का स्तर';

  @override
  String get background_label_employment => 'रोज़गार की स्थिति';

  @override
  String background_label_income_bracket(Object currency) {
    return 'आय वर्ग ($currency)';
  }

  @override
  String get background_label_income_range => 'आय सीमा (वैकल्पिक)';

  @override
  String get background_label_profession => 'पेशा (वैकल्पिक)';

  @override
  String get background_label_study => 'अध्ययन का क्षेत्र (वैकल्पिक)';

  @override
  String get background_label_who_see => 'इसे कौन देख सकता है?';

  @override
  String get background_vis_everyone => 'सभी को ब्रैकेट दिखाएँ';

  @override
  String get background_vis_mutual => 'आपसी हित के बाद ही दिखाएँ';

  @override
  String get background_vis_private => 'निजी रखें';

  @override
  String get ceremony_text_blessing => 'अल्लाह इसे भलाई से नवाजे';

  @override
  String get chat_closure_1 =>
      'अस्सलामु अलैकुम. गहन चिंतन के बाद, मुझे लगता है कि यह हमारे लिए सही मैच नहीं हो सकता है। मैं ईमानदारी से आपको शुभकामनाएं देता हूं और प्रार्थना करता हूं कि अल्लाह आपको एक अद्भुत साथी दे। जज़ाकअल्लाह खैर.';

  @override
  String get chat_closure_2 =>
      'अस्सलामु अलैकुम. मैं आपके साथ ईमानदार और सम्मानजनक रहना चाहता था। मुझे नहीं लगता कि हम सही जोड़ीदार हैं, लेकिन मैं प्रार्थना करता हूं कि अल्लाह आपके लिए बेहतर दरवाजे खोले। आपके मंगलमय होने की कामना।';

  @override
  String get chat_closure_3 =>
      'अस्सलामु अलैकुम. ईमानदारी से विचार करने के बाद, मुझे लगता है कि हम संगत नहीं हो सकते हैं। मुझे आशा है कि आपको वास्तव में कोई आपके लिए सही व्यक्ति मिल जाएगा। अल्लाह आपके लिए इसे आसान बना दे. जज़ाकअल्लाह खैर आपके समय के लिए।';

  @override
  String get chat_closure_4 =>
      'अस्सलामु अलैकुम. मैंने हमारी बातचीत पर विचार किया है और महसूस किया है कि इस समय इस मैच को बंद कर देना ही सबसे अच्छा है। मेरे मन में आपके लिए सम्मान के अलावा कुछ नहीं है और मैं दुआ करता हूं कि अल्लाह आपको सबसे अच्छा आशीर्वाद दे।';

  @override
  String get chat_closure_5 =>
      'अस्सलामु अलैकुम. मैं आपके साथ फीका पड़ने के बजाय पारदर्शी होना चाहता था। मुझे नहीं लगता कि यह आगे बढ़ेगा, लेकिन मैं वास्तव में आपके समय की सराहना करता हूं और आपकी हर खुशी की कामना करता हूं। अल्लाह तुम्हें आशीर्वाद दे।';

  @override
  String get chat_endMatch_button => 'भेजें और मिलान समाप्त करें';

  @override
  String get chat_endMatch_subtitle =>
      'इस वार्तालाप को बंद करने के लिए एक सम्मानजनक संदेश चुनें। दूसरे व्यक्ति को सूचित किया जाएगा.';

  @override
  String get chat_endMatch_title => 'इस मैच को समाप्त करें';

  @override
  String chat_label_probation(int hours) {
    return 'मैसेजिंग $hours घंटों में अनलॉक हो जाती है. अब आप रुचियां भेज सकते हैं.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'मैसेजिंग को अनलॉक करने के लिए सदस्यता लें. महिलाएं हमेशा Silarah पर निःशुल्क संदेश भेजती हैं।';

  @override
  String get chat_matchClosed_banner =>
      'यह मैच सम्मानपूर्वक बंद कर दिया गया है.';

  @override
  String get chat_opener_1 =>
      'अस्सलामु अलैकुम! मैं आपकी प्रोफ़ाइल पर आया और वास्तव में प्रभावित हुआ। क्या मैं अपना परिचय दे सकता हुँ?';

  @override
  String get chat_opener_2 =>
      'बिस्मिल्लाह. आपकी प्रोफ़ाइल ने मेरा ध्यान खींचा. मुझे आपके बारे में और अधिक जानना अच्छा लगेगा।';

  @override
  String get chat_opener_3 =>
      'अस्सलामु अलैकुम. मेरा मानना ​​है कि हम समान मूल्य साझा करते हैं। क्या आप एक-दूसरे को जानने के लिए तैयार होंगे?';

  @override
  String get chat_placeholder_typeMessage => 'एक संदेश टाइप करें...';

  @override
  String get common_button_back => 'पीछे';

  @override
  String get common_button_cancel => 'रद्द करना';

  @override
  String get common_button_done => 'हो गया';

  @override
  String get common_button_next => 'अगला';

  @override
  String get common_button_retry => 'पुनः प्रयास करें';

  @override
  String get common_button_save => 'बचाना';

  @override
  String get common_button_skip => 'छोडना';

  @override
  String get common_button_submit => 'जमा करना';

  @override
  String get common_error_generic => 'कुछ गलत हो गया। कृपया पुन: प्रयास करें।';

  @override
  String get common_error_noInternet =>
      'कोई इंटरनेट कनेक्शन नहीं। कृपया अपना कनेक्शन जांचें.';

  @override
  String get common_label_optional => 'वैकल्पिक';

  @override
  String get copy_beard_parent => 'क्या आपके बेटे की दाढ़ी है?';

  @override
  String get copy_beard_self => 'क्या आपके पास दाढ़ी है?';

  @override
  String get copy_beard_sibling => 'क्या आपके भाई की दाढ़ी है?';

  @override
  String get copy_hijab_parent => 'क्या आपकी बेटी हिजाब का पालन करती है?';

  @override
  String get copy_hijab_self => 'क्या आप हिजाब का पालन करते हैं?';

  @override
  String get copy_hijab_sibling => 'क्या आपकी बहन हिजाब का पालन करती है?';

  @override
  String get copy_prayer_parent =>
      'क्या आपका बच्चा प्रतिदिन पाँच बार प्रार्थना करता है?';

  @override
  String get copy_prayer_self =>
      'क्या आप प्रतिदिन पाँच बार प्रार्थना करते हैं?';

  @override
  String get copy_prayer_sibling =>
      'क्या आपका भाई-बहन प्रतिदिन पाँच बार प्रार्थना करता है?';

  @override
  String get deleteAccount_title => 'खाता हटा दो';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name हटा दिया गया';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name सहेजा गया';
  }

  @override
  String get discovery_button_sendInterest => 'रुचि भेजें';

  @override
  String get discovery_completeness_button => 'संपूर्ण प्रोफ़ाइल';

  @override
  String get discovery_completeness_subtitle =>
      '40% से ऊपर की प्रोफ़ाइल पर 3× अधिक रुचियाँ मिलती हैं।\nब्राउज़िंग प्रारंभ करने के लिए अपनी प्रोफ़ाइल पूर्ण करें.';

  @override
  String get discovery_completeness_title => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get discovery_empty_subtitle =>
      'सिलाराह पर हर दिन नए सदस्य जुड़ते हैं। नई प्रोफ़ाइल के लिए कल फिर देखें, या अभी और लोगों से मिलने के लिए अपनी पसंद का दायरा बढ़ाएँ।';

  @override
  String get discovery_empty_filtered_eyebrow => 'अपनी खोज निखारें';

  @override
  String get discovery_empty_filtered_title =>
      'इन फ़िल्टर से अभी कोई मेल नहीं खाता';

  @override
  String get discovery_empty_filtered_subtitle =>
      'आपकी पसंद दायरे को छोटा कर रही है। सिर्फ़ एक फ़िल्टर में ढील देने से अक्सर तुरंत नई प्रोफ़ाइल दिखने लगती हैं।';

  @override
  String get discovery_empty_clear_filters => 'सभी फ़िल्टर हटाएँ';

  @override
  String get discovery_empty_refresh => 'प्रोफ़ाइल रीफ़्रेश करें';

  @override
  String get discovery_empty_adjust_filters => 'फ़िल्टर बदलें';

  @override
  String get discovery_empty_hint_trust => 'पहले भरोसा जाँच में ढील देकर देखें';

  @override
  String get discovery_empty_hint_deen => 'पहले दीन स्तर का दायरा बढ़ाकर देखें';

  @override
  String get discovery_empty_hint_family =>
      'पहले परिवार का प्रकार बढ़ाकर देखें';

  @override
  String get discovery_empty_hint_sect => 'पहले संप्रदाय फ़िल्टर खोलकर देखें';

  @override
  String get discovery_empty_hint_location => 'पहले बड़ा इलाका चुनकर देखें';

  @override
  String get discovery_empty_hint_age => 'पहले आयु सीमा बढ़ाकर देखें';

  @override
  String get discovery_empty_hint_other =>
      'एक बार में एक फ़िल्टर में ढील देकर देखें';

  @override
  String get discovery_empty_eyebrow => 'आपने सब देख लिया';

  @override
  String get discovery_empty_title => 'आज के लिए आपने सभी को देख लिया है';

  @override
  String get discovery_handoff_interest_subtitle =>
      'सक्रिय अनुरोध वाली प्रोफ़ाइलें आपके इंतज़ार या जवाब देने तक इंटरेस्ट्स में रहती हैं।';

  @override
  String get discovery_handoff_interest_title =>
      'आपकी दिलचस्पी प्रक्रिया में है';

  @override
  String get discovery_handoff_match_subtitle =>
      'मैच हुई प्रोफ़ाइलें चैट में चली जाती हैं, इसलिए वे डिस्कवर में दोबारा नहीं दिखतीं।';

  @override
  String get discovery_handoff_match_title => 'आपका कनेक्शन तैयार है';

  @override
  String get discovery_handoff_open_chat => 'चैट खोलें';

  @override
  String get discovery_handoff_open_interests => 'इंटरेस्ट्स खोलें';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'रुचि भेजी गई ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'कोई ऐसा व्यक्ति जिसके साथ आप जुड़ सकते हैं';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count प्रोफ़ाइल आज शेष हैं';
  }

  @override
  String get discovery_limit_button => 'अभी अपग्रेड करें';

  @override
  String get discovery_limit_subtitle =>
      'आपने आज 15 प्रोफ़ाइलें ब्राउज़ कीं।\nअसीमित ब्राउज़िंग अनलॉक करने के लिए अपग्रेड करें।';

  @override
  String get discovery_limit_title => 'दैनिक सीमा पूरी हो गई';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count प्रोफ़ाइल शेष हैं';
  }

  @override
  String get discovery_wildcard_label =>
      'कोई ऐसा व्यक्ति जिसके साथ आप जुड़ सकते हैं';

  @override
  String get family_children_no => 'नहीं';

  @override
  String get family_children_yes => 'हाँ';

  @override
  String get family_label_children_guardian => 'क्या उनके बच्चे हैं?';

  @override
  String get family_label_children_self => 'आपके बच्चे है क्या?';

  @override
  String get family_label_how_many => 'कितने?';

  @override
  String get family_label_parents => 'माता-पिता की वैवाहिक स्थिति';

  @override
  String get family_label_polygamy_female_self =>
      'बहुविवाह स्वीकृति (वैकल्पिक)';

  @override
  String get family_label_polygamy_male_self => 'बहुविवाह स्थिति (वैकल्पिक)';

  @override
  String get family_label_prev_married => 'पहले से शादीशुदा?';

  @override
  String get family_label_relocate => 'यहां रीलोकेट होना चाहते हैं';

  @override
  String get family_label_siblings => 'भाई-बहनों की संख्या';

  @override
  String get family_label_type => 'परिवार का प्रकार';

  @override
  String get family_living_title => 'विवाहोपरान्त जीवन-यापन की अपेक्षाएँ';

  @override
  String get family_parents_both_deceased => 'दोनों मृतक';

  @override
  String get family_parents_divorced => 'तलाकशुदा';

  @override
  String get family_parents_father_deceased => 'पिता दिवंगत';

  @override
  String get family_parents_mother_deceased => 'माँ मर गयी';

  @override
  String get family_parents_separated => 'अलग किए';

  @override
  String get family_parents_together => 'एक साथ';

  @override
  String get family_polygamy_female_discussion => 'चर्चा के लिए खुला';

  @override
  String get family_polygamy_female_no => 'नहीं';

  @override
  String get family_polygamy_female_prefer_not => 'नहीं कहना पसंद करते हैं';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'क्या आपकी $relation सह-पत्नी बनने पर विचार करेगी?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'क्या आप सहपत्नी बनने पर विचार करेंगी?';

  @override
  String get family_polygamy_female_yes => 'हाँ';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'क्या आपका $relation वर्तमान में विवाहित है और अतिरिक्त जीवनसाथी की तलाश कर रहा है?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'क्या आप वर्तमान में विवाहित हैं और अतिरिक्त जीवनसाथी की तलाश कर रहे हैं?';

  @override
  String get family_polygamy_option_first => 'नहीं, यह मेरा पहला है';

  @override
  String get family_polygamy_option_married => 'हां, फिलहाल शादीशुदा हूं';

  @override
  String get family_polygamy_option_prefer_not => 'नहीं कहना पसंद करते हैं';

  @override
  String get family_prev_divorced => 'तलाकशुदा';

  @override
  String get family_prev_no => 'नहीं';

  @override
  String get family_prev_widowed => 'विधवा';

  @override
  String get family_relocate_discussion => 'चर्चा के लिए खुला';

  @override
  String get family_relocate_no => 'नहीं';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'क्या आपका $relation विवाह के लिए स्थानांतरित होगा?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'क्या आप शादी के लिए स्थान परिवर्तन करेंगे?';

  @override
  String get family_relocate_yes => 'हाँ';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'हमें अपने $relation के परिवार के बारे में बताएं।';
  }

  @override
  String get family_subtitle_self =>
      'स्थायी विवाह के लिए पारिवारिक अनुकूलता केंद्रीय है।';

  @override
  String get family_title_guardian => 'पारिवारिक पृष्ठभूमि';

  @override
  String get family_title_self => 'पारिवारिक पृष्ठभूमि';

  @override
  String get family_type_extended => 'विस्तारित';

  @override
  String get family_type_joint => 'संयुक्त';

  @override
  String get family_type_nuclear => 'नाभिकीय';

  @override
  String get filter_label_community => 'समुदाय/बिरादारी';

  @override
  String get filter_label_livingExpectation => 'विवाहोपरान्त जीवन-यापन';

  @override
  String get filter_label_motherTongue => 'मातृभाषा';

  @override
  String get guardian_details_candidate_female =>
      'महिला अभ्यर्थी • महिला संदेश निःशुल्क';

  @override
  String get guardian_details_candidate_label =>
      'के लिए प्रोफ़ाइल बनाई जा रही है';

  @override
  String get guardian_details_candidate_male => 'पुरुष उम्मीदवार';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'मेरा $relation';
  }

  @override
  String get guardian_details_involvement => 'संरक्षक की भागीदारी';

  @override
  String get guardian_details_involvement_subtitle =>
      'आप बातचीत में कितना शामिल होना चाहते हैं?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'चैट देखें, मिलान स्वीकृत करें और अपनी $relation की ओर से संदेश भेजें।';
  }

  @override
  String get guardian_details_mode_active_title => 'सक्रिय अभिभावक';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'सभी चैट वास्तविक समय में देखें, लेकिन केवल आपका $relation ही संदेश भेज सकता है।';
  }

  @override
  String get guardian_details_mode_passive_title => 'केवल निरीक्षण करें';

  @override
  String get guardian_details_name_hint => 'पूरा नाम';

  @override
  String get guardian_details_name_subtitle =>
      'संरक्षक के रूप में आपका नाम. यह मैचों को दिखाया जाता है.';

  @override
  String guardian_details_notice(Object relation) {
    return 'आप अपने $relation के लिए एक प्रोफ़ाइल बना रहे हैं। अगली स्क्रीन पर सभी प्रोफ़ाइल विवरण उनका वर्णन करेंगे, आपका नहीं।';
  }

  @override
  String get guardian_details_search_hint => 'खोज';

  @override
  String get guardian_details_select_code => 'देश कोड चुनें';

  @override
  String get guardian_details_subtitle =>
      'अभिभावक के रूप में अपने बारे में बताएं।';

  @override
  String get guardian_details_title => 'आपके अभिभावक का विवरण';

  @override
  String get guardian_details_your_name => 'आपका नाम';

  @override
  String get interest_cat_creative => 'रचनात्मक';

  @override
  String get interest_cat_faith => 'आस्था';

  @override
  String get interest_cat_learning => 'सीखना';

  @override
  String get interest_cat_lifestyle => 'जीवन शैली';

  @override
  String get interest_cat_social => 'सामाजिक';

  @override
  String get interest_cat_sports => 'खेल';

  @override
  String get interest_tag_art => 'कला';

  @override
  String get interest_tag_calligraphy => 'सुलेख';

  @override
  String get interest_tag_community_work => 'समुदाय विशेष के लिए कार्य करना';

  @override
  String get interest_tag_cooking => 'खाना बनाना';

  @override
  String get interest_tag_crafts => 'शिल्प';

  @override
  String get interest_tag_cricket => 'क्रिकेट';

  @override
  String get interest_tag_cycling => 'साइकिल चलाना';

  @override
  String get interest_tag_dawah => 'दावा';

  @override
  String get interest_tag_family_gatherings => 'परिवार के समारोहों';

  @override
  String get interest_tag_fitness => 'स्वास्थ्य';

  @override
  String get interest_tag_football => 'फ़ुटबॉल';

  @override
  String get interest_tag_gardening => 'बागवानी';

  @override
  String get interest_tag_graphic_design => 'ग्राफ़िक डिज़ाइन';

  @override
  String get interest_tag_hiking => 'लंबी पैदल यात्रा';

  @override
  String get interest_tag_history => 'इतिहास';

  @override
  String get interest_tag_islamic_lectures => 'इस्लामी व्याख्यान';

  @override
  String get interest_tag_languages => 'बोली';

  @override
  String get interest_tag_martial_arts => 'मार्शल आर्ट';

  @override
  String get interest_tag_mentoring => 'सलाह';

  @override
  String get interest_tag_photography => 'फोटोग्राफी';

  @override
  String get interest_tag_poetry => 'कविता';

  @override
  String get interest_tag_quran_recitation => 'कुरान पाठ';

  @override
  String get interest_tag_reading => 'पढ़ना';

  @override
  String get interest_tag_science => 'विज्ञान';

  @override
  String get interest_tag_swimming => 'तैरना';

  @override
  String get interest_tag_tahajjud => 'Tahajjud';

  @override
  String get interest_tag_teaching => 'शिक्षण';

  @override
  String get interest_tag_technology => 'तकनीकी';

  @override
  String get interest_tag_travel => 'यात्रा';

  @override
  String get interest_tag_umrah_hajj => 'उमरा/हज';

  @override
  String get interest_tag_voluntary_fasting => 'स्वैच्छिक उपवास';

  @override
  String get interest_tag_volunteering => 'स्वयं सेवा';

  @override
  String get interest_tag_writing => 'लिखना';

  @override
  String get interests_button_accept => 'स्वीकार करना';

  @override
  String get interests_button_decline => 'गिरावट';

  @override
  String get interests_tab_received => 'प्राप्त';

  @override
  String get interests_tab_sent => 'भेजा';

  @override
  String get interests_title => 'रुचियाँ';

  @override
  String get lang_albanian => 'अल्बानियन';

  @override
  String get lang_amazigh => 'अमेज़घ (बर्बर)';

  @override
  String get lang_amharic => 'अम्हारिक्';

  @override
  String get lang_arabic => 'अरबी';

  @override
  String get lang_assamese => 'असमिया';

  @override
  String get lang_balochi => 'बलूची';

  @override
  String get lang_bengali => 'बंगाली';

  @override
  String get lang_bosnian => 'बोस्नियाई';

  @override
  String get lang_burmese => 'बर्मी';

  @override
  String get lang_chechen => 'चेचन';

  @override
  String get lang_chinese => 'चीनी (मंदारिन)';

  @override
  String get lang_dari => 'दारी';

  @override
  String get lang_dutch => 'डच';

  @override
  String get lang_english => 'अंग्रेज़ी';

  @override
  String get lang_french => 'फ़्रेंच';

  @override
  String get lang_fulani => 'फुलानी';

  @override
  String get lang_german => 'जर्मन';

  @override
  String get lang_gujarati => 'गुजराती';

  @override
  String get lang_hausa => 'होउसा';

  @override
  String get lang_hindi => 'हिंदी';

  @override
  String get lang_igbo => 'ईग्बो';

  @override
  String get lang_indonesian => 'इन्डोनेशियाई';

  @override
  String get lang_italian => 'इतालवी';

  @override
  String get lang_japanese => 'जापानी';

  @override
  String get lang_javanese => 'जावानीस';

  @override
  String get lang_kannada => 'कन्नडा';

  @override
  String get lang_kazakh => 'कजाख';

  @override
  String get lang_korean => 'कोरियाई';

  @override
  String get lang_kurdish => 'कुर्द';

  @override
  String get lang_kyrgyz => 'किरगिज़';

  @override
  String get lang_malay => 'मलायी';

  @override
  String get lang_malayalam => 'मलयालम';

  @override
  String get lang_mandinka => 'मंडिंका';

  @override
  String get lang_marathi => 'मराठी';

  @override
  String get lang_norwegian => 'नार्वेजियन';

  @override
  String get lang_odia => 'उड़िया';

  @override
  String get lang_other => 'अन्य';

  @override
  String get lang_pashto => 'पश्तो';

  @override
  String get lang_persian => 'फ़ारसी';

  @override
  String get lang_portuguese => 'पुर्तगाली';

  @override
  String get lang_punjabi => 'पंजाबी';

  @override
  String get lang_rohingya => 'रोहिंग्या';

  @override
  String get lang_russian => 'रूसी';

  @override
  String get lang_saraiki => 'सरैकी';

  @override
  String get lang_sindhi => 'सिंधी';

  @override
  String get lang_somali => 'सोमाली';

  @override
  String get lang_spanish => 'स्पैनिश';

  @override
  String get lang_sundanese => 'सुंडानी';

  @override
  String get lang_swahili => 'स्वाहिली';

  @override
  String get lang_swedish => 'स्वीडिश';

  @override
  String get lang_tagalog => 'तागालोग';

  @override
  String get lang_tajik => 'ताजिक';

  @override
  String get lang_tamil => 'तामिल';

  @override
  String get lang_tatar => 'टाटर';

  @override
  String get lang_telugu => 'तेलुगू';

  @override
  String get lang_thai => 'थाई';

  @override
  String get lang_tigrinya => 'तिग्रिन्या';

  @override
  String get lang_turkish => 'तुर्की';

  @override
  String get lang_urdu => 'उर्दू';

  @override
  String get lang_uzbek => 'उज़बेक';

  @override
  String get lang_wolof => 'वोलोफ';

  @override
  String get lang_yoruba => 'योरूबा';

  @override
  String get legal_button_continue => 'जारी रखना';

  @override
  String get legal_checkbox_age =>
      'मैं पुष्टि करता हूँ कि मेरी आयु 18 वर्ष या उससे अधिक है';

  @override
  String get legal_checkbox_terms =>
      'मैं सेवा की शर्तों और गोपनीयता नीति से सहमत हूं';

  @override
  String get legal_subtitle => 'कृपया पढ़ें और जारी रखने के लिए सहमत हों।';

  @override
  String get legal_summary_1 =>
      'आपका डेटा एन्क्रिप्ट किया गया है और कभी भी तीसरे पक्ष को नहीं बेचा जाता है।';

  @override
  String get legal_summary_2 =>
      'हर फ़ोटो की सुरक्षा जाँच होती है और हमारी टीम नई फ़ोटो की समीक्षा करती है।';

  @override
  String get legal_summary_3 =>
      'उत्पीड़न, फर्जी प्रोफाइल और घोटालों के परिणामस्वरूप स्थायी प्रतिबंध लग जाता है।';

  @override
  String get legal_summary_4 =>
      'यह मंच केवल विवाह संबंधी उद्देश्यों के लिए है। गरिमा मानक है.';

  @override
  String get legal_summary_5 =>
      'आप किसी भी समय अपना खाता और सारा डेटा हटा सकते हैं।';

  @override
  String get legal_title => 'शुरू करने से पहले';

  @override
  String get notifications_empty_subtitle => 'अभी कोई नई सूचना नहीं.';

  @override
  String get notifications_empty_title => 'आप सब फंस गए हैं';

  @override
  String get notifications_markAllRead => 'सभी को पढ़ा दिखाएं';

  @override
  String get notifications_title => 'सूचनाएं';

  @override
  String get onboarding_about_title => 'अपने बारे में';

  @override
  String get onboarding_background_title => 'शिक्षा एवं कैरियर';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'आप एक अभिभावक के तौर पर इसे भर रहे हैं. ये विवरण आपके $relation के बारे में हैं.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'अन्य लोग अपनी प्रोफ़ाइल पर यही देखेंगे.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'अन्य लोग आपकी प्रोफ़ाइल पर यही देखेंगे.';

  @override
  String get onboarding_basicIdentity_title => 'अपने बारे में हमें बताएं';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'हमें अपने $relation के बारे में बताएं';
  }

  @override
  String get onboarding_debt_manageable => 'प्रबंधनीय ऋण';

  @override
  String get onboarding_debt_none => 'कोई कर्ज नहीं';

  @override
  String get onboarding_debt_significant => 'महत्वपूर्ण ऋण';

  @override
  String get onboarding_diet_eatsAnything => 'कुछ भी हलाल खाता है';

  @override
  String get onboarding_diet_halalOnly => 'केवल हलाल';

  @override
  String get onboarding_diet_vegan => 'शाकाहारी';

  @override
  String get onboarding_diet_vegetarian => 'शाकाहारी';

  @override
  String get onboarding_diet_zabihaStrict => 'सख्त ज़बीहा';

  @override
  String get onboarding_error_bioContactInfo =>
      'कृपया अपने बायो से संपर्क जानकारी हटा दें। आपकी सुरक्षा के लिए बाहरी संपर्क विवरण की अनुमति नहीं है।';

  @override
  String get onboarding_error_multipleFaces =>
      'समूह फ़ोटो आपकी प्राथमिक फ़ोटो नहीं हो सकती.';

  @override
  String get onboarding_error_noFace =>
      'कृपया ऐसी फोटो का उपयोग करें जिसमें आपका चेहरा स्पष्ट रूप से दिखाई दे।';

  @override
  String get onboarding_error_under18 =>
      'Silarah उन 18 वर्ष और उससे अधिक उम्र वालों के लिए है। हमने अपने समुदाय में हर किसी की सुरक्षा के लिए यह आवश्यकता बनाई है।';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Silarah का उपयोग करने के लिए आपकी $relation की आयु 18 वर्ष या उससे अधिक होनी चाहिए।';
  }

  @override
  String get onboarding_error_under18_self =>
      'Silarah का उपयोग करने के लिए आपकी आयु 18 वर्ष या उससे अधिक होनी चाहिए। हम तब आपका स्वागत करने के लिए उत्सुक हैं।';

  @override
  String get onboarding_habit_frequently => 'बार-बार';

  @override
  String get onboarding_habit_never => 'कभी नहीं';

  @override
  String get onboarding_habit_occasionally => 'कभी-कभी';

  @override
  String get onboarding_habit_preferNotToSay => 'नहीं कहना पसंद करते हैं';

  @override
  String get onboarding_hijab_always => 'हमेशा';

  @override
  String get onboarding_hijab_no => 'नहीं';

  @override
  String get onboarding_hijab_sometimes => 'कभी-कभी';

  @override
  String get onboarding_hint_bio => 'अपना वर्णन ईमानदारी और गरिमा के साथ करें।';

  @override
  String get onboarding_hint_profession =>
      'जैसे सॉफ्टवेयर इंजीनियर, शिक्षक, डॉक्टर';

  @override
  String get onboarding_hint_searchCity => 'अपना शहर खोजें...';

  @override
  String get onboarding_hint_selectCommunity => 'समुदाय चुनें (वैकल्पिक)';

  @override
  String get onboarding_hint_selectCountry => 'देश चुनें';

  @override
  String get onboarding_hint_selectDateOfBirth => 'जन्मतिथि चुनें';

  @override
  String get onboarding_hint_selectLanguage => 'भाषा चुने';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'यह आपको किसी संगत व्यक्ति से मिलाने में मदद करता है।';

  @override
  String get onboarding_islamicIdentity_title => 'आपकी इस्लामी पहचान';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'शहर';

  @override
  String get onboarding_label_city_guardian => 'उनका शहर';

  @override
  String get onboarding_label_city_self => 'आपका सिटि';

  @override
  String get onboarding_label_community => 'आपका समुदाय/बिरादारी';

  @override
  String get onboarding_label_community_parent => 'उनका समुदाय/बिरादरी';

  @override
  String get onboarding_label_complexion => 'रंग (वैकल्पिक)';

  @override
  String get onboarding_label_country_guardian => 'उनके देश';

  @override
  String get onboarding_label_country_self => 'आपका देश';

  @override
  String get onboarding_label_cultural => 'सांस्कृतिक मुस्लिम';

  @override
  String get onboarding_label_dateOfBirth => 'जन्मतिथि';

  @override
  String get onboarding_label_debtStatus => 'ऋण स्थिति';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'आपके वर्तमान वित्तीय दायित्व.';

  @override
  String get onboarding_label_deenLevel => 'दीन स्तर';

  @override
  String get onboarding_label_diet => 'आहार';

  @override
  String get onboarding_label_educationLevel => 'शिक्षा का स्तर';

  @override
  String get onboarding_label_female => 'महिला';

  @override
  String get onboarding_label_firstName => 'पहला नाम';

  @override
  String get onboarding_label_firstName_guardian => 'उम्मीदवार का पहला नाम';

  @override
  String get onboarding_label_firstName_self => 'पहला नाम';

  @override
  String get onboarding_label_gender => 'लिंग';

  @override
  String get onboarding_label_gender_guardian => 'उम्मीदवार का लिंग';

  @override
  String get onboarding_label_gender_self => 'लिंग';

  @override
  String get onboarding_label_height_guardian => 'उनकी ऊंचाई';

  @override
  String get onboarding_label_height_self => 'आपकी ऊंचाई';

  @override
  String get onboarding_label_hookah => 'हुक्का/शीशा';

  @override
  String get onboarding_label_housing => 'आवास';

  @override
  String get onboarding_label_housingQuestion =>
      'क्या आप अलग रहने की जगह उपलब्ध करा सकते हैं?';

  @override
  String get onboarding_label_lastName => 'उपनाम';

  @override
  String get onboarding_label_leadership => 'धार्मिक नेतृत्व';

  @override
  String get onboarding_label_leadershipQuestion =>
      'क्या आप सामूहिक प्रार्थना का नेतृत्व कर सकते हैं?';

  @override
  String get onboarding_label_lifestyleDiet => 'जीवनशैली और आहार';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'ये कई परिवारों के लिए डीलब्रेकर क्षेत्र हैं। कृपया ईमानदारी से उत्तर दें।';

  @override
  String get onboarding_label_livingExpectation =>
      'विवाहोपरान्त जीवन-यापन की अपेक्षाएँ';

  @override
  String get onboarding_label_mahrBudget => 'महर बजट';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'आप किस महर रेंज की पेशकश करने के लिए तैयार हैं?';

  @override
  String get onboarding_label_mahrExpectation => 'महर उम्मीद';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'महर से आपकी क्या अपेक्षा है?';

  @override
  String get onboarding_label_maintenance => 'वित्तीय रखरखाव';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'क्या आप जीवनसाथी को आर्थिक रूप से सहायता प्रदान करने में सक्षम हैं?';

  @override
  String get onboarding_label_male => 'पुरुष';

  @override
  String get onboarding_label_marriageTimeline => 'विवाह समयरेखा';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'आप कब शादी करना चाह रहे हैं?';

  @override
  String get onboarding_label_moderate => 'मध्यम';

  @override
  String get onboarding_label_motherTongue => 'मातृभाषा';

  @override
  String get onboarding_label_niqab => 'नकाब';

  @override
  String get onboarding_label_practicing => 'अभ्यास';

  @override
  String get onboarding_label_praysFiveDaily =>
      'मैं प्रतिदिन पांच बार प्रार्थना करता हूं';

  @override
  String get onboarding_label_preferNotToSay => 'नहीं कहना पसंद करते हैं';

  @override
  String get onboarding_label_preferredLiving =>
      'रहने की व्यवस्था को प्राथमिकता';

  @override
  String get onboarding_label_profession => 'पेशा';

  @override
  String get onboarding_label_providerReadiness => 'प्रदाता की तत्परता';

  @override
  String get onboarding_label_quranMemorization => 'कुरान कंठस्थ';

  @override
  String get onboarding_label_religiousEducation => 'धार्मिक शिक्षा';

  @override
  String get onboarding_label_residencyStatus => 'निवास स्थिति (वैकल्पिक)';

  @override
  String get onboarding_label_revert =>
      'पूर्ववत करें/रूपांतरित करें (वैकल्पिक)';

  @override
  String get onboarding_label_revertQuestion =>
      'क्या आप इस्लाम में वापस आये हैं?';

  @override
  String get onboarding_label_sect => 'संप्रदाय';

  @override
  String get onboarding_label_shia => 'शिया';

  @override
  String get onboarding_label_smoking => 'धूम्रपान';

  @override
  String get onboarding_label_specialNeeds => 'विशेष आवश्यकताएँ (वैकल्पिक)';

  @override
  String onboarding_label_step(int current, int total) {
    return '$total का चरण $current';
  }

  @override
  String get onboarding_label_subSect => 'विचारधारा का विद्यालय (वैकल्पिक)';

  @override
  String get onboarding_label_substanceUse => 'पदार्थ का उपयोग';

  @override
  String get onboarding_label_sunni => 'सुन्नी';

  @override
  String get onboarding_label_vaping => 'वेपिंग/ई-सिगरेट';

  @override
  String get onboarding_label_workAfterMarriage => 'शादी के बाद काम';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'क्या आप शादी के बाद काम करना चाहेंगी?';

  @override
  String get onboarding_leadership_leads => 'प्रार्थना का नेतृत्व करता है';

  @override
  String get onboarding_leadership_learning => 'सीखना';

  @override
  String get onboarding_leadership_notYet => 'अभी तक नहीं';

  @override
  String get onboarding_living_openToDiscussion => 'चर्चा के लिए खुला';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'मैं इस बात पर चर्चा करने में लचीला और खुश हूं कि दोनों के लिए क्या काम करता है।';

  @override
  String get onboarding_living_separate => 'अलग घर';

  @override
  String get onboarding_living_separateSub =>
      'मैं पसंद करता हूं कि हमारा अपना स्वतंत्र घर हो।';

  @override
  String get onboarding_living_withInlaws => 'ससुराल वालों के साथ';

  @override
  String get onboarding_living_withInlawsSub =>
      'मैं अपने जीवनसाथी या अपने परिवार के साथ रहने की उम्मीद करता हूं।';

  @override
  String get onboarding_location_confirmed => 'स्थान की पुष्टि';

  @override
  String get onboarding_mahr_generous => 'उदार';

  @override
  String get onboarding_mahr_moderate => 'मध्यम';

  @override
  String get onboarding_mahr_modest => 'मामूली';

  @override
  String get onboarding_mahr_noPreference => 'कोई वरीयता नहीं';

  @override
  String get onboarding_mahr_toDiscuss => 'गुफ़्तगू करना';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'ये विवरण आपकी सार्वजनिक प्रोफ़ाइल पर नहीं दिखाए जाते हैं. स्वीकृति चरण के दौरान उन्हें निजी तौर पर साझा किया जाता है।';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'आपकी यात्रा और तैयारी को समझने में हमारी सहायता करें।';

  @override
  String get onboarding_marriageDeen_title => 'विवाह और दीन';

  @override
  String get onboarding_niqab_dontWear => 'मैं नकाब नहीं पहनता';

  @override
  String get onboarding_niqab_open => 'पहनने के लिए खुला';

  @override
  String get onboarding_niqab_wear => 'मैं नकाब पहनता हूं';

  @override
  String get onboarding_photo_subtitle =>
      'कम से कम एक फोटो आवश्यक है. आपकी प्राथमिक तस्वीर में आपका चेहरा स्पष्ट रूप से शामिल होना चाहिए।';

  @override
  String get onboarding_photo_title => 'अपनी तस्वीरें जोड़ें';

  @override
  String get onboarding_photo_verifySelfie => 'सत्यापन सेल्फी';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'यह सत्यापित करने के लिए कि आप असली हैं, एक लाइव फ़ोटो लें';

  @override
  String get onboarding_preferredLiving_noPreference => 'कोई वरीयता नहीं';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'मैं इसे अपने लिए बना रहा हूं...';

  @override
  String get onboarding_profileForWhom_guardian => 'मेरा बेटा या बेटी';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'मैं यह प्रोफ़ाइल किसी के लिए बना रहा हूं';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'अभिभावक';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'मैं माता-पिता या अभिभावक हूं';

  @override
  String get onboarding_profileForWhom_myself => 'खुद';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'मैं जीवनसाथी की तलाश कर रहा हूं';

  @override
  String get onboarding_profileForWhom_relation_brother => 'भाई';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'बेटी';

  @override
  String get onboarding_profileForWhom_relation_sister => 'बहन';

  @override
  String get onboarding_profileForWhom_relation_son => 'बेटा';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'जारी रखने के लिए एक का चयन करें';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'जारी रखने के लिए एक रिश्ता चुनें';

  @override
  String get onboarding_profileForWhom_sibling => 'मेरा भाई या बहन';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'मैं अपने भाई-बहन को रिश्ता ढूंढने में मदद कर रहा हूं';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'आप इसे बाद में सेटिंग से अपडेट कर सकते हैं.';

  @override
  String get onboarding_profileForWhom_title => 'यह प्रोफ़ाइल किसके लिए है?';

  @override
  String get onboarding_profileForWhom_ward => 'मेरा वार्ड';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'मैं इस प्रोफ़ाइल का प्रबंधन करने वाला एक अभिभावक हूं';

  @override
  String get onboarding_providerQuote =>
      '\"आपमें से जो सर्वश्रेष्ठ हैं, वे आपकी पत्नियों के लिए सर्वश्रेष्ठ हैं।\" - पैगंबर मुहम्मद ﷺ\n\nअपनी तैयारी के प्रति ईमानदार रहने से एक मजबूत नींव बनाने में मदद मिलती है।';

  @override
  String get onboarding_quran_hafiz => 'हाफ़िज़/हाफ़ीज़ा';

  @override
  String get onboarding_quran_none => 'कोई नहीं';

  @override
  String get onboarding_quran_partial => 'आंशिक हिफ़्ज़';

  @override
  String get onboarding_quran_some => 'कुछ सूरह';

  @override
  String get onboarding_religiousEdu_alim => 'आलिम कोर्स';

  @override
  String get onboarding_religiousEdu_islamicUni => 'इस्लामी विश्वविद्यालय';

  @override
  String get onboarding_religiousEdu_madrasa => 'मदरसे';

  @override
  String get onboarding_religiousEdu_selfTaught => 'स्व सिखाया';

  @override
  String get onboarding_timeline_1year => 'एक साल के अंदर';

  @override
  String get onboarding_timeline_2years => '2+ वर्ष';

  @override
  String get onboarding_timeline_6months => '6 महीने के अंदर';

  @override
  String get onboarding_timeline_asap => 'जितनी जल्दी हो सके';

  @override
  String get onboarding_timeline_notSure => 'अभी तक निश्चित नहीं हूं';

  @override
  String get onboarding_tooltip_cultural =>
      'अपनी पहचान मुस्लिम के रूप में करता है, अवसरों का जश्न मनाता है, नियमित रूप से प्रार्थना नहीं करता है';

  @override
  String get onboarding_tooltip_moderate =>
      'इस्लामी उसूलों को मानते हैं और नमाज़ पढ़ते हैं, हालाँकि हमेशा दिन में पाँच बार नहीं';

  @override
  String get onboarding_tooltip_practicing =>
      'सभी पांच स्तंभों का पालन करता है, नियमित रूप से प्रार्थना करता है, हलाल जीवनशैली अपनाता है';

  @override
  String get onboarding_work_no => 'नहीं, मैं ऐसा नहीं करना पसंद करूंगा';

  @override
  String get onboarding_work_yes => 'हाँ, मैं काम करने की योजना बना रहा हूँ';

  @override
  String get photo_add_main_required => 'मुख्य फ़ोटो जोड़ें\n(आवश्यक)';

  @override
  String get photo_add_photo => 'तस्वीर जोड़ो';

  @override
  String get photo_banner_text =>
      'स्पष्ट सामग्री वाली तस्वीरों की अनुमति नहीं है';

  @override
  String get photo_error_no_face_detected =>
      'कोई चेहरा दिखाई नहीं दे रहा है - कृपया स्पष्ट चेहरे की तस्वीर के साथ पुनः प्रयास करें';

  @override
  String photo_error_pick_failed(Object error) {
    return 'फ़ोटो नहीं चुना जा सका: $error';
  }

  @override
  String get photo_face_detected => 'चेहरे का पता चला ✓';

  @override
  String get photo_label_photo2 => 'फोटो 2';

  @override
  String get photo_label_photo3 => 'फोटो 3';

  @override
  String get photo_label_primary => 'प्राथमिक फ़ोटो';

  @override
  String get photo_label_selfie => 'फ़ोटो 4';

  @override
  String get photo_no_face => 'कोई चेहरा नजर नहीं आ रहा';

  @override
  String get photo_privacy_everyone => 'हर किसी के लिए दृश्यमान';

  @override
  String get photo_privacy_everyone_sub =>
      'सभी सदस्य आपकी तस्वीरें देख सकते हैं.';

  @override
  String get photo_privacy_label => 'फोटो गोपनीयता';

  @override
  String get photo_privacy_mutual => 'आपसी हित के बाद दिखाई देता है';

  @override
  String get photo_privacy_mutual_sub =>
      'तस्वीरें तभी सामने आती हैं जब दोनों पक्ष रुचि व्यक्त करते हैं।';

  @override
  String get photo_privacy_request => 'देखने का अनुरोध';

  @override
  String get photo_privacy_request_sub =>
      'जब तक आप किसी अनुरोध को स्वीकार नहीं करते तब तक तस्वीरें धुंधली रहती हैं।';

  @override
  String get photo_sheet_camera => 'कैमरा';

  @override
  String get photo_sheet_gallery => 'गैलरी';

  @override
  String get photo_sheet_title => 'फोटो स्रोत का चयन करें';

  @override
  String get photo_slots_help => 'अपलोड करने के लिए स्लॉट टैप करें';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'अपने $relation की फ़ोटो जोड़ें. कम से कम एक तो आवश्यक है.';
  }

  @override
  String get photo_subtitle_self => 'कम से कम एक फोटो आवश्यक है. अधिकतम चार.';

  @override
  String get photo_title_guardian => 'उनकी तस्वीरें जोड़ें';

  @override
  String get photo_title_self => 'अपनी तस्वीरें जोड़ें';

  @override
  String get preferences_deen_any => 'कोई';

  @override
  String get preferences_deen_cultural => 'सांस्कृतिक मुस्लिम';

  @override
  String get preferences_deen_moderate => 'मध्यम';

  @override
  String get preferences_deen_practicing => 'अभ्यास';

  @override
  String get preferences_edu_any => 'कोई';

  @override
  String get preferences_edu_bachelors => 'स्नातक +';

  @override
  String get preferences_edu_diploma => 'डिप्लोमा +';

  @override
  String get preferences_edu_masters => 'मास्टर +';

  @override
  String get preferences_edu_phd => 'केवल पीएचडी';

  @override
  String get preferences_edu_secondary => 'माध्यमिक +';

  @override
  String get preferences_label_age => 'आयु सीमा';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max वर्ष';
  }

  @override
  String get preferences_label_deen => 'दीन स्तर की प्राथमिकता';

  @override
  String get preferences_label_edu => 'न्यूनतम शिक्षा';

  @override
  String get preferences_label_living => 'रहने की व्यवस्था की प्राथमिकता';

  @override
  String get preferences_label_location => 'जगह';

  @override
  String get preferences_label_openness => 'खुलापन';

  @override
  String get preferences_label_sect => 'संप्रदाय वरीयता';

  @override
  String get preferences_living_discussion => 'चर्चा के लिए खुला';

  @override
  String get preferences_living_family => 'परिवार के साथ';

  @override
  String get preferences_living_no_pref => 'कोई वरीयता नहीं';

  @override
  String get preferences_living_separate => 'अलग घर';

  @override
  String get preferences_location_abroad => 'विदेश के लिए खुला';

  @override
  String get preferences_location_diaspora => 'डायस्पोरा मोड';

  @override
  String get preferences_location_same_city => 'एक ही शहर';

  @override
  String get preferences_location_same_country => 'वही देश';

  @override
  String get preferences_open_children =>
      'बच्चों वाले किसी व्यक्ति के लिए खुला';

  @override
  String get preferences_open_divorced =>
      'पहले से तलाकशुदा किसी व्यक्ति के लिए खुला है';

  @override
  String get preferences_open_widowed =>
      'पहले से विधवा किसी व्यक्ति के लिए खुला';

  @override
  String get preferences_sect_any => 'कोई';

  @override
  String get preferences_sect_same => 'मेरे जैसा ही';

  @override
  String get preferences_sect_shia => 'शिया';

  @override
  String get preferences_sect_sunni => 'सुन्नी';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'अपने $relation के आदर्श मिलान के लिए प्राथमिकताएँ निर्धारित करें।';
  }

  @override
  String get preferences_subtitle_self =>
      'ये प्राथमिकताएँ हैं, कठोर फ़िल्टर नहीं।';

  @override
  String get preferences_title => 'साझेदार प्राथमिकताएँ';

  @override
  String get preview_age_label => 'आयु';

  @override
  String get preview_background => 'पृष्ठभूमि';

  @override
  String get preview_basic_info => 'बुनियादी जानकारी';

  @override
  String get preview_city_label => 'शहर';

  @override
  String get preview_community_label => 'समुदाय';

  @override
  String get preview_cowife_label => 'सहपत्नी स्वीकृति';

  @override
  String get preview_deen_label => 'दीन स्तर';

  @override
  String get preview_diet_label => 'आहार';

  @override
  String get preview_edit => 'संपादन करना';

  @override
  String get preview_education_label => 'शिक्षा';

  @override
  String get preview_faith => 'आस्था';

  @override
  String get preview_family => 'परिवार';

  @override
  String get preview_family_type_label => 'पारिवारिक प्रकार';

  @override
  String get preview_gender_label => 'लिंग';

  @override
  String get preview_hijab_label => 'हिजाब';

  @override
  String get preview_hookah_label => 'हुक्के';

  @override
  String get preview_leadership_label => 'नेतृत्व';

  @override
  String get preview_marital_label => 'वैवाहिक';

  @override
  String get preview_marriage_timeline_label => 'विवाह समयरेखा';

  @override
  String get preview_mother_tongue_label => 'मातृभाषा';

  @override
  String get preview_name_label => 'नाम';

  @override
  String get preview_notice_guardian =>
      'ठीक इसी प्रकार अन्य लोग उनकी प्रोफ़ाइल देखेंगे।';

  @override
  String get preview_notice_self =>
      'यह ठीक इसी प्रकार है कि अन्य लोग आपकी प्रोफ़ाइल देखेंगे.';

  @override
  String get preview_polygamy_label => 'बहुविवाह';

  @override
  String get preview_post_marriage_living_label => 'विवाहोपरान्त जीवन-यापन';

  @override
  String get preview_prays_label => '5x प्रार्थना करता है';

  @override
  String get preview_profession_label => 'पेशा';

  @override
  String get preview_quran_label => 'कुरान';

  @override
  String get preview_religious_edu_label => 'धार्मिक शिक्षा';

  @override
  String get preview_residency_label => 'निवास';

  @override
  String get preview_revert_label => 'फिर लौट आना';

  @override
  String get preview_sect_label => 'संप्रदाय';

  @override
  String get preview_siblings_label => 'भाई-बहन';

  @override
  String get preview_smoking_label => 'धूम्रपान';

  @override
  String get preview_special_needs_label => 'विशेष जरूरतों';

  @override
  String get preview_submit_btn => 'प्रोफ़ाइल सबमिट करें';

  @override
  String get preview_title => 'पूर्व दर्शन';

  @override
  String get preview_vaping_label => 'वेपिंग';

  @override
  String get preview_willing_relocate_label => 'यहां रीलोकेट होना चाहते हैं';

  @override
  String profile_label_completeness(int percent) {
    return 'प्रोफ़ाइल $percent% पूर्ण';
  }

  @override
  String get profile_nudge_completeness =>
      '80%+ पूर्णता वाली प्रोफ़ाइलों को 3× अधिक रुचियाँ प्राप्त होती हैं।';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · अल्लाह के लिए';

  @override
  String get settings_button_deleteAccount => 'खाता हटा दो';

  @override
  String get settings_guardian_mirror => 'दर्पण संदेश';

  @override
  String get settings_guardian_mirror_sub =>
      'सभी संदेशों की प्रतियां अभिभावक को भेजें';

  @override
  String get settings_guardian_name_hint => 'संरक्षक का नाम';

  @override
  String get settings_guardian_relationship => 'संबंध';

  @override
  String get settings_guardian_reply => 'अभिभावक को उत्तर देने की अनुमति दें';

  @override
  String get settings_guardian_reply_sub =>
      'अभिभावक बातचीत में भाग ले सकते हैं';

  @override
  String get settings_guardian_save => 'अभिभावक सेटिंग सहेजें';

  @override
  String get settings_guardian_saved => 'सहेजा गया';

  @override
  String get settings_guardian_sub => 'मैसेजिंग के लिए वाली ओवरसाइट सक्षम करें';

  @override
  String get settings_guardian_title => 'संरक्षक मोड';

  @override
  String get settings_label_blocked => 'अवरुद्ध प्रोफ़ाइलें';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count अवरुद्ध';
  }

  @override
  String get settings_label_blocked_none => 'कोई नहीं';

  @override
  String get settings_label_deleteGrace =>
      'आपकी प्रोफ़ाइल तुरंत छिपा दी जाएगी. आपका डेटा 30 दिनों के बाद स्थायी रूप से हटा दिया जाएगा।';

  @override
  String get settings_label_editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get settings_label_language => 'भाषा';

  @override
  String get settings_label_photoPrivacy => 'फोटो गोपनीयता';

  @override
  String get settings_label_rate => 'Silarah को रेट करें';

  @override
  String get settings_label_rate_snackbar =>
      'ऐप स्टोर पर Silarah लॉन्च होते ही रेटिंग उपलब्ध हो जाएगी।';

  @override
  String get settings_label_reports => 'रिपोर्ट इतिहास';

  @override
  String settings_label_reports_count(Object count) {
    return '$count रिपोर्ट';
  }

  @override
  String get settings_label_reports_none => 'कोई रिपोर्ट प्रस्तुत नहीं की गई';

  @override
  String get settings_label_selfieChallenge => 'सेल्फी चैलेंज';

  @override
  String get settings_label_verifyProfile => 'प्रोफ़ाइल सत्यापित करें';

  @override
  String get settings_label_version => 'संस्करण';

  @override
  String get settings_notify_activityNudges => 'गतिविधि संकेत';

  @override
  String get settings_notify_activityNudgesSub =>
      'प्रोफ़ाइल पूरी करने के सुझाव और 7 दिन निष्क्रिय रहने पर याद दिलाना';

  @override
  String get settings_notify_boostReminders => 'अनुस्मारक बूस्ट करें';

  @override
  String get settings_notify_boostRemindersSub =>
      'याद दिलाएं कि आपका साप्ताहिक बूस्ट कब तैयार हो जाएगा';

  @override
  String get settings_notify_interestAccepted => 'रुचि स्वीकार की गई';

  @override
  String get settings_notify_interestExpiring =>
      'रुचि जल्द ही समाप्त हो रही है';

  @override
  String get settings_notify_newInterest => 'नई रुचियाँ';

  @override
  String get settings_notify_newMessage => 'नए संदेश';

  @override
  String get settings_notify_quietHours => 'शांत घंटे';

  @override
  String get settings_photo_privacy_accepted_interests => 'केवल स्वीकृत हित';

  @override
  String get settings_photo_privacy_after_acceptance => 'स्वीकृति के बाद';

  @override
  String get settings_photo_privacy_everyone => 'सब लोग';

  @override
  String get settings_photo_privacy_public => 'जनता';

  @override
  String get settings_photo_privacy_request_only => 'केवल अनुरोध करें';

  @override
  String get settings_photo_privacy_request_to_view => 'देखने का अनुरोध';

  @override
  String get settings_privacy_download_body =>
      'अपने खाते, प्रोफ़ाइल, फ़ोटो, रुचियों, मैच, संदेशों, सेटिंग्स, सहमतियों और सदस्यता इतिहास का निजी ZIP संग्रह अभी बनाएँ। इसे अपने डिवाइस की सुरक्षित शेयर शीट से सहेजें।';

  @override
  String get settings_privacy_download_btn => 'सुरक्षित संग्रह बनाएँ';

  @override
  String get settings_privacy_download_label => 'मेरा डेटा डाउनलोड करें';

  @override
  String get settings_privacy_download_sub =>
      'अपने Silarah डेटा की मशीन-पठनीय प्रति सहेजें';

  @override
  String get settings_privacy_export_body =>
      'आपका निजी संग्रह तैयार है। इसे सुरक्षित रूप से सहेजने के लिए शेयर शीट का उपयोग करें।';

  @override
  String get settings_privacy_export_btn_close => 'समझा';

  @override
  String get settings_privacy_export_subbody =>
      'इस संग्रह में निजी संदेश और संपर्क विवरण हो सकते हैं। इसे सुरक्षित रखें और केवल भरोसेमंद लोगों से साझा करें।';

  @override
  String get settings_privacy_export_title => 'संग्रह तैयार है';

  @override
  String get settings_privacy_online_label => 'ऑनलाइन स्थिति';

  @override
  String get settings_privacy_online_sub =>
      'दिखाएँ कि आप आखिरी बार कब सक्रिय थे';

  @override
  String get settings_privacy_pause_label => 'प्रोफ़ाइल विराम';

  @override
  String get settings_privacy_pause_sub => 'अपनी प्रोफ़ाइल को खोज से छिपाएँ';

  @override
  String get settings_privacy_pause_warning =>
      'आपकी प्रोफ़ाइल छिपी हुई है. तुम्हें कोई ढूंढ नहीं सकता.';

  @override
  String get settings_privacy_photo_label => 'फोटो दृश्यता';

  @override
  String get settings_privacy_photo_sub => 'आपकी तस्वीरें कौन देख सकता है';

  @override
  String get settings_privacy_visibility_all => 'सभी पंजीकृत उपयोगकर्ता';

  @override
  String get settings_privacy_visibility_label =>
      'मेरी प्रोफ़ाइल कौन देख सकता है?';

  @override
  String get settings_privacy_visibility_sub =>
      'नियंत्रित करता है कि आपकी प्रोफ़ाइल कौन ब्राउज़ कर सकता है';

  @override
  String get settings_privacy_visibility_subscribers => 'केवल सदस्य';

  @override
  String get settings_relation_brother => 'भाई';

  @override
  String get settings_relation_father => 'पिता';

  @override
  String get settings_relation_mother => 'माँ';

  @override
  String get settings_relation_other => 'अन्य';

  @override
  String get settings_relation_uncle => 'चाचा';

  @override
  String get settings_section_account => 'खाता';

  @override
  String get settings_section_app => 'अनुप्रयोग';

  @override
  String get settings_section_dangerZone => 'खाता बंद करें';

  @override
  String get settings_section_guardian => 'अभिभावक';

  @override
  String get settings_section_legal => 'कानूनी';

  @override
  String get settings_section_notifications => 'सूचनाएं';

  @override
  String get settings_section_privacy => 'गोपनीयता';

  @override
  String get settings_section_safety => 'सुरक्षा';

  @override
  String get settings_support_body =>
      'किसी भी प्रश्न, चिंता या प्रतिक्रिया के लिए:';

  @override
  String get settings_support_btn_close => 'बंद करना';

  @override
  String get settings_support_contact => 'समर्थन से संपर्क करें';

  @override
  String get settings_support_note =>
      'हमारा लक्ष्य 48 घंटों के भीतर जवाब देना है।';

  @override
  String get settings_title => 'सेटिंग्स';

  @override
  String get splash_button_createProfile => 'प्रोफ़ाइल बनाएं';

  @override
  String get splash_button_signIn => 'दाखिल करना';

  @override
  String get splash_intention_subtitle =>
      'निजी परिचय, सोच-समझकर अनुकूलता और परिवार का सम्मान करने वाला जुड़ाव।';

  @override
  String get splash_intention_title => 'विवाह, नेक इरादे के साथ।';

  @override
  String get splash_referral_button => 'कोड लागू करें';

  @override
  String get splash_referral_hint => 'जैसे SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'कृपया एक वैध 6-अक्षर वाला कोड दर्ज करें।';

  @override
  String get splash_referral_question => 'क्या आपके पास रेफरल कोड है?';

  @override
  String get splash_referral_saved =>
      'रेफरल कोड सहेजा गया! आपके साइन इन करने के बाद इसे लागू कर दिया जाएगा.';

  @override
  String get splash_referral_subtitle =>
      'यदि किसी मित्र ने आपको Silarah के लिए आमंत्रित किया है, तो नीचे उनका 6-वर्ण का रेफरल कोड दर्ज करें।';

  @override
  String get splash_referral_title => 'रेफरल कोड दर्ज करें';

  @override
  String subscription_button_monthly(String price) {
    return 'सदस्यता लें - $price/माह';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'सदस्यता लें — $price/3 महीने';
  }

  @override
  String get subscription_label_bestValue => 'सबसे अच्छा मूल्य';

  @override
  String get subscription_subtitle =>
      'महिला संदेश निःशुल्क. पुरुष जुड़ने के लिए सदस्यता लेते हैं.';

  @override
  String get subscription_title => 'Silarah को अनलॉक करें';

  @override
  String get startup_connectivity_preparing_title =>
      'आपका निजी स्थान तैयार हो रहा है';

  @override
  String get startup_connectivity_preparing_body =>
      'सिलाराह से सुरक्षित कनेक्शन स्थापित किया जा रहा है।';

  @override
  String get startup_connectivity_offline_title => 'कनेक्शन की प्रतीक्षा है';

  @override
  String get startup_connectivity_offline_body =>
      'आपकी प्रोफ़ाइल, रुचियाँ और बातचीत सुरक्षित हैं। जैसे ही आप फिर से ऑनलाइन होंगे, सिलाराह वहीं से शुरू करेगा जहाँ आपने छोड़ा था।';

  @override
  String get startup_connectivity_verifying => 'कनेक्शन जाँचा जा रहा है';

  @override
  String get startup_connectivity_waiting => 'नेटवर्क की प्रतीक्षा';

  @override
  String get startup_connectivity_still_waiting =>
      'अभी भी ऑफ़लाइन · फिर से कोशिश जारी';

  @override
  String get startup_connectivity_check => 'फिर से कोशिश करें';

  @override
  String get startup_connectivity_checking => 'जाँच हो रही है…';

  @override
  String get startup_connectivity_auto =>
      'नेटवर्क लौटते ही हम अपने-आप फिर से जुड़ जाएँगे।';

  @override
  String get startup_connectivity_tip =>
      'देखें कि Wi-Fi या मोबाइल डेटा चालू है।';

  @override
  String get startup_connectivity_protected => 'सुरक्षित कनेक्शन';

  @override
  String get settings_label_email => 'ईमेल';

  @override
  String get settings_notify_profileViews => 'प्रोफ़ाइल देखे जाने की सूचना';

  @override
  String get settings_notify_profileViewsSub =>
      'जब कोई आपकी प्रोफ़ाइल खोले तो निजी सूचना';

  @override
  String get settings_notify_profileLive => 'प्रोफ़ाइल लाइव हुई';

  @override
  String get settings_notify_profileLiveSub =>
      'आपकी प्रोफ़ाइल दिखाई देने पर पुष्टि';

  @override
  String get settings_appearance => 'दिखावट';

  @override
  String get settings_helpSupport => 'सहायता और समर्थन';

  @override
  String get settings_helpCenter => 'सहायता केंद्र';

  @override
  String get settings_grievanceOfficer => 'शिकायत अधिकारी';

  @override
  String get settings_grievanceResponse =>
      '24 घंटे में पावती; अधिकांश शिकायतों का समाधान 7 दिनों में';

  @override
  String get settings_grievanceIndiaNotice =>
      'भारत में शिकायत निवारण संशोधित सूचना प्रौद्योगिकी (मध्यस्थ दिशानिर्देश और डिजिटल मीडिया आचार संहिता) नियमों के अनुसार होता है। तत्काल अवैध या अंतरंग सामग्री की शिकायतों पर कम कानूनी समय-सीमा लागू होती है।';

  @override
  String get settings_managePhotoRequests => 'फ़ोटो अनुरोध प्रबंधित करें';

  @override
  String get settings_managePhotoRequestsSub =>
      'पहुँच मंज़ूर करें, अनुरोध अस्वीकार करें या साझा करना रद्द करें';

  @override
  String get settings_theme_chooseTitle => 'अपना माहौल चुनें';

  @override
  String get settings_theme_chooseSubtitle =>
      'यह केवल रंग फ़िल्टर नहीं, पूरी दृश्य पहचान है। हर सतह, फ़ील्ड और सिस्टम नियंत्रण साथ बदलता है।';

  @override
  String get settings_theme_applied => 'तुरंत लागू · इस डिवाइस पर सहेजा गया';

  @override
  String get settings_reportPending => 'समीक्षा लंबित';

  @override
  String get legal_document_terms => 'सेवा की शर्तें';

  @override
  String get legal_document_privacy => 'गोपनीयता नीति';

  @override
  String get legal_document_community => 'समुदाय दिशानिर्देश';

  @override
  String get legal_specialCategoryConsent =>
      'अनुकूल मिलान के लिए Silarah द्वारा मेरी धार्मिक जानकारी (मज़हब, नमाज़ का अभ्यास और इस्लामी पहचान) संसाधित किए जाने पर मैं स्पष्ट सहमति देता/देती हूँ। अनुबंधित सेवा प्रदाता इसे केवल सिलाराह चलाने के लिए उपयोग करते हैं, व्यवहार-आधारित विज्ञापन के लिए कभी नहीं।';

  @override
  String get onboarding_complexion_fair => 'गोरा';

  @override
  String get onboarding_complexion_medium => 'मध्यम';

  @override
  String get onboarding_complexion_olive => 'गेहुँआ';

  @override
  String get onboarding_complexion_dark => 'साँवला';

  @override
  String get onboarding_residency_citizen => 'नागरिक';

  @override
  String get onboarding_residency_permanentResident => 'स्थायी निवासी';

  @override
  String get onboarding_residency_workVisa => 'कार्य वीज़ा';

  @override
  String get onboarding_residency_studentVisa => 'छात्र वीज़ा';

  @override
  String get onboarding_specialNeeds_none => 'कोई नहीं';

  @override
  String get onboarding_specialNeeds_physical => 'शारीरिक दिव्यांगता';

  @override
  String get onboarding_specialNeeds_hearing => 'श्रवण बाधा';

  @override
  String get onboarding_specialNeeds_visual => 'दृष्टि बाधा';

  @override
  String get onboarding_label_stateRegion => 'राज्य / क्षेत्र';

  @override
  String get onboarding_specialNeeds_privacy =>
      'यह केवल परस्पर रुचि के बाद साझा किया जाता है।';

  @override
  String get settings_theme_automatic => 'स्वचालित';

  @override
  String get settings_theme_automaticDesc =>
      'दिन में आइवरी और एमराल्ड, फ़ोन डार्क मोड में हो तो OLED नाइट';

  @override
  String get settings_theme_rose => 'गुलाब और गेंदा';

  @override
  String get settings_theme_roseDesc =>
      'कोमल गुलाबी आभा, गहरा गुलाब और गेंदे जैसा सुनहरा';

  @override
  String get settings_theme_oled => 'OLED नाइट';

  @override
  String get settings_theme_oledDesc => 'OLED स्क्रीन के लिए असली काला';

  @override
  String get settings_theme_ivory => 'आइवरी और एमराल्ड';

  @override
  String get settings_theme_ivoryDesc =>
      'गर्म आइवरी, गहरा एमराल्ड और एंटीक गोल्ड';

  @override
  String get settings_guardian_backendRequired =>
      'अभिभावक सेटिंग के लिए सुरक्षित कनेक्शन आवश्यक है।';

  @override
  String get settings_guardian_saveError =>
      'अभिभावक सेटिंग सहेजी नहीं जा सकीं। फिर कोशिश करें।';

  @override
  String get common_openSettings => 'सेटिंग खोलें';

  @override
  String get media_cameraAccessOff => 'कैमरा अनुमति बंद है';

  @override
  String get media_cameraUnavailable => 'कैमरा उपलब्ध नहीं है';

  @override
  String get media_cameraAccessBody =>
      'सेटिंग में कैमरा अनुमति दें, फिर साफ़ फ़ोटो लेने के लिए लौटें।';

  @override
  String get media_cameraUnavailableBody =>
      'कैमरा नहीं खुल सका। फिर कोशिश करें।';

  @override
  String get media_photoAccessOff => 'फ़ोटो अनुमति बंद है';

  @override
  String get media_photoAccessBody =>
      'सेटिंग में कैमरा या फ़ोटो अनुमति दें, फिर फ़ोटो जोड़ने के लिए लौटें।';

  @override
  String get chat_searchHint => 'संदेश खोजें';

  @override
  String get chat_noConversationsFound => 'कोई बातचीत नहीं मिली';

  @override
  String get chat_noConversationsFoundBody =>
      'दूसरा नाम आज़माएँ या खोज साफ़ करें।';

  @override
  String get chat_noConversationsYet => 'अभी कोई बातचीत नहीं';

  @override
  String get chat_noConversationsYetBody =>
      'बातचीत शुरू करने के लिए रुचि स्वीकार करें या अपनी रुचि स्वीकार होने दें।';

  @override
  String get referral_title => 'मित्र को आमंत्रित करें';

  @override
  String get referral_loading => 'पुरस्कार लोड हो रहे हैं';

  @override
  String get referral_heading => 'खबर फैलाएँ, प्रीमियम पाएँ!';

  @override
  String get referral_body =>
      'किसी भी योग्य मित्र को Silarah पर बुलाएँ। हर अकाउंट जीवन में केवल एक बार 3 दिन का रेफ़रल प्रीमियम पा सकता है। यदि आपको अपना पुरस्कार मिल चुका है, तब भी आपके मित्र को उनका पुरस्कार मिलेगा।';

  @override
  String get referral_premiumActiveTitle => 'रेफ़रल प्रीमियम सक्रिय है';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '$daysदि $hoursघं बाकी';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '$hoursघं $minutesमि बाकी';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '$minutesमि बाकी';
  }

  @override
  String get referral_premiumEndingNow => 'पुरस्कार अभी समाप्त हो रहा है';

  @override
  String referral_premiumEndsAt(String date) {
    return '$date को समाप्त';
  }

  @override
  String get referral_premiumNoPayment =>
      'सभी प्रीमियम सुविधाएँ खुली हैं। कोई भुगतान नहीं लिया गया और यह पुरस्कार अपने आप नवीनीकृत नहीं होगा।';

  @override
  String get referral_premiumPlansAfter =>
      'मुफ़्त पुरस्कार समाप्त होने के बाद सब्सक्रिप्शन प्लान उपलब्ध होंगे, इसलिए आपका बचा मुफ़्त समय व्यर्थ नहीं होगा।';

  @override
  String get referral_premiumBackToProfile => 'प्रोफ़ाइल पर वापस जाएँ';

  @override
  String get referral_premiumFeaturesUnlocked =>
      'सभी प्रीमियम सुविधाएँ खुली हैं';

  @override
  String get referral_premiumViewReward => 'पुरस्कार देखें';

  @override
  String get referral_codeLabel => 'आपका रेफ़रल कोड';

  @override
  String get referral_tapToCopy => 'कॉपी करने के लिए कोड टैप करें';

  @override
  String get referral_totalInvited => 'कुल आमंत्रित';

  @override
  String get referral_rewardsEarned => 'मिले पुरस्कार';

  @override
  String referral_premiumDays(int count) {
    return '$count प्रीमियम दिन';
  }

  @override
  String get referral_pending => 'लंबित पंजीकरण';

  @override
  String get referral_shareButton => 'मित्रों के साथ कोड साझा करें';

  @override
  String get referral_copied => 'रेफ़रल कोड कॉपी हो गया!';

  @override
  String get referral_shareSubject => 'Silarah से जुड़ें';

  @override
  String referral_shareText(String code) {
    return 'विश्वसनीय मुस्लिम विवाह ऐप Silarah से जुड़ें। मेरा रेफ़रल कोड इस्तेमाल करें: $code\n\nडाउनलोड: https://silarah.com';
  }

  @override
  String get profile_share => 'प्रोफ़ाइल साझा करें';

  @override
  String safety_reportMember(String name) {
    return '$name की रिपोर्ट करें';
  }

  @override
  String safety_blockMember(String name) {
    return '$name को ब्लॉक करें';
  }

  @override
  String safety_blockTitle(String name) {
    return '$name को ब्लॉक करें?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name डिस्कवरी से छिप जाएगा और आपसे संपर्क नहीं कर सकेगा। सुरक्षा के लिए चैट इतिहास सुरक्षित रहेगा। अनब्लॉक करने से बातचीत दोबारा नहीं खुलेगी।';
  }

  @override
  String get safety_blockAction => 'ब्लॉक करें';

  @override
  String safety_blocked(String name) {
    return '$name को ब्लॉक किया गया।';
  }

  @override
  String ui_openProfile(String name) {
    return '$name प्रोफ़ाइल खोलें';
  }

  @override
  String ui_typing(String name) {
    return '$name टाइप कर रहा है';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'खाता हटाने में विफल: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'देश बदलें, वर्तमान में $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'कोई ईमेल ऐप नहीं मिला. $email की प्रतिलिपि बनाई गई थी.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'संदेश $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'नवीनीकृत $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age वर्ष';
  }

  @override
  String ui_photoNumber(int number) {
    return 'फ़ोटो$number';
  }

  @override
  String ui_photoCount(int count) {
    return '4 फ़ोटो में से $count';
  }

  @override
  String ui_removeLabel(String label) {
    return '$label हटाएं';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label चयनित';
  }

  @override
  String ui_addLabel(String label) {
    return '$label जोड़ें';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'फोटो अनुरोध $name को भेजा गया।';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'कल $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count घंटा पहले';
  }

  @override
  String ui_daysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String ui_renewsAt(String time) {
    return '$time पर नवीनीकृत';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'फोटो $number संरक्षित समीक्षा के लिए तैयार है';
  }

  @override
  String get ui_onePhotoUnlock =>
      'आप दोनों के रुचि व्यक्त करने पर 1 फोटो अपने आप अनलॉक हो जाएगी।';

  @override
  String ui_manyPhotosUnlock(int count) {
    return 'जब आप दोनों रुचि व्यक्त करेंगे तो $count तस्वीरें स्वचालित रूप से अनलॉक हो जाएंगी।';
  }

  @override
  String get ui_askOnePhoto => '1 फ़ोटो देखने के लिए स्वामी से अनुमति माँगें।';

  @override
  String ui_askManyPhotos(int count) {
    return '$count फ़ोटो देखने के लिए स्वामी से अनुमति माँगें।';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet फीट $inches इंच';
  }

  @override
  String ui_minutesShort(int count) {
    return '${count}m';
  }

  @override
  String ui_hoursShort(int count) {
    return '$countह';
  }

  @override
  String ui_daysShort(int count) {
    return '${count}d';
  }

  @override
  String discovery_filters_count(int count) {
    return 'फ़िल्टर ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'पहले $date को मैच हुआ था';
  }

  @override
  String discovery_rematch_days(int count) {
    return '$count दिनों में दोबारा मैच उपलब्ध होगा';
  }

  @override
  String get settings_notify_compatibleProfiles => 'अनुकूल प्रोफ़ाइल अलर्ट';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'जब खाली डिस्कवरी फ़ीड में नए परिणाम आएँ';

  @override
  String get settings_notify_discoveryDigest => 'डिस्कवरी सारांश';

  @override
  String get settings_notify_digestHelp =>
      'वैकल्पिक सारांश; खाली फ़ीड में नए परिणाम के अलर्ट तुरंत मिलेंगे।';

  @override
  String get settings_notify_digestOff => 'बंद';

  @override
  String get settings_notify_digestDaily => 'दैनिक';

  @override
  String get settings_notify_digestWeekly => 'साप्ताहिक';

  @override
  String get settings_quietHoursStart => 'शांत समय शुरू';

  @override
  String get settings_quietHoursEnd => 'शांत समय समाप्त';

  @override
  String get settings_notify_festivalGreetings => 'त्योहार की मुबारकबाद';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'रमज़ान और ईद की मुबारकबाद, साल में लगभग पाँच बार';

  @override
  String get profile_quality_tier_complete => 'पूर्ण';

  @override
  String get profile_quality_tier_strong => 'लगभग पूरा';

  @override
  String get profile_quality_tier_good => 'अच्छी प्रगति';

  @override
  String get profile_quality_tier_start => 'शुरुआत';

  @override
  String profile_quality_ring_semantics(int percent) {
    return 'प्रोफ़ाइल $percent% पूरी';
  }

  @override
  String profile_quality_next_eyebrow(int percent) {
    return 'अगला कदम · $percent% तक पहुँचें';
  }

  @override
  String profile_quality_points(int points) {
    return '+$points%';
  }

  @override
  String get profile_quality_step_photo => 'प्रोफ़ाइल फ़ोटो जोड़ें';

  @override
  String get profile_quality_step_bio => 'परिचय जोड़ें';

  @override
  String get profile_quality_step_deen => 'अपनी इस्लामी पहचान पूरी करें';

  @override
  String get profile_quality_step_education => 'शिक्षा और पेशा जोड़ें';

  @override
  String get profile_quality_step_family => 'पारिवारिक पृष्ठभूमि जोड़ें';

  @override
  String get profile_quality_step_partner => 'जीवनसाथी की पसंद तय करें';

  @override
  String get profile_quality_step_second_photo => 'दूसरी फ़ोटो जोड़ें';

  @override
  String get profile_quality_step_income => 'आय सीमा जोड़ें';

  @override
  String get profile_quality_step_languages => 'भाषाएँ जोड़ें';

  @override
  String get profile_quality_complete_title => 'आपकी प्रोफ़ाइल पूरी है';

  @override
  String get profile_quality_complete_body =>
      'हर जानकारी अपनी जगह पर है। सदस्य आपकी पूरी कहानी देखते हैं।';

  @override
  String get profile_quality_tip_verified_benefit =>
      'भरोसेमंद चेहरे को ज़्यादा जवाब मिलते हैं';

  @override
  String get profile_quality_tip_photos_benefit =>
      'ज़्यादा फ़ोटो से सदस्यों के लिए हाँ कहना आसान होता है';

  @override
  String get profile_quality_tip_bio_benefit =>
      'आपके अपने शब्द पहली छाप छोड़ते हैं';

  @override
  String get profile_quality_tip_guardian_benefit =>
      'परिवार जुड़े हुए अभिभावक को महत्व देते हैं';

  @override
  String get profile_quality_done => 'हो गया';

  @override
  String get profile_quality_name_fallback => 'आपका नाम';

  @override
  String get profile_quality_subtitle_fallback =>
      'नीचे अपनी प्रोफ़ाइल पूरी करें';
}
