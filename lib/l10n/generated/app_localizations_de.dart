// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get guide_optional_details => 'Weitere Angaben (optional)';

  @override
  String get guide_optional_details_body =>
      'Du kannst diese Angaben später in deinem Profil ergänzen.';

  @override
  String get guide_profile_ownership =>
      'Dieses Profil beschreibt die Person, die heiraten möchte. Ein separater Guardian kann später zur Begleitung der Gespräche eingeladen werden.';

  @override
  String get about_button_later => 'Ich mache das später';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'Beschreiben Sie Ihr $relation mit Ehrlichkeit und Würde.';
  }

  @override
  String get about_hint_bio_self =>
      'Beschreiben Sie sich selbst mit Ehrlichkeit und Würde.';

  @override
  String get about_label_bio_guardian => 'IHRE BIO';

  @override
  String get about_label_bio_self => 'DEINE BIO';

  @override
  String get about_label_interests => 'INTERESSEN';

  @override
  String get about_label_languages => 'Gesprochene Sprachen';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max ausgewählt';
  }

  @override
  String get about_subtitle => 'Schreiben Sie mit Ehrlichkeit und Würde.';

  @override
  String about_title_guardian(Object relation) {
    return 'Über Ihr $relation';
  }

  @override
  String get about_title_self => 'Über dich';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'Beginnen Sie mit Bismillah';

  @override
  String get auth_button_resendOtp => 'Bestätigungscode erneut senden';

  @override
  String get auth_button_sendCode => 'Bestätigungscode senden';

  @override
  String get auth_button_sendOtp => 'Bestätigungscode senden';

  @override
  String get auth_button_verifyOtp => 'Verifizieren';

  @override
  String get auth_label_changeNumber => 'Falsche Nummer? Ändere es';

  @override
  String get auth_label_enterOtp =>
      'Geben Sie den 6-stelligen Bestätigungscode ein, der an gesendet wurde';

  @override
  String get auth_label_resendCode => 'Bestätigungscode erneut senden';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'Verifizierungscode in ${seconds}s erneut senden';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'In ${seconds}s erneut senden';
  }

  @override
  String get auth_label_sentCodeTo =>
      'Wir haben einen 6-stelligen Bestätigungscode an gesendet';

  @override
  String get auth_subtitle_verifyOtp =>
      'Wir verifizieren es mit einem Einmalcode.';

  @override
  String get auth_title_enterCode => 'Geben Sie Ihren Bestätigungscode ein';

  @override
  String get auth_title_yourNumber => 'Ihre Nummer';

  @override
  String get background_edu_bachelors => 'Bachelor-Abschluss';

  @override
  String get background_edu_below_secondary => 'Unterhalb der Sekundarstufe';

  @override
  String get background_edu_diploma => 'Diplom / Associate';

  @override
  String get background_edu_doctorate => 'Doktortitel / PhD';

  @override
  String get background_edu_higher_secondary => 'Höhere Sekundarstufe / Abitur';

  @override
  String get background_edu_masters => 'Master-Abschluss';

  @override
  String get background_edu_secondary => 'Sekundarstufe / O-Level';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'Erzählen Sie uns etwas über die Ausbildung und Karriere Ihres $relation.';
  }

  @override
  String get background_edu_subtitle_self =>
      'Hilft bei der Suche nach professionell kompatiblen Partnern.';

  @override
  String get background_edu_title_guardian => 'Ihr Hintergrund';

  @override
  String get background_edu_title_self => 'Dein Hintergrund';

  @override
  String get background_emp_employed => 'Beschäftigt';

  @override
  String get background_emp_not_working => 'Funktioniert nicht';

  @override
  String get background_emp_self_employed => 'Selbstständig';

  @override
  String get background_emp_student => 'Student';

  @override
  String get background_income_subtitle =>
      'Viele Leute überspringen dies – es ist völlig optional.';

  @override
  String get background_label_eduLevel => 'BILDUNGSNIVEAU';

  @override
  String get background_label_employment => 'BESCHÄFTIGUNGSSTATUS';

  @override
  String background_label_income_bracket(Object currency) {
    return 'EINKOMMENSKLASSE ($currency)';
  }

  @override
  String get background_label_income_range => 'EINKOMMENSBEREICH (optional)';

  @override
  String get background_label_profession => 'Beruf (optional)';

  @override
  String get background_label_study => 'Studienfach (optional)';

  @override
  String get background_label_who_see => 'WER KANN DAS SEHEN?';

  @override
  String get background_vis_everyone => 'Klammer allen zeigen';

  @override
  String get background_vis_mutual =>
      'Nur bei gegenseitigem Interesse anzeigen';

  @override
  String get background_vis_private => 'Bleiben Sie privat';

  @override
  String get ceremony_text_blessing => 'Möge Allah dies mit Güte segnen';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. Nach reiflicher Überlegung bin ich zu dem Schluss gekommen, dass dies möglicherweise nicht das Richtige für uns ist. Ich wünsche Ihnen aufrichtig alles Gute und bete, dass Allah Sie mit einem wunderbaren Partner segnet. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. Ich wollte ehrlich und respektvoll mit dir sein. Ich glaube nicht, dass wir zusammenpassen, aber ich bete, dass Allah Ihnen bessere Türen öffnet. Ich wünsche Ihnen alles Gute.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. Nach ernsthafter Überlegung habe ich das Gefühl, dass wir möglicherweise nicht kompatibel sind. Ich hoffe, dass Sie jemanden finden, der wirklich zu Ihnen passt. Möge Allah es dir leicht machen. JazakAllah khair für deine Zeit.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. Ich habe über unsere Gespräche nachgedacht und bin der Meinung, dass es das Beste ist, dieses Spiel zu diesem Zeitpunkt zu beenden. Ich habe nichts als Respekt vor dir und ich mache Dua, dass Allah dich mit dem Besten segnet.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. Ich wollte dir gegenüber transparent sein, anstatt zu verschwinden. Ich sehe keine weiteren Fortschritte, aber ich schätze Ihre Zeit wirklich und wünsche Ihnen viel Glück. Möge Allah dich segnen.';

  @override
  String get chat_endMatch_button => 'Match senden und beenden';

  @override
  String get chat_endMatch_subtitle =>
      'Wählen Sie eine respektvolle Nachricht, um dieses Gespräch zu beenden. Die andere Person wird benachrichtigt.';

  @override
  String get chat_endMatch_title => 'Beende dieses Spiel';

  @override
  String chat_label_probation(int hours) {
    return 'Die Freischaltung von Messaging erfolgt in $hours Stunden. Sie können jetzt Interessen senden.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Abonnieren Sie, um Nachrichten freizuschalten. Frauen können auf Silarah immer kostenlos Nachrichten senden.';

  @override
  String get chat_matchClosed_banner =>
      'Dieses Spiel wurde respektvoll geschlossen.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! Ich bin auf Ihr Profil gestoßen und war wirklich beeindruckt. Darf ich mich vorstellen?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Ihr Profil hat meine Aufmerksamkeit erregt. Ich würde gerne mehr über Sie erfahren.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. Ich glaube, wir teilen ähnliche Werte. Wären Sie offen für ein Kennenlernen?';

  @override
  String get chat_placeholder_typeMessage => 'Geben Sie eine Nachricht ein…';

  @override
  String get common_button_back => 'Zurück';

  @override
  String get common_button_cancel => 'Stornieren';

  @override
  String get common_button_done => 'Erledigt';

  @override
  String get common_button_next => 'Nächste';

  @override
  String get common_button_retry => 'Versuchen Sie es erneut';

  @override
  String get common_button_save => 'Speichern';

  @override
  String get common_button_skip => 'Überspringen';

  @override
  String get common_button_submit => 'Einreichen';

  @override
  String get common_error_generic =>
      'Etwas ist schief gelaufen. Bitte versuchen Sie es erneut.';

  @override
  String get common_error_noInternet =>
      'Keine Internetverbindung. Bitte überprüfen Sie Ihre Verbindung.';

  @override
  String get common_label_optional => 'Optional';

  @override
  String get copy_beard_parent => 'Hat Ihr Sohn einen Bart?';

  @override
  String get copy_beard_self => 'Hast du einen Bart?';

  @override
  String get copy_beard_sibling => 'Hat dein Bruder einen Bart?';

  @override
  String get copy_hijab_parent => 'Beachtet Ihre Tochter den Hijab?';

  @override
  String get copy_hijab_self => 'Beobachten Sie den Hijab?';

  @override
  String get copy_hijab_sibling => 'Beachtet deine Schwester den Hijab?';

  @override
  String get copy_prayer_parent => 'Betet Ihr Kind fünfmal täglich?';

  @override
  String get copy_prayer_self => 'Beten Sie fünfmal täglich?';

  @override
  String get copy_prayer_sibling =>
      'Betet Ihr Geschwisterkind fünfmal täglich?';

  @override
  String get deleteAccount_title => 'Konto löschen';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name entfernt';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name gespeichert';
  }

  @override
  String get discovery_button_sendInterest => 'Interesse senden';

  @override
  String get discovery_completeness_button => 'Vollständiges Profil';

  @override
  String get discovery_completeness_subtitle =>
      'Profile über 40 % erhalten dreimal mehr Interessen.\nVervollständigen Sie Ihr Profil, um mit dem Surfen zu beginnen.';

  @override
  String get discovery_completeness_title => 'Vervollständigen Sie Ihr Profil';

  @override
  String get discovery_empty_subtitle =>
      'Jeden Tag kommen neue Mitglieder zu Silarah. Schauen Sie morgen wieder vorbei oder erweitern Sie Ihre Präferenzen, um jetzt mehr Menschen kennenzulernen.';

  @override
  String get discovery_empty_filtered_eyebrow => 'SUCHE VERFEINERN';

  @override
  String get discovery_empty_filtered_title =>
      'Noch passt niemand zu diesen Filtern';

  @override
  String get discovery_empty_filtered_subtitle =>
      'Ihre Präferenzen grenzen den Kreis ein. Schon ein gelockerter Filter bringt meist sofort neue Profile.';

  @override
  String get discovery_empty_clear_filters => 'Alle Filter löschen';

  @override
  String get discovery_empty_refresh => 'Profile aktualisieren';

  @override
  String get discovery_empty_adjust_filters => 'Filter anpassen';

  @override
  String get discovery_empty_hint_trust =>
      'Lockern Sie zuerst die Vertrauensprüfungen';

  @override
  String get discovery_empty_hint_deen => 'Erweitern Sie zuerst die Deen-Ebene';

  @override
  String get discovery_empty_hint_family =>
      'Erweitern Sie zuerst den Familientyp';

  @override
  String get discovery_empty_hint_sect =>
      'Öffnen Sie zuerst den Filter „Sekte“';

  @override
  String get discovery_empty_hint_location =>
      'Wählen Sie zuerst einen größeren Umkreis';

  @override
  String get discovery_empty_hint_age =>
      'Wählen Sie zuerst eine größere Altersspanne';

  @override
  String get discovery_empty_hint_other =>
      'Lockern Sie die Filter einzeln nacheinander';

  @override
  String get discovery_empty_eyebrow => 'ALLES GESEHEN';

  @override
  String get discovery_empty_title => 'Für heute haben Sie alle gesehen';

  @override
  String get discovery_handoff_interest_subtitle =>
      'Profile mit einer aktiven Anfrage wechseln zu Interessen, während du wartest oder antwortest.';

  @override
  String get discovery_handoff_interest_title =>
      'Dein Interesse wird bearbeitet';

  @override
  String get discovery_handoff_match_subtitle =>
      'Matches wechseln in den Chat und werden deshalb nicht erneut in Entdecken angezeigt.';

  @override
  String get discovery_handoff_match_title => 'Deine Verbindung ist bereit';

  @override
  String get discovery_handoff_open_chat => 'Chat öffnen';

  @override
  String get discovery_handoff_open_interests => 'Interessen öffnen';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'Interesse gesendet ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Jemand, mit dem Sie in Kontakt treten könnten';

  @override
  String discovery_label_profilesRemaining(int count) {
    return 'Heute verbleiben noch $count-Profile';
  }

  @override
  String get discovery_limit_button => 'Jetzt upgraden';

  @override
  String get discovery_limit_subtitle =>
      'Sie haben heute 15 Profile durchsucht.\nFühren Sie ein Upgrade durch, um unbegrenztes Surfen freizuschalten.';

  @override
  String get discovery_limit_title => 'Tageslimit erreicht';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count-Profile verbleiben';
  }

  @override
  String get discovery_wildcard_label =>
      'Jemand, mit dem Sie in Kontakt treten könnten';

  @override
  String get family_children_no => 'NEIN';

  @override
  String get family_children_yes => 'Ja';

  @override
  String get family_label_children_guardian => 'HABEN SIE KINDER?';

  @override
  String get family_label_children_self => 'HABEN SIE KINDER?';

  @override
  String get family_label_how_many => 'WIE VIELE?';

  @override
  String get family_label_parents => 'FAMILIENSTAND DER ELTERN';

  @override
  String get family_label_polygamy_female_self =>
      'ANNAHME DER POLYGAMIE (optional)';

  @override
  String get family_label_polygamy_male_self => 'Polygamie-Status (optional)';

  @override
  String get family_label_prev_married => 'BEREITS VERHEIRATET?';

  @override
  String get family_label_relocate => 'UMZUGSBEREITSCHAFT';

  @override
  String get family_label_siblings => 'ANZAHL DER GESCHWISTER';

  @override
  String get family_label_type => 'FAMILIENTYP';

  @override
  String get family_living_title => 'LEBENSERWARTUNGEN NACH DER EHE';

  @override
  String get family_parents_both_deceased => 'Beide verstorben';

  @override
  String get family_parents_divorced => 'Geschieden';

  @override
  String get family_parents_father_deceased => 'Vater verstorben';

  @override
  String get family_parents_mother_deceased => 'Mutter verstorben';

  @override
  String get family_parents_separated => 'Getrennt';

  @override
  String get family_parents_together => 'Zusammen';

  @override
  String get family_polygamy_female_discussion => 'Offen für Diskussionen';

  @override
  String get family_polygamy_female_no => 'NEIN';

  @override
  String get family_polygamy_female_prefer_not => 'Sag es lieber nicht';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'Würde Ihr $relation eine Lebenspartnerschaft in Betracht ziehen?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'Würden Sie darüber nachdenken, eine Mitfrau zu sein?';

  @override
  String get family_polygamy_female_yes => 'Ja';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'Ist Ihr $relation derzeit verheiratet und auf der Suche nach einem weiteren Ehepartner?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'Sind Sie bereits verheiratet und suchen einen weiteren Ehepartner?';

  @override
  String get family_polygamy_option_first => 'Nein, das ist mein erstes';

  @override
  String get family_polygamy_option_married => 'Ja, derzeit verheiratet';

  @override
  String get family_polygamy_option_prefer_not => 'Sag es lieber nicht';

  @override
  String get family_prev_divorced => 'Geschieden';

  @override
  String get family_prev_no => 'NEIN';

  @override
  String get family_prev_widowed => 'Verwitwet';

  @override
  String get family_relocate_discussion => 'Offen für Diskussionen';

  @override
  String get family_relocate_no => 'NEIN';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'Würde Ihr $relation wegen der Heirat umziehen?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'Würden Sie wegen der Heirat umziehen?';

  @override
  String get family_relocate_yes => 'Ja';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'Erzählen Sie uns etwas über die Familie Ihres $relation.';
  }

  @override
  String get family_subtitle_self =>
      'Die Vereinbarkeit der Familie ist für dauerhafte Ehen von zentraler Bedeutung.';

  @override
  String get family_title_guardian => 'Familiärer Hintergrund';

  @override
  String get family_title_self => 'Familiärer Hintergrund';

  @override
  String get family_type_extended => 'Erweitert';

  @override
  String get family_type_joint => 'Gemeinsam';

  @override
  String get family_type_nuclear => 'Nuklear';

  @override
  String get filter_label_community => 'Gemeinschaft / Biradari';

  @override
  String get filter_label_livingExpectation => 'Leben nach der Ehe';

  @override
  String get filter_label_motherTongue => 'Muttersprache';

  @override
  String get guardian_details_candidate_female =>
      'Kandidatin • Frauennachricht kostenlos';

  @override
  String get guardian_details_candidate_label => 'PROFIL ERSTELLEN FÜR';

  @override
  String get guardian_details_candidate_male => 'Männlicher Kandidat';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'Mein $relation';
  }

  @override
  String get guardian_details_involvement => 'BETEILIGUNG DES WÄCHTERS';

  @override
  String get guardian_details_involvement_subtitle =>
      'Wie involviert möchten Sie in Gespräche eingebunden werden?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'Sehen Sie sich Chats an, genehmigen Sie Übereinstimmungen und senden Sie Nachrichten im Namen Ihres $relation.';
  }

  @override
  String get guardian_details_mode_active_title => 'Aktiver Vormund';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'Sehen Sie alle Chats in Echtzeit, aber nur Ihr $relation kann Nachrichten senden.';
  }

  @override
  String get guardian_details_mode_passive_title => 'Nur beobachten';

  @override
  String get guardian_details_name_hint => 'Vollständiger Name';

  @override
  String get guardian_details_name_subtitle =>
      'Ihr Name als Vormund. Dies wird bei Übereinstimmungen angezeigt.';

  @override
  String guardian_details_notice(Object relation) {
    return 'Sie erstellen ein Profil für Ihr $relation. Alle Profildetails auf den nächsten Bildschirmen beschreiben sie, nicht Sie.';
  }

  @override
  String get guardian_details_search_hint => 'Suchen';

  @override
  String get guardian_details_select_code => 'Ländercode auswählen';

  @override
  String get guardian_details_subtitle =>
      'Erzählen Sie uns von sich als Vormund.';

  @override
  String get guardian_details_title => 'Angaben zu Ihrem Vormund';

  @override
  String get guardian_details_your_name => 'IHR NAME';

  @override
  String get interest_cat_creative => 'Kreativ';

  @override
  String get interest_cat_faith => 'Glaube';

  @override
  String get interest_cat_learning => 'Lernen';

  @override
  String get interest_cat_lifestyle => 'Lebensstil';

  @override
  String get interest_cat_social => 'Sozial';

  @override
  String get interest_cat_sports => 'Sport';

  @override
  String get interest_tag_art => 'Kunst';

  @override
  String get interest_tag_calligraphy => 'Kalligraphie';

  @override
  String get interest_tag_community_work => 'Gemeinschaftsarbeit';

  @override
  String get interest_tag_cooking => 'Kochen';

  @override
  String get interest_tag_crafts => 'Kunsthandwerk';

  @override
  String get interest_tag_cricket => 'Kricket';

  @override
  String get interest_tag_cycling => 'Radfahren';

  @override
  String get interest_tag_dawah => 'Dawah';

  @override
  String get interest_tag_family_gatherings => 'Familientreffen';

  @override
  String get interest_tag_fitness => 'Fitness';

  @override
  String get interest_tag_football => 'Fußball';

  @override
  String get interest_tag_gardening => 'Gartenarbeit';

  @override
  String get interest_tag_graphic_design => 'Grafikdesign';

  @override
  String get interest_tag_hiking => 'Wandern';

  @override
  String get interest_tag_history => 'Geschichte';

  @override
  String get interest_tag_islamic_lectures => 'Islamische Vorträge';

  @override
  String get interest_tag_languages => 'Sprachen';

  @override
  String get interest_tag_martial_arts => 'Kampfkunst';

  @override
  String get interest_tag_mentoring => 'Mentoring';

  @override
  String get interest_tag_photography => 'Fotografie';

  @override
  String get interest_tag_poetry => 'Poesie';

  @override
  String get interest_tag_quran_recitation => 'Koranrezitation';

  @override
  String get interest_tag_reading => 'Lektüre';

  @override
  String get interest_tag_science => 'Wissenschaft';

  @override
  String get interest_tag_swimming => 'Baden';

  @override
  String get interest_tag_tahajjud => 'Tahajjud';

  @override
  String get interest_tag_teaching => 'Lehre';

  @override
  String get interest_tag_technology => 'Technologie';

  @override
  String get interest_tag_travel => 'Reisen';

  @override
  String get interest_tag_umrah_hajj => 'Umrah/Hajj';

  @override
  String get interest_tag_voluntary_fasting => 'Freiwilliges Fasten';

  @override
  String get interest_tag_volunteering => 'Freiwilligenarbeit';

  @override
  String get interest_tag_writing => 'Schreiben';

  @override
  String get interests_button_accept => 'Akzeptieren';

  @override
  String get interests_button_decline => 'Abfall';

  @override
  String get interests_tab_received => 'Erhalten';

  @override
  String get interests_tab_sent => 'Gesendet';

  @override
  String get interests_title => 'Interessen';

  @override
  String get lang_albanian => 'albanisch';

  @override
  String get lang_amazigh => 'Amazigh (Berber)';

  @override
  String get lang_amharic => 'Amharisch';

  @override
  String get lang_arabic => 'Arabisch';

  @override
  String get lang_assamese => 'Assamesisch';

  @override
  String get lang_balochi => 'Belutschi';

  @override
  String get lang_bengali => 'Bengali';

  @override
  String get lang_bosnian => 'bosnisch';

  @override
  String get lang_burmese => 'birmanisch';

  @override
  String get lang_chechen => 'Tschetschenisch';

  @override
  String get lang_chinese => 'Chinesisch (Mandarin)';

  @override
  String get lang_dari => 'Dari';

  @override
  String get lang_dutch => 'Niederländisch';

  @override
  String get lang_english => 'Englisch';

  @override
  String get lang_french => 'Französisch';

  @override
  String get lang_fulani => 'Fulani';

  @override
  String get lang_german => 'Deutsch';

  @override
  String get lang_gujarati => 'Gujarati';

  @override
  String get lang_hausa => 'Hausa';

  @override
  String get lang_hindi => 'Hindi';

  @override
  String get lang_igbo => 'Igbo';

  @override
  String get lang_indonesian => 'Indonesisch';

  @override
  String get lang_italian => 'Italienisch';

  @override
  String get lang_japanese => 'japanisch';

  @override
  String get lang_javanese => 'Javanisch';

  @override
  String get lang_kannada => 'Kannada';

  @override
  String get lang_kazakh => 'Kasachisch';

  @override
  String get lang_korean => 'Koreanisch';

  @override
  String get lang_kurdish => 'kurdisch';

  @override
  String get lang_kyrgyz => 'Kirgisisch';

  @override
  String get lang_malay => 'malaiisch';

  @override
  String get lang_malayalam => 'Malayalam';

  @override
  String get lang_mandinka => 'Mandinka';

  @override
  String get lang_marathi => 'Marathi';

  @override
  String get lang_norwegian => 'norwegisch';

  @override
  String get lang_odia => 'Odia';

  @override
  String get lang_other => 'Andere';

  @override
  String get lang_pashto => 'Paschtu';

  @override
  String get lang_persian => 'persisch';

  @override
  String get lang_portuguese => 'Portugiesisch';

  @override
  String get lang_punjabi => 'Punjabi';

  @override
  String get lang_rohingya => 'Rohingya';

  @override
  String get lang_russian => 'Russisch';

  @override
  String get lang_saraiki => 'Saraiki';

  @override
  String get lang_sindhi => 'Sindhi';

  @override
  String get lang_somali => 'somali';

  @override
  String get lang_spanish => 'Spanisch';

  @override
  String get lang_sundanese => 'Sundanesisch';

  @override
  String get lang_swahili => 'Suaheli';

  @override
  String get lang_swedish => 'Schwedisch';

  @override
  String get lang_tagalog => 'Tagalog';

  @override
  String get lang_tajik => 'Tadschikisch';

  @override
  String get lang_tamil => 'Tamilisch';

  @override
  String get lang_tatar => 'Tatarisch';

  @override
  String get lang_telugu => 'Telugu';

  @override
  String get lang_thai => 'Thailändisch';

  @override
  String get lang_tigrinya => 'Tigrinya';

  @override
  String get lang_turkish => 'Türkisch';

  @override
  String get lang_urdu => 'Urdu';

  @override
  String get lang_uzbek => 'Usbekisch';

  @override
  String get lang_wolof => 'Wolof';

  @override
  String get lang_yoruba => 'Yoruba';

  @override
  String get legal_button_continue => 'Weitermachen';

  @override
  String get legal_checkbox_age =>
      'Ich bestätige, dass ich mindestens 18 Jahre alt bin';

  @override
  String get legal_checkbox_terms =>
      'Ich stimme den Nutzungsbedingungen und Datenschutzbestimmungen zu';

  @override
  String get legal_subtitle =>
      'Bitte lesen und stimmen Sie zu, um fortzufahren.';

  @override
  String get legal_summary_1 =>
      'Ihre Daten werden verschlüsselt und niemals an Dritte verkauft.';

  @override
  String get legal_summary_2 =>
      'Jedes Foto wird auf Sicherheit geprüft, und unser Team prüft neue Fotos.';

  @override
  String get legal_summary_3 =>
      'Belästigung, Fake-Profile und Betrug führen zu dauerhaften Sperren.';

  @override
  String get legal_summary_4 =>
      'Diese Plattform ist nur für Heiratsabsichten gedacht. Würde ist der Maßstab.';

  @override
  String get legal_summary_5 =>
      'Sie können Ihr Konto und alle Daten jederzeit löschen.';

  @override
  String get legal_title => 'Bevor Sie beginnen';

  @override
  String get notifications_empty_subtitle =>
      'Im Moment keine neuen Benachrichtigungen.';

  @override
  String get notifications_empty_title => 'Ihr seid alle beschäftigt';

  @override
  String get notifications_markAllRead => 'Alles als gelesen markieren';

  @override
  String get notifications_title => 'Benachrichtigungen';

  @override
  String get onboarding_about_title => 'Über dich selbst';

  @override
  String get onboarding_background_title => 'Bildung & Karriere';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'Sie füllen dies als Vormund aus. Diese Angaben beziehen sich auf Ihr $relation.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'Das sehen andere in ihrem Profil.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'Das sehen andere in Ihrem Profil.';

  @override
  String get onboarding_basicIdentity_title =>
      'Erzählen Sie uns etwas über sich';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Erzählen Sie uns von Ihrem $relation';
  }

  @override
  String get onboarding_debt_manageable => 'Überschaubare Schulden';

  @override
  String get onboarding_debt_none => 'Keine Schulden';

  @override
  String get onboarding_debt_significant => 'Erhebliche Schulden';

  @override
  String get onboarding_diet_eatsAnything => 'Isst alles Halal';

  @override
  String get onboarding_diet_halalOnly => 'Nur Halal';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarier';

  @override
  String get onboarding_diet_zabihaStrict => 'Strenges Zabiha';

  @override
  String get onboarding_error_bioContactInfo =>
      'Bitte entfernen Sie die Kontaktinformationen aus Ihrer Biografie. Aus Sicherheitsgründen sind externe Kontaktdaten nicht gestattet.';

  @override
  String get onboarding_error_multipleFaces =>
      'Gruppenfotos können nicht Ihr Hauptfoto sein.';

  @override
  String get onboarding_error_noFace =>
      'Bitte verwenden Sie ein Foto, auf dem Ihr Gesicht deutlich zu erkennen ist.';

  @override
  String get onboarding_error_under18 =>
      'Silarah ist für Personen ab 18 Jahren. Wir haben diese Anforderung gestellt, um alle in unserer Gemeinschaft zu schützen.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Ihr $relation muss mindestens 18 Jahre alt sein, um Silarah verwenden zu können.';
  }

  @override
  String get onboarding_error_under18_self =>
      'Sie müssen mindestens 18 Jahre alt sein, um Silarah verwenden zu können. Wir freuen uns, Sie dann bei uns begrüßen zu dürfen.';

  @override
  String get onboarding_habit_frequently => 'Häufig';

  @override
  String get onboarding_habit_never => 'Niemals';

  @override
  String get onboarding_habit_occasionally => 'Gelegentlich';

  @override
  String get onboarding_habit_preferNotToSay => 'Sag es lieber nicht';

  @override
  String get onboarding_hijab_always => 'Stets';

  @override
  String get onboarding_hijab_no => 'NEIN';

  @override
  String get onboarding_hijab_sometimes => 'Manchmal';

  @override
  String get onboarding_hint_bio =>
      'Beschreiben Sie sich selbst mit Ehrlichkeit und Würde.';

  @override
  String get onboarding_hint_profession =>
      'z.B. Softwareentwickler, Lehrer, Arzt';

  @override
  String get onboarding_hint_searchCity => 'Durchsuchen Sie Ihre Stadt…';

  @override
  String get onboarding_hint_selectCommunity =>
      'Community auswählen (optional)';

  @override
  String get onboarding_hint_selectCountry => 'Land auswählen';

  @override
  String get onboarding_hint_selectDateOfBirth => 'Geburtsdatum auswählen';

  @override
  String get onboarding_hint_selectLanguage => 'Sprache auswählen';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'Dies hilft Ihnen dabei, jemanden zu finden, der zu Ihnen passt.';

  @override
  String get onboarding_islamicIdentity_title => 'Ihre islamische Identität';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'Stadt';

  @override
  String get onboarding_label_city_guardian => 'Ihre Stadt';

  @override
  String get onboarding_label_city_self => 'Deine Stadt';

  @override
  String get onboarding_label_community => 'Eure Community / biradari';

  @override
  String get onboarding_label_community_parent =>
      'Ihre Gemeinschaft / Biradari';

  @override
  String get onboarding_label_complexion => 'Teint (optional)';

  @override
  String get onboarding_label_country_guardian => 'Ihr Land';

  @override
  String get onboarding_label_country_self => 'Dein Land';

  @override
  String get onboarding_label_cultural => 'Kultureller Muslim';

  @override
  String get onboarding_label_dateOfBirth => 'Geburtsdatum';

  @override
  String get onboarding_label_debtStatus => 'Schuldenstatus';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Ihre aktuellen finanziellen Verpflichtungen.';

  @override
  String get onboarding_label_deenLevel => 'Deen-Ebene';

  @override
  String get onboarding_label_diet => 'Diät';

  @override
  String get onboarding_label_educationLevel => 'Bildungsniveau';

  @override
  String get onboarding_label_female => 'Weiblich';

  @override
  String get onboarding_label_firstName => 'Vorname';

  @override
  String get onboarding_label_firstName_guardian => 'Vorname des Kandidaten';

  @override
  String get onboarding_label_firstName_self => 'Vorname';

  @override
  String get onboarding_label_gender => 'Geschlecht';

  @override
  String get onboarding_label_gender_guardian => 'Geschlecht des Kandidaten';

  @override
  String get onboarding_label_gender_self => 'Geschlecht';

  @override
  String get onboarding_label_height_guardian => 'Ihre Größe';

  @override
  String get onboarding_label_height_self => 'Deine Größe';

  @override
  String get onboarding_label_hookah => 'Wasserpfeife / Shisha';

  @override
  String get onboarding_label_housing => 'Gehäuse';

  @override
  String get onboarding_label_housingQuestion =>
      'Können Sie einen separaten Wohnraum zur Verfügung stellen?';

  @override
  String get onboarding_label_lastName => 'Nachname';

  @override
  String get onboarding_label_leadership => 'Religiöse Führung';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Können Sie Gemeinschaftsgebete leiten?';

  @override
  String get onboarding_label_lifestyleDiet => 'Lebensstil und Ernährung';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'Dies sind für viele Familien entscheidende Bereiche. Bitte antworten Sie ehrlich.';

  @override
  String get onboarding_label_livingExpectation =>
      'Lebenserwartungen nach der Ehe';

  @override
  String get onboarding_label_mahrBudget => 'Mahr-Budget';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'Welches Mahr-Sortiment sind Sie bereit anzubieten?';

  @override
  String get onboarding_label_mahrExpectation => 'Mahr-Erwartung';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'Was erwarten Sie von Mahr?';

  @override
  String get onboarding_label_maintenance => 'Finanzielle Wartung';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Können Sie Ihren Ehepartner finanziell versorgen?';

  @override
  String get onboarding_label_male => 'Männlich';

  @override
  String get onboarding_label_marriageTimeline => 'Zeitleiste der Ehe';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'Wann möchten Sie heiraten?';

  @override
  String get onboarding_label_moderate => 'Mäßig';

  @override
  String get onboarding_label_motherTongue => 'Muttersprache';

  @override
  String get onboarding_label_niqab => 'Niqab';

  @override
  String get onboarding_label_practicing => 'Üben';

  @override
  String get onboarding_label_praysFiveDaily => 'Ich bete fünfmal täglich';

  @override
  String get onboarding_label_preferNotToSay => 'Sag es lieber nicht';

  @override
  String get onboarding_label_preferredLiving => 'Bevorzugte Wohnform';

  @override
  String get onboarding_label_profession => 'Beruf';

  @override
  String get onboarding_label_providerReadiness => 'Bereitschaft des Anbieters';

  @override
  String get onboarding_label_quranMemorization => 'Koran-Auswendiglernen';

  @override
  String get onboarding_label_religiousEducation => 'Religionsunterricht';

  @override
  String get onboarding_label_residencyStatus => 'Aufenthaltsstatus (optional)';

  @override
  String get onboarding_label_revert => 'Zurücksetzen/Konvertieren (optional)';

  @override
  String get onboarding_label_revertQuestion =>
      'Sind Sie zum Islam zurückgekehrt (Konvertit)?';

  @override
  String get onboarding_label_sect => 'Sekte';

  @override
  String get onboarding_label_shia => 'Schiiten';

  @override
  String get onboarding_label_smoking => 'Rauchen';

  @override
  String get onboarding_label_specialNeeds =>
      'Besondere Bedürfnisse (optional)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get onboarding_label_subSect => 'Denkschule (optional)';

  @override
  String get onboarding_label_substanceUse => 'Substanzgebrauch';

  @override
  String get onboarding_label_sunni => 'Sunnitisch';

  @override
  String get onboarding_label_vaping => 'Dampfen / E-Zigaretten';

  @override
  String get onboarding_label_workAfterMarriage => 'Arbeit nach der Heirat';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Möchten Sie nach der Heirat arbeiten?';

  @override
  String get onboarding_leadership_leads => 'Leitet das Gebet';

  @override
  String get onboarding_leadership_learning => 'Lernen';

  @override
  String get onboarding_leadership_notYet => 'Noch nicht';

  @override
  String get onboarding_living_openToDiscussion => 'Offen für Diskussionen';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Ich bin flexibel und bespreche gerne, was für beide funktioniert.';

  @override
  String get onboarding_living_separate => 'Separates Zuhause';

  @override
  String get onboarding_living_separateSub =>
      'Mir ist es lieber, wenn wir ein eigenes, unabhängiges Zuhause haben.';

  @override
  String get onboarding_living_withInlaws => 'Mit Schwiegereltern';

  @override
  String get onboarding_living_withInlawsSub =>
      'Ich erwarte, bei der Familie meines Ehepartners oder meiner eigenen Familie zu leben.';

  @override
  String get onboarding_location_confirmed => 'Bestätigter Standort';

  @override
  String get onboarding_mahr_generous => 'Großzügig';

  @override
  String get onboarding_mahr_moderate => 'Mäßig';

  @override
  String get onboarding_mahr_modest => 'Bescheiden';

  @override
  String get onboarding_mahr_noPreference => 'Keine Präferenz';

  @override
  String get onboarding_mahr_toDiscuss => 'Zur Diskussion';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'Diese Angaben werden nicht in Ihrem öffentlichen Profil angezeigt. Sie werden während der Akzeptanzphase privat weitergegeben.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Helfen Sie uns, Ihren Weg und Ihre Bereitschaft zu verstehen.';

  @override
  String get onboarding_marriageDeen_title => 'Ehe und Religion';

  @override
  String get onboarding_niqab_dontWear => 'Ich trage keinen Niqab';

  @override
  String get onboarding_niqab_open => 'Offen zum Tragen';

  @override
  String get onboarding_niqab_wear => 'Ich trage Niqab';

  @override
  String get onboarding_photo_subtitle =>
      'Mindestens ein Foto ist erforderlich. Ihr Hauptfoto muss Ihr Gesicht deutlich zeigen.';

  @override
  String get onboarding_photo_title => 'Fügen Sie Ihre Fotos hinzu';

  @override
  String get onboarding_photo_verifySelfie => 'Verifizierungs-Selfie';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Machen Sie ein Live-Foto, um zu bestätigen, dass Sie echt sind';

  @override
  String get onboarding_preferredLiving_noPreference => 'Keine Präferenz';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'Ich erstelle dies für meine…';

  @override
  String get onboarding_profileForWhom_guardian =>
      'Mein Sohn oder meine Tochter';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'Ich erstelle dieses Profil für jemanden';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Wächter';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Ich bin ein Elternteil oder Erziehungsberechtigter';

  @override
  String get onboarding_profileForWhom_myself => 'Ich selbst';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'Ich suche einen Ehepartner';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Bruder';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Tochter';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Schwester';

  @override
  String get onboarding_profileForWhom_relation_son => 'Sohn';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'Wählen Sie eine aus, um fortzufahren';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Wählen Sie eine Beziehung aus, um fortzufahren';

  @override
  String get onboarding_profileForWhom_sibling =>
      'Mein Bruder oder meine Schwester';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Ich helfe meinem Geschwister dabei, einen Partner zu finden';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'Sie können dies später in den Einstellungen aktualisieren.';

  @override
  String get onboarding_profileForWhom_title => 'Für wen ist dieses Profil?';

  @override
  String get onboarding_profileForWhom_ward => 'Mein Mündel';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Ich bin ein Vormund, der dieses Profil verwaltet';

  @override
  String get onboarding_providerQuote =>
      '„Die Besten von euch sind die Besten für eure Frauen.“ — Prophet Muhammad ﷺ\n\nWenn Sie ehrlich über Ihre Bereitschaft sprechen, können Sie eine solide Grundlage schaffen.';

  @override
  String get onboarding_quran_hafiz => 'Hafiz / Hafiza';

  @override
  String get onboarding_quran_none => 'Keiner';

  @override
  String get onboarding_quran_partial => 'Teilweise Hifz';

  @override
  String get onboarding_quran_some => 'Einige Suren';

  @override
  String get onboarding_religiousEdu_alim => 'Alim-Kurs';

  @override
  String get onboarding_religiousEdu_islamicUni => 'Islamische Universität';

  @override
  String get onboarding_religiousEdu_madrasa => 'Madrasa';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Autodidakt';

  @override
  String get onboarding_timeline_1year => 'Innerhalb eines Jahres';

  @override
  String get onboarding_timeline_2years => '2+ Jahre';

  @override
  String get onboarding_timeline_6months => 'Innerhalb von 6 Monaten';

  @override
  String get onboarding_timeline_asap => 'So schnell wie möglich';

  @override
  String get onboarding_timeline_notSure => 'Noch nicht sicher';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifiziert sich als Muslim, feiert Anlässe und betet möglicherweise nicht regelmäßig';

  @override
  String get onboarding_tooltip_moderate =>
      'Schätzt islamische Werte und betet, wenn auch nicht immer fünfmal am Tag';

  @override
  String get onboarding_tooltip_practicing =>
      'Befolgt alle fünf Säulen, betet regelmäßig, Halal-Lebensstil';

  @override
  String get onboarding_work_no => 'Nein, das möchte ich lieber nicht';

  @override
  String get onboarding_work_yes => 'Ja, ich habe vor zu arbeiten';

  @override
  String get photo_add_main_required => 'Hauptfoto hinzufügen\n(erforderlich)';

  @override
  String get photo_add_photo => 'Foto hinzufügen';

  @override
  String get photo_banner_text =>
      'Fotos mit eindeutigem Inhalt sind nicht gestattet';

  @override
  String get photo_error_no_face_detected =>
      'Kein Gesicht sichtbar – bitte versuchen Sie es erneut mit einem klaren Gesichtsfoto';

  @override
  String photo_error_pick_failed(Object error) {
    return 'Foto konnte nicht ausgewählt werden: $error';
  }

  @override
  String get photo_face_detected => 'Gesicht erkannt ✓';

  @override
  String get photo_label_photo2 => 'Foto 2';

  @override
  String get photo_label_photo3 => 'Foto 3';

  @override
  String get photo_label_primary => 'Hauptfoto';

  @override
  String get photo_label_selfie => 'Foto 4';

  @override
  String get photo_no_face => 'Kein Gesicht sichtbar';

  @override
  String get photo_privacy_everyone => 'Für jeden sichtbar';

  @override
  String get photo_privacy_everyone_sub =>
      'Alle Mitglieder können Ihre Fotos sehen.';

  @override
  String get photo_privacy_label => 'FOTO-DATENSCHUTZ';

  @override
  String get photo_privacy_mutual => 'Sichtbar nach gegenseitigem Interesse';

  @override
  String get photo_privacy_mutual_sub =>
      'Fotos werden nur veröffentlicht, wenn beide Parteien Interesse bekunden.';

  @override
  String get photo_privacy_request => 'Bitte um Besichtigung';

  @override
  String get photo_privacy_request_sub =>
      'Fotos bleiben unscharf, bis Sie eine Anfrage genehmigen.';

  @override
  String get photo_sheet_camera => 'Kamera';

  @override
  String get photo_sheet_gallery => 'Galerie';

  @override
  String get photo_sheet_title => 'Wählen Sie Fotoquelle';

  @override
  String get photo_slots_help => 'TIPP SLOTS ZUM HOCHLADEN';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'Fügen Sie Fotos von Ihrem $relation hinzu. Mindestens eine ist erforderlich.';
  }

  @override
  String get photo_subtitle_self =>
      'Mindestens ein Foto ist erforderlich. Maximal vier.';

  @override
  String get photo_title_guardian => 'Fügen Sie ihre Fotos hinzu';

  @override
  String get photo_title_self => 'Fügen Sie Ihre Fotos hinzu';

  @override
  String get preferences_deen_any => 'Beliebig';

  @override
  String get preferences_deen_cultural => 'Kultureller Muslim';

  @override
  String get preferences_deen_moderate => 'Mäßig';

  @override
  String get preferences_deen_practicing => 'Üben';

  @override
  String get preferences_edu_any => 'Beliebig';

  @override
  String get preferences_edu_bachelors => 'Bachelor +';

  @override
  String get preferences_edu_diploma => 'Diplom +';

  @override
  String get preferences_edu_masters => 'Master +';

  @override
  String get preferences_edu_phd => 'Nur Doktortitel';

  @override
  String get preferences_edu_secondary => 'Sekundär +';

  @override
  String get preferences_label_age => 'ALTERSBEREICH';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max Jahre';
  }

  @override
  String get preferences_label_deen => 'DEEN-LEVEL-PRÄFERENZ';

  @override
  String get preferences_label_edu => 'MINDESTBILDUNG';

  @override
  String get preferences_label_living => 'WOHNZIMMERPRÄFERENZ';

  @override
  String get preferences_label_location => 'STANDORT';

  @override
  String get preferences_label_openness => 'OFFENHEIT';

  @override
  String get preferences_label_sect => 'Sektenpräferenz';

  @override
  String get preferences_living_discussion => 'Offen für Diskussionen';

  @override
  String get preferences_living_family => 'Mit Familie';

  @override
  String get preferences_living_no_pref => 'Keine Präferenz';

  @override
  String get preferences_living_separate => 'Separates Zuhause';

  @override
  String get preferences_location_abroad => 'Offen für das Ausland';

  @override
  String get preferences_location_diaspora => 'Diaspora-Modus';

  @override
  String get preferences_location_same_city => 'Dieselbe Stadt';

  @override
  String get preferences_location_same_country => 'Gleiches Land';

  @override
  String get preferences_open_children => 'Offen für jemanden mit Kindern';

  @override
  String get preferences_open_divorced =>
      'Offen für jemanden, der bereits geschieden ist';

  @override
  String get preferences_open_widowed =>
      'Offen für jemanden, der zuvor verwitwet war';

  @override
  String get preferences_sect_any => 'Beliebig';

  @override
  String get preferences_sect_same => 'Das Gleiche wie meins';

  @override
  String get preferences_sect_shia => 'Schiiten';

  @override
  String get preferences_sect_sunni => 'Sunnitisch';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'Legen Sie Einstellungen für die ideale Übereinstimmung Ihres $relation fest.';
  }

  @override
  String get preferences_subtitle_self =>
      'Dabei handelt es sich um Präferenzen, nicht um harte Filter.';

  @override
  String get preferences_title => 'Partnerpräferenzen';

  @override
  String get preview_age_label => 'Alter';

  @override
  String get preview_background => 'Hintergrund';

  @override
  String get preview_basic_info => 'Grundlegende Informationen';

  @override
  String get preview_city_label => 'Stadt';

  @override
  String get preview_community_label => 'Gemeinschaft';

  @override
  String get preview_cowife_label => 'Akzeptanz der Co-Frau';

  @override
  String get preview_deen_label => 'Deen-Ebene';

  @override
  String get preview_diet_label => 'Diät';

  @override
  String get preview_edit => 'Bearbeiten';

  @override
  String get preview_education_label => 'Ausbildung';

  @override
  String get preview_faith => 'Glaube';

  @override
  String get preview_family => 'Familie';

  @override
  String get preview_family_type_label => 'Familientyp';

  @override
  String get preview_gender_label => 'Geschlecht';

  @override
  String get preview_hijab_label => 'Hijab';

  @override
  String get preview_hookah_label => 'Huka';

  @override
  String get preview_leadership_label => 'Führung';

  @override
  String get preview_marital_label => 'Ehe';

  @override
  String get preview_marriage_timeline_label => 'Zeitleiste der Ehe';

  @override
  String get preview_mother_tongue_label => 'Muttersprache';

  @override
  String get preview_name_label => 'Name';

  @override
  String get preview_notice_guardian => 'Genau so sehen andere ihr Profil.';

  @override
  String get preview_notice_self => 'Genau so werden andere Ihr Profil sehen.';

  @override
  String get preview_polygamy_label => 'Polygamie';

  @override
  String get preview_post_marriage_living_label => 'Leben nach der Ehe';

  @override
  String get preview_prays_label => 'Betet 5x';

  @override
  String get preview_profession_label => 'Beruf';

  @override
  String get preview_quran_label => 'Koran';

  @override
  String get preview_religious_edu_label => 'Religionsunterricht';

  @override
  String get preview_residency_label => 'Residenz';

  @override
  String get preview_revert_label => 'Zurücksetzen';

  @override
  String get preview_sect_label => 'Sekte';

  @override
  String get preview_siblings_label => 'Geschwister';

  @override
  String get preview_smoking_label => 'Rauchen';

  @override
  String get preview_special_needs_label => 'Besondere Bedürfnisse';

  @override
  String get preview_submit_btn => 'Profil senden';

  @override
  String get preview_title => 'Vorschau';

  @override
  String get preview_vaping_label => 'Dampfen';

  @override
  String get preview_willing_relocate_label => 'Umzugsbereitschaft';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil $percent % abgeschlossen';
  }

  @override
  String get profile_nudge_completeness =>
      'Profile mit einer Vollständigkeit von über 80 % erhalten dreimal mehr Interessen.';

  @override
  String get settings_brand_credit => 'Silarah (سيلارا) · Um Allahs willen';

  @override
  String get settings_button_deleteAccount => 'Konto löschen';

  @override
  String get settings_guardian_mirror => 'Spiegelnachrichten';

  @override
  String get settings_guardian_mirror_sub =>
      'Senden Sie Kopien aller Nachrichten an den Vormund';

  @override
  String get settings_guardian_name_hint => 'Name des Wächters';

  @override
  String get settings_guardian_relationship => 'Beziehung';

  @override
  String get settings_guardian_reply => 'Erlaube dem Hüter zu antworten';

  @override
  String get settings_guardian_reply_sub =>
      'Der Erziehungsberechtigte darf an Gesprächen teilnehmen';

  @override
  String get settings_guardian_save =>
      'Speichern Sie die Guardian-Einstellungen';

  @override
  String get settings_guardian_saved => 'Gespeichert';

  @override
  String get settings_guardian_sub =>
      'Aktivieren Sie die Wali-Überwachung für Nachrichten';

  @override
  String get settings_guardian_title => 'Wächtermodus';

  @override
  String get settings_label_blocked => 'Blockierte Profile';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count blockiert';
  }

  @override
  String get settings_label_blocked_none => 'Keiner';

  @override
  String get settings_label_deleteGrace =>
      'Ihr Profil wird sofort ausgeblendet. Ihre Daten werden nach 30 Tagen endgültig gelöscht.';

  @override
  String get settings_label_editProfile => 'Profil bearbeiten';

  @override
  String get settings_label_language => 'Sprache';

  @override
  String get settings_label_photoPrivacy => 'Foto-Datenschutz';

  @override
  String get settings_label_rate => 'Bewerten Sie Silarah';

  @override
  String get settings_label_rate_snackbar =>
      'Die Bewertung wird verfügbar sein, sobald Silarah im App Store startet.';

  @override
  String get settings_label_reports => 'Berichtsverlauf';

  @override
  String settings_label_reports_count(Object count) {
    return '$count-Berichte';
  }

  @override
  String get settings_label_reports_none => 'Keine Berichte eingereicht';

  @override
  String get settings_label_selfieChallenge => 'Selfie-Herausforderung';

  @override
  String get settings_label_verifyProfile => 'Profil überprüfen';

  @override
  String get settings_label_version => 'Version';

  @override
  String get settings_notify_activityNudges => 'Aktivitätsschübe';

  @override
  String get settings_notify_activityNudgesSub =>
      'Profiltipps und eine Erinnerung nach 7 Tagen Abwesenheit';

  @override
  String get settings_notify_boostReminders => 'Boost-Erinnerungen';

  @override
  String get settings_notify_boostRemindersSub =>
      'Erinnere dich daran, wann dein wöchentlicher Boost fertig ist';

  @override
  String get settings_notify_interestAccepted => 'Interesse angenommen';

  @override
  String get settings_notify_interestExpiring => 'Interesse läuft bald ab';

  @override
  String get settings_notify_newInterest => 'Neue Interessen';

  @override
  String get settings_notify_newMessage => 'Neue Nachrichten';

  @override
  String get settings_notify_quietHours => 'Ruhige Stunden';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'Nur akzeptierte Interessen';

  @override
  String get settings_photo_privacy_after_acceptance => 'Nach der Annahme';

  @override
  String get settings_photo_privacy_everyone => 'Alle';

  @override
  String get settings_photo_privacy_public => 'Öffentlich';

  @override
  String get settings_photo_privacy_request_only => 'Nur auf Anfrage';

  @override
  String get settings_photo_privacy_request_to_view => 'Bitte um Besichtigung';

  @override
  String get settings_privacy_download_body =>
      'Erstellen Sie jetzt ein privates ZIP-Archiv mit Konto, Profil, Fotos, Interessen, Matches, Nachrichten, Einstellungen, Einwilligungen und Abonnementverlauf. Speichern Sie es über das sichere Teilen-Menü Ihres Geräts.';

  @override
  String get settings_privacy_download_btn => 'Sicheres Archiv erstellen';

  @override
  String get settings_privacy_download_label => 'Meine Daten herunterladen';

  @override
  String get settings_privacy_download_sub =>
      'Eine maschinenlesbare Kopie Ihrer Silarah-Daten speichern';

  @override
  String get settings_privacy_export_body =>
      'Ihr privates Archiv ist bereit. Speichern Sie es sicher über das Teilen-Menü.';

  @override
  String get settings_privacy_export_btn_close => 'Verstanden';

  @override
  String get settings_privacy_export_subbody =>
      'Dieses Archiv kann private Nachrichten und Kontaktdaten enthalten. Bewahren Sie es sicher auf und teilen Sie es nur mit vertrauenswürdigen Personen.';

  @override
  String get settings_privacy_export_title => 'Archiv bereit';

  @override
  String get settings_privacy_online_label => 'ONLINE-STATUS';

  @override
  String get settings_privacy_online_sub =>
      'Zeigt an, wann Sie zuletzt aktiv waren';

  @override
  String get settings_privacy_pause_label => 'Profilpause';

  @override
  String get settings_privacy_pause_sub =>
      'Verstecken Sie Ihr Profil vor der Suche';

  @override
  String get settings_privacy_pause_warning =>
      'Ihr Profil ist ausgeblendet. Niemand kann dich finden.';

  @override
  String get settings_privacy_photo_label => 'Fotosichtbarkeit';

  @override
  String get settings_privacy_photo_sub => 'Wer kann Ihre Fotos sehen?';

  @override
  String get settings_privacy_visibility_all => 'Alle registrierten Benutzer';

  @override
  String get settings_privacy_visibility_label => 'Wer kann mein Profil sehen?';

  @override
  String get settings_privacy_visibility_sub =>
      'Steuert, wer Ihr Profil durchsuchen kann';

  @override
  String get settings_privacy_visibility_subscribers => 'Nur für Abonnenten';

  @override
  String get settings_relation_brother => 'Bruder';

  @override
  String get settings_relation_father => 'Vater';

  @override
  String get settings_relation_mother => 'Mutter';

  @override
  String get settings_relation_other => 'Andere';

  @override
  String get settings_relation_uncle => 'Onkel';

  @override
  String get settings_section_account => 'Konto';

  @override
  String get settings_section_app => 'App';

  @override
  String get settings_section_dangerZone => 'Konto schließen';

  @override
  String get settings_section_guardian => 'Wächter';

  @override
  String get settings_section_legal => 'Legal';

  @override
  String get settings_section_notifications => 'Benachrichtigungen';

  @override
  String get settings_section_privacy => 'Privatsphäre';

  @override
  String get settings_section_safety => 'Sicherheit';

  @override
  String get settings_support_body => 'Für Fragen, Bedenken oder Feedback:';

  @override
  String get settings_support_btn_close => 'Schließen';

  @override
  String get settings_support_contact => 'Kontaktieren Sie den Support';

  @override
  String get settings_support_note =>
      'Unser Ziel ist es, innerhalb von 48 Stunden zu antworten.';

  @override
  String get settings_title => 'Einstellungen';

  @override
  String get splash_button_createProfile => 'Profil erstellen';

  @override
  String get splash_button_signIn => 'Anmelden';

  @override
  String get splash_intention_subtitle =>
      'Private Begegnungen, durchdachte Kompatibilität und eine familienbewusste Verbindung.';

  @override
  String get splash_intention_title => 'Ehe, mit bewusster Absicht.';

  @override
  String get splash_referral_button => 'Code anwenden';

  @override
  String get splash_referral_hint => 'z.B. SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'Bitte geben Sie einen gültigen 6-stelligen Code ein.';

  @override
  String get splash_referral_question => 'Haben Sie einen Empfehlungscode?';

  @override
  String get splash_referral_saved =>
      'Empfehlungscode gespeichert! Es wird angewendet, nachdem Sie sich angemeldet haben.';

  @override
  String get splash_referral_subtitle =>
      'Wenn ein Freund Sie zu Silarah eingeladen hat, geben Sie unten seinen 6-stelligen Empfehlungscode ein.';

  @override
  String get splash_referral_title => 'Geben Sie den Empfehlungscode ein';

  @override
  String subscription_button_monthly(String price) {
    return 'Abonnieren – $price/Monat';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'Abonnieren – $price/3 Monate';
  }

  @override
  String get subscription_label_bestValue =>
      'Bestes Preis-Leistungs-Verhältnis';

  @override
  String get subscription_subtitle =>
      'Frauennachrichten kostenlos. Männer abonnieren, um Kontakte zu knüpfen.';

  @override
  String get subscription_title => 'Schalten Sie Silarah frei';

  @override
  String get startup_connectivity_preparing_title =>
      'Ihr privater Bereich wird vorbereitet';

  @override
  String get startup_connectivity_preparing_body =>
      'Eine sichere Verbindung zu Silarah wird hergestellt.';

  @override
  String get startup_connectivity_offline_title => 'Warten auf Verbindung';

  @override
  String get startup_connectivity_offline_body =>
      'Ihr Profil, Ihre Interessen und Gespräche sind sicher. Silarah macht genau dort weiter, wo Sie aufgehört haben, sobald Sie wieder online sind.';

  @override
  String get startup_connectivity_verifying => 'VERBINDUNG WIRD GEPRÜFT';

  @override
  String get startup_connectivity_waiting => 'WARTEN AUF NETZWERK';

  @override
  String get startup_connectivity_still_waiting =>
      'NOCH OFFLINE · NEUER VERSUCH';

  @override
  String get startup_connectivity_check => 'Erneut versuchen';

  @override
  String get startup_connectivity_checking => 'Wird geprüft…';

  @override
  String get startup_connectivity_auto =>
      'Sobald das Netzwerk zurück ist, verbinden wir Sie automatisch.';

  @override
  String get startup_connectivity_tip =>
      'Prüfen Sie, ob WLAN oder mobile Daten eingeschaltet sind.';

  @override
  String get startup_connectivity_protected => 'Geschützte Verbindung';

  @override
  String get settings_label_email => 'E-Mail';

  @override
  String get settings_notify_profileViews => 'Profilaufrufe';

  @override
  String get settings_notify_profileViewsSub =>
      'Private Benachrichtigung, wenn jemand dein Profil öffnet';

  @override
  String get settings_notify_profileLive => 'Profil wird sichtbar';

  @override
  String get settings_notify_profileLiveSub =>
      'Bestätigung, sobald dein Profil sichtbar ist';

  @override
  String get settings_appearance => 'Erscheinungsbild';

  @override
  String get settings_helpSupport => 'Hilfe & Support';

  @override
  String get settings_helpCenter => 'Hilfe-Center';

  @override
  String get settings_grievanceOfficer => 'Beschwerdebeauftragte Person';

  @override
  String get settings_grievanceResponse =>
      'Bestätigung innerhalb von 24 Stunden; die meisten Beschwerden innerhalb von 7 Tagen gelöst';

  @override
  String get settings_grievanceIndiaNotice =>
      'Die Beschwerdebearbeitung in Indien folgt den geänderten Information Technology Rules (Intermediary Guidelines and Digital Media Ethics Code). Für dringende rechtswidrige oder intime Inhalte gelten kürzere gesetzliche Fristen.';

  @override
  String get settings_managePhotoRequests => 'Fotoanfragen verwalten';

  @override
  String get settings_managePhotoRequestsSub =>
      'Zugriff genehmigen, Anfragen ablehnen oder Freigaben widerrufen';

  @override
  String get settings_theme_chooseTitle => 'Wähle deine Atmosphäre';

  @override
  String get settings_theme_chooseSubtitle =>
      'Eine vollständige visuelle Identität – kein Farbfilter. Alle Flächen, Felder und Systemelemente ändern sich gemeinsam.';

  @override
  String get settings_theme_applied =>
      'Sofort angewendet · auf diesem Gerät gespeichert';

  @override
  String get settings_reportPending => 'Ausstehend';

  @override
  String get legal_document_terms => 'Nutzungsbedingungen';

  @override
  String get legal_document_privacy => 'Datenschutzrichtlinie';

  @override
  String get legal_document_community => 'Community-Richtlinien';

  @override
  String get legal_specialCategoryConsent =>
      'Ich willige ausdrücklich ein, dass Silarah meine religiösen Angaben (Rechtsschule, Gebetspraxis und islamische Identität) für die Kompatibilitätsvermittlung verarbeitet. Beauftragte Dienstleister verwenden sie nur zum Betrieb von Silarah, niemals für verhaltensbasierte Werbung.';

  @override
  String get onboarding_complexion_fair => 'Hell';

  @override
  String get onboarding_complexion_medium => 'Mittel';

  @override
  String get onboarding_complexion_olive => 'Olivfarben';

  @override
  String get onboarding_complexion_dark => 'Dunkel';

  @override
  String get onboarding_residency_citizen => 'Staatsbürger/in';

  @override
  String get onboarding_residency_permanentResident => 'Daueraufenthalt';

  @override
  String get onboarding_residency_workVisa => 'Arbeitsvisum';

  @override
  String get onboarding_residency_studentVisa => 'Studierendenvisum';

  @override
  String get onboarding_specialNeeds_none => 'Keine';

  @override
  String get onboarding_specialNeeds_physical => 'Körperliche Behinderung';

  @override
  String get onboarding_specialNeeds_hearing => 'Hörbeeinträchtigung';

  @override
  String get onboarding_specialNeeds_visual => 'Sehbeeinträchtigung';

  @override
  String get onboarding_label_stateRegion => 'Bundesland / Region';

  @override
  String get onboarding_specialNeeds_privacy =>
      'Wird erst nach gegenseitigem Interesse geteilt.';

  @override
  String get settings_theme_automatic => 'Automatisch';

  @override
  String get settings_theme_automaticDesc =>
      'Tagsüber Elfenbein & Smaragd, OLED-Nacht im dunklen Modus des Telefons';

  @override
  String get settings_theme_rose => 'Rose & Ringelblume';

  @override
  String get settings_theme_roseDesc =>
      'Zartes Rosé mit tiefem Rosenrot und Ringelblumengold';

  @override
  String get settings_theme_oled => 'OLED-Nacht';

  @override
  String get settings_theme_oledDesc =>
      'Echtes Schwarz, optimiert für OLED-Displays';

  @override
  String get settings_theme_ivory => 'Elfenbein & Smaragd';

  @override
  String get settings_theme_ivoryDesc =>
      'Warmes Elfenbein mit tiefem Smaragd und Antikgold';

  @override
  String get settings_guardian_backendRequired =>
      'Für Vormund-Einstellungen ist eine sichere Verbindung erforderlich.';

  @override
  String get settings_guardian_saveError =>
      'Vormund-Einstellungen konnten nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get common_openSettings => 'Einstellungen öffnen';

  @override
  String get media_cameraAccessOff => 'Kamerazugriff ist deaktiviert';

  @override
  String get media_cameraUnavailable => 'Kamera nicht verfügbar';

  @override
  String get media_cameraAccessBody =>
      'Erlaube den Kamerazugriff in den Einstellungen und kehre dann zurück, um ein deutliches Foto aufzunehmen.';

  @override
  String get media_cameraUnavailableBody =>
      'Die Kamera konnte nicht geöffnet werden. Bitte erneut versuchen.';

  @override
  String get media_photoAccessOff => 'Fotozugriff ist deaktiviert';

  @override
  String get media_photoAccessBody =>
      'Erlaube Kamera- oder Fotozugriff in den Einstellungen und kehre dann zurück, um dein Foto hinzuzufügen.';

  @override
  String get chat_searchHint => 'Nachrichten durchsuchen';

  @override
  String get chat_noConversationsFound => 'Keine Unterhaltungen gefunden';

  @override
  String get chat_noConversationsFoundBody =>
      'Versuche einen anderen Namen oder lösche die Suche.';

  @override
  String get chat_noConversationsYet => 'Noch keine Unterhaltungen';

  @override
  String get chat_noConversationsYetBody =>
      'Nimm ein Interesse an oder warte auf die Annahme deines Interesses, um eine Unterhaltung zu beginnen.';

  @override
  String get referral_title => 'Freund einladen';

  @override
  String get referral_loading => 'Prämien werden geladen';

  @override
  String get referral_heading => 'Weitersagen und Premium verdienen!';

  @override
  String get referral_body =>
      'Lade eine beliebige berechtigte Person zu Silarah ein. Jedes Konto kann einmalig 3 Tage Empfehlungs-Premium erhalten. Hast du deine Prämie bereits erhalten, kann dein Freund seine weiterhin bekommen.';

  @override
  String get referral_premiumActiveTitle => 'Empfehlungs-Premium ist aktiv';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return 'Noch $days T. $hours Std.';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return 'Noch $hours Std. $minutes Min.';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return 'Noch $minutes Min.';
  }

  @override
  String get referral_premiumEndingNow => 'Prämie endet jetzt';

  @override
  String referral_premiumEndsAt(String date) {
    return 'Endet am $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'Alle Premium-Funktionen sind freigeschaltet. Es wurde nichts berechnet und diese Prämie verlängert sich nicht automatisch.';

  @override
  String get referral_premiumPlansAfter =>
      'Abos sind nach Ende deiner Gratis-Prämie verfügbar, damit keine kostenlose Restzeit verloren geht.';

  @override
  String get referral_premiumBackToProfile => 'Zurück zum Profil';

  @override
  String get referral_premiumFeaturesUnlocked =>
      'Alle Premium-Funktionen sind freigeschaltet';

  @override
  String get referral_premiumViewReward => 'Prämie ansehen';

  @override
  String get referral_codeLabel => 'DEIN EMPFEHLUNGSCODE';

  @override
  String get referral_tapToCopy => 'Zum Kopieren Code antippen';

  @override
  String get referral_totalInvited => 'Eingeladen';

  @override
  String get referral_rewardsEarned => 'Verdiente Prämien';

  @override
  String referral_premiumDays(int count) {
    return '$count Premium-Tage';
  }

  @override
  String get referral_pending => 'Ausstehende Registrierungen';

  @override
  String get referral_shareButton => 'Code mit Freunden teilen';

  @override
  String get referral_copied => 'Empfehlungscode kopiert!';

  @override
  String get referral_shareSubject => 'Silarah beitreten';

  @override
  String referral_shareText(String code) {
    return 'Tritt Silarah bei, der vertrauenswürdigen muslimischen Heirats-App. Nutze meinen Empfehlungscode: $code\n\nDownload: https://silarah.com/r/$code';
  }

  @override
  String get profile_share => 'Profil teilen';

  @override
  String safety_reportMember(String name) {
    return '$name melden';
  }

  @override
  String safety_blockMember(String name) {
    return '$name blockieren';
  }

  @override
  String safety_blockTitle(String name) {
    return '$name blockieren?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name wird in Discovery ausgeblendet und kann dich nicht kontaktieren. Der Chatverlauf bleibt aus Sicherheitsgründen erhalten. Entsperren öffnet die Unterhaltung nicht erneut.';
  }

  @override
  String get safety_blockAction => 'Blockieren';

  @override
  String safety_blocked(String name) {
    return '$name wurde blockiert.';
  }

  @override
  String ui_openProfile(String name) {
    return 'Öffnen Sie das Profil $name';
  }

  @override
  String ui_typing(String name) {
    return '$name tippt';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'Konto konnte nicht gelöscht werden: $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'Land ändern, derzeit $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'Keine E-Mail-App gefunden. $email wurde kopiert.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'Nachricht $name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'Erneuert $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age Jahre';
  }

  @override
  String ui_photoNumber(int number) {
    return 'Foto $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count von 4 Fotos';
  }

  @override
  String ui_removeLabel(String label) {
    return '$label entfernen';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label ausgewählt';
  }

  @override
  String ui_addLabel(String label) {
    return '$label hinzufügen';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'Fotoanfrage gesendet an $name.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'Gestern $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return 'Vor $count Minuten';
  }

  @override
  String ui_hoursAgo(int count) {
    return 'Vor $count Stunden';
  }

  @override
  String ui_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen',
      one: 'Vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String ui_renewsAt(String time) {
    return 'Verlängert um $time';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'Foto $number ist zur geschützten Überprüfung bereit';
  }

  @override
  String get ui_onePhotoUnlock =>
      '1 Foto wird automatisch freigeschaltet, sobald Sie beide Interesse bekunden.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return '$count-Fotos werden automatisch freigeschaltet, sobald Sie beide Interesse bekunden.';
  }

  @override
  String get ui_askOnePhoto =>
      'Bitten Sie den Eigentümer um Erlaubnis, 1 Foto anzusehen.';

  @override
  String ui_askManyPhotos(int count) {
    return 'Bitten Sie den Eigentümer um Erlaubnis, $count-Fotos anzusehen.';
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
    return 'Filter ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'Bereits am $date zusammengeführt';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'Erneutes Match in $count Tagen verfügbar';
  }

  @override
  String get settings_notify_compatibleProfiles =>
      'Hinweise auf passende Profile';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'Wenn ein leerer Entdecken-Feed neue Ergebnisse erhält';

  @override
  String get settings_notify_discoveryDigest => 'Entdecken-Zusammenfassung';

  @override
  String get settings_notify_digestHelp =>
      'Optionale Zusammenfassungen; Hinweise bei neuen Ergebnissen bleiben sofortig.';

  @override
  String get settings_notify_digestOff => 'Aus';

  @override
  String get settings_notify_digestDaily => 'Täglich';

  @override
  String get settings_notify_digestWeekly => 'Wöchentlich';

  @override
  String get settings_quietHoursStart => 'Beginn der Ruhezeit';

  @override
  String get settings_quietHoursEnd => 'Ende der Ruhezeit';

  @override
  String get settings_notify_festivalGreetings => 'Festtagsgrüße';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'Grüße zu Ramadan und Eid, etwa fünfmal im Jahr';
}
