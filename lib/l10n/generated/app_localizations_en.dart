// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get guide_optional_details => 'Additional details (optional)';

  @override
  String get guide_optional_details_body =>
      'You can complete these details later from your profile.';

  @override
  String get guide_profile_ownership =>
      'This profile describes the person seeking marriage. A separate Guardian can be invited later for conversation oversight.';

  @override
  String get about_button_later => 'I\'ll do this later';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'Describe your $relation with honesty and dignity.';
  }

  @override
  String get about_hint_bio_self =>
      'Describe yourself with honesty and dignity.';

  @override
  String get about_label_bio_guardian => 'THEIR BIO';

  @override
  String get about_label_bio_self => 'YOUR BIO';

  @override
  String get about_label_interests => 'INTERESTS';

  @override
  String get about_label_languages => 'LANGUAGES SPOKEN';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max selected';
  }

  @override
  String get about_subtitle => 'Write with honesty and dignity.';

  @override
  String about_title_guardian(Object relation) {
    return 'About your $relation';
  }

  @override
  String get about_title_self => 'About you';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'Begin with bismillah';

  @override
  String get auth_button_resendOtp => 'Resend Verification Code';

  @override
  String get auth_button_sendCode => 'Send Verification Code';

  @override
  String get auth_button_sendOtp => 'Send Verification Code';

  @override
  String get auth_button_verifyOtp => 'Verify';

  @override
  String get auth_label_changeNumber => 'Wrong number? Change it';

  @override
  String get auth_label_enterOtp =>
      'Enter the 6-digit verification code sent to';

  @override
  String get auth_label_resendCode => 'Resend verification code';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'Resend verification code in ${seconds}s';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get auth_label_sentCodeTo =>
      'We sent a 6-digit verification code to\n';

  @override
  String get auth_subtitle_verifyOtp =>
      'We\'ll verify it with a one-time code.';

  @override
  String get auth_title_enterCode => 'Enter your verification code';

  @override
  String get auth_title_yourNumber => 'Your number';

  @override
  String get background_edu_bachelors => 'Bachelor\'s Degree';

  @override
  String get background_edu_below_secondary => 'Below Secondary';

  @override
  String get background_edu_diploma => 'Diploma / Associate';

  @override
  String get background_edu_doctorate => 'Doctorate / PhD';

  @override
  String get background_edu_higher_secondary => 'Higher Secondary / A-Level';

  @override
  String get background_edu_masters => 'Master\'s Degree';

  @override
  String get background_edu_secondary => 'Secondary / O-Level';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'Tell us about your $relation\'s education and career.';
  }

  @override
  String get background_edu_subtitle_self =>
      'Helps find professionally compatible matches.';

  @override
  String get background_edu_title_guardian => 'Their background';

  @override
  String get background_edu_title_self => 'Your background';

  @override
  String get background_emp_employed => 'Employed';

  @override
  String get background_emp_not_working => 'Not working';

  @override
  String get background_emp_self_employed => 'Self-employed';

  @override
  String get background_emp_student => 'Student';

  @override
  String get background_income_subtitle =>
      'Many people skip this — it\'s entirely optional.';

  @override
  String get background_label_eduLevel => 'EDUCATION LEVEL';

  @override
  String get background_label_employment => 'EMPLOYMENT STATUS';

  @override
  String background_label_income_bracket(Object currency) {
    return 'INCOME BRACKET ($currency)';
  }

  @override
  String get background_label_income_range => 'INCOME RANGE  (Optional)';

  @override
  String get background_label_profession => 'Profession  (Optional)';

  @override
  String get background_label_study => 'Field of study  (Optional)';

  @override
  String get background_label_who_see => 'WHO CAN SEE THIS?';

  @override
  String get background_vis_everyone => 'Show bracket to everyone';

  @override
  String get background_vis_mutual => 'Show only after mutual interest';

  @override
  String get background_vis_private => 'Keep private';

  @override
  String get ceremony_text_blessing => 'May Allah bless this with goodness';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. I wanted to be honest and respectful with you. I do not think we are the right match, but I pray that Allah opens better doors for you. Wishing you all the best.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. I hope you find someone truly right for you. May Allah make it easy for you. JazakAllah khair for your time.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. I do not see this progressing further, but I truly appreciate your time and wish you every happiness. May Allah bless you.';

  @override
  String get chat_endMatch_button => 'Send & End Match';

  @override
  String get chat_endMatch_subtitle =>
      'Choose a respectful message to close this conversation. The other person will be notified.';

  @override
  String get chat_endMatch_title => 'End this match';

  @override
  String chat_label_probation(int hours) {
    return 'Messaging unlocks in $hours hours. You can send Interests now.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Subscribe to unlock messaging. Women always message free on Silarah.';

  @override
  String get chat_matchClosed_banner =>
      'This match has been respectfully closed.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! I came across your profile and was genuinely impressed. May I introduce myself?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Your profile caught my attention. I would love to learn more about you.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. I believe we share similar values. Would you be open to getting to know each other?';

  @override
  String get chat_placeholder_typeMessage => 'Type a message…';

  @override
  String get common_button_back => 'Back';

  @override
  String get common_button_cancel => 'Cancel';

  @override
  String get common_button_done => 'Done';

  @override
  String get common_button_next => 'Next';

  @override
  String get common_button_retry => 'Try Again';

  @override
  String get common_button_save => 'Save';

  @override
  String get common_button_skip => 'Skip';

  @override
  String get common_button_submit => 'Submit';

  @override
  String get common_error_generic => 'Something went wrong. Please try again.';

  @override
  String get common_error_noInternet =>
      'No internet connection. Please check your connection.';

  @override
  String get common_label_optional => 'Optional';

  @override
  String get copy_beard_parent => 'Does your son have a beard?';

  @override
  String get copy_beard_self => 'Do you have a beard?';

  @override
  String get copy_beard_sibling => 'Does your brother have a beard?';

  @override
  String get copy_hijab_parent => 'Does your daughter observe hijab?';

  @override
  String get copy_hijab_self => 'Do you observe hijab?';

  @override
  String get copy_hijab_sibling => 'Does your sister observe hijab?';

  @override
  String get copy_prayer_parent => 'Does your child pray five times daily?';

  @override
  String get copy_prayer_self => 'Do you pray five times daily?';

  @override
  String get copy_prayer_sibling => 'Does your sibling pray five times daily?';

  @override
  String get deleteAccount_title => 'Delete Account';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name removed';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name saved';
  }

  @override
  String get discovery_button_sendInterest => 'Send Interest';

  @override
  String get discovery_completeness_button => 'Complete Profile';

  @override
  String get discovery_completeness_subtitle =>
      'Profiles above 40% get 3× more interests.\nComplete your profile to start browsing.';

  @override
  String get discovery_completeness_title => 'Complete Your Profile';

  @override
  String get discovery_empty_subtitle =>
      'New members join Silarah every day. Check back tomorrow for fresh profiles, or widen your preferences to meet more people now.';

  @override
  String get discovery_empty_filtered_eyebrow => 'REFINE YOUR SEARCH';

  @override
  String get discovery_empty_filtered_title =>
      'No one matches these filters yet';

  @override
  String get discovery_empty_filtered_subtitle =>
      'Your preferences are narrowing the circle. Relaxing just one filter usually brings new profiles right away.';

  @override
  String get discovery_empty_clear_filters => 'Clear all filters';

  @override
  String get discovery_empty_refresh => 'Refresh profiles';

  @override
  String get discovery_empty_adjust_filters => 'Adjust filters';

  @override
  String get discovery_empty_hint_trust => 'Try relaxing Trust checks first';

  @override
  String get discovery_empty_hint_deen => 'Try widening Deen level first';

  @override
  String get discovery_empty_hint_family => 'Try widening Family type first';

  @override
  String get discovery_empty_hint_sect => 'Try opening up Sect first';

  @override
  String get discovery_empty_hint_location => 'Try a wider location first';

  @override
  String get discovery_empty_hint_age => 'Try a wider age range first';

  @override
  String get discovery_empty_hint_other => 'Try relaxing one filter at a time';

  @override
  String get discovery_empty_eyebrow => 'ALL CAUGHT UP';

  @override
  String get discovery_empty_title => 'You\'ve seen everyone for today';

  @override
  String get discovery_handoff_interest_subtitle =>
      'Profiles with an active request move to Interests while you wait or respond.';

  @override
  String get discovery_handoff_interest_title => 'Your interest is in progress';

  @override
  String get discovery_handoff_match_subtitle =>
      'Matched profiles move to Chat, so they are not shown again in Discover.';

  @override
  String get discovery_handoff_match_title => 'Your connection is ready';

  @override
  String get discovery_handoff_open_chat => 'Open Chat';

  @override
  String get discovery_handoff_open_interests => 'Open Interests';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'Interest Sent ✓';

  @override
  String get discovery_label_outsidePrefs => 'Someone you might connect with';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profiles remaining today';
  }

  @override
  String get discovery_limit_button => 'Upgrade Now';

  @override
  String get discovery_limit_subtitle =>
      'You\'ve browsed 15 profiles today.\nUpgrade to unlock unlimited browsing.';

  @override
  String get discovery_limit_title => 'Daily limit reached';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count profiles remaining';
  }

  @override
  String get discovery_wildcard_label => 'Someone you might connect with';

  @override
  String get family_children_no => 'No';

  @override
  String get family_children_yes => 'Yes';

  @override
  String get family_label_children_guardian => 'DO THEY HAVE CHILDREN?';

  @override
  String get family_label_children_self => 'DO YOU HAVE CHILDREN?';

  @override
  String get family_label_how_many => 'HOW MANY?';

  @override
  String get family_label_parents => 'PARENTS\' MARITAL STATUS';

  @override
  String get family_label_polygamy_female_self =>
      'POLYGAMY ACCEPTANCE  (Optional)';

  @override
  String get family_label_polygamy_male_self => 'POLYGAMY STATUS  (Optional)';

  @override
  String get family_label_prev_married => 'PREVIOUSLY MARRIED?';

  @override
  String get family_label_relocate => 'WILLING TO RELOCATE';

  @override
  String get family_label_siblings => 'NUMBER OF SIBLINGS';

  @override
  String get family_label_type => 'FAMILY TYPE';

  @override
  String get family_living_title => 'POST-MARRIAGE LIVING EXPECTATIONS';

  @override
  String get family_parents_both_deceased => 'Both deceased';

  @override
  String get family_parents_divorced => 'Divorced';

  @override
  String get family_parents_father_deceased => 'Father deceased';

  @override
  String get family_parents_mother_deceased => 'Mother deceased';

  @override
  String get family_parents_separated => 'Separated';

  @override
  String get family_parents_together => 'Together';

  @override
  String get family_polygamy_female_discussion => 'Open to discussion';

  @override
  String get family_polygamy_female_no => 'No';

  @override
  String get family_polygamy_female_prefer_not => 'Prefer not to say';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'Would your $relation consider being a co-wife?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'Would you consider being a co-wife?';

  @override
  String get family_polygamy_female_yes => 'Yes';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'Is your $relation currently married and looking for an additional spouse?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'Are you currently married and looking for an additional spouse?';

  @override
  String get family_polygamy_option_first => 'No, this is my first';

  @override
  String get family_polygamy_option_married => 'Yes, currently married';

  @override
  String get family_polygamy_option_prefer_not => 'Prefer not to say';

  @override
  String get family_prev_divorced => 'Divorced';

  @override
  String get family_prev_no => 'No';

  @override
  String get family_prev_widowed => 'Widowed';

  @override
  String get family_relocate_discussion => 'Open to Discussion';

  @override
  String get family_relocate_no => 'No';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'Would your $relation relocate for marriage?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'Would you relocate for marriage?';

  @override
  String get family_relocate_yes => 'Yes';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'Tell us about your $relation\'s family.';
  }

  @override
  String get family_subtitle_self =>
      'Family compatibility is central to lasting marriages.';

  @override
  String get family_title_guardian => 'Family background';

  @override
  String get family_title_self => 'Family background';

  @override
  String get family_type_extended => 'Extended';

  @override
  String get family_type_joint => 'Joint';

  @override
  String get family_type_nuclear => 'Nuclear';

  @override
  String get filter_label_community => 'Community / Biradari';

  @override
  String get filter_label_livingExpectation => 'Post-Marriage Living';

  @override
  String get filter_label_motherTongue => 'Mother Tongue';

  @override
  String get guardian_details_candidate_female =>
      'Female candidate • Women message free';

  @override
  String get guardian_details_candidate_label => 'CREATING PROFILE FOR';

  @override
  String get guardian_details_candidate_male => 'Male candidate';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'My $relation';
  }

  @override
  String get guardian_details_involvement => 'GUARDIAN INVOLVEMENT';

  @override
  String get guardian_details_involvement_subtitle =>
      'How involved do you want to be in conversations?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'See chats, approve matches, and send messages on behalf of your $relation.';
  }

  @override
  String get guardian_details_mode_active_title => 'Active guardian';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'See all chats in real-time, but only your $relation can send messages.';
  }

  @override
  String get guardian_details_mode_passive_title => 'Observe only';

  @override
  String get guardian_details_name_hint => 'Full name';

  @override
  String get guardian_details_name_subtitle =>
      'Your name as the guardian. This is shown to matches.';

  @override
  String guardian_details_notice(Object relation) {
    return 'You are creating a profile for your $relation. All profile details on the next screens will describe them, not you.';
  }

  @override
  String get guardian_details_search_hint => 'Search';

  @override
  String get guardian_details_select_code => 'Select country code';

  @override
  String get guardian_details_subtitle =>
      'Tell us about yourself as the guardian.';

  @override
  String get guardian_details_title => 'Your guardian details';

  @override
  String get guardian_details_your_name => 'YOUR NAME';

  @override
  String get interest_cat_creative => 'Creative';

  @override
  String get interest_cat_faith => 'Faith';

  @override
  String get interest_cat_learning => 'Learning';

  @override
  String get interest_cat_lifestyle => 'Lifestyle';

  @override
  String get interest_cat_social => 'Social';

  @override
  String get interest_cat_sports => 'Sports';

  @override
  String get interest_tag_art => 'Art';

  @override
  String get interest_tag_calligraphy => 'Calligraphy';

  @override
  String get interest_tag_community_work => 'Community work';

  @override
  String get interest_tag_cooking => 'Cooking';

  @override
  String get interest_tag_crafts => 'Crafts';

  @override
  String get interest_tag_cricket => 'Cricket';

  @override
  String get interest_tag_cycling => 'Cycling';

  @override
  String get interest_tag_dawah => 'Dawah';

  @override
  String get interest_tag_family_gatherings => 'Family gatherings';

  @override
  String get interest_tag_fitness => 'Fitness';

  @override
  String get interest_tag_football => 'Football';

  @override
  String get interest_tag_gardening => 'Gardening';

  @override
  String get interest_tag_graphic_design => 'Graphic design';

  @override
  String get interest_tag_hiking => 'Hiking';

  @override
  String get interest_tag_history => 'History';

  @override
  String get interest_tag_islamic_lectures => 'Islamic lectures';

  @override
  String get interest_tag_languages => 'Languages';

  @override
  String get interest_tag_martial_arts => 'Martial arts';

  @override
  String get interest_tag_mentoring => 'Mentoring';

  @override
  String get interest_tag_photography => 'Photography';

  @override
  String get interest_tag_poetry => 'Poetry';

  @override
  String get interest_tag_quran_recitation => 'Quran recitation';

  @override
  String get interest_tag_reading => 'Reading';

  @override
  String get interest_tag_science => 'Science';

  @override
  String get interest_tag_swimming => 'Swimming';

  @override
  String get interest_tag_tahajjud => 'Tahajjud';

  @override
  String get interest_tag_teaching => 'Teaching';

  @override
  String get interest_tag_technology => 'Technology';

  @override
  String get interest_tag_travel => 'Travel';

  @override
  String get interest_tag_umrah_hajj => 'Umrah/Hajj';

  @override
  String get interest_tag_voluntary_fasting => 'Voluntary fasting';

  @override
  String get interest_tag_volunteering => 'Volunteering';

  @override
  String get interest_tag_writing => 'Writing';

  @override
  String get interests_button_accept => 'Accept';

  @override
  String get interests_button_decline => 'Decline';

  @override
  String get interests_tab_received => 'Received';

  @override
  String get interests_tab_sent => 'Sent';

  @override
  String get interests_title => 'Interests';

  @override
  String get lang_albanian => 'Albanian';

  @override
  String get lang_amazigh => 'Amazigh (Berber)';

  @override
  String get lang_amharic => 'Amharic';

  @override
  String get lang_arabic => 'Arabic';

  @override
  String get lang_assamese => 'Assamese';

  @override
  String get lang_balochi => 'Balochi';

  @override
  String get lang_bengali => 'Bengali';

  @override
  String get lang_bosnian => 'Bosnian';

  @override
  String get lang_burmese => 'Burmese';

  @override
  String get lang_chechen => 'Chechen';

  @override
  String get lang_chinese => 'Chinese (Mandarin)';

  @override
  String get lang_dari => 'Dari';

  @override
  String get lang_dutch => 'Dutch';

  @override
  String get lang_english => 'English';

  @override
  String get lang_french => 'French';

  @override
  String get lang_fulani => 'Fulani';

  @override
  String get lang_german => 'German';

  @override
  String get lang_gujarati => 'Gujarati';

  @override
  String get lang_hausa => 'Hausa';

  @override
  String get lang_hindi => 'Hindi';

  @override
  String get lang_igbo => 'Igbo';

  @override
  String get lang_indonesian => 'Indonesian';

  @override
  String get lang_italian => 'Italian';

  @override
  String get lang_japanese => 'Japanese';

  @override
  String get lang_javanese => 'Javanese';

  @override
  String get lang_kannada => 'Kannada';

  @override
  String get lang_kazakh => 'Kazakh';

  @override
  String get lang_korean => 'Korean';

  @override
  String get lang_kurdish => 'Kurdish';

  @override
  String get lang_kyrgyz => 'Kyrgyz';

  @override
  String get lang_malay => 'Malay';

  @override
  String get lang_malayalam => 'Malayalam';

  @override
  String get lang_mandinka => 'Mandinka';

  @override
  String get lang_marathi => 'Marathi';

  @override
  String get lang_norwegian => 'Norwegian';

  @override
  String get lang_odia => 'Odia';

  @override
  String get lang_other => 'Other';

  @override
  String get lang_pashto => 'Pashto';

  @override
  String get lang_persian => 'Persian';

  @override
  String get lang_portuguese => 'Portuguese';

  @override
  String get lang_punjabi => 'Punjabi';

  @override
  String get lang_rohingya => 'Rohingya';

  @override
  String get lang_russian => 'Russian';

  @override
  String get lang_saraiki => 'Saraiki';

  @override
  String get lang_sindhi => 'Sindhi';

  @override
  String get lang_somali => 'Somali';

  @override
  String get lang_spanish => 'Spanish';

  @override
  String get lang_sundanese => 'Sundanese';

  @override
  String get lang_swahili => 'Swahili';

  @override
  String get lang_swedish => 'Swedish';

  @override
  String get lang_tagalog => 'Tagalog';

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
  String get lang_tigrinya => 'Tigrinya';

  @override
  String get lang_turkish => 'Turkish';

  @override
  String get lang_urdu => 'Urdu';

  @override
  String get lang_uzbek => 'Uzbek';

  @override
  String get lang_wolof => 'Wolof';

  @override
  String get lang_yoruba => 'Yoruba';

  @override
  String get legal_button_continue => 'Continue';

  @override
  String get legal_checkbox_age => 'I confirm I am 18 years or older';

  @override
  String get legal_checkbox_terms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get legal_subtitle => 'Please read and agree to continue.';

  @override
  String get legal_summary_1 =>
      'Your data is encrypted and never sold to third parties.';

  @override
  String get legal_summary_2 =>
      'Every photo is safety-checked, and our team reviews new uploads.';

  @override
  String get legal_summary_3 =>
      'Harassment, fake profiles, and scams result in permanent bans.';

  @override
  String get legal_summary_4 =>
      'This platform is for marriage intentions only. Dignity is the standard.';

  @override
  String get legal_summary_5 =>
      'You may delete your account and all data at any time.';

  @override
  String get legal_title => 'Before you begin';

  @override
  String get notifications_empty_subtitle => 'No new notifications right now.';

  @override
  String get notifications_empty_title => 'You\'re all caught up';

  @override
  String get notifications_markAllRead => 'Mark all read';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get onboarding_about_title => 'About yourself';

  @override
  String get onboarding_background_title => 'Education & Career';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'You are filling this as a guardian. These details are about your $relation.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'This is what others will see on their profile.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'This is what others will see on your profile.';

  @override
  String get onboarding_basicIdentity_title => 'Tell us about yourself';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Tell us about your $relation';
  }

  @override
  String get onboarding_debt_manageable => 'Manageable debt';

  @override
  String get onboarding_debt_none => 'No debt';

  @override
  String get onboarding_debt_significant => 'Significant debt';

  @override
  String get onboarding_diet_eatsAnything => 'Eats anything halal';

  @override
  String get onboarding_diet_halalOnly => 'Halal only';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarian';

  @override
  String get onboarding_diet_zabihaStrict => 'Strict Zabiha';

  @override
  String get onboarding_error_bioContactInfo =>
      'Please remove contact information from your bio. External contact details are not allowed for your safety.';

  @override
  String get onboarding_error_multipleFaces =>
      'Group photos cannot be your primary photo.';

  @override
  String get onboarding_error_noFace =>
      'Please use a photo where your face is clearly visible.';

  @override
  String get onboarding_error_under18 =>
      'Silarah is for those 18 and older. We\'ve made this requirement to protect everyone in our community.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Your $relation must be 18 or older to use Silarah.';
  }

  @override
  String get onboarding_error_under18_self =>
      'You must be 18 or older to use Silarah. We look forward to welcoming you then.';

  @override
  String get onboarding_habit_frequently => 'Frequently';

  @override
  String get onboarding_habit_never => 'Never';

  @override
  String get onboarding_habit_occasionally => 'Occasionally';

  @override
  String get onboarding_habit_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_hijab_always => 'Always';

  @override
  String get onboarding_hijab_no => 'No';

  @override
  String get onboarding_hijab_sometimes => 'Sometimes';

  @override
  String get onboarding_hint_bio =>
      'Describe yourself with honesty and dignity.';

  @override
  String get onboarding_hint_profession =>
      'e.g. Software Engineer, Teacher, Doctor';

  @override
  String get onboarding_hint_searchCity => 'Search your city…';

  @override
  String get onboarding_hint_selectCommunity => 'Select community (optional)';

  @override
  String get onboarding_hint_selectCountry => 'Select country';

  @override
  String get onboarding_hint_selectDateOfBirth => 'Select date of birth';

  @override
  String get onboarding_hint_selectLanguage => 'Select language';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'This helps match you with someone compatible.';

  @override
  String get onboarding_islamicIdentity_title => 'Your Islamic identity';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'City';

  @override
  String get onboarding_label_city_guardian => 'Their city';

  @override
  String get onboarding_label_city_self => 'Your city';

  @override
  String get onboarding_label_community => 'Your community / biradari';

  @override
  String get onboarding_label_community_parent => 'Their community / biradari';

  @override
  String get onboarding_label_complexion => 'Complexion (Optional)';

  @override
  String get onboarding_label_country_guardian => 'Their country';

  @override
  String get onboarding_label_country_self => 'Your country';

  @override
  String get onboarding_label_cultural => 'Cultural Muslim';

  @override
  String get onboarding_label_dateOfBirth => 'Date of Birth';

  @override
  String get onboarding_label_debtStatus => 'Debt Status';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Your current financial obligations.';

  @override
  String get onboarding_label_deenLevel => 'Deen Level';

  @override
  String get onboarding_label_diet => 'Diet';

  @override
  String get onboarding_label_educationLevel => 'Education Level';

  @override
  String get onboarding_label_female => 'Female';

  @override
  String get onboarding_label_firstName => 'First name';

  @override
  String get onboarding_label_firstName_guardian => 'Candidate\'s first name';

  @override
  String get onboarding_label_firstName_self => 'First name';

  @override
  String get onboarding_label_gender => 'Gender';

  @override
  String get onboarding_label_gender_guardian => 'Candidate\'s gender';

  @override
  String get onboarding_label_gender_self => 'Gender';

  @override
  String get onboarding_label_height_guardian => 'Their height';

  @override
  String get onboarding_label_height_self => 'Your height';

  @override
  String get onboarding_label_hookah => 'Hookah / Shisha';

  @override
  String get onboarding_label_housing => 'Housing';

  @override
  String get onboarding_label_housingQuestion =>
      'Can you provide a separate living space?';

  @override
  String get onboarding_label_lastName => 'Last name';

  @override
  String get onboarding_label_leadership => 'Religious Leadership';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Can you lead congregational prayers?';

  @override
  String get onboarding_label_lifestyleDiet => 'Lifestyle & Diet';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'These are dealbreaker fields for many families. Please answer honestly.';

  @override
  String get onboarding_label_livingExpectation =>
      'Post-marriage living expectations';

  @override
  String get onboarding_label_mahrBudget => 'Mahr Budget';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'What mahr range are you prepared to offer?';

  @override
  String get onboarding_label_mahrExpectation => 'Mahr Expectation';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'What is your expectation for mahr?';

  @override
  String get onboarding_label_maintenance => 'Financial Maintenance';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Are you able to provide for a spouse financially?';

  @override
  String get onboarding_label_male => 'Male';

  @override
  String get onboarding_label_marriageTimeline => 'Marriage Timeline';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'When are you looking to get married?';

  @override
  String get onboarding_label_moderate => 'Moderate';

  @override
  String get onboarding_label_motherTongue => 'Mother tongue';

  @override
  String get onboarding_label_niqab => 'Niqab';

  @override
  String get onboarding_label_practicing => 'Practicing';

  @override
  String get onboarding_label_praysFiveDaily => 'I pray five times daily';

  @override
  String get onboarding_label_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_label_preferredLiving =>
      'Living arrangement preference';

  @override
  String get onboarding_label_profession => 'Profession';

  @override
  String get onboarding_label_providerReadiness => 'Provider Readiness';

  @override
  String get onboarding_label_quranMemorization => 'Quran Memorization';

  @override
  String get onboarding_label_religiousEducation => 'Religious Education';

  @override
  String get onboarding_label_residencyStatus => 'Residency Status (Optional)';

  @override
  String get onboarding_label_revert => 'Revert / Convert (Optional)';

  @override
  String get onboarding_label_revertQuestion =>
      'Are you a revert (convert) to Islam?';

  @override
  String get onboarding_label_sect => 'Sect';

  @override
  String get onboarding_label_shia => 'Shia';

  @override
  String get onboarding_label_smoking => 'Smoking';

  @override
  String get onboarding_label_specialNeeds => 'Special Needs (Optional)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboarding_label_subSect => 'School of thought (Optional)';

  @override
  String get onboarding_label_substanceUse => 'Substance Use';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_vaping => 'Vaping / E-Cigarettes';

  @override
  String get onboarding_label_workAfterMarriage => 'Work After Marriage';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Would you like to work after marriage?';

  @override
  String get onboarding_leadership_leads => 'Leads Prayer';

  @override
  String get onboarding_leadership_learning => 'Learning';

  @override
  String get onboarding_leadership_notYet => 'Not Yet';

  @override
  String get onboarding_living_openToDiscussion => 'Open to Discussion';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'I am flexible and happy to discuss what works for both.';

  @override
  String get onboarding_living_separate => 'Separate Home';

  @override
  String get onboarding_living_separateSub =>
      'I prefer we have our own independent home.';

  @override
  String get onboarding_living_withInlaws => 'With In-Laws';

  @override
  String get onboarding_living_withInlawsSub =>
      'I expect to live with my spouse\'s or my own family.';

  @override
  String get onboarding_location_confirmed => 'Confirmed Location';

  @override
  String get onboarding_mahr_generous => 'Generous';

  @override
  String get onboarding_mahr_moderate => 'Moderate';

  @override
  String get onboarding_mahr_modest => 'Modest';

  @override
  String get onboarding_mahr_noPreference => 'No preference';

  @override
  String get onboarding_mahr_toDiscuss => 'To discuss';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'These details are not shown on your public profile. They are shared privately during the acceptance stage.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Help us understand your journey and readiness.';

  @override
  String get onboarding_marriageDeen_title => 'Marriage & Deen';

  @override
  String get onboarding_niqab_dontWear => 'I don\'t wear niqab';

  @override
  String get onboarding_niqab_open => 'Open to wearing';

  @override
  String get onboarding_niqab_wear => 'I wear niqab';

  @override
  String get onboarding_photo_subtitle =>
      'At least one photo is required. Your primary photo must include your face clearly.';

  @override
  String get onboarding_photo_title => 'Add your photos';

  @override
  String get onboarding_photo_verifySelfie => 'Verification Selfie';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Take a live photo to verify you are real';

  @override
  String get onboarding_preferredLiving_noPreference => 'No Preference';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'I am creating this for my…';

  @override
  String get onboarding_profileForWhom_guardian => 'My son or daughter';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'I am creating this profile for someone';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Guardian';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'I am a parent or guardian';

  @override
  String get onboarding_profileForWhom_myself => 'Myself';

  @override
  String get onboarding_profileForWhom_myselfSub => 'I am looking for a spouse';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Brother';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Daughter';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Sister';

  @override
  String get onboarding_profileForWhom_relation_son => 'Son';

  @override
  String get onboarding_profileForWhom_selectOne => 'Select one to continue';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Select a relationship to continue';

  @override
  String get onboarding_profileForWhom_sibling => 'My brother or sister';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'I am helping my sibling find a match';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'You can update this later from settings.';

  @override
  String get onboarding_profileForWhom_title => 'Who is this profile for?';

  @override
  String get onboarding_profileForWhom_ward => 'My ward';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'I am a guardian managing this profile';

  @override
  String get onboarding_providerQuote =>
      '\"The best of you are the best to your wives.\" — Prophet Muhammad ﷺ\n\nBeing honest about your readiness helps build a strong foundation.';

  @override
  String get onboarding_quran_hafiz => 'Hafiz / Hafiza';

  @override
  String get onboarding_quran_none => 'None';

  @override
  String get onboarding_quran_partial => 'Partial Hifz';

  @override
  String get onboarding_quran_some => 'Some Surahs';

  @override
  String get onboarding_religiousEdu_alim => 'Alim Course';

  @override
  String get onboarding_religiousEdu_islamicUni => 'Islamic University';

  @override
  String get onboarding_religiousEdu_madrasa => 'Madrasa';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Self-Taught';

  @override
  String get onboarding_timeline_1year => 'Within a year';

  @override
  String get onboarding_timeline_2years => '2+ years';

  @override
  String get onboarding_timeline_6months => 'Within 6 months';

  @override
  String get onboarding_timeline_asap => 'As soon as possible';

  @override
  String get onboarding_timeline_notSure => 'Not sure yet';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifies as Muslim, celebrates occasions, may not pray regularly';

  @override
  String get onboarding_tooltip_moderate =>
      'Values Islamic principles and prays, though not always five times a day';

  @override
  String get onboarding_tooltip_practicing =>
      'Follows all five pillars, prays regularly, halal lifestyle';

  @override
  String get onboarding_work_no => 'No, I prefer not to';

  @override
  String get onboarding_work_yes => 'Yes, I plan to work';

  @override
  String get photo_add_main_required => 'Add main photo\n(required)';

  @override
  String get photo_add_photo => 'Add photo';

  @override
  String get photo_banner_text =>
      'Photos with explicit content are not permitted';

  @override
  String get photo_error_no_face_detected =>
      'No face visible — please retry with a clear face photo';

  @override
  String photo_error_pick_failed(Object error) {
    return 'Could not pick photo: $error';
  }

  @override
  String get photo_face_detected => 'Face detected ✓';

  @override
  String get photo_label_photo2 => 'Photo 2';

  @override
  String get photo_label_photo3 => 'Photo 3';

  @override
  String get photo_label_primary => 'Primary photo';

  @override
  String get photo_label_selfie => 'Photo 4';

  @override
  String get photo_no_face => 'No face visible';

  @override
  String get photo_privacy_everyone => 'Visible to everyone';

  @override
  String get photo_privacy_everyone_sub => 'All members can see your photos.';

  @override
  String get photo_privacy_label => 'PHOTO PRIVACY';

  @override
  String get photo_privacy_mutual => 'Visible after mutual interest';

  @override
  String get photo_privacy_mutual_sub =>
      'Photos only reveal when both parties express interest.';

  @override
  String get photo_privacy_request => 'Request to view';

  @override
  String get photo_privacy_request_sub =>
      'Photos are blurred until you approve a request.';

  @override
  String get photo_sheet_camera => 'Camera';

  @override
  String get photo_sheet_gallery => 'Gallery';

  @override
  String get photo_sheet_title => 'Select Photo Source';

  @override
  String get photo_slots_help => 'TAP SLOTS TO UPLOAD';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'Add photos of your $relation. At least one is required.';
  }

  @override
  String get photo_subtitle_self =>
      'At least one photo is required. Maximum four.';

  @override
  String get photo_title_guardian => 'Add their photos';

  @override
  String get photo_title_self => 'Add your photos';

  @override
  String get preferences_deen_any => 'Any';

  @override
  String get preferences_deen_cultural => 'Cultural Muslim';

  @override
  String get preferences_deen_moderate => 'Moderate';

  @override
  String get preferences_deen_practicing => 'Practicing';

  @override
  String get preferences_edu_any => 'Any';

  @override
  String get preferences_edu_bachelors => 'Bachelor\'s +';

  @override
  String get preferences_edu_diploma => 'Diploma +';

  @override
  String get preferences_edu_masters => 'Master\'s +';

  @override
  String get preferences_edu_phd => 'PhD only';

  @override
  String get preferences_edu_secondary => 'Secondary +';

  @override
  String get preferences_label_age => 'AGE RANGE';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max years';
  }

  @override
  String get preferences_label_deen => 'DEEN LEVEL PREFERENCE';

  @override
  String get preferences_label_edu => 'MINIMUM EDUCATION';

  @override
  String get preferences_label_living => 'LIVING ARRANGEMENT PREFERENCE';

  @override
  String get preferences_label_location => 'LOCATION';

  @override
  String get preferences_label_openness => 'OPENNESS';

  @override
  String get preferences_label_sect => 'SECT PREFERENCE';

  @override
  String get preferences_living_discussion => 'Open to Discussion';

  @override
  String get preferences_living_family => 'With Family';

  @override
  String get preferences_living_no_pref => 'No Preference';

  @override
  String get preferences_living_separate => 'Separate Home';

  @override
  String get preferences_location_abroad => 'Open to abroad';

  @override
  String get preferences_location_diaspora => 'Diaspora mode';

  @override
  String get preferences_location_same_city => 'Same city';

  @override
  String get preferences_location_same_country => 'Same country';

  @override
  String get preferences_open_children => 'Open to someone with children';

  @override
  String get preferences_open_divorced => 'Open to someone previously divorced';

  @override
  String get preferences_open_widowed => 'Open to someone previously widowed';

  @override
  String get preferences_sect_any => 'Any';

  @override
  String get preferences_sect_same => 'Same as mine';

  @override
  String get preferences_sect_shia => 'Shia';

  @override
  String get preferences_sect_sunni => 'Sunni';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'Set preferences for your $relation\'s ideal match.';
  }

  @override
  String get preferences_subtitle_self =>
      'These are preferences, not hard filters.';

  @override
  String get preferences_title => 'Partner preferences';

  @override
  String get preview_age_label => 'Age';

  @override
  String get preview_background => 'Background';

  @override
  String get preview_basic_info => 'Basic Info';

  @override
  String get preview_city_label => 'City';

  @override
  String get preview_community_label => 'Community';

  @override
  String get preview_cowife_label => 'Co-wife Acceptance';

  @override
  String get preview_deen_label => 'Deen Level';

  @override
  String get preview_diet_label => 'Diet';

  @override
  String get preview_edit => 'Edit';

  @override
  String get preview_education_label => 'Education';

  @override
  String get preview_faith => 'Faith';

  @override
  String get preview_family => 'Family';

  @override
  String get preview_family_type_label => 'Family type';

  @override
  String get preview_gender_label => 'Gender';

  @override
  String get preview_hijab_label => 'Hijab';

  @override
  String get preview_hookah_label => 'Hookah';

  @override
  String get preview_leadership_label => 'Leadership';

  @override
  String get preview_marital_label => 'Marital';

  @override
  String get preview_marriage_timeline_label => 'Marriage Timeline';

  @override
  String get preview_mother_tongue_label => 'Mother Tongue';

  @override
  String get preview_name_label => 'Name';

  @override
  String get preview_notice_guardian =>
      'This is exactly how others will see their profile.';

  @override
  String get preview_notice_self =>
      'This is exactly how others will see your profile.';

  @override
  String get preview_polygamy_label => 'Polygamy';

  @override
  String get preview_post_marriage_living_label => 'Post-Marriage Living';

  @override
  String get preview_prays_label => 'Prays 5x';

  @override
  String get preview_profession_label => 'Profession';

  @override
  String get preview_quran_label => 'Quran';

  @override
  String get preview_religious_edu_label => 'Religious Education';

  @override
  String get preview_residency_label => 'Residency';

  @override
  String get preview_revert_label => 'Revert';

  @override
  String get preview_sect_label => 'Sect';

  @override
  String get preview_siblings_label => 'Siblings';

  @override
  String get preview_smoking_label => 'Smoking';

  @override
  String get preview_special_needs_label => 'Special Needs';

  @override
  String get preview_submit_btn => 'Submit Profile';

  @override
  String get preview_title => 'Preview';

  @override
  String get preview_vaping_label => 'Vaping';

  @override
  String get preview_willing_relocate_label => 'Willing to Relocate';

  @override
  String profile_label_completeness(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get profile_nudge_completeness =>
      'Profiles with 80%+ completeness receive 3× more interests.';

  @override
  String get settings_brand_credit =>
      'Silarah (سيلارا) · For the sake of Allah';

  @override
  String get settings_button_deleteAccount => 'Delete Account';

  @override
  String get settings_guardian_mirror => 'Mirror Messages';

  @override
  String get settings_guardian_mirror_sub =>
      'Send copies of all messages to guardian';

  @override
  String get settings_guardian_name_hint => 'Guardian Name';

  @override
  String get settings_guardian_relationship => 'Relationship';

  @override
  String get settings_guardian_reply => 'Allow Guardian to Reply';

  @override
  String get settings_guardian_reply_sub =>
      'Guardian may participate in conversations';

  @override
  String get settings_guardian_save => 'Save Guardian Settings';

  @override
  String get settings_guardian_saved => 'Saved';

  @override
  String get settings_guardian_sub => 'Enable Wali oversight for messaging';

  @override
  String get settings_guardian_title => 'Guardian Mode';

  @override
  String get settings_label_blocked => 'Blocked Profiles';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count blocked';
  }

  @override
  String get settings_label_blocked_none => 'None';

  @override
  String get settings_label_deleteGrace =>
      'Your profile will be hidden immediately. Your data will be permanently deleted after 30 days.';

  @override
  String get settings_label_editProfile => 'Edit Profile';

  @override
  String get settings_label_language => 'Language';

  @override
  String get settings_label_photoPrivacy => 'Photo Privacy';

  @override
  String get settings_label_rate => 'Rate Silarah';

  @override
  String get settings_label_rate_snackbar =>
      'Rating will be available once Silarah launches on the app store.';

  @override
  String get settings_label_reports => 'Report History';

  @override
  String settings_label_reports_count(Object count) {
    return '$count reports';
  }

  @override
  String get settings_label_reports_none => 'No reports submitted';

  @override
  String get settings_label_selfieChallenge => 'Selfie Challenge';

  @override
  String get settings_label_verifyProfile => 'Verify Profile';

  @override
  String get settings_label_version => 'Version';

  @override
  String get settings_notify_activityNudges => 'Activity nudges';

  @override
  String get settings_notify_activityNudgesSub =>
      'Profile tips, and a reminder after 7 days away';

  @override
  String get settings_notify_boostReminders => 'Boost reminders';

  @override
  String get settings_notify_boostRemindersSub =>
      'Remind when your weekly boost is ready';

  @override
  String get settings_notify_interestAccepted => 'Interest accepted';

  @override
  String get settings_notify_interestExpiring => 'Interest expiring soon';

  @override
  String get settings_notify_newInterest => 'New interests';

  @override
  String get settings_notify_newMessage => 'New messages';

  @override
  String get settings_notify_quietHours => 'Quiet hours';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'Accepted interests only';

  @override
  String get settings_photo_privacy_after_acceptance => 'After Acceptance';

  @override
  String get settings_photo_privacy_everyone => 'Everyone';

  @override
  String get settings_photo_privacy_public => 'Public';

  @override
  String get settings_photo_privacy_request_only => 'Request Only';

  @override
  String get settings_photo_privacy_request_to_view => 'Request to view';

  @override
  String get settings_privacy_download_body =>
      'Create a private ZIP archive now with your account, profile, photos, interests, matches, messages, settings, consent and subscription history. You can save it using your device\'s secure share sheet.';

  @override
  String get settings_privacy_download_btn => 'Create secure archive';

  @override
  String get settings_privacy_download_label => 'Download my data';

  @override
  String get settings_privacy_download_sub =>
      'Save a machine-readable copy of your Silarah data';

  @override
  String get settings_privacy_export_body =>
      'Your private archive is ready. Use the share sheet to save it securely.';

  @override
  String get settings_privacy_export_btn_close => 'Understood';

  @override
  String get settings_privacy_export_subbody =>
      'This archive may contain private messages and contact details. Store it securely and share it only with people you trust.';

  @override
  String get settings_privacy_export_title => 'Archive ready';

  @override
  String get settings_privacy_online_label => 'ONLINE STATUS';

  @override
  String get settings_privacy_online_sub => 'Show when you were last active';

  @override
  String get settings_privacy_pause_label => 'Profile pause';

  @override
  String get settings_privacy_pause_sub => 'Hide your profile from search';

  @override
  String get settings_privacy_pause_warning =>
      'Your profile is hidden. No one can find you.';

  @override
  String get settings_privacy_photo_label => 'Photo visibility';

  @override
  String get settings_privacy_photo_sub => 'Who can see your photos';

  @override
  String get settings_privacy_visibility_all => 'All registered users';

  @override
  String get settings_privacy_visibility_label => 'WHO CAN SEE MY PROFILE';

  @override
  String get settings_privacy_visibility_sub =>
      'Controls who can browse your profile';

  @override
  String get settings_privacy_visibility_subscribers => 'Subscribers only';

  @override
  String get settings_relation_brother => 'Brother';

  @override
  String get settings_relation_father => 'Father';

  @override
  String get settings_relation_mother => 'Mother';

  @override
  String get settings_relation_other => 'Other';

  @override
  String get settings_relation_uncle => 'Uncle';

  @override
  String get settings_section_account => 'Account';

  @override
  String get settings_section_app => 'App';

  @override
  String get settings_section_dangerZone => 'Close account';

  @override
  String get settings_section_guardian => 'Guardian';

  @override
  String get settings_section_legal => 'Legal';

  @override
  String get settings_section_notifications => 'Notifications';

  @override
  String get settings_section_privacy => 'Privacy';

  @override
  String get settings_section_safety => 'Safety';

  @override
  String get settings_support_body =>
      'For any questions, concerns, or feedback:';

  @override
  String get settings_support_btn_close => 'Close';

  @override
  String get settings_support_contact => 'Contact Support';

  @override
  String get settings_support_note => 'We aim to respond within 48 hours.';

  @override
  String get settings_title => 'Settings';

  @override
  String get splash_button_createProfile => 'Create Profile';

  @override
  String get splash_button_signIn => 'Sign In';

  @override
  String get splash_intention_subtitle =>
      'Private introductions, thoughtful compatibility, and family-aware connection.';

  @override
  String get splash_intention_title => 'Marriage, approached with intention.';

  @override
  String get splash_referral_button => 'Apply Code';

  @override
  String get splash_referral_hint => 'e.g. SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'Please enter a valid 6-character code.';

  @override
  String get splash_referral_question => 'Have a referral code?';

  @override
  String get splash_referral_saved =>
      'Referral code saved! It will be applied after you sign in.';

  @override
  String get splash_referral_subtitle =>
      'If a friend invited you to Silarah, enter their 6-character referral code below.';

  @override
  String get splash_referral_title => 'Enter Referral Code';

  @override
  String subscription_button_monthly(String price) {
    return 'Subscribe — $price/month';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'Subscribe — $price/3 months';
  }

  @override
  String get subscription_label_bestValue => 'Best Value';

  @override
  String get subscription_subtitle =>
      'Women message free. Men subscribe to connect.';

  @override
  String get subscription_title => 'Unlock Silarah';

  @override
  String get startup_connectivity_preparing_title =>
      'Preparing your private space';

  @override
  String get startup_connectivity_preparing_body =>
      'Establishing a secure connection to Silarah.';

  @override
  String get startup_connectivity_offline_title => 'Waiting for a connection';

  @override
  String get startup_connectivity_offline_body =>
      'Your profile, interests and conversations are safe. Silarah will pick up right where you left off as soon as you\'re back online.';

  @override
  String get startup_connectivity_verifying => 'CHECKING CONNECTION';

  @override
  String get startup_connectivity_waiting => 'WAITING FOR NETWORK';

  @override
  String get startup_connectivity_still_waiting => 'STILL OFFLINE · RETRYING';

  @override
  String get startup_connectivity_check => 'Try again';

  @override
  String get startup_connectivity_checking => 'Checking…';

  @override
  String get startup_connectivity_auto =>
      'We\'ll reconnect automatically when the network returns.';

  @override
  String get startup_connectivity_tip =>
      'Check that Wi-Fi or mobile data is turned on.';

  @override
  String get startup_connectivity_protected => 'Protected connection';

  @override
  String get settings_label_email => 'Email';

  @override
  String get settings_notify_profileViews => 'Profile views';

  @override
  String get settings_notify_profileViewsSub =>
      'A private alert when someone opens your profile';

  @override
  String get settings_notify_profileLive => 'Profile goes live';

  @override
  String get settings_notify_profileLiveSub =>
      'Confirmation when your profile becomes visible';

  @override
  String get settings_appearance => 'Appearance';

  @override
  String get settings_helpSupport => 'Help & Support';

  @override
  String get settings_helpCenter => 'Help Center';

  @override
  String get settings_grievanceOfficer => 'Grievance Officer';

  @override
  String get settings_grievanceResponse =>
      'Acknowledgement within 24 hours; most complaints resolved within 7 days';

  @override
  String get settings_grievanceIndiaNotice =>
      'India grievance handling follows the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, as amended. Urgent unlawful or intimate-content complaints receive the shorter legally required timelines.';

  @override
  String get settings_managePhotoRequests => 'Manage photo requests';

  @override
  String get settings_managePhotoRequestsSub =>
      'Approve access, decline requests, or revoke sharing';

  @override
  String get settings_theme_chooseTitle => 'Choose your atmosphere';

  @override
  String get settings_theme_chooseSubtitle =>
      'A complete visual identity—not a color filter. Every surface, field and system control changes together.';

  @override
  String get settings_theme_applied =>
      'Applied instantly · saved on this device';

  @override
  String get settings_reportPending => 'Pending';

  @override
  String get legal_document_terms => 'Terms of Service';

  @override
  String get legal_document_privacy => 'Privacy Policy';

  @override
  String get legal_document_community => 'Community Guidelines';

  @override
  String get legal_specialCategoryConsent =>
      'I explicitly consent to Silarah processing my religious information (sect, prayer practice and Islamic identity) for compatibility matching. Contracted processors use it only to operate Silarah, never for behavioural advertising.';

  @override
  String get onboarding_complexion_fair => 'Fair';

  @override
  String get onboarding_complexion_medium => 'Medium';

  @override
  String get onboarding_complexion_olive => 'Olive';

  @override
  String get onboarding_complexion_dark => 'Dark';

  @override
  String get onboarding_residency_citizen => 'Citizen';

  @override
  String get onboarding_residency_permanentResident => 'Permanent resident';

  @override
  String get onboarding_residency_workVisa => 'Work visa';

  @override
  String get onboarding_residency_studentVisa => 'Student visa';

  @override
  String get onboarding_specialNeeds_none => 'None';

  @override
  String get onboarding_specialNeeds_physical => 'Physical disability';

  @override
  String get onboarding_specialNeeds_hearing => 'Hearing impairment';

  @override
  String get onboarding_specialNeeds_visual => 'Visual impairment';

  @override
  String get onboarding_label_stateRegion => 'State / Region';

  @override
  String get onboarding_specialNeeds_privacy =>
      'Shared only after mutual interest.';

  @override
  String get settings_theme_automatic => 'Automatic';

  @override
  String get settings_theme_automaticDesc =>
      'Ivory & Emerald by day, OLED Night when your phone is dark';

  @override
  String get settings_theme_rose => 'Rose & Marigold';

  @override
  String get settings_theme_roseDesc =>
      'Soft blush with deep rose and marigold gold';

  @override
  String get settings_theme_oled => 'OLED Night';

  @override
  String get settings_theme_oledDesc => 'True black tuned for OLED displays';

  @override
  String get settings_theme_ivory => 'Ivory & Emerald';

  @override
  String get settings_theme_ivoryDesc =>
      'Warm ivory with deep emerald and antique gold';

  @override
  String get settings_guardian_backendRequired =>
      'Guardian settings require a secure connection.';

  @override
  String get settings_guardian_saveError =>
      'Could not save guardian settings. Please try again.';

  @override
  String get common_openSettings => 'Open Settings';

  @override
  String get media_cameraAccessOff => 'Camera access is off';

  @override
  String get media_cameraUnavailable => 'Camera unavailable';

  @override
  String get media_cameraAccessBody =>
      'Allow camera access in Settings, then return to take a clear photo.';

  @override
  String get media_cameraUnavailableBody =>
      'The camera could not be opened. Please try again.';

  @override
  String get media_photoAccessOff => 'Photo access is off';

  @override
  String get media_photoAccessBody =>
      'Allow camera or photo access in Settings, then return to add your photo.';

  @override
  String get chat_searchHint => 'Search messages';

  @override
  String get chat_noConversationsFound => 'No conversations found';

  @override
  String get chat_noConversationsFoundBody =>
      'Try a different name or clear your search.';

  @override
  String get chat_noConversationsYet => 'No conversations yet';

  @override
  String get chat_noConversationsYetBody =>
      'Accept an interest or have yours accepted to begin a conversation.';

  @override
  String get referral_title => 'Refer a Friend';

  @override
  String get referral_loading => 'Loading rewards';

  @override
  String get referral_heading => 'Spread the word, earn Premium!';

  @override
  String get referral_body =>
      'Invite any eligible friend to Silarah. Each account can claim one 3-day referral Premium reward in its lifetime. If you already claimed yours, your friend can still claim theirs.';

  @override
  String get referral_premiumActiveTitle => 'Referral Premium is active';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '${days}d ${hours}h remaining';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m remaining';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '${minutes}m remaining';
  }

  @override
  String get referral_premiumEndingNow => 'Reward ending now';

  @override
  String referral_premiumEndsAt(String date) {
    return 'Ends $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'All Premium features are unlocked. No payment was taken and this reward will not renew automatically.';

  @override
  String get referral_premiumPlansAfter =>
      'Subscription plans become available after your free reward ends, so none of your remaining free time is wasted.';

  @override
  String get referral_premiumBackToProfile => 'Back to profile';

  @override
  String get referral_premiumFeaturesUnlocked =>
      'All Premium features are unlocked';

  @override
  String get referral_premiumViewReward => 'View reward';

  @override
  String get referral_codeLabel => 'YOUR REFERRAL CODE';

  @override
  String get referral_tapToCopy => 'Tap code to copy';

  @override
  String get referral_totalInvited => 'Total Invited';

  @override
  String get referral_rewardsEarned => 'Rewards Earned';

  @override
  String referral_premiumDays(int count) {
    return '$count premium days';
  }

  @override
  String get referral_pending => 'Pending Registrations';

  @override
  String get referral_shareButton => 'Share Code with Friends';

  @override
  String get referral_copied => 'Referral code copied to clipboard!';

  @override
  String get referral_shareSubject => 'Join Silarah';

  @override
  String referral_shareText(String code) {
    return 'Join Silarah—the trusted Muslim matrimony app. Use my referral code: $code\n\nDownload: https://silarah.com/r/$code';
  }

  @override
  String get profile_share => 'Share profile';

  @override
  String safety_reportMember(String name) {
    return 'Report $name';
  }

  @override
  String safety_blockMember(String name) {
    return 'Block $name';
  }

  @override
  String safety_blockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name will be hidden from Discovery and cannot contact you. Existing chat history is preserved for safety. Unblocking will not reopen a conversation.';
  }

  @override
  String get safety_blockAction => 'Block';

  @override
  String safety_blocked(String name) {
    return '$name blocked.';
  }

  @override
  String ui_openProfile(String name) {
    return 'Open $name profile';
  }

  @override
  String ui_typing(String name) {
    return '$name is typing';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'Change country, currently $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'No email app found. $email was copied.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'Message $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'Renews $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age yrs';
  }

  @override
  String ui_photoNumber(int number) {
    return 'Photo $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count of 4 photos';
  }

  @override
  String ui_removeLabel(String label) {
    return 'Remove $label';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label selected';
  }

  @override
  String ui_addLabel(String label) {
    return 'Add $label';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'Photo request sent to $name.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'Yesterday $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String ui_hoursAgo(int count) {
    return '$count hr ago';
  }

  @override
  String ui_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String ui_renewsAt(String time) {
    return 'Renews at $time';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'Photo $number is ready for protected review';
  }

  @override
  String get ui_onePhotoUnlock =>
      '1 photo will unlock automatically once you both express interest.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return '$count photos will unlock automatically once you both express interest.';
  }

  @override
  String get ui_askOnePhoto => 'Ask the owner for permission to view 1 photo.';

  @override
  String ui_askManyPhotos(int count) {
    return 'Ask the owner for permission to view $count photos.';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet ft $inches in';
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
    return 'Filters ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'Previously matched on $date';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'Rematch available in $count days';
  }

  @override
  String get settings_notify_compatibleProfiles => 'Compatible profile alerts';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'When an empty Discovery feed has new results';

  @override
  String get settings_notify_discoveryDigest => 'Discovery digest';

  @override
  String get settings_notify_digestHelp =>
      'Optional summaries; zero-to-available alerts stay immediate.';

  @override
  String get settings_notify_digestOff => 'Off';

  @override
  String get settings_notify_digestDaily => 'Daily';

  @override
  String get settings_notify_digestWeekly => 'Weekly';

  @override
  String get settings_quietHoursStart => 'Quiet hours start';

  @override
  String get settings_quietHoursEnd => 'Quiet hours end';

  @override
  String get settings_notify_festivalGreetings => 'Festival greetings';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'Ramadan and Eid wishes, about five a year';

  @override
  String get profile_quality_tier_complete => 'Complete';

  @override
  String get profile_quality_tier_strong => 'Almost there';

  @override
  String get profile_quality_tier_good => 'Good progress';

  @override
  String get profile_quality_tier_start => 'Getting started';

  @override
  String profile_quality_ring_semantics(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String profile_quality_next_eyebrow(int percent) {
    return 'Next step · reach $percent%';
  }

  @override
  String profile_quality_points(int points) {
    return '+$points%';
  }

  @override
  String get profile_quality_step_photo => 'Add a profile photo';

  @override
  String get profile_quality_step_bio => 'Add a bio';

  @override
  String get profile_quality_step_deen => 'Complete your Islamic identity';

  @override
  String get profile_quality_step_education => 'Add education & profession';

  @override
  String get profile_quality_step_family => 'Add family background';

  @override
  String get profile_quality_step_partner => 'Set partner preferences';

  @override
  String get profile_quality_step_second_photo => 'Add a second photo';

  @override
  String get profile_quality_step_income => 'Add income range';

  @override
  String get profile_quality_step_languages => 'Add languages';

  @override
  String get profile_quality_complete_title => 'Your profile is complete';

  @override
  String get profile_quality_complete_body =>
      'Every detail is in place. Members see your full story.';

  @override
  String get profile_quality_tip_verified_benefit =>
      'A trusted face earns more replies';

  @override
  String get profile_quality_tip_photos_benefit =>
      'More photos help members say yes';

  @override
  String get profile_quality_tip_bio_benefit =>
      'Your own words make the first impression';

  @override
  String get profile_quality_tip_guardian_benefit =>
      'Families value a linked guardian';

  @override
  String get profile_quality_done => 'Done';

  @override
  String get profile_quality_name_fallback => 'Your name';

  @override
  String get profile_quality_subtitle_fallback => 'Complete your profile below';
}
