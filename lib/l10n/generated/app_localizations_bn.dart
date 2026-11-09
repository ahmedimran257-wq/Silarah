// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get guide_optional_details => 'অতিরিক্ত বিবরণ (ঐচ্ছিক)';

  @override
  String get guide_optional_details_body =>
      'আপনি পরে আপনার প্রোফাইল থেকে এই বিবরণ পূরণ করতে পারবেন।';

  @override
  String get guide_profile_ownership =>
      'এই প্রোফাইলটি বিবাহপ্রত্যাশী ব্যক্তির পরিচয় দেয়। কথোপকথন তত্ত্বাবধানের জন্য পরে আলাদা অভিভাবককে আমন্ত্রণ জানানো যাবে।';

  @override
  String get about_button_later => 'আমি এটা পরে করব';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'সততা এবং মর্যাদার সাথে আপনার $relation বর্ণনা করুন।';
  }

  @override
  String get about_hint_bio_self =>
      'সততা এবং মর্যাদার সাথে নিজেকে বর্ণনা করুন।';

  @override
  String get about_label_bio_guardian => 'তাদের BIO';

  @override
  String get about_label_bio_self => 'আপনার বায়ো';

  @override
  String get about_label_interests => 'আগ্রহ';

  @override
  String get about_label_languages => 'কথ্য ভাষা';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max নির্বাচিত';
  }

  @override
  String get about_subtitle => 'সততা এবং মর্যাদার সাথে লিখুন।';

  @override
  String about_title_guardian(Object relation) {
    return 'আপনার $relation সম্পর্কে';
  }

  @override
  String get about_title_self => 'আপনার সম্পর্কে';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'বিসমিল্লাহ দিয়ে শুরু করুন';

  @override
  String get auth_button_resendOtp => 'যাচাইকরণ কোড পুনরায় পাঠান';

  @override
  String get auth_button_sendCode => 'যাচাইকরণ কোড পাঠান';

  @override
  String get auth_button_sendOtp => 'যাচাইকরণ কোড পাঠান';

  @override
  String get auth_button_verifyOtp => 'যাচাই করুন';

  @override
  String get auth_label_changeNumber => 'ভুল নম্বর? এটি পরিবর্তন করুন';

  @override
  String get auth_label_enterOtp => 'পাঠানো 6-সংখ্যার যাচাইকরণ কোড লিখুন';

  @override
  String get auth_label_resendCode => 'যাচাইকরণ কোড পুনরায় পাঠান';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return '$secondsসেকেন্ডে যাচাইকরণ কোড আবার পাঠান';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return '$secondsসেকেন্ডে আবার পাঠান';
  }

  @override
  String get auth_label_sentCodeTo =>
      'আমরা একটি 6-সংখ্যার যাচাইকরণ কোড পাঠিয়েছি';

  @override
  String get auth_subtitle_verifyOtp =>
      'আমরা এটিকে একবারের কোড দিয়ে যাচাই করব।';

  @override
  String get auth_title_enterCode => 'আপনার যাচাইকরণ কোড লিখুন';

  @override
  String get auth_title_yourNumber => 'আপনার নম্বর';

  @override
  String get background_edu_bachelors => 'ব্যাচেলর ডিগ্রী';

  @override
  String get background_edu_below_secondary => 'মাধ্যমিকের নিচে';

  @override
  String get background_edu_diploma => 'ডিপ্লোমা/অ্যাসোসিয়েট';

  @override
  String get background_edu_doctorate => 'ডক্টরেট/পিএইচডি';

  @override
  String get background_edu_higher_secondary => 'উচ্চ মাধ্যমিক/এ-লেভেল';

  @override
  String get background_edu_masters => 'স্নাতকোত্তর ডিগ্রি';

  @override
  String get background_edu_secondary => 'মাধ্যমিক/ও-লেভেল';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'আপনার $relation-এর শিক্ষা এবং কর্মজীবন সম্পর্কে আমাদের বলুন।';
  }

  @override
  String get background_edu_subtitle_self =>
      'পেশাগতভাবে সামঞ্জস্যপূর্ণ মিল খুঁজে পেতে সাহায্য করে।';

  @override
  String get background_edu_title_guardian => 'তাদের পটভূমি';

  @override
  String get background_edu_title_self => 'আপনার পটভূমি';

  @override
  String get background_emp_employed => 'নিযুক্ত';

  @override
  String get background_emp_not_working => 'কাজ হচ্ছে না';

  @override
  String get background_emp_self_employed => 'স্ব-নিযুক্ত';

  @override
  String get background_emp_student => 'ছাত্র';

  @override
  String get background_income_subtitle =>
      'অনেকে এটি এড়িয়ে যান - এটি সম্পূর্ণ ঐচ্ছিক।';

  @override
  String get background_label_eduLevel => 'শিক্ষার স্তর';

  @override
  String get background_label_employment => 'কর্মসংস্থানের অবস্থা';

  @override
  String background_label_income_bracket(Object currency) {
    return 'ইনকাম ব্র্যাকেট ($currency)';
  }

  @override
  String get background_label_income_range => 'ইনকাম রেঞ্জ (ঐচ্ছিক)';

  @override
  String get background_label_profession => 'পেশা (ঐচ্ছিক)';

  @override
  String get background_label_study => 'অধ্যয়নের ক্ষেত্র (ঐচ্ছিক)';

  @override
  String get background_label_who_see => 'কে এটা দেখতে পারেন?';

  @override
  String get background_vis_everyone => 'সবাইকে বন্ধনী দেখান';

  @override
  String get background_vis_mutual => 'পারস্পরিক স্বার্থের পরেই দেখান';

  @override
  String get background_vis_private => 'ব্যক্তিগত রাখুন';

  @override
  String get ceremony_text_blessing => 'আল্লাহ তায়ালা এর কল্যাণ করুন';

  @override
  String get chat_closure_1 =>
      'আসসালামু আলাইকুম। চিন্তাশীল প্রতিফলনের পরে, আমি মনে করি এটি আমাদের জন্য সঠিক ম্যাচ নাও হতে পারে। আমি আন্তরিকভাবে আপনাকে শুভকামনা জানাই এবং প্রার্থনা করি যে আল্লাহ আপনাকে একটি দুর্দান্ত অংশীদার দিয়ে আশীর্বাদ করুন। জাযাকাল্লাহ খাইর।';

  @override
  String get chat_closure_2 =>
      'আসসালামু আলাইকুম। আমি আপনার সাথে সৎ এবং শ্রদ্ধাশীল হতে চেয়েছিলাম। আমি মনে করি না যে আমরা সঠিক ম্যাচ, তবে আমি প্রার্থনা করি যে আল্লাহ আপনার জন্য আরও ভাল দরজা খুলে দিন। আপনি সব শুভ কামনা.';

  @override
  String get chat_closure_3 =>
      'আসসালামু আলাইকুম। আন্তরিকভাবে বিবেচনা করার পরে, আমি মনে করি আমরা সামঞ্জস্যপূর্ণ নাও হতে পারে। আমি আশা করি আপনি আপনার জন্য সত্যিই সঠিক কাউকে খুঁজে পেয়েছেন। আল্লাহ আপনার জন্য সহজ করে দিন। আপনার সময়ের জন্য জাজাকাল্লাহ খাইর।';

  @override
  String get chat_closure_4 =>
      'আসসালামু আলাইকুম। আমি আমাদের কথোপকথনের প্রতিফলন করেছি এবং মনে করি এই সময়ে এই ম্যাচটি বন্ধ করাই ভাল। আপনার প্রতি আমার শ্রদ্ধা ছাড়া আর কিছুই নেই এবং আমি দোয়া করি যে আল্লাহ আপনাকে সর্বোত্তম আশীর্বাদ করুন।';

  @override
  String get chat_closure_5 =>
      'আসসালামু আলাইকুম। আমি বিবর্ণ না হয়ে আপনার সাথে স্বচ্ছ হতে চেয়েছিলাম। আমি এটিকে আরও অগ্রগতি দেখতে পাচ্ছি না, তবে আমি সত্যিই আপনার সময়ের প্রশংসা করি এবং আপনাকে প্রতিটি সুখ কামনা করি। আল্লাহ আপনার মঙ্গল করুন।';

  @override
  String get chat_endMatch_button => 'পাঠান এবং ম্যাচ শেষ করুন';

  @override
  String get chat_endMatch_subtitle =>
      'এই কথোপকথন বন্ধ করতে একটি সম্মানজনক বার্তা চয়ন করুন. অন্য ব্যক্তিকে অবহিত করা হবে।';

  @override
  String get chat_endMatch_title => 'এই ম্যাচটি শেষ করুন';

  @override
  String chat_label_probation(int hours) {
    return '$hours ঘন্টার মধ্যে মেসেজিং আনলক হয়। আপনি এখন আগ্রহ পাঠাতে পারেন.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'মেসেজিং আনলক করতে সদস্যতা নিন। মহিলারা সবসময় Silarah-এ বিনামূল্যে বার্তা পাঠান।';

  @override
  String get chat_matchClosed_banner =>
      'এই ম্যাচটি সম্মানজনকভাবে বন্ধ করা হয়েছে।';

  @override
  String get chat_opener_1 =>
      'আসসালামু আলাইকুম! আমি আপনার প্রোফাইল জুড়ে এসেছিলাম এবং সত্যিকারের মুগ্ধ. আমি কি আমার পরিচয় দিতে পারি?';

  @override
  String get chat_opener_2 =>
      'বিসমিল্লাহ। আপনার প্রোফাইল আমার মনোযোগ আকর্ষণ. আমি আপনার সম্পর্কে আরো জানতে চাই.';

  @override
  String get chat_opener_3 =>
      'আসসালামু আলাইকুম। আমি বিশ্বাস করি আমরা একই মান শেয়ার করি। আপনি কি একে অপরকে জানার জন্য উন্মুক্ত হবেন?';

  @override
  String get chat_placeholder_typeMessage => 'একটি বার্তা টাইপ করুন...';

  @override
  String get common_button_back => 'ব্যাক';

  @override
  String get common_button_cancel => 'বাতিল করুন';

  @override
  String get common_button_done => 'সম্পন্ন';

  @override
  String get common_button_next => 'পরবর্তী';

  @override
  String get common_button_retry => 'আবার চেষ্টা করুন';

  @override
  String get common_button_save => 'সংরক্ষণ করুন';

  @override
  String get common_button_skip => 'এড়িয়ে যান';

  @override
  String get common_button_submit => 'জমা দিন';

  @override
  String get common_error_generic => 'কিছু ভুল হয়েছে আবার চেষ্টা করুন.';

  @override
  String get common_error_noInternet =>
      'ইন্টারনেট সংযোগ নেই। আপনার সংযোগ পরীক্ষা করুন.';

  @override
  String get common_label_optional => 'ঐচ্ছিক';

  @override
  String get copy_beard_parent => 'আপনার ছেলের কি দাড়ি আছে?';

  @override
  String get copy_beard_self => 'তোমার কি দাড়ি আছে?';

  @override
  String get copy_beard_sibling => 'তোমার ভাইয়ের কি দাড়ি আছে?';

  @override
  String get copy_hijab_parent => 'আপনার মেয়ে হিজাব পালন করে?';

  @override
  String get copy_hijab_self => 'আপনি কি হিজাব পালন করেন?';

  @override
  String get copy_hijab_sibling => 'আপনার বোন হিজাব পালন করেন?';

  @override
  String get copy_prayer_parent =>
      'আপনার সন্তান কি প্রতিদিন পাঁচ ওয়াক্ত নামাজ পড়ে?';

  @override
  String get copy_prayer_self => 'আপনি কি প্রতিদিন পাঁচ ওয়াক্ত নামাজ পড়েন?';

  @override
  String get copy_prayer_sibling =>
      'আপনার ভাই কি প্রতিদিন পাঁচ ওয়াক্ত নামাজ পড়ে?';

  @override
  String get deleteAccount_title => 'অ্যাকাউন্ট মুছুন';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name সরানো হয়েছে';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name সংরক্ষিত';
  }

  @override
  String get discovery_button_sendInterest => 'আগ্রহ পাঠান';

  @override
  String get discovery_completeness_button => 'সম্পূর্ণ প্রোফাইল';

  @override
  String get discovery_completeness_subtitle =>
      '40% এর বেশি প্রোফাইল 3× বেশি আগ্রহ পায়।\nব্রাউজিং শুরু করতে আপনার প্রোফাইল সম্পূর্ণ করুন।';

  @override
  String get discovery_completeness_title => 'আপনার প্রোফাইল সম্পূর্ণ করুন';

  @override
  String get discovery_empty_subtitle =>
      'সিলারাহতে প্রতিদিন নতুন সদস্য যোগ দেন। নতুন প্রোফাইলের জন্য আগামীকাল আবার দেখুন, অথবা এখনই আরও মানুষের সঙ্গে পরিচিত হতে আপনার পছন্দের পরিসর বাড়ান।';

  @override
  String get discovery_empty_filtered_eyebrow => 'আপনার খোঁজ আরও নিখুঁত করুন';

  @override
  String get discovery_empty_filtered_title =>
      'এই ফিল্টারগুলোর সঙ্গে এখনও কেউ মেলেনি';

  @override
  String get discovery_empty_filtered_subtitle =>
      'আপনার পছন্দগুলো পরিসর সংকুচিত করছে। মাত্র একটি ফিল্টার শিথিল করলেই সাধারণত সঙ্গে সঙ্গে নতুন প্রোফাইল দেখা যায়।';

  @override
  String get discovery_empty_clear_filters => 'সব ফিল্টার মুছুন';

  @override
  String get discovery_empty_refresh => 'প্রোফাইল রিফ্রেশ করুন';

  @override
  String get discovery_empty_adjust_filters => 'ফিল্টার বদলান';

  @override
  String get discovery_empty_hint_trust =>
      'প্রথমে বিশ্বাসযোগ্যতা যাচাই শিথিল করে দেখুন';

  @override
  String get discovery_empty_hint_deen => 'প্রথমে দ্বীন লেভেল বাড়িয়ে দেখুন';

  @override
  String get discovery_empty_hint_family =>
      'প্রথমে পারিবারিক ধরন বাড়িয়ে দেখুন';

  @override
  String get discovery_empty_hint_sect =>
      'প্রথমে সম্প্রদায় ফিল্টারটি খুলে দেখুন';

  @override
  String get discovery_empty_hint_location => 'প্রথমে আরও বড় এলাকা বেছে দেখুন';

  @override
  String get discovery_empty_hint_age => 'প্রথমে বয়সের পরিসীমা বাড়িয়ে দেখুন';

  @override
  String get discovery_empty_hint_other =>
      'একবারে একটি করে ফিল্টার শিথিল করে দেখুন';

  @override
  String get discovery_empty_eyebrow => 'সবই দেখা হয়ে গেছে';

  @override
  String get discovery_empty_title => 'আজকের জন্য আপনি সবাইকে দেখে ফেলেছেন';

  @override
  String get discovery_handoff_interest_subtitle =>
      'সক্রিয় অনুরোধের প্রোফাইলগুলো অপেক্ষা বা উত্তর দেওয়ার সময় ইন্টারেস্টসে থাকে।';

  @override
  String get discovery_handoff_interest_title => 'আপনার আগ্রহটি প্রক্রিয়াধীন';

  @override
  String get discovery_handoff_match_subtitle =>
      'ম্যাচ হওয়া প্রোফাইলগুলো চ্যাটে চলে যায়, তাই ডিসকভারে আবার দেখানো হয় না।';

  @override
  String get discovery_handoff_match_title => 'আপনার সংযোগ প্রস্তুত';

  @override
  String get discovery_handoff_open_chat => 'চ্যাট খুলুন';

  @override
  String get discovery_handoff_open_interests => 'ইন্টারেস্টস খুলুন';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'আগ্রহ পাঠানো হয়েছে ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'এমন কেউ যার সাথে আপনি সংযোগ করতে পারেন৷';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count প্রোফাইল আজ বাকি আছে';
  }

  @override
  String get discovery_limit_button => 'এখন আপগ্রেড করুন';

  @override
  String get discovery_limit_subtitle =>
      'আপনি আজ 15টি প্রোফাইল ব্রাউজ করেছেন।\nআনলিমিটেড ব্রাউজিং আনলক করতে আপগ্রেড করুন।';

  @override
  String get discovery_limit_title => 'দৈনিক সীমা পৌঁছেছে';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count প্রোফাইল বাকি';
  }

  @override
  String get discovery_wildcard_label =>
      'এমন কেউ যার সাথে আপনি সংযোগ করতে পারেন৷';

  @override
  String get family_children_no => 'না';

  @override
  String get family_children_yes => 'হ্যাঁ';

  @override
  String get family_label_children_guardian => 'তাদের কি সন্তান আছে?';

  @override
  String get family_label_children_self => 'আপনার কি সন্তান আছে?';

  @override
  String get family_label_how_many => 'কতজন?';

  @override
  String get family_label_parents => 'পিতামাতার বৈবাহিক অবস্থা';

  @override
  String get family_label_polygamy_female_self => 'বহুবিবাহ গ্রহণ (ঐচ্ছিক)';

  @override
  String get family_label_polygamy_male_self => 'বহুবিবাহের অবস্থা (ঐচ্ছিক)';

  @override
  String get family_label_prev_married => 'পূর্বে বিবাহিত?';

  @override
  String get family_label_relocate => 'স্থানান্তর করতে ইচ্ছুক';

  @override
  String get family_label_siblings => 'ভাইবোনের সংখ্যা';

  @override
  String get family_label_type => 'পরিবারের ধরন';

  @override
  String get family_living_title => 'বিবাহ-পরবর্তী জীবনযাত্রার প্রত্যাশা';

  @override
  String get family_parents_both_deceased => 'দুজনেই মৃত';

  @override
  String get family_parents_divorced => 'তালাকপ্রাপ্ত';

  @override
  String get family_parents_father_deceased => 'পিতা মৃত';

  @override
  String get family_parents_mother_deceased => 'মা মৃত';

  @override
  String get family_parents_separated => 'বিচ্ছিন্ন';

  @override
  String get family_parents_together => 'একসাথে';

  @override
  String get family_polygamy_female_discussion => 'আলোচনার জন্য উন্মুক্ত';

  @override
  String get family_polygamy_female_no => 'না';

  @override
  String get family_polygamy_female_prefer_not => 'না বলতে পছন্দ করেন';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'আপনার $relation একজন সহ-স্ত্রী হিসেবে বিবেচনা করবেন?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'আপনি একজন সহ-স্ত্রী হিসেবে বিবেচনা করবেন?';

  @override
  String get family_polygamy_female_yes => 'হ্যাঁ';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'আপনার $relation বর্তমানে বিবাহিত এবং একজন অতিরিক্ত পত্নী খুঁজছেন?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'আপনি কি বর্তমানে বিবাহিত এবং একটি অতিরিক্ত পত্নী খুঁজছেন?';

  @override
  String get family_polygamy_option_first => 'না, এই আমার প্রথম';

  @override
  String get family_polygamy_option_married => 'হ্যাঁ, বর্তমানে বিবাহিত';

  @override
  String get family_polygamy_option_prefer_not => 'না বলতে পছন্দ করেন';

  @override
  String get family_prev_divorced => 'তালাকপ্রাপ্ত';

  @override
  String get family_prev_no => 'না';

  @override
  String get family_prev_widowed => 'বিধবা';

  @override
  String get family_relocate_discussion => 'আলোচনার জন্য উন্মুক্ত';

  @override
  String get family_relocate_no => 'না';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'আপনার $relation কি বিয়ের জন্য স্থানান্তরিত হবে?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'আপনি কি বিয়ের জন্য স্থান পরিবর্তন করবেন?';

  @override
  String get family_relocate_yes => 'হ্যাঁ';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'আপনার $relation এর পরিবার সম্পর্কে আমাদের বলুন।';
  }

  @override
  String get family_subtitle_self =>
      'পারিবারিক সামঞ্জস্যতা দীর্ঘস্থায়ী বিবাহের কেন্দ্রবিন্দু।';

  @override
  String get family_title_guardian => 'পারিবারিক পটভূমি';

  @override
  String get family_title_self => 'পারিবারিক পটভূমি';

  @override
  String get family_type_extended => 'বর্ধিত';

  @override
  String get family_type_joint => 'জয়েন্ট';

  @override
  String get family_type_nuclear => 'পারমাণবিক';

  @override
  String get filter_label_community => 'সম্প্রদায়/বিরাদারি';

  @override
  String get filter_label_livingExpectation => 'বিবাহ-পরবর্তী জীবনযাপন';

  @override
  String get filter_label_motherTongue => 'মাতৃভাষা';

  @override
  String get guardian_details_candidate_female =>
      'মহিলা প্রার্থী • মহিলা বার্তা বিনামূল্যে';

  @override
  String get guardian_details_candidate_label => 'জন্য প্রোফাইল তৈরি করা হচ্ছে';

  @override
  String get guardian_details_candidate_male => 'পুরুষ প্রার্থী';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'আমার $relation';
  }

  @override
  String get guardian_details_involvement => 'অভিভাবক জড়িত';

  @override
  String get guardian_details_involvement_subtitle =>
      'আপনি কথোপকথনে কতটা জড়িত হতে চান?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'চ্যাট দেখুন, ম্যাচ অনুমোদন করুন এবং আপনার $relation এর হয়ে বার্তা পাঠান।';
  }

  @override
  String get guardian_details_mode_active_title => 'সক্রিয় অভিভাবক';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'রিয়েল-টাইমে সমস্ত চ্যাট দেখুন, কিন্তু শুধুমাত্র আপনার $relation বার্তা পাঠাতে পারে।';
  }

  @override
  String get guardian_details_mode_passive_title => 'শুধুমাত্র পর্যবেক্ষণ করুন';

  @override
  String get guardian_details_name_hint => 'পুরো নাম';

  @override
  String get guardian_details_name_subtitle =>
      'অভিভাবক হিসেবে আপনার নাম। এই মিল দেখানো হয়.';

  @override
  String guardian_details_notice(Object relation) {
    return 'আপনি আপনার $relation এর জন্য একটি প্রোফাইল তৈরি করছেন৷ পরবর্তী স্ক্রিনে সমস্ত প্রোফাইল বিবরণ সেগুলি বর্ণনা করবে, আপনি নয়৷';
  }

  @override
  String get guardian_details_search_hint => 'অনুসন্ধান করুন';

  @override
  String get guardian_details_select_code => 'দেশের কোড নির্বাচন করুন';

  @override
  String get guardian_details_subtitle =>
      'অভিভাবক হিসাবে আপনার সম্পর্কে আমাদের বলুন.';

  @override
  String get guardian_details_title => 'আপনার অভিভাবকের বিবরণ';

  @override
  String get guardian_details_your_name => 'আপনার নাম';

  @override
  String get interest_cat_creative => 'সৃজনশীল';

  @override
  String get interest_cat_faith => 'বিশ্বাস';

  @override
  String get interest_cat_learning => 'শেখা';

  @override
  String get interest_cat_lifestyle => 'জীবনধারা';

  @override
  String get interest_cat_social => 'সামাজিক';

  @override
  String get interest_cat_sports => 'খেলাধুলা';

  @override
  String get interest_tag_art => 'শিল্প';

  @override
  String get interest_tag_calligraphy => 'ক্যালিগ্রাফি';

  @override
  String get interest_tag_community_work => 'সম্প্রদায়ের কাজ';

  @override
  String get interest_tag_cooking => 'রান্না';

  @override
  String get interest_tag_crafts => 'কারুশিল্প';

  @override
  String get interest_tag_cricket => 'ক্রিকেট';

  @override
  String get interest_tag_cycling => 'সাইক্লিং';

  @override
  String get interest_tag_dawah => 'দাওয়াহ';

  @override
  String get interest_tag_family_gatherings => 'পারিবারিক সমাবেশ';

  @override
  String get interest_tag_fitness => 'ফিটনেস';

  @override
  String get interest_tag_football => 'ফুটবল';

  @override
  String get interest_tag_gardening => 'বাগান করা';

  @override
  String get interest_tag_graphic_design => 'গ্রাফিক ডিজাইন';

  @override
  String get interest_tag_hiking => 'হাইকিং';

  @override
  String get interest_tag_history => 'ইতিহাস';

  @override
  String get interest_tag_islamic_lectures => 'ইসলামিক লেকচার';

  @override
  String get interest_tag_languages => 'ভাষা';

  @override
  String get interest_tag_martial_arts => 'মার্শাল আর্ট';

  @override
  String get interest_tag_mentoring => 'মেন্টরিং';

  @override
  String get interest_tag_photography => 'ফটোগ্রাফি';

  @override
  String get interest_tag_poetry => 'কবিতা';

  @override
  String get interest_tag_quran_recitation => 'কোরআন তেলাওয়াত';

  @override
  String get interest_tag_reading => 'পড়া';

  @override
  String get interest_tag_science => 'বিজ্ঞান';

  @override
  String get interest_tag_swimming => 'সাঁতার';

  @override
  String get interest_tag_tahajjud => 'তাহাজ্জুদ';

  @override
  String get interest_tag_teaching => 'শিক্ষাদান';

  @override
  String get interest_tag_technology => 'প্রযুক্তি';

  @override
  String get interest_tag_travel => 'ভ্রমণ';

  @override
  String get interest_tag_umrah_hajj => 'ওমরাহ/হজ্জ';

  @override
  String get interest_tag_voluntary_fasting => 'স্বেচ্ছায় উপবাস';

  @override
  String get interest_tag_volunteering => 'স্বেচ্ছাসেবক';

  @override
  String get interest_tag_writing => 'লেখা';

  @override
  String get interests_button_accept => 'গ্রহণ করুন';

  @override
  String get interests_button_decline => 'প্রত্যাখ্যান';

  @override
  String get interests_tab_received => 'গৃহীত';

  @override
  String get interests_tab_sent => 'পাঠানো হয়েছে';

  @override
  String get interests_title => 'আগ্রহ';

  @override
  String get lang_albanian => 'আলবেনিয়ান';

  @override
  String get lang_amazigh => 'আমাজিঘ (বারবার)';

  @override
  String get lang_amharic => 'আমহারিক';

  @override
  String get lang_arabic => 'আরবি';

  @override
  String get lang_assamese => 'অসমীয়া';

  @override
  String get lang_balochi => 'বেলুচি';

  @override
  String get lang_bengali => 'বাংলা';

  @override
  String get lang_bosnian => 'বসনিয়ান';

  @override
  String get lang_burmese => 'বার্মিজ';

  @override
  String get lang_chechen => 'চেচেন';

  @override
  String get lang_chinese => 'চাইনিজ (ম্যান্ডারিন)';

  @override
  String get lang_dari => 'দারি';

  @override
  String get lang_dutch => 'ডাচ';

  @override
  String get lang_english => 'ইংরেজি';

  @override
  String get lang_french => 'ফরাসি';

  @override
  String get lang_fulani => 'ফুলানি';

  @override
  String get lang_german => 'জার্মান';

  @override
  String get lang_gujarati => 'গুজরাটি';

  @override
  String get lang_hausa => 'হাউসা';

  @override
  String get lang_hindi => 'হিন্দি';

  @override
  String get lang_igbo => 'ইগবো';

  @override
  String get lang_indonesian => 'ইন্দোনেশিয়ান';

  @override
  String get lang_italian => 'ইতালীয়';

  @override
  String get lang_japanese => 'জাপানিজ';

  @override
  String get lang_javanese => 'জাভানিজ';

  @override
  String get lang_kannada => 'কন্নড়';

  @override
  String get lang_kazakh => 'কাজাখ';

  @override
  String get lang_korean => 'কোরিয়ান';

  @override
  String get lang_kurdish => 'কুর্দি';

  @override
  String get lang_kyrgyz => 'কিরগিজ';

  @override
  String get lang_malay => 'মলয়';

  @override
  String get lang_malayalam => 'মালায়লাম';

  @override
  String get lang_mandinka => 'মান্দিঙ্কা';

  @override
  String get lang_marathi => 'মারাঠি';

  @override
  String get lang_norwegian => 'নরওয়েজিয়ান';

  @override
  String get lang_odia => 'ওডিয়া';

  @override
  String get lang_other => 'অন্যান্য';

  @override
  String get lang_pashto => 'পশতু';

  @override
  String get lang_persian => 'ফার্সি';

  @override
  String get lang_portuguese => 'পর্তুগিজ';

  @override
  String get lang_punjabi => 'পাঞ্জাবি';

  @override
  String get lang_rohingya => 'রোহিঙ্গা';

  @override
  String get lang_russian => 'রাশিয়ান';

  @override
  String get lang_saraiki => 'সারাইকি';

  @override
  String get lang_sindhi => 'সিন্ধি';

  @override
  String get lang_somali => 'সোমালি';

  @override
  String get lang_spanish => 'স্প্যানিশ';

  @override
  String get lang_sundanese => 'সুন্দানিজ';

  @override
  String get lang_swahili => 'সোয়াহিলি';

  @override
  String get lang_swedish => 'সুইডিশ';

  @override
  String get lang_tagalog => 'তাগালগ';

  @override
  String get lang_tajik => 'তাজিক';

  @override
  String get lang_tamil => 'তামিল';

  @override
  String get lang_tatar => 'তাতার';

  @override
  String get lang_telugu => 'তেলেগু';

  @override
  String get lang_thai => 'থাই';

  @override
  String get lang_tigrinya => 'টাইগ্রিনিয়া';

  @override
  String get lang_turkish => 'তুর্কি';

  @override
  String get lang_urdu => 'উর্দু';

  @override
  String get lang_uzbek => 'উজবেক';

  @override
  String get lang_wolof => 'ওলোফ';

  @override
  String get lang_yoruba => 'ইওরুবা';

  @override
  String get legal_button_continue => 'চালিয়ে যান';

  @override
  String get legal_checkbox_age =>
      'আমি নিশ্চিত করছি যে আমার বয়স 18 বছর বা তার বেশি';

  @override
  String get legal_checkbox_terms =>
      'আমি পরিষেবার শর্তাবলী এবং গোপনীয়তা নীতিতে সম্মত';

  @override
  String get legal_subtitle => 'অনুগ্রহ করে পড়ুন এবং চালিয়ে যেতে সম্মত হন।';

  @override
  String get legal_summary_1 =>
      'আপনার ডেটা এনক্রিপ্ট করা হয় এবং তৃতীয় পক্ষের কাছে বিক্রি হয় না।';

  @override
  String get legal_summary_2 =>
      'প্রতিটি ছবি নিরাপত্তার জন্য যাচাই করা হয় এবং আমাদের টিম নতুন ছবি পর্যালোচনা করে।';

  @override
  String get legal_summary_3 =>
      'হয়রানি, জাল প্রোফাইল, এবং স্ক্যামের ফলে স্থায়ী নিষেধাজ্ঞা হয়৷';

  @override
  String get legal_summary_4 =>
      'এই প্ল্যাটফর্ম শুধুমাত্র বিবাহের উদ্দেশ্য জন্য. মর্যাদা মান.';

  @override
  String get legal_summary_5 =>
      'আপনি যেকোনো সময় আপনার অ্যাকাউন্ট এবং সমস্ত ডেটা মুছে ফেলতে পারেন।';

  @override
  String get legal_title => 'আপনি শুরু করার আগে';

  @override
  String get notifications_empty_subtitle =>
      'এই মুহূর্তে কোন নতুন বিজ্ঞপ্তি নেই.';

  @override
  String get notifications_empty_title => 'আপনি সব ধরা হয়েছে';

  @override
  String get notifications_markAllRead => 'সব পড়া চিহ্নিত করুন';

  @override
  String get notifications_title => 'বিজ্ঞপ্তি';

  @override
  String get onboarding_about_title => 'নিজের সম্পর্কে';

  @override
  String get onboarding_background_title => 'শিক্ষা ও কর্মজীবন';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'আপনি একজন অভিভাবক হিসাবে এটি পূরণ করছেন। এই বিবরণ আপনার $relation সম্পর্কে।';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'এটি অন্যরা তাদের প্রোফাইলে দেখতে পাবে।';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'এটি অন্যরা আপনার প্রোফাইলে দেখতে পাবে।';

  @override
  String get onboarding_basicIdentity_title => 'আপনার সম্পর্কে আমাদের বলুন';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'আপনার $relation সম্পর্কে আমাদের বলুন';
  }

  @override
  String get onboarding_debt_manageable => 'পরিচালনাযোগ্য ঋণ';

  @override
  String get onboarding_debt_none => 'ঋণ নেই';

  @override
  String get onboarding_debt_significant => 'উল্লেখযোগ্য ঋণ';

  @override
  String get onboarding_diet_eatsAnything => 'হালাল কিছু খায়';

  @override
  String get onboarding_diet_halalOnly => 'শুধু হালাল';

  @override
  String get onboarding_diet_vegan => 'ভেগান';

  @override
  String get onboarding_diet_vegetarian => 'নিরামিষাশী';

  @override
  String get onboarding_diet_zabihaStrict => 'কঠোর জাবিহা';

  @override
  String get onboarding_error_bioContactInfo =>
      'আপনার বায়ো থেকে যোগাযোগের তথ্য মুছে দিন. আপনার নিরাপত্তার জন্য বহিরাগত যোগাযোগের বিবরণ অনুমোদিত নয়।';

  @override
  String get onboarding_error_multipleFaces =>
      'গ্রুপ ফটো আপনার প্রাথমিক ছবি হতে পারে না.';

  @override
  String get onboarding_error_noFace =>
      'আপনার মুখ স্পষ্টভাবে দৃশ্যমান যেখানে একটি ছবি ব্যবহার করুন.';

  @override
  String get onboarding_error_under18 =>
      'Silarah 18 বা তার বেশি বয়সীদের জন্য। আমাদের সম্প্রদায়ের সবাইকে রক্ষা করার জন্য আমরা এই প্রয়োজনীয়তা তৈরি করেছি।';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Silarah ব্যবহার করার জন্য আপনার $relation এর বয়স 18 বা তার বেশি হতে হবে।';
  }

  @override
  String get onboarding_error_under18_self =>
      'Silarah ব্যবহার করার জন্য আপনার বয়স 18 বা তার বেশি হতে হবে। আমরা তখন আপনাকে স্বাগত জানাতে উন্মুখ।';

  @override
  String get onboarding_habit_frequently => 'ঘন ঘন';

  @override
  String get onboarding_habit_never => 'কখনই না';

  @override
  String get onboarding_habit_occasionally => 'মাঝে মাঝে';

  @override
  String get onboarding_habit_preferNotToSay => 'না বলতে পছন্দ করেন';

  @override
  String get onboarding_hijab_always => 'সর্বদা';

  @override
  String get onboarding_hijab_no => 'না';

  @override
  String get onboarding_hijab_sometimes => 'মাঝে মাঝে';

  @override
  String get onboarding_hint_bio =>
      'সততা এবং মর্যাদার সাথে নিজেকে বর্ণনা করুন।';

  @override
  String get onboarding_hint_profession =>
      'যেমন সফটওয়্যার ইঞ্জিনিয়ার, শিক্ষক, ডাক্তার';

  @override
  String get onboarding_hint_searchCity => 'আপনার শহর অনুসন্ধান করুন...';

  @override
  String get onboarding_hint_selectCommunity =>
      'সম্প্রদায় নির্বাচন করুন (ঐচ্ছিক)';

  @override
  String get onboarding_hint_selectCountry => 'দেশ নির্বাচন করুন';

  @override
  String get onboarding_hint_selectDateOfBirth => 'জন্ম তারিখ নির্বাচন করুন';

  @override
  String get onboarding_hint_selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'এটি আপনাকে সামঞ্জস্যপূর্ণ কারো সাথে মেলাতে সাহায্য করে।';

  @override
  String get onboarding_islamicIdentity_title => 'আপনার ইসলামিক পরিচয়';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'শহর';

  @override
  String get onboarding_label_city_guardian => 'তাদের শহর';

  @override
  String get onboarding_label_city_self => 'তোমার শহর';

  @override
  String get onboarding_label_community => 'তোমার সম্প্রদায়/বিরদারী';

  @override
  String get onboarding_label_community_parent => 'তাদের সম্প্রদায়/বিরদারী';

  @override
  String get onboarding_label_complexion => 'কমপ্লেশান (ঐচ্ছিক)';

  @override
  String get onboarding_label_country_guardian => 'তাদের দেশ';

  @override
  String get onboarding_label_country_self => 'তোমার দেশ';

  @override
  String get onboarding_label_cultural => 'সাংস্কৃতিক মুসলিম';

  @override
  String get onboarding_label_dateOfBirth => 'জন্ম তারিখ';

  @override
  String get onboarding_label_debtStatus => 'ঋণের অবস্থা';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'আপনার বর্তমান আর্থিক বাধ্যবাধকতা.';

  @override
  String get onboarding_label_deenLevel => 'দ্বীন লেভেল';

  @override
  String get onboarding_label_diet => 'ডায়েট';

  @override
  String get onboarding_label_educationLevel => 'শিক্ষার স্তর';

  @override
  String get onboarding_label_female => 'মহিলা';

  @override
  String get onboarding_label_firstName => 'প্রথম নাম';

  @override
  String get onboarding_label_firstName_guardian => 'প্রার্থীর প্রথম নাম';

  @override
  String get onboarding_label_firstName_self => 'প্রথম নাম';

  @override
  String get onboarding_label_gender => 'লিঙ্গ';

  @override
  String get onboarding_label_gender_guardian => 'প্রার্থীর লিঙ্গ';

  @override
  String get onboarding_label_gender_self => 'লিঙ্গ';

  @override
  String get onboarding_label_height_guardian => 'তাদের উচ্চতা';

  @override
  String get onboarding_label_height_self => 'আপনার উচ্চতা';

  @override
  String get onboarding_label_hookah => 'হুক্কা/শিশা';

  @override
  String get onboarding_label_housing => 'হাউজিং';

  @override
  String get onboarding_label_housingQuestion =>
      'আপনি একটি পৃথক থাকার জায়গা প্রদান করতে পারেন?';

  @override
  String get onboarding_label_lastName => 'পদবি';

  @override
  String get onboarding_label_leadership => 'ধর্মীয় নেতৃত্ব';

  @override
  String get onboarding_label_leadershipQuestion =>
      'আপনি কি জামাতে নামাজের ইমামতি করতে পারবেন?';

  @override
  String get onboarding_label_lifestyleDiet => 'লাইফস্টাইল এবং ডায়েট';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'এগুলি অনেক পরিবারের জন্য ডিলব্রেকার ক্ষেত্র। দয়া করে সৎভাবে উত্তর দিন।';

  @override
  String get onboarding_label_livingExpectation =>
      'বিবাহ-পরবর্তী জীবনযাপনের প্রত্যাশা';

  @override
  String get onboarding_label_mahrBudget => 'মাহর বাজেট';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'আপনি কি মাহর রেঞ্জ অফার করতে প্রস্তুত?';

  @override
  String get onboarding_label_mahrExpectation => 'মহর প্রত্যাশা';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'মহর জন্য আপনার প্রত্যাশা কি?';

  @override
  String get onboarding_label_maintenance => 'আর্থিক রক্ষণাবেক্ষণ';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'আপনি কি একজন পত্নীকে আর্থিকভাবে প্রদান করতে পারবেন?';

  @override
  String get onboarding_label_male => 'পুরুষ';

  @override
  String get onboarding_label_marriageTimeline => 'বিয়ের সময়রেখা';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'আপনি কখন বিয়ে করতে চাইছেন?';

  @override
  String get onboarding_label_moderate => 'পরিমিত';

  @override
  String get onboarding_label_motherTongue => 'মাতৃভাষা';

  @override
  String get onboarding_label_niqab => 'নেকাব';

  @override
  String get onboarding_label_practicing => 'অনুশীলন করছে';

  @override
  String get onboarding_label_praysFiveDaily =>
      'প্রতিদিন পাঁচ ওয়াক্ত নামাজ পড়ি';

  @override
  String get onboarding_label_preferNotToSay => 'না বলতে পছন্দ করেন';

  @override
  String get onboarding_label_preferredLiving => 'বসবাসের ব্যবস্থা পছন্দ';

  @override
  String get onboarding_label_profession => 'পেশা';

  @override
  String get onboarding_label_providerReadiness => 'প্রদানকারী প্রস্তুতি';

  @override
  String get onboarding_label_quranMemorization => 'কুরআন মুখস্থ করা';

  @override
  String get onboarding_label_religiousEducation => 'ধর্মীয় শিক্ষা';

  @override
  String get onboarding_label_residencyStatus => 'আবাসিক অবস্থা (ঐচ্ছিক)';

  @override
  String get onboarding_label_revert => 'প্রত্যাবর্তন / রূপান্তর (ঐচ্ছিক)';

  @override
  String get onboarding_label_revertQuestion =>
      'আপনি কি ইসলামে প্রত্যাবর্তনকারী (ধর্মান্তরিত)?';

  @override
  String get onboarding_label_sect => 'সম্প্রদায়';

  @override
  String get onboarding_label_shia => 'শিয়া';

  @override
  String get onboarding_label_smoking => 'ধূমপান';

  @override
  String get onboarding_label_specialNeeds => 'বিশেষ প্রয়োজন (ঐচ্ছিক)';

  @override
  String onboarding_label_step(int current, int total) {
    return '$total এর $current ধাপ';
  }

  @override
  String get onboarding_label_subSect => 'চিন্তাধারা (ঐচ্ছিক)';

  @override
  String get onboarding_label_substanceUse => 'পদার্থ ব্যবহার';

  @override
  String get onboarding_label_sunni => 'সুন্নি';

  @override
  String get onboarding_label_vaping => 'ভ্যাপিং / ই-সিগারেট';

  @override
  String get onboarding_label_workAfterMarriage => 'বিয়ের পর কাজ';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'আপনি কি বিয়ের পর কাজ করতে চান?';

  @override
  String get onboarding_leadership_leads => 'নামাজের নেতৃত্ব দেন';

  @override
  String get onboarding_leadership_learning => 'শেখা';

  @override
  String get onboarding_leadership_notYet => 'এখনো না';

  @override
  String get onboarding_living_openToDiscussion => 'আলোচনার জন্য উন্মুক্ত';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'উভয়ের জন্য কী কাজ করে তা নিয়ে আলোচনা করতে আমি নমনীয় এবং খুশি।';

  @override
  String get onboarding_living_separate => 'আলাদা বাড়ি';

  @override
  String get onboarding_living_separateSub =>
      'আমি পছন্দ করি যে আমাদের নিজস্ব স্বাধীন বাড়ি আছে।';

  @override
  String get onboarding_living_withInlaws => 'শ্বশুরবাড়ির সঙ্গে';

  @override
  String get onboarding_living_withInlawsSub =>
      'আমি আমার পত্নী বা আমার নিজের পরিবারের সাথে বাস করার আশা করি।';

  @override
  String get onboarding_location_confirmed => 'নিশ্চিত অবস্থান';

  @override
  String get onboarding_mahr_generous => 'উদার';

  @override
  String get onboarding_mahr_moderate => 'পরিমিত';

  @override
  String get onboarding_mahr_modest => 'বিনয়ী';

  @override
  String get onboarding_mahr_noPreference => 'কোন পছন্দ নেই';

  @override
  String get onboarding_mahr_toDiscuss => 'আলোচনা করতে';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'এই বিবরণ আপনার পাবলিক প্রোফাইলে দেখানো হয় না. এগুলি গ্রহণযোগ্যতার পর্যায়ে ব্যক্তিগতভাবে ভাগ করা হয়।';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'আমাদের আপনার যাত্রা এবং প্রস্তুতি বুঝতে সাহায্য করুন.';

  @override
  String get onboarding_marriageDeen_title => 'বিবাহ ও দ্বীন';

  @override
  String get onboarding_niqab_dontWear => 'আমি নেকাব পরি না';

  @override
  String get onboarding_niqab_open => 'পরার জন্য খোলা';

  @override
  String get onboarding_niqab_wear => 'আমি নেকাব পরি';

  @override
  String get onboarding_photo_subtitle =>
      'অন্তত একটি ফটো প্রয়োজন. আপনার প্রাথমিক ফটোতে আপনার মুখ পরিষ্কারভাবে অন্তর্ভুক্ত করতে হবে।';

  @override
  String get onboarding_photo_title => 'আপনার ফটো যোগ করুন';

  @override
  String get onboarding_photo_verifySelfie => 'যাচাইকরণ সেলফি';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'আপনি বাস্তব তা যাচাই করতে একটি লাইভ ফটো নিন';

  @override
  String get onboarding_preferredLiving_noPreference => 'কোন পছন্দ নেই';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'আমি আমার জন্য এটি তৈরি করছি...';

  @override
  String get onboarding_profileForWhom_guardian => 'আমার ছেলে বা মেয়ে';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'আমি কারো জন্য এই প্রোফাইল তৈরি করছি';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'অভিভাবক';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'আমি একজন অভিভাবক বা অভিভাবক';

  @override
  String get onboarding_profileForWhom_myself => 'আমি নিজেই';

  @override
  String get onboarding_profileForWhom_myselfSub => 'আমি একটি জীবনসঙ্গী খুঁজছি';

  @override
  String get onboarding_profileForWhom_relation_brother => 'ভাই';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'কন্যা';

  @override
  String get onboarding_profileForWhom_relation_sister => 'বোন';

  @override
  String get onboarding_profileForWhom_relation_son => 'পুত্র';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'চালিয়ে যেতে একটি নির্বাচন করুন';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'চালিয়ে যেতে একটি সম্পর্ক নির্বাচন করুন';

  @override
  String get onboarding_profileForWhom_sibling => 'আমার ভাই বা বোন';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'আমি আমার ভাইবোনকে একটি মিল খুঁজে পেতে সাহায্য করছি';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'আপনি সেটিংস থেকে পরে এটি আপডেট করতে পারেন।';

  @override
  String get onboarding_profileForWhom_title => 'এই প্রোফাইল কার জন্য?';

  @override
  String get onboarding_profileForWhom_ward => 'আমার ওয়ার্ড';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'আমি একজন অভিভাবক এই প্রোফাইলটি পরিচালনা করছি';

  @override
  String get onboarding_providerQuote =>
      '\"তোমাদের মধ্যে উত্তম তারাই তোমাদের স্ত্রীদের কাছে উত্তম।\" - নবী মুহাম্মদ সা\n\nআপনার প্রস্তুতি সম্পর্কে সৎ থাকা একটি শক্তিশালী ভিত্তি তৈরি করতে সহায়তা করে।';

  @override
  String get onboarding_quran_hafiz => 'হাফিজ/হাফিজা';

  @override
  String get onboarding_quran_none => 'কোনোটিই নয়';

  @override
  String get onboarding_quran_partial => 'আংশিক হিফজ';

  @override
  String get onboarding_quran_some => 'কিছু সূরা';

  @override
  String get onboarding_religiousEdu_alim => 'আলিম কোর্স';

  @override
  String get onboarding_religiousEdu_islamicUni => 'ইসলামী বিশ্ববিদ্যালয়';

  @override
  String get onboarding_religiousEdu_madrasa => 'মাদ্রাসা';

  @override
  String get onboarding_religiousEdu_selfTaught => 'স্ব-শিক্ষিত';

  @override
  String get onboarding_timeline_1year => 'এক বছরের মধ্যে';

  @override
  String get onboarding_timeline_2years => '2+ বছর';

  @override
  String get onboarding_timeline_6months => '৬ মাসের মধ্যে';

  @override
  String get onboarding_timeline_asap => 'যত তাড়াতাড়ি সম্ভব';

  @override
  String get onboarding_timeline_notSure => 'এখনো নিশ্চিত নই';

  @override
  String get onboarding_tooltip_cultural =>
      'মুসলিম হিসেবে পরিচয় দেয়, অনুষ্ঠান উদযাপন করে, নিয়মিত প্রার্থনা নাও করতে পারে';

  @override
  String get onboarding_tooltip_moderate =>
      'ইসলামি মূল্যবোধ মেনে চলেন এবং নামাজ পড়েন, যদিও সবসময় দিনে পাঁচ ওয়াক্ত নয়';

  @override
  String get onboarding_tooltip_practicing =>
      'পাঁচটি স্তম্ভ অনুসরণ করে, নিয়মিত নামাজ পড়ে, হালাল জীবনধারা';

  @override
  String get onboarding_work_no => 'না, আমি পছন্দ করি না';

  @override
  String get onboarding_work_yes => 'হ্যাঁ, আমি কাজ করার পরিকল্পনা করছি';

  @override
  String get photo_add_main_required => 'প্রধান ছবি যোগ করুন\n(প্রয়োজনীয়)';

  @override
  String get photo_add_photo => 'ছবি যোগ করুন';

  @override
  String get photo_banner_text => 'স্পষ্ট বিষয়বস্তু সহ ফটো অনুমোদিত নয়';

  @override
  String get photo_error_no_face_detected =>
      'কোনো মুখ দৃশ্যমান নয় — দয়া করে একটি পরিষ্কার মুখের ফটো দিয়ে আবার চেষ্টা করুন';

  @override
  String photo_error_pick_failed(Object error) {
    return 'ফটো বাছাই করা যায়নি: $error';
  }

  @override
  String get photo_face_detected => 'মুখ শনাক্ত করা হয়েছে ✓৷';

  @override
  String get photo_label_photo2 => 'ছবি 2';

  @override
  String get photo_label_photo3 => 'ছবি 3';

  @override
  String get photo_label_primary => 'প্রাথমিক ছবি';

  @override
  String get photo_label_selfie => 'ছবি ৪';

  @override
  String get photo_no_face => 'মুখ দেখা যাচ্ছে না';

  @override
  String get photo_privacy_everyone => 'সবার কাছে দৃশ্যমান';

  @override
  String get photo_privacy_everyone_sub => 'সমস্ত সদস্য আপনার ছবি দেখতে পারেন.';

  @override
  String get photo_privacy_label => 'ফটো গোপনীয়তা';

  @override
  String get photo_privacy_mutual => 'পারস্পরিক স্বার্থ পরে দৃশ্যমান';

  @override
  String get photo_privacy_mutual_sub =>
      'ছবি শুধুমাত্র তখনই প্রকাশ করে যখন উভয় পক্ষই আগ্রহ প্রকাশ করে।';

  @override
  String get photo_privacy_request => 'দেখার অনুরোধ রইলো';

  @override
  String get photo_privacy_request_sub =>
      'আপনি একটি অনুরোধ অনুমোদন না করা পর্যন্ত ফটোগুলি অস্পষ্ট হয়৷';

  @override
  String get photo_sheet_camera => 'ক্যামেরা';

  @override
  String get photo_sheet_gallery => 'গ্যালারি';

  @override
  String get photo_sheet_title => 'ছবির উৎস নির্বাচন করুন';

  @override
  String get photo_slots_help => 'আপলোড করতে স্লট ট্যাপ করুন';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'আপনার $relation এর ফটো যোগ করুন। অন্তত একটি প্রয়োজন.';
  }

  @override
  String get photo_subtitle_self => 'অন্তত একটি ফটো প্রয়োজন. সর্বোচ্চ চারটি।';

  @override
  String get photo_title_guardian => 'তাদের ফটো যোগ করুন';

  @override
  String get photo_title_self => 'আপনার ফটো যোগ করুন';

  @override
  String get preferences_deen_any => 'যে কোন';

  @override
  String get preferences_deen_cultural => 'সাংস্কৃতিক মুসলিম';

  @override
  String get preferences_deen_moderate => 'পরিমিত';

  @override
  String get preferences_deen_practicing => 'অনুশীলন করছে';

  @override
  String get preferences_edu_any => 'যে কোন';

  @override
  String get preferences_edu_bachelors => 'স্নাতক +';

  @override
  String get preferences_edu_diploma => 'ডিপ্লোমা +';

  @override
  String get preferences_edu_masters => 'মাস্টার্স +';

  @override
  String get preferences_edu_phd => 'শুধুমাত্র পিএইচডি';

  @override
  String get preferences_edu_secondary => 'মাধ্যমিক +';

  @override
  String get preferences_label_age => 'বয়সের সীমা';

  @override
  String get preferences_label_age_bounds => '18 - 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max বছর';
  }

  @override
  String get preferences_label_deen => 'দীন স্তরের পছন্দ';

  @override
  String get preferences_label_edu => 'ন্যূনতম শিক্ষা';

  @override
  String get preferences_label_living => 'বসবাসের ব্যবস্থা পছন্দ';

  @override
  String get preferences_label_location => 'LOCATION';

  @override
  String get preferences_label_openness => 'উন্মুক্ততা';

  @override
  String get preferences_label_sect => 'SECT পছন্দ';

  @override
  String get preferences_living_discussion => 'আলোচনার জন্য উন্মুক্ত';

  @override
  String get preferences_living_family => 'পরিবারের সাথে';

  @override
  String get preferences_living_no_pref => 'কোন পছন্দ নেই';

  @override
  String get preferences_living_separate => 'আলাদা বাড়ি';

  @override
  String get preferences_location_abroad => 'বিদেশের জন্য উন্মুক্ত';

  @override
  String get preferences_location_diaspora => 'প্রবাসী মোড';

  @override
  String get preferences_location_same_city => 'একই শহর';

  @override
  String get preferences_location_same_country => 'একই দেশ';

  @override
  String get preferences_open_children => 'শিশুদের সঙ্গে কারো জন্য খোলা';

  @override
  String get preferences_open_divorced =>
      'পূর্বে তালাকপ্রাপ্ত কারো জন্য উন্মুক্ত';

  @override
  String get preferences_open_widowed => 'পূর্বে বিধবা কারো জন্য খোলা';

  @override
  String get preferences_sect_any => 'যে কোন';

  @override
  String get preferences_sect_same => 'আমার মত একই';

  @override
  String get preferences_sect_shia => 'শিয়া';

  @override
  String get preferences_sect_sunni => 'সুন্নি';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'আপনার $relation এর আদর্শ ম্যাচের জন্য পছন্দগুলি সেট করুন৷';
  }

  @override
  String get preferences_subtitle_self => 'এগুলি পছন্দ, হার্ড ফিল্টার নয়।';

  @override
  String get preferences_title => 'অংশীদার পছন্দ';

  @override
  String get preview_age_label => 'বয়স';

  @override
  String get preview_background => 'পটভূমি';

  @override
  String get preview_basic_info => 'মৌলিক তথ্য';

  @override
  String get preview_city_label => 'শহর';

  @override
  String get preview_community_label => 'সম্প্রদায়';

  @override
  String get preview_cowife_label => 'সহ-স্ত্রী গ্রহণ';

  @override
  String get preview_deen_label => 'দ্বীন লেভেল';

  @override
  String get preview_diet_label => 'ডায়েট';

  @override
  String get preview_edit => 'সম্পাদনা করুন';

  @override
  String get preview_education_label => 'শিক্ষা';

  @override
  String get preview_faith => 'বিশ্বাস';

  @override
  String get preview_family => 'পরিবার';

  @override
  String get preview_family_type_label => 'পারিবারিক ধরন';

  @override
  String get preview_gender_label => 'লিঙ্গ';

  @override
  String get preview_hijab_label => 'হিজাব';

  @override
  String get preview_hookah_label => 'হুক্কা';

  @override
  String get preview_leadership_label => 'নেতৃত্ব';

  @override
  String get preview_marital_label => 'বৈবাহিক';

  @override
  String get preview_marriage_timeline_label => 'বিয়ের সময়রেখা';

  @override
  String get preview_mother_tongue_label => 'মাতৃভাষা';

  @override
  String get preview_name_label => 'নাম';

  @override
  String get preview_notice_guardian =>
      'অন্যরা তাদের প্রোফাইল দেখতে ঠিক এভাবেই দেখবে।';

  @override
  String get preview_notice_self => 'ঠিক এভাবেই অন্যরা আপনার প্রোফাইল দেখবে।';

  @override
  String get preview_polygamy_label => 'বহুবিবাহ';

  @override
  String get preview_post_marriage_living_label => 'বিবাহ-পরবর্তী জীবনযাপন';

  @override
  String get preview_prays_label => '৫ বার নামাজ পড়ে';

  @override
  String get preview_profession_label => 'পেশা';

  @override
  String get preview_quran_label => 'কুরআন';

  @override
  String get preview_religious_edu_label => 'ধর্মীয় শিক্ষা';

  @override
  String get preview_residency_label => 'রেসিডেন্সি';

  @override
  String get preview_revert_label => 'প্রত্যাবর্তন';

  @override
  String get preview_sect_label => 'সম্প্রদায়';

  @override
  String get preview_siblings_label => 'ভাইবোন';

  @override
  String get preview_smoking_label => 'ধূমপান';

  @override
  String get preview_special_needs_label => 'বিশেষ প্রয়োজন';

  @override
  String get preview_submit_btn => 'প্রোফাইল জমা দিন';

  @override
  String get preview_title => 'পূর্বরূপ';

  @override
  String get preview_vaping_label => 'ভ্যাপিং';

  @override
  String get preview_willing_relocate_label => 'স্থানান্তর করতে ইচ্ছুক';

  @override
  String profile_label_completeness(int percent) {
    return 'প্রোফাইল $percent% সম্পূর্ণ';
  }

  @override
  String get profile_nudge_completeness =>
      '80%+ সম্পূর্ণতা সহ প্রোফাইলগুলি 3× বেশি আগ্রহ পায়।';

  @override
  String get settings_brand_credit =>
      'Silarah (سيلارا) · আল্লাহর সন্তুষ্টির জন্য';

  @override
  String get settings_button_deleteAccount => 'অ্যাকাউন্ট মুছুন';

  @override
  String get settings_guardian_mirror => 'মিরর বার্তা';

  @override
  String get settings_guardian_mirror_sub =>
      'অভিভাবককে সমস্ত বার্তার কপি পাঠান';

  @override
  String get settings_guardian_name_hint => 'অভিভাবকের নাম';

  @override
  String get settings_guardian_relationship => 'সম্পর্ক';

  @override
  String get settings_guardian_reply => 'অভিভাবককে উত্তর দেওয়ার অনুমতি দিন';

  @override
  String get settings_guardian_reply_sub =>
      'অভিভাবক কথোপকথনে অংশগ্রহণ করতে পারেন';

  @override
  String get settings_guardian_save => 'অভিভাবক সেটিংস সংরক্ষণ করুন';

  @override
  String get settings_guardian_saved => 'সংরক্ষিত';

  @override
  String get settings_guardian_sub =>
      'বার্তা পাঠানোর জন্য ওয়ালি তদারকি সক্ষম করুন৷';

  @override
  String get settings_guardian_title => 'অভিভাবক মোড';

  @override
  String get settings_label_blocked => 'ব্লক করা প্রোফাইল';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count ব্লক করা হয়েছে';
  }

  @override
  String get settings_label_blocked_none => 'কোনোটিই নয়';

  @override
  String get settings_label_deleteGrace =>
      'আপনার প্রোফাইল অবিলম্বে লুকানো হবে. আপনার ডেটা 30 দিন পরে স্থায়ীভাবে মুছে ফেলা হবে।';

  @override
  String get settings_label_editProfile => 'প্রোফাইল সম্পাদনা করুন';

  @override
  String get settings_label_language => 'ভাষা';

  @override
  String get settings_label_photoPrivacy => 'ছবির গোপনীয়তা';

  @override
  String get settings_label_rate => 'Silarah রেট দিন';

  @override
  String get settings_label_rate_snackbar =>
      'অ্যাপ স্টোরে Silarah চালু হলেই রেটিং পাওয়া যাবে।';

  @override
  String get settings_label_reports => 'রিপোর্ট ইতিহাস';

  @override
  String settings_label_reports_count(Object count) {
    return '$count রিপোর্ট';
  }

  @override
  String get settings_label_reports_none => 'কোন রিপোর্ট জমা দেওয়া';

  @override
  String get settings_label_selfieChallenge => 'সেলফি চ্যালেঞ্জ';

  @override
  String get settings_label_verifyProfile => 'প্রোফাইল যাচাই করুন';

  @override
  String get settings_label_version => 'সংস্করণ';

  @override
  String get settings_notify_activityNudges => 'কার্যকলাপ নাজ';

  @override
  String get settings_notify_activityNudgesSub =>
      'প্রোফাইল সম্পূর্ণ করার টিপস এবং ৭ দিন নিষ্ক্রিয় থাকলে মনে করানো';

  @override
  String get settings_notify_boostReminders => 'বুস্ট রিমাইন্ডার';

  @override
  String get settings_notify_boostRemindersSub =>
      'আপনার সাপ্তাহিক বুস্ট প্রস্তুত হলে মনে করিয়ে দিন';

  @override
  String get settings_notify_interestAccepted => 'আগ্রহ গৃহীত';

  @override
  String get settings_notify_interestExpiring =>
      'আগ্রহের মেয়াদ শীঘ্রই শেষ হচ্ছে';

  @override
  String get settings_notify_newInterest => 'নতুন আগ্রহ';

  @override
  String get settings_notify_newMessage => 'নতুন বার্তা';

  @override
  String get settings_notify_quietHours => 'শান্ত ঘন্টা';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'গৃহীত স্বার্থ শুধুমাত্র';

  @override
  String get settings_photo_privacy_after_acceptance => 'গ্রহণের পর';

  @override
  String get settings_photo_privacy_everyone => 'সবাই';

  @override
  String get settings_photo_privacy_public => 'পাবলিক';

  @override
  String get settings_photo_privacy_request_only => 'শুধুমাত্র অনুরোধ';

  @override
  String get settings_photo_privacy_request_to_view => 'দেখার অনুরোধ রইলো';

  @override
  String get settings_privacy_download_body =>
      'আপনার অ্যাকাউন্ট, প্রোফাইল, ছবি, আগ্রহ, ম্যাচ, বার্তা, সেটিংস, সম্মতি ও সাবস্ক্রিপশন ইতিহাসের একটি ব্যক্তিগত ZIP আর্কাইভ এখনই তৈরি করুন। ডিভাইসের নিরাপদ শেয়ার শিট দিয়ে এটি সংরক্ষণ করুন।';

  @override
  String get settings_privacy_download_btn => 'নিরাপদ আর্কাইভ তৈরি করুন';

  @override
  String get settings_privacy_download_label => 'আমার ডেটা ডাউনলোড করুন';

  @override
  String get settings_privacy_download_sub =>
      'আপনার Silarah ডেটার মেশিন-পঠনযোগ্য কপি সংরক্ষণ করুন';

  @override
  String get settings_privacy_export_body =>
      'আপনার ব্যক্তিগত আর্কাইভ প্রস্তুত। নিরাপদে সংরক্ষণ করতে শেয়ার শিট ব্যবহার করুন।';

  @override
  String get settings_privacy_export_btn_close => 'বোঝা গেল';

  @override
  String get settings_privacy_export_subbody =>
      'এই আর্কাইভে ব্যক্তিগত বার্তা ও যোগাযোগের তথ্য থাকতে পারে। নিরাপদে রাখুন এবং শুধু বিশ্বস্ত ব্যক্তির সঙ্গে ভাগ করুন।';

  @override
  String get settings_privacy_export_title => 'আর্কাইভ প্রস্তুত';

  @override
  String get settings_privacy_online_label => 'অনলাইন স্ট্যাটাস';

  @override
  String get settings_privacy_online_sub =>
      'আপনি শেষ কবে সক্রিয় ছিলেন তা দেখান';

  @override
  String get settings_privacy_pause_label => 'প্রোফাইল পজ';

  @override
  String get settings_privacy_pause_sub =>
      'অনুসন্ধান থেকে আপনার প্রোফাইল লুকান';

  @override
  String get settings_privacy_pause_warning =>
      'আপনার প্রোফাইল লুকানো আছে. কেউ তোমাকে খুঁজে পাবে না।';

  @override
  String get settings_privacy_photo_label => 'ফটো দৃশ্যমানতা';

  @override
  String get settings_privacy_photo_sub => 'যারা আপনার ছবি দেখতে পারেন';

  @override
  String get settings_privacy_visibility_all => 'সমস্ত নিবন্ধিত ব্যবহারকারী';

  @override
  String get settings_privacy_visibility_label => 'কে আমার প্রোফাইল দেখতে পারে';

  @override
  String get settings_privacy_visibility_sub =>
      'কে আপনার প্রোফাইল ব্রাউজ করতে পারে তা নিয়ন্ত্রণ করে';

  @override
  String get settings_privacy_visibility_subscribers => 'শুধুমাত্র গ্রাহকরা';

  @override
  String get settings_relation_brother => 'ভাই';

  @override
  String get settings_relation_father => 'বাবা';

  @override
  String get settings_relation_mother => 'মা';

  @override
  String get settings_relation_other => 'অন্যান্য';

  @override
  String get settings_relation_uncle => 'চাচা';

  @override
  String get settings_section_account => 'হিসাব';

  @override
  String get settings_section_app => 'অ্যাপ';

  @override
  String get settings_section_dangerZone => 'অ্যাকাউন্ট বন্ধ করুন';

  @override
  String get settings_section_guardian => 'অভিভাবক';

  @override
  String get settings_section_legal => 'আইনি';

  @override
  String get settings_section_notifications => 'বিজ্ঞপ্তি';

  @override
  String get settings_section_privacy => 'গোপনীয়তা';

  @override
  String get settings_section_safety => 'নিরাপত্তা';

  @override
  String get settings_support_body =>
      'যেকোনো প্রশ্ন, উদ্বেগ বা প্রতিক্রিয়ার জন্য:';

  @override
  String get settings_support_btn_close => 'বন্ধ';

  @override
  String get settings_support_contact => 'সহায়তার সাথে যোগাযোগ করুন';

  @override
  String get settings_support_note =>
      'আমরা 48 ঘন্টার মধ্যে প্রতিক্রিয়া জানাতে চাই।';

  @override
  String get settings_title => 'সেটিংস';

  @override
  String get splash_button_createProfile => 'প্রোফাইল তৈরি করুন';

  @override
  String get splash_button_signIn => 'সাইন ইন করুন';

  @override
  String get splash_intention_subtitle =>
      'ব্যক্তিগত পরিচয়, বিবেচনাপূর্ণ সামঞ্জস্য এবং পরিবার-সচেতন সংযোগ।';

  @override
  String get splash_intention_title => 'বিয়ে, সচেতন অভিপ্রায়ে।';

  @override
  String get splash_referral_button => 'কোড প্রয়োগ করুন';

  @override
  String get splash_referral_hint => 'যেমন SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'অনুগ্রহ করে একটি বৈধ 6-অক্ষরের কোড লিখুন।';

  @override
  String get splash_referral_question => 'একটি রেফারেল কোড আছে?';

  @override
  String get splash_referral_saved =>
      'রেফারেল কোড সংরক্ষিত! আপনি সাইন ইন করার পরে এটি প্রয়োগ করা হবে।';

  @override
  String get splash_referral_subtitle =>
      'যদি কোনো বন্ধু আপনাকে Silarah-এ আমন্ত্রণ জানায়, নিচে তাদের 6-অক্ষরের রেফারেল কোড লিখুন।';

  @override
  String get splash_referral_title => 'রেফারেল কোড লিখুন';

  @override
  String subscription_button_monthly(String price) {
    return 'সদস্যতা নিন — $price/মাস';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'সদস্যতা নিন — $price/৩ মাস';
  }

  @override
  String get subscription_label_bestValue => 'শ্রেষ্ঠ মান';

  @override
  String get subscription_subtitle =>
      'নারী বার্তা বিনামূল্যে. পুরুষদের সংযোগ সাবস্ক্রাইব.';

  @override
  String get subscription_title => 'আনলক করুন Silarah';

  @override
  String get startup_connectivity_preparing_title =>
      'আপনার ব্যক্তিগত স্থান প্রস্তুত হচ্ছে';

  @override
  String get startup_connectivity_preparing_body =>
      'সিলারাহর সাথে নিরাপদ সংযোগ স্থাপন করা হচ্ছে।';

  @override
  String get startup_connectivity_offline_title => 'সংযোগের অপেক্ষায়';

  @override
  String get startup_connectivity_offline_body =>
      'আপনার প্রোফাইল, আগ্রহ ও কথোপকথন নিরাপদ আছে। আপনি আবার অনলাইনে এলেই সিলারাহ ঠিক যেখানে থেমেছিলেন সেখান থেকে শুরু করবে।';

  @override
  String get startup_connectivity_verifying => 'সংযোগ যাচাই হচ্ছে';

  @override
  String get startup_connectivity_waiting => 'নেটওয়ার্কের অপেক্ষায়';

  @override
  String get startup_connectivity_still_waiting =>
      'এখনও অফলাইন · আবার চেষ্টা চলছে';

  @override
  String get startup_connectivity_check => 'আবার চেষ্টা করুন';

  @override
  String get startup_connectivity_checking => 'যাচাই হচ্ছে…';

  @override
  String get startup_connectivity_auto =>
      'নেটওয়ার্ক ফিরলেই আমরা নিজে থেকে আবার সংযোগ করব।';

  @override
  String get startup_connectivity_tip =>
      'Wi-Fi বা মোবাইল ডেটা চালু আছে কি না দেখে নিন।';

  @override
  String get startup_connectivity_protected => 'সুরক্ষিত সংযোগ';

  @override
  String get settings_label_email => 'ইমেইল';

  @override
  String get settings_notify_profileViews => 'প্রোফাইল দেখা';

  @override
  String get settings_notify_profileViewsSub =>
      'কেউ আপনার প্রোফাইল খুললে ব্যক্তিগত সতর্কতা';

  @override
  String get settings_notify_profileLive => 'প্রোফাইল প্রকাশিত হয়েছে';

  @override
  String get settings_notify_profileLiveSub =>
      'আপনার প্রোফাইল দৃশ্যমান হলে নিশ্চিতকরণ';

  @override
  String get settings_appearance => 'চেহারা';

  @override
  String get settings_helpSupport => 'সহায়তা ও সমর্থন';

  @override
  String get settings_helpCenter => 'সহায়তা কেন্দ্র';

  @override
  String get settings_grievanceOfficer => 'অভিযোগ কর্মকর্তা';

  @override
  String get settings_grievanceResponse =>
      '২৪ ঘণ্টার মধ্যে স্বীকৃতি; অধিকাংশ অভিযোগ ৭ দিনের মধ্যে সমাধান';

  @override
  String get settings_grievanceIndiaNotice =>
      'ভারতে অভিযোগ নিষ্পত্তি সংশোধিত তথ্য প্রযুক্তি (মধ্যস্থতাকারী নির্দেশিকা ও ডিজিটাল মিডিয়া নৈতিকতা বিধি) অনুসরণ করে। জরুরি বেআইনি বা অন্তরঙ্গ বিষয়বস্তুর অভিযোগে আরও কম আইনি সময়সীমা প্রযোজ্য।';

  @override
  String get settings_managePhotoRequests => 'ছবির অনুরোধ পরিচালনা করুন';

  @override
  String get settings_managePhotoRequestsSub =>
      'অ্যাক্সেস অনুমোদন, অনুরোধ প্রত্যাখ্যান বা শেয়ার বাতিল করুন';

  @override
  String get settings_theme_chooseTitle => 'আপনার পরিবেশ বেছে নিন';

  @override
  String get settings_theme_chooseSubtitle =>
      'শুধু রঙের ফিল্টার নয়—একটি সম্পূর্ণ ভিজ্যুয়াল পরিচয়। সব পৃষ্ঠ, ক্ষেত্র ও সিস্টেম কন্ট্রোল একসঙ্গে বদলায়।';

  @override
  String get settings_theme_applied =>
      'সঙ্গে সঙ্গে প্রয়োগ · এই ডিভাইসে সংরক্ষিত';

  @override
  String get settings_reportPending => 'পর্যালোচনাধীন';

  @override
  String get legal_document_terms => 'পরিষেবার শর্তাবলী';

  @override
  String get legal_document_privacy => 'গোপনীয়তা নীতি';

  @override
  String get legal_document_community => 'কমিউনিটি নির্দেশিকা';

  @override
  String get legal_specialCategoryConsent =>
      'সামঞ্জস্যপূর্ণ মিল খোঁজার জন্য Silarah আমার ধর্মীয় তথ্য (মাযহাব, নামাজের অনুশীলন ও ইসলামি পরিচয়) প্রক্রিয়া করুক—এতে আমি স্পষ্ট সম্মতি দিচ্ছি। চুক্তিবদ্ধ সেবাদাতারা শুধু সিলারাহ পরিচালনার জন্য এটি ব্যবহার করে, আচরণভিত্তিক বিজ্ঞাপনের জন্য নয়।';

  @override
  String get onboarding_complexion_fair => 'ফর্সা';

  @override
  String get onboarding_complexion_medium => 'মাঝারি';

  @override
  String get onboarding_complexion_olive => 'জলপাই বর্ণ';

  @override
  String get onboarding_complexion_dark => 'গাঢ়';

  @override
  String get onboarding_residency_citizen => 'নাগরিক';

  @override
  String get onboarding_residency_permanentResident => 'স্থায়ী বাসিন্দা';

  @override
  String get onboarding_residency_workVisa => 'কর্ম ভিসা';

  @override
  String get onboarding_residency_studentVisa => 'শিক্ষার্থী ভিসা';

  @override
  String get onboarding_specialNeeds_none => 'কোনোটিই নয়';

  @override
  String get onboarding_specialNeeds_physical => 'শারীরিক প্রতিবন্ধকতা';

  @override
  String get onboarding_specialNeeds_hearing => 'শ্রবণ প্রতিবন্ধকতা';

  @override
  String get onboarding_specialNeeds_visual => 'দৃষ্টি প্রতিবন্ধকতা';

  @override
  String get onboarding_label_stateRegion => 'রাজ্য / অঞ্চল';

  @override
  String get onboarding_specialNeeds_privacy =>
      'এটি শুধু পারস্পরিক আগ্রহের পরে শেয়ার করা হয়।';

  @override
  String get settings_theme_automatic => 'স্বয়ংক্রিয়';

  @override
  String get settings_theme_automaticDesc =>
      'দিনে হাতির দাঁত ও পান্না, ফোন ডার্ক মোডে থাকলে OLED রাত';

  @override
  String get settings_theme_rose => 'গোলাপ ও গাঁদা';

  @override
  String get settings_theme_roseDesc =>
      'কোমল গোলাপি আভা, গাঢ় গোলাপ ও গাঁদা সোনালি';

  @override
  String get settings_theme_oled => 'OLED রাত';

  @override
  String get settings_theme_oledDesc => 'OLED পর্দার জন্য প্রকৃত কালো';

  @override
  String get settings_theme_ivory => 'হাতির দাঁত ও পান্না';

  @override
  String get settings_theme_ivoryDesc =>
      'উষ্ণ হাতির দাঁত, গাঢ় পান্না ও প্রাচীন সোনা';

  @override
  String get settings_guardian_backendRequired =>
      'অভিভাবক সেটিংসের জন্য নিরাপদ সংযোগ প্রয়োজন।';

  @override
  String get settings_guardian_saveError =>
      'অভিভাবক সেটিংস সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get common_openSettings => 'সেটিংস খুলুন';

  @override
  String get media_cameraAccessOff => 'ক্যামেরা অ্যাক্সেস বন্ধ';

  @override
  String get media_cameraUnavailable => 'ক্যামেরা পাওয়া যাচ্ছে না';

  @override
  String get media_cameraAccessBody =>
      'সেটিংসে ক্যামেরা অ্যাক্সেস দিন, তারপর পরিষ্কার ছবি তুলতে ফিরে আসুন।';

  @override
  String get media_cameraUnavailableBody =>
      'ক্যামেরা খোলা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get media_photoAccessOff => 'ছবির অ্যাক্সেস বন্ধ';

  @override
  String get media_photoAccessBody =>
      'সেটিংসে ক্যামেরা বা ছবির অ্যাক্সেস দিন, তারপর ছবি যোগ করতে ফিরে আসুন।';

  @override
  String get chat_searchHint => 'বার্তা খুঁজুন';

  @override
  String get chat_noConversationsFound => 'কোনো কথোপকথন পাওয়া যায়নি';

  @override
  String get chat_noConversationsFoundBody =>
      'অন্য নাম চেষ্টা করুন বা অনুসন্ধান মুছুন।';

  @override
  String get chat_noConversationsYet => 'এখনও কোনো কথোপকথন নেই';

  @override
  String get chat_noConversationsYetBody =>
      'কথোপকথন শুরু করতে আগ্রহ গ্রহণ করুন বা আপনার আগ্রহ গৃহীত হওয়ার অপেক্ষা করুন।';

  @override
  String get referral_title => 'বন্ধুকে আমন্ত্রণ জানান';

  @override
  String get referral_loading => 'পুরস্কার লোড হচ্ছে';

  @override
  String get referral_heading => 'খবর ছড়ান, প্রিমিয়াম অর্জন করুন!';

  @override
  String get referral_body =>
      'Silarah-এ যেকোনো যোগ্য বন্ধুকে আমন্ত্রণ জানান। প্রতিটি অ্যাকাউন্ট জীবনে একবার ৩ দিনের রেফারেল প্রিমিয়াম পেতে পারে। আপনি নিজের পুরস্কার পেয়ে থাকলেও আপনার বন্ধু তার পুরস্কার পেতে পারবেন।';

  @override
  String get referral_premiumActiveTitle => 'রেফারেল প্রিমিয়াম সক্রিয়';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '$daysদিন $hoursঘণ্টা বাকি';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '$hoursঘণ্টা $minutesমিনিট বাকি';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '$minutesমিনিট বাকি';
  }

  @override
  String get referral_premiumEndingNow => 'পুরস্কার এখন শেষ হচ্ছে';

  @override
  String referral_premiumEndsAt(String date) {
    return 'শেষ হবে $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'সব প্রিমিয়াম সুবিধা চালু আছে। কোনো অর্থ নেওয়া হয়নি এবং এই পুরস্কার স্বয়ংক্রিয়ভাবে নবায়ন হবে না।';

  @override
  String get referral_premiumPlansAfter =>
      'বিনামূল্যের পুরস্কার শেষ হলে সাবস্ক্রিপশন প্ল্যান পাওয়া যাবে, তাই আপনার বাকি বিনামূল্যের সময় নষ্ট হবে না।';

  @override
  String get referral_premiumBackToProfile => 'প্রোফাইলে ফিরে যান';

  @override
  String get referral_premiumFeaturesUnlocked =>
      'সব প্রিমিয়াম সুবিধা চালু আছে';

  @override
  String get referral_premiumViewReward => 'পুরস্কার দেখুন';

  @override
  String get referral_codeLabel => 'আপনার রেফারেল কোড';

  @override
  String get referral_tapToCopy => 'কপি করতে কোডে চাপুন';

  @override
  String get referral_totalInvited => 'মোট আমন্ত্রিত';

  @override
  String get referral_rewardsEarned => 'অর্জিত পুরস্কার';

  @override
  String referral_premiumDays(int count) {
    return '$count প্রিমিয়াম দিন';
  }

  @override
  String get referral_pending => 'অপেক্ষমাণ নিবন্ধন';

  @override
  String get referral_shareButton => 'বন্ধুদের সঙ্গে কোড শেয়ার করুন';

  @override
  String get referral_copied => 'রেফারেল কোড কপি হয়েছে!';

  @override
  String get referral_shareSubject => 'Silarah-এ যোগ দিন';

  @override
  String referral_shareText(String code) {
    return 'বিশ্বস্ত মুসলিম বিবাহ অ্যাপ Silarah-এ যোগ দিন। আমার রেফারেল কোড ব্যবহার করুন: $code\n\nডাউনলোড: https://silarah.com';
  }

  @override
  String get profile_share => 'প্রোফাইল শেয়ার করুন';

  @override
  String safety_reportMember(String name) {
    return '$name-কে রিপোর্ট করুন';
  }

  @override
  String safety_blockMember(String name) {
    return '$name-কে ব্লক করুন';
  }

  @override
  String safety_blockTitle(String name) {
    return '$name-কে ব্লক করবেন?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name ডিসকভারি থেকে লুকানো থাকবে এবং আপনার সঙ্গে যোগাযোগ করতে পারবে না। নিরাপত্তার জন্য চ্যাট ইতিহাস রাখা হবে। আনব্লক করলে কথোপকথন আবার খুলবে না।';
  }

  @override
  String get safety_blockAction => 'ব্লক করুন';

  @override
  String safety_blocked(String name) {
    return '$name-কে ব্লক করা হয়েছে।';
  }

  @override
  String ui_openProfile(String name) {
    return '$name প্রোফাইল খুলুন';
  }

  @override
  String ui_typing(String name) {
    return '$name টাইপ করছে';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'অ্যাকাউন্ট মুছে ফেলতে ব্যর্থ হয়েছে: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'দেশ পরিবর্তন করুন, বর্তমানে $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'কোনো ইমেল অ্যাপ পাওয়া যায়নি। $email কপি করা হয়েছে।';
  }

  @override
  String ui_messagePerson(String name) {
    return 'বার্তা $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'পুনর্নবীকরণ $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age বছর';
  }

  @override
  String ui_photoNumber(int number) {
    return 'ছবি $number';
  }

  @override
  String ui_photoCount(int count) {
    return '4টি ছবির মধ্যে $count';
  }

  @override
  String ui_removeLabel(String label) {
    return '$label সরান';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label নির্বাচিত';
  }

  @override
  String ui_addLabel(String label) {
    return '$label যোগ করুন';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'ছবির অনুরোধ $name এ পাঠানো হয়েছে।';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'গতকাল $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count মিনিট আগে';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count ঘন্টা আগে';
  }

  @override
  String ui_daysAgo(int count) {
    return '$count দিন আগে';
  }

  @override
  String ui_renewsAt(String time) {
    return '$time এ রিনিউ হবে';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'ছবি $number সুরক্ষিত পর্যালোচনার জন্য প্রস্তুত';
  }

  @override
  String get ui_onePhotoUnlock =>
      'একবার আপনি দুজনেই আগ্রহ প্রকাশ করলে 1টি ফটো স্বয়ংক্রিয়ভাবে আনলক হয়ে যাবে।';

  @override
  String ui_manyPhotosUnlock(int count) {
    return '$count ফটোগুলি স্বয়ংক্রিয়ভাবে আনলক হয়ে যাবে যখন আপনি উভয়ে আগ্রহ প্রকাশ করবেন।';
  }

  @override
  String get ui_askOnePhoto =>
      '1টি ছবি দেখার অনুমতির জন্য মালিককে জিজ্ঞাসা করুন৷';

  @override
  String ui_askManyPhotos(int count) {
    return '$count ফটো দেখার অনুমতির জন্য মালিককে জিজ্ঞাসা করুন৷';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet ফুট $inches ইঞ্চি';
  }

  @override
  String ui_minutesShort(int count) {
    return '$countমি';
  }

  @override
  String ui_hoursShort(int count) {
    return '$countঘণ্টা';
  }

  @override
  String ui_daysShort(int count) {
    return '$countদিন';
  }

  @override
  String discovery_filters_count(int count) {
    return 'ফিল্টার ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'আগে $date তারিখে ম্যাচ হয়েছিল';
  }

  @override
  String discovery_rematch_days(int count) {
    return '$count দিনের মধ্যে আবার ম্যাচ করা যাবে';
  }

  @override
  String get settings_notify_compatibleProfiles => 'উপযুক্ত প্রোফাইলের সতর্কতা';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'খালি ডিসকভারি ফিডে নতুন ফলাফল এলে';

  @override
  String get settings_notify_discoveryDigest => 'ডিসকভারি সারসংক্ষেপ';

  @override
  String get settings_notify_digestHelp =>
      'ঐচ্ছিক সারসংক্ষেপ; খালি ফিডে নতুন ফলাফলের সতর্কতা তাৎক্ষণিক থাকবে।';

  @override
  String get settings_notify_digestOff => 'বন্ধ';

  @override
  String get settings_notify_digestDaily => 'দৈনিক';

  @override
  String get settings_notify_digestWeekly => 'সাপ্তাহিক';

  @override
  String get settings_quietHoursStart => 'নীরব সময় শুরু';

  @override
  String get settings_quietHoursEnd => 'নীরব সময় শেষ';

  @override
  String get settings_notify_festivalGreetings => 'উৎসবের শুভেচ্ছা';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'রমজান ও ঈদের শুভেচ্ছা, বছরে প্রায় পাঁচবার';

  @override
  String get profile_quality_tier_complete => 'সম্পূর্ণ';

  @override
  String get profile_quality_tier_strong => 'প্রায় হয়ে গেছে';

  @override
  String get profile_quality_tier_good => 'ভালো অগ্রগতি';

  @override
  String get profile_quality_tier_start => 'শুরু';

  @override
  String profile_quality_ring_semantics(int percent) {
    return 'প্রোফাইল $percent% সম্পূর্ণ';
  }

  @override
  String profile_quality_next_eyebrow(int percent) {
    return 'পরের ধাপ · $percent%-এ পৌঁছান';
  }

  @override
  String profile_quality_points(int points) {
    return '+$points%';
  }

  @override
  String get profile_quality_step_photo => 'প্রোফাইল ছবি যোগ করুন';

  @override
  String get profile_quality_step_bio => 'পরিচিতি যোগ করুন';

  @override
  String get profile_quality_step_deen => 'আপনার ইসলামি পরিচয় সম্পূর্ণ করুন';

  @override
  String get profile_quality_step_education => 'শিক্ষা ও পেশা যোগ করুন';

  @override
  String get profile_quality_step_family => 'পারিবারিক পটভূমি যোগ করুন';

  @override
  String get profile_quality_step_partner => 'জীবনসঙ্গীর পছন্দ ঠিক করুন';

  @override
  String get profile_quality_step_second_photo => 'দ্বিতীয় ছবি যোগ করুন';

  @override
  String get profile_quality_step_income => 'আয়ের সীমা যোগ করুন';

  @override
  String get profile_quality_step_languages => 'ভাষা যোগ করুন';

  @override
  String get profile_quality_complete_title => 'আপনার প্রোফাইল সম্পূর্ণ';

  @override
  String get profile_quality_complete_body =>
      'সব তথ্য ঠিক জায়গায় আছে। সদস্যরা আপনার পুরো গল্প দেখতে পান।';

  @override
  String get profile_quality_tip_verified_benefit =>
      'বিশ্বস্ত মুখ বেশি সাড়া পায়';

  @override
  String get profile_quality_tip_photos_benefit =>
      'বেশি ছবি সদস্যদের হ্যাঁ বলতে সাহায্য করে';

  @override
  String get profile_quality_tip_bio_benefit =>
      'আপনার নিজের কথাই প্রথম ছাপ তৈরি করে';

  @override
  String get profile_quality_tip_guardian_benefit =>
      'পরিবার যুক্ত অভিভাবককে গুরুত্ব দেয়';

  @override
  String get profile_quality_done => 'সম্পন্ন';

  @override
  String get profile_quality_name_fallback => 'আপনার নাম';

  @override
  String get profile_quality_subtitle_fallback =>
      'নিচে আপনার প্রোফাইল সম্পূর্ণ করুন';
}
