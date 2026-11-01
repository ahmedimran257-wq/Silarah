// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get guide_optional_details =>
      'Informations complémentaires (facultatif)';

  @override
  String get guide_optional_details_body =>
      'Vous pourrez compléter ces informations plus tard depuis votre profil.';

  @override
  String get guide_profile_ownership =>
      'Ce profil décrit la personne qui souhaite se marier. Un tuteur distinct pourra être invité plus tard pour superviser les conversations.';

  @override
  String get about_button_later => 'je ferai ça plus tard';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'Décrivez votre $relation avec honnêteté et dignité.';
  }

  @override
  String get about_hint_bio_self => 'Décrivez-vous avec honnêteté et dignité.';

  @override
  String get about_label_bio_guardian => 'LEUR BIO';

  @override
  String get about_label_bio_self => 'VOTRE BIO';

  @override
  String get about_label_interests => 'INTÉRÊTS';

  @override
  String get about_label_languages => 'LANGUES PARLÉES';

  @override
  String about_label_selected_count(Object current, Object max) {
    return '$current/$max sélectionné';
  }

  @override
  String get about_subtitle => 'Écrivez avec honnêteté et dignité.';

  @override
  String about_title_guardian(Object relation) {
    return 'À propos de votre $relation';
  }

  @override
  String get about_title_self => 'Au propos de vous';

  @override
  String get appName => 'Silarah';

  @override
  String get appTagline => 'Commencez par bismillah';

  @override
  String get auth_button_resendOtp => 'Renvoyer le code de vérification';

  @override
  String get auth_button_sendCode => 'Envoyer le code de vérification';

  @override
  String get auth_button_sendOtp => 'Envoyer le code de vérification';

  @override
  String get auth_button_verifyOtp => 'Vérifier';

  @override
  String get auth_label_changeNumber => 'Mauvais numéro ? Changez-le';

  @override
  String get auth_label_enterOtp =>
      'Entrez le code de vérification à 6 chiffres envoyé à';

  @override
  String get auth_label_resendCode => 'Renvoyer le code de vérification';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'Renvoyer le code de vérification dans ${seconds}s';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get auth_label_sentCodeTo =>
      'Nous avons envoyé un code de vérification à 6 chiffres à';

  @override
  String get auth_subtitle_verifyOtp =>
      'Nous le vérifierons avec un code à usage unique.';

  @override
  String get auth_title_enterCode => 'Entrez votre code de vérification';

  @override
  String get auth_title_yourNumber => 'Votre numéro';

  @override
  String get background_edu_bachelors => 'Licence';

  @override
  String get background_edu_below_secondary => 'En dessous du secondaire';

  @override
  String get background_edu_diploma => 'Diplôme / Associé';

  @override
  String get background_edu_doctorate => 'Doctorat / PhD';

  @override
  String get background_edu_higher_secondary =>
      'Secondaire supérieur / A-Level';

  @override
  String get background_edu_masters => 'Une maîtrise';

  @override
  String get background_edu_secondary => 'Secondaire / Niveau O';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'Parlez-nous de la formation et de la carrière de votre $relation.';
  }

  @override
  String get background_edu_subtitle_self =>
      'Aide à trouver des correspondances professionnellement compatibles.';

  @override
  String get background_edu_title_guardian => 'Leur parcours';

  @override
  String get background_edu_title_self => 'Votre parcours';

  @override
  String get background_emp_employed => 'Employé';

  @override
  String get background_emp_not_working => 'Ne fonctionne pas';

  @override
  String get background_emp_self_employed => 'Travailleur indépendant';

  @override
  String get background_emp_student => 'Étudiant';

  @override
  String get background_income_subtitle =>
      'Beaucoup de gens ignorent cela – c\'est entièrement facultatif.';

  @override
  String get background_label_eduLevel => 'NIVEAU D\'ÉDUCATION';

  @override
  String get background_label_employment => 'STATUT D\'EMPLOI';

  @override
  String background_label_income_bracket(Object currency) {
    return 'TRANCHE DE REVENU ($currency)';
  }

  @override
  String get background_label_income_range => 'GAMME DE REVENU (Facultatif)';

  @override
  String get background_label_profession => 'Métier (facultatif)';

  @override
  String get background_label_study => 'Domaine d\'études (facultatif)';

  @override
  String get background_label_who_see => 'QUI PEUT VOIR CELA ?';

  @override
  String get background_vis_everyone => 'Montrer le support à tout le monde';

  @override
  String get background_vis_mutual =>
      'Afficher seulement après un intérêt mutuel';

  @override
  String get background_vis_private => 'Garder privé';

  @override
  String get ceremony_text_blessing => 'Qu\'Allah bénisse cela avec bonté';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaykoum. Après mûre réflexion, je pense que ce n’est peut-être pas le bon choix pour nous. Je vous souhaite sincèrement tout le meilleur et prie pour qu\'Allah vous bénisse avec un merveilleux partenaire. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaykoum. Je voulais être honnête et respectueux avec toi. Je ne pense pas que nous soyons le bon partenaire, mais je prie pour qu\'Allah vous ouvre de meilleures portes. Je vous souhaite tout le meilleur.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaykoum. Après mûre réflexion, je pense que nous ne sommes peut-être pas compatibles. J\'espère que vous trouverez quelqu\'un qui vous convient vraiment. Qu\'Allah vous facilite la tâche. JazakAllah khair pour votre temps.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaykoum. J\'ai réfléchi à nos conversations et je pense qu\'il est préférable de clôturer ce match à ce moment-là. Je n\'ai que du respect pour vous et je fais dua pour qu\'Allah vous bénisse du meilleur.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaykoum. Je voulais être transparente avec toi plutôt que de disparaître. Je ne vois pas cela progresser davantage, mais j\'apprécie vraiment votre temps et vous souhaite tout le bonheur. Qu\'Allah vous bénisse.';

  @override
  String get chat_endMatch_button => 'Envoyer et terminer la correspondance';

  @override
  String get chat_endMatch_subtitle =>
      'Choisissez un message respectueux pour clôturer cette conversation. L\'autre personne sera informée.';

  @override
  String get chat_endMatch_title => 'Terminez ce match';

  @override
  String chat_label_probation(int hours) {
    return 'La messagerie se déverrouille dans $hours heures. Vous pouvez envoyer des intérêts maintenant.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Abonnez-vous pour débloquer la messagerie. Les femmes envoient toujours des messages gratuits sur Silarah.';

  @override
  String get chat_matchClosed_banner =>
      'Ce match a été respectueusement clôturé.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikoum! Je suis tombé sur votre profil et j\'ai été vraiment impressionné. Puis-je me présenter ?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Votre profil a retenu mon attention. J\'aimerais en savoir plus sur vous.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaykoum. Je crois que nous partageons des valeurs similaires. Seriez-vous disposé à faire connaissance ?';

  @override
  String get chat_placeholder_typeMessage => 'Tapez un message…';

  @override
  String get common_button_back => 'Dos';

  @override
  String get common_button_cancel => 'Annuler';

  @override
  String get common_button_done => 'Fait';

  @override
  String get common_button_next => 'Suivant';

  @override
  String get common_button_retry => 'Essayer à nouveau';

  @override
  String get common_button_save => 'Sauvegarder';

  @override
  String get common_button_skip => 'Sauter';

  @override
  String get common_button_submit => 'Soumettre';

  @override
  String get common_error_generic =>
      'Quelque chose s\'est mal passé. Veuillez réessayer.';

  @override
  String get common_error_noInternet =>
      'Pas de connexion Internet. Veuillez vérifier votre connexion.';

  @override
  String get common_label_optional => 'Facultatif';

  @override
  String get copy_beard_parent => 'Votre fils a-t-il une barbe ?';

  @override
  String get copy_beard_self => 'As-tu une barbe ?';

  @override
  String get copy_beard_sibling => 'Ton frère a-t-il une barbe ?';

  @override
  String get copy_hijab_parent => 'Votre fille porte-t-elle le hijab ?';

  @override
  String get copy_hijab_self => 'Observez-vous le hijab ?';

  @override
  String get copy_hijab_sibling => 'Votre sœur porte-t-elle le hijab ?';

  @override
  String get copy_prayer_parent =>
      'Votre enfant prie-t-il cinq fois par jour ?';

  @override
  String get copy_prayer_self => 'Priez-vous cinq fois par jour ?';

  @override
  String get copy_prayer_sibling =>
      'Votre frère ou sœur prie-t-il cinq fois par jour ?';

  @override
  String get deleteAccount_title => 'Supprimer le compte';

  @override
  String discovery_bookmark_removed(Object name) {
    return '$name supprimé';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return '$name enregistré';
  }

  @override
  String get discovery_button_sendInterest => 'Envoyer un intérêt';

  @override
  String get discovery_completeness_button => 'Profil complet';

  @override
  String get discovery_completeness_subtitle =>
      'Les profils supérieurs à 40 % obtiennent 3 fois plus d’intérêts.\nComplétez votre profil pour commencer à naviguer.';

  @override
  String get discovery_completeness_title => 'Complétez votre profil';

  @override
  String get discovery_empty_subtitle =>
      'Essayez d\'élargir vos filtres de recherche\nou revenez demain.';

  @override
  String get discovery_empty_title => 'Vous avez vu tout le monde à proximité';

  @override
  String get discovery_handoff_interest_subtitle =>
      'Les profils avec une demande active passent dans Intérêts pendant votre attente ou votre réponse.';

  @override
  String get discovery_handoff_interest_title => 'Votre intérêt est en cours';

  @override
  String get discovery_handoff_match_subtitle =>
      'Les profils compatibles passent dans Chat et ne sont donc plus affichés dans Découvrir.';

  @override
  String get discovery_handoff_match_title => 'Votre connexion est prête';

  @override
  String get discovery_handoff_open_chat => 'Ouvrir le chat';

  @override
  String get discovery_handoff_open_interests => 'Ouvrir les intérêts';

  @override
  String get discovery_header_title => 'Silarah';

  @override
  String get discovery_label_interestSent => 'Intérêt envoyé ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Quelqu\'un avec qui vous pourriez vous connecter';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profils restants aujourd\'hui';
  }

  @override
  String get discovery_limit_button => 'Mettre à niveau maintenant';

  @override
  String get discovery_limit_subtitle =>
      'Vous avez parcouru 15 profils aujourd\'hui.\nMettez à niveau pour débloquer une navigation illimitée.';

  @override
  String get discovery_limit_title => 'Limite quotidienne atteinte';

  @override
  String discovery_remaining_profiles(Object count) {
    return '$count profils restants';
  }

  @override
  String get discovery_wildcard_label =>
      'Quelqu\'un avec qui vous pourriez vous connecter';

  @override
  String get family_children_no => 'Non';

  @override
  String get family_children_yes => 'Oui';

  @override
  String get family_label_children_guardian => 'ONT-ILS DES ENFANTS ?';

  @override
  String get family_label_children_self => 'AVEZ-VOUS DES ENFANTS?';

  @override
  String get family_label_how_many => 'COMBIEN?';

  @override
  String get family_label_parents => 'ÉTAT MARITIME DES PARENTS';

  @override
  String get family_label_polygamy_female_self =>
      'ACCEPTATION DE LA POLYGAMIE (Facultatif)';

  @override
  String get family_label_polygamy_male_self =>
      'STATUT DE POLYGAMIE (Facultatif)';

  @override
  String get family_label_prev_married => 'DÉJÀ MARIÉ ?';

  @override
  String get family_label_relocate => 'DISPOSÉ À DÉMÉNAGER';

  @override
  String get family_label_siblings => 'NOMBRE DE FRÈRES ET SŒURS';

  @override
  String get family_label_type => 'TYPE DE FAMILLE';

  @override
  String get family_living_title => 'ATTENTES DE VIE APRÈS LE MARIAGE';

  @override
  String get family_parents_both_deceased => 'Tous deux décédés';

  @override
  String get family_parents_divorced => 'Divorcé';

  @override
  String get family_parents_father_deceased => 'Père décédé';

  @override
  String get family_parents_mother_deceased => 'Mère décédée';

  @override
  String get family_parents_separated => 'Séparé';

  @override
  String get family_parents_together => 'Ensemble';

  @override
  String get family_polygamy_female_discussion => 'Ouvert à la discussion';

  @override
  String get family_polygamy_female_no => 'Non';

  @override
  String get family_polygamy_female_prefer_not => 'Je préfère ne pas dire';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'Votre $relation envisagerait-elle de devenir coépouse ?';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'Envisageriez-vous de devenir co-épouse ?';

  @override
  String get family_polygamy_female_yes => 'Oui';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'Votre $relation est-il actuellement marié et cherche-t-il un autre conjoint ?';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'Êtes-vous actuellement marié et recherchez-vous un conjoint supplémentaire?';

  @override
  String get family_polygamy_option_first => 'Non, c\'est mon premier';

  @override
  String get family_polygamy_option_married => 'Oui, actuellement marié';

  @override
  String get family_polygamy_option_prefer_not => 'Je préfère ne pas dire';

  @override
  String get family_prev_divorced => 'Divorcé';

  @override
  String get family_prev_no => 'Non';

  @override
  String get family_prev_widowed => 'Veuf';

  @override
  String get family_relocate_discussion => 'Ouvert à la discussion';

  @override
  String get family_relocate_no => 'Non';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'Votre $relation déménagerait-il pour se marier ?';
  }

  @override
  String get family_relocate_subtitle_self =>
      'Voudriez-vous déménager pour vous marier ?';

  @override
  String get family_relocate_yes => 'Oui';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'Parlez-nous de la famille de votre $relation.';
  }

  @override
  String get family_subtitle_self =>
      'La compatibilité familiale est essentielle à des mariages durables.';

  @override
  String get family_title_guardian => 'Antécédents familiaux';

  @override
  String get family_title_self => 'Antécédents familiaux';

  @override
  String get family_type_extended => 'Étendu';

  @override
  String get family_type_joint => 'Articulation';

  @override
  String get family_type_nuclear => 'Nucléaire';

  @override
  String get filter_label_community => 'Communauté / Biradari';

  @override
  String get filter_label_livingExpectation => 'Vivre après le mariage';

  @override
  String get filter_label_motherTongue => 'Langue maternelle';

  @override
  String get guardian_details_candidate_female =>
      'Candidate féminine • Message femme gratuit';

  @override
  String get guardian_details_candidate_label => 'CRÉATION D\'UN PROFIL POUR';

  @override
  String get guardian_details_candidate_male => 'Candidat masculin';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'Mon $relation';
  }

  @override
  String get guardian_details_involvement => 'IMPLICATION DU GARDIEN';

  @override
  String get guardian_details_involvement_subtitle =>
      'Dans quelle mesure souhaitez-vous participer aux conversations ?';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'Consultez les discussions, approuvez les correspondances et envoyez des messages au nom de votre $relation.';
  }

  @override
  String get guardian_details_mode_active_title => 'Tuteur actif';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'Consultez toutes les discussions en temps réel, mais seul votre $relation peut envoyer des messages.';
  }

  @override
  String get guardian_details_mode_passive_title => 'Observer seulement';

  @override
  String get guardian_details_name_hint => 'Nom et prénom';

  @override
  String get guardian_details_name_subtitle =>
      'Votre nom en tant que tuteur. Ceci est montré aux correspondances.';

  @override
  String guardian_details_notice(Object relation) {
    return 'Vous créez un profil pour votre $relation. Tous les détails du profil sur les écrans suivants les décriront, pas vous.';
  }

  @override
  String get guardian_details_search_hint => 'Recherche';

  @override
  String get guardian_details_select_code => 'Sélectionnez le code du pays';

  @override
  String get guardian_details_subtitle =>
      'Parlez-nous de vous en tant que tuteur.';

  @override
  String get guardian_details_title => 'Les coordonnées de votre tuteur';

  @override
  String get guardian_details_your_name => 'VOTRE NOM';

  @override
  String get interest_cat_creative => 'Créatif';

  @override
  String get interest_cat_faith => 'Foi';

  @override
  String get interest_cat_learning => 'Apprentissage';

  @override
  String get interest_cat_lifestyle => 'Mode de vie';

  @override
  String get interest_cat_social => 'Sociale';

  @override
  String get interest_cat_sports => 'Sportif';

  @override
  String get interest_tag_art => 'Art';

  @override
  String get interest_tag_calligraphy => 'Calligraphie';

  @override
  String get interest_tag_community_work => 'Travail communautaire';

  @override
  String get interest_tag_cooking => 'Cuisson';

  @override
  String get interest_tag_crafts => 'Artisanat';

  @override
  String get interest_tag_cricket => 'Cricket';

  @override
  String get interest_tag_cycling => 'Vélo';

  @override
  String get interest_tag_dawah => 'Dawah';

  @override
  String get interest_tag_family_gatherings => 'Réunions de famille';

  @override
  String get interest_tag_fitness => 'Aptitude';

  @override
  String get interest_tag_football => 'Football';

  @override
  String get interest_tag_gardening => 'Jardinage';

  @override
  String get interest_tag_graphic_design => 'Conception graphique';

  @override
  String get interest_tag_hiking => 'Randonnée';

  @override
  String get interest_tag_history => 'Histoire';

  @override
  String get interest_tag_islamic_lectures => 'Conférences islamiques';

  @override
  String get interest_tag_languages => 'Langues';

  @override
  String get interest_tag_martial_arts => 'Arts martiaux';

  @override
  String get interest_tag_mentoring => 'Mentorat';

  @override
  String get interest_tag_photography => 'Photographie';

  @override
  String get interest_tag_poetry => 'Poésie';

  @override
  String get interest_tag_quran_recitation => 'Récitation du Coran';

  @override
  String get interest_tag_reading => 'En lisant';

  @override
  String get interest_tag_science => 'Science';

  @override
  String get interest_tag_swimming => 'Natation';

  @override
  String get interest_tag_tahajjud => 'Tahajjud';

  @override
  String get interest_tag_teaching => 'Enseignement';

  @override
  String get interest_tag_technology => 'Technologie';

  @override
  String get interest_tag_travel => 'Voyage';

  @override
  String get interest_tag_umrah_hajj => 'Omra/Hajj';

  @override
  String get interest_tag_voluntary_fasting => 'Jeûne volontaire';

  @override
  String get interest_tag_volunteering => 'Volontariat';

  @override
  String get interest_tag_writing => 'En écrivant';

  @override
  String get interests_button_accept => 'Accepter';

  @override
  String get interests_button_decline => 'Déclin';

  @override
  String get interests_tab_received => 'Reçu';

  @override
  String get interests_tab_sent => 'Envoyé';

  @override
  String get interests_title => 'Intérêts';

  @override
  String get lang_albanian => 'albanais';

  @override
  String get lang_amazigh => 'Amazigh (berbère)';

  @override
  String get lang_amharic => 'Amharique';

  @override
  String get lang_arabic => 'arabe';

  @override
  String get lang_assamese => 'Assamais';

  @override
  String get lang_balochi => 'Baloutches';

  @override
  String get lang_bengali => 'bengali';

  @override
  String get lang_bosnian => 'bosniaque';

  @override
  String get lang_burmese => 'birman';

  @override
  String get lang_chechen => 'Tchétchène';

  @override
  String get lang_chinese => 'Chinois (mandarin)';

  @override
  String get lang_dari => 'Dari';

  @override
  String get lang_dutch => 'Néerlandais';

  @override
  String get lang_english => 'Anglais';

  @override
  String get lang_french => 'Français';

  @override
  String get lang_fulani => 'Peul';

  @override
  String get lang_german => 'Allemand';

  @override
  String get lang_gujarati => 'gujarati';

  @override
  String get lang_hausa => 'Haoussa';

  @override
  String get lang_hindi => 'hindi';

  @override
  String get lang_igbo => 'Igbo';

  @override
  String get lang_indonesian => 'indonésien';

  @override
  String get lang_italian => 'italien';

  @override
  String get lang_japanese => 'japonais';

  @override
  String get lang_javanese => 'javanais';

  @override
  String get lang_kannada => 'Kannada';

  @override
  String get lang_kazakh => 'Kazakh';

  @override
  String get lang_korean => 'coréen';

  @override
  String get lang_kurdish => 'kurde';

  @override
  String get lang_kyrgyz => 'Kirghize';

  @override
  String get lang_malay => 'malais';

  @override
  String get lang_malayalam => 'Malayalam';

  @override
  String get lang_mandinka => 'Mandingue';

  @override
  String get lang_marathi => 'Marathi';

  @override
  String get lang_norwegian => 'norvégien';

  @override
  String get lang_odia => 'Odia';

  @override
  String get lang_other => 'Autre';

  @override
  String get lang_pashto => 'pachtou';

  @override
  String get lang_persian => 'persan';

  @override
  String get lang_portuguese => 'portugais';

  @override
  String get lang_punjabi => 'Pendjabi';

  @override
  String get lang_rohingya => 'Rohingyas';

  @override
  String get lang_russian => 'russe';

  @override
  String get lang_saraiki => 'Saraiki';

  @override
  String get lang_sindhi => 'Sindhi';

  @override
  String get lang_somali => 'somali';

  @override
  String get lang_spanish => 'Espagnol';

  @override
  String get lang_sundanese => 'Soundanais';

  @override
  String get lang_swahili => 'Swahili';

  @override
  String get lang_swedish => 'suédois';

  @override
  String get lang_tagalog => 'Tagalog';

  @override
  String get lang_tajik => 'tadjik';

  @override
  String get lang_tamil => 'Tamoul';

  @override
  String get lang_tatar => 'tatar';

  @override
  String get lang_telugu => 'Télougou';

  @override
  String get lang_thai => 'thaïlandais';

  @override
  String get lang_tigrinya => 'Tigrinya';

  @override
  String get lang_turkish => 'turc';

  @override
  String get lang_urdu => 'Ourdou';

  @override
  String get lang_uzbek => 'Ouzbek';

  @override
  String get lang_wolof => 'Wolof';

  @override
  String get lang_yoruba => 'Yorouba';

  @override
  String get legal_button_continue => 'Continuer';

  @override
  String get legal_checkbox_age => 'Je confirme que j\'ai 18 ans ou plus';

  @override
  String get legal_checkbox_terms =>
      'J\'accepte les conditions d\'utilisation et la politique de confidentialité';

  @override
  String get legal_subtitle => 'Veuillez lire et accepter de continuer.';

  @override
  String get legal_summary_1 =>
      'Vos données sont cryptées et jamais revendues à des tiers.';

  @override
  String get legal_summary_2 =>
      'Chaque photo fait l’objet d’un contrôle de sécurité et notre équipe examine les nouvelles photos.';

  @override
  String get legal_summary_3 =>
      'Le harcèlement, les faux profils et les escroqueries entraînent des bannissements permanents.';

  @override
  String get legal_summary_4 =>
      'Cette plateforme est réservée aux intentions de mariage. La dignité est la norme.';

  @override
  String get legal_summary_5 =>
      'Vous pouvez supprimer votre compte et toutes vos données à tout moment.';

  @override
  String get legal_title => 'Avant de commencer';

  @override
  String get notifications_empty_subtitle =>
      'Aucune nouvelle notification pour le moment.';

  @override
  String get notifications_empty_title => 'Vous êtes tous rattrapés';

  @override
  String get notifications_markAllRead => 'Marquer tout comme lu';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get onboarding_about_title => 'À propos de vous';

  @override
  String get onboarding_background_title => 'Éducation et carrière';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'Vous remplissez cela en tant que tuteur. Ces informations concernent votre $relation.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'C\'est ce que les autres verront sur leur profil.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'C\'est ce que les autres verront sur votre profil.';

  @override
  String get onboarding_basicIdentity_title => 'Parlez-nous de vous';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Parlez-nous de votre $relation';
  }

  @override
  String get onboarding_debt_manageable => 'Dette gérable';

  @override
  String get onboarding_debt_none => 'Pas de dette';

  @override
  String get onboarding_debt_significant => 'Une dette importante';

  @override
  String get onboarding_diet_eatsAnything => 'Mange n\'importe quoi halal';

  @override
  String get onboarding_diet_halalOnly => 'Halal uniquement';

  @override
  String get onboarding_diet_vegan => 'Végétalien';

  @override
  String get onboarding_diet_vegetarian => 'Végétarien';

  @override
  String get onboarding_diet_zabihaStrict => 'Zabiha stricte';

  @override
  String get onboarding_error_bioContactInfo =>
      'Veuillez supprimer les informations de contact de votre bio. Les coordonnées externes ne sont pas autorisées pour votre sécurité.';

  @override
  String get onboarding_error_multipleFaces =>
      'Les photos de groupe ne peuvent pas être votre photo principale.';

  @override
  String get onboarding_error_noFace =>
      'Veuillez utiliser une photo où votre visage est clairement visible.';

  @override
  String get onboarding_error_under18 =>
      'Silarah est destiné aux personnes de 18 ans et plus. Nous avons formulé cette exigence pour protéger tous les membres de notre communauté.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Votre $relation doit être âgé d\'au moins 18 ans pour pouvoir utiliser Silarah.';
  }

  @override
  String get onboarding_error_under18_self =>
      'Vous devez avoir 18 ans ou plus pour utiliser Silarah. Nous nous réjouissons alors de vous accueillir.';

  @override
  String get onboarding_habit_frequently => 'Fréquemment';

  @override
  String get onboarding_habit_never => 'Jamais';

  @override
  String get onboarding_habit_occasionally => 'Occasionnellement';

  @override
  String get onboarding_habit_preferNotToSay => 'Je préfère ne pas dire';

  @override
  String get onboarding_hijab_always => 'Toujours';

  @override
  String get onboarding_hijab_no => 'Non';

  @override
  String get onboarding_hijab_sometimes => 'Parfois';

  @override
  String get onboarding_hint_bio => 'Décrivez-vous avec honnêteté et dignité.';

  @override
  String get onboarding_hint_profession =>
      'par ex. Ingénieur logiciel, enseignant, docteur';

  @override
  String get onboarding_hint_searchCity => 'Recherchez votre ville…';

  @override
  String get onboarding_hint_selectCommunity =>
      'Sélectionnez la communauté (facultatif)';

  @override
  String get onboarding_hint_selectCountry => 'Sélectionnez un pays';

  @override
  String get onboarding_hint_selectDateOfBirth =>
      'Sélectionnez la date de naissance';

  @override
  String get onboarding_hint_selectLanguage => 'Sélectionnez la langue';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'Cela permet de vous mettre en contact avec une personne compatible.';

  @override
  String get onboarding_islamicIdentity_title => 'Votre identité islamique';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'Ville';

  @override
  String get onboarding_label_city_guardian => 'Leur ville';

  @override
  String get onboarding_label_city_self => 'Votre ville';

  @override
  String get onboarding_label_community => 'Votre communauté / biradari';

  @override
  String get onboarding_label_community_parent => 'Leur communauté / biradari';

  @override
  String get onboarding_label_complexion => 'Teint (facultatif)';

  @override
  String get onboarding_label_country_guardian => 'Leur pays';

  @override
  String get onboarding_label_country_self => 'Votre pays';

  @override
  String get onboarding_label_cultural => 'Musulman culturel';

  @override
  String get onboarding_label_dateOfBirth => 'Date de naissance';

  @override
  String get onboarding_label_debtStatus => 'Statut de la dette';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Vos obligations financières actuelles.';

  @override
  String get onboarding_label_deenLevel => 'Niveau Deen';

  @override
  String get onboarding_label_diet => 'Régime';

  @override
  String get onboarding_label_educationLevel => 'Niveau d\'éducation';

  @override
  String get onboarding_label_female => 'Femelle';

  @override
  String get onboarding_label_firstName => 'Prénom';

  @override
  String get onboarding_label_firstName_guardian => 'Prénom du candidat';

  @override
  String get onboarding_label_firstName_self => 'Prénom';

  @override
  String get onboarding_label_gender => 'Genre';

  @override
  String get onboarding_label_gender_guardian => 'Sexe du candidat';

  @override
  String get onboarding_label_gender_self => 'Genre';

  @override
  String get onboarding_label_height_guardian => 'Leur hauteur';

  @override
  String get onboarding_label_height_self => 'Votre taille';

  @override
  String get onboarding_label_hookah => 'Narguilé / Chicha';

  @override
  String get onboarding_label_housing => 'Logement';

  @override
  String get onboarding_label_housingQuestion =>
      'Pouvez-vous fournir un espace de vie séparé ?';

  @override
  String get onboarding_label_lastName => 'Nom de famille';

  @override
  String get onboarding_label_leadership => 'Leadership religieux';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Pouvez-vous diriger les prières en commun ?';

  @override
  String get onboarding_label_lifestyleDiet => 'Mode de vie et alimentation';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'Ce sont des domaines décisifs pour de nombreuses familles. Veuillez répondre honnêtement.';

  @override
  String get onboarding_label_livingExpectation =>
      'Attentes de vie après le mariage';

  @override
  String get onboarding_label_mahrBudget => 'Budget';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'Quelle gamme de mahr êtes-vous prêt à proposer ?';

  @override
  String get onboarding_label_mahrExpectation => 'Attente de Mahr';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'Qu’attendez-vous du mahr ?';

  @override
  String get onboarding_label_maintenance => 'Entretien financier';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Êtes-vous en mesure de subvenir aux besoins financiers de votre conjoint ?';

  @override
  String get onboarding_label_male => 'Mâle';

  @override
  String get onboarding_label_marriageTimeline => 'Chronologie du mariage';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'Quand comptez-vous vous marier ?';

  @override
  String get onboarding_label_moderate => 'Modéré';

  @override
  String get onboarding_label_motherTongue => 'Langue maternelle';

  @override
  String get onboarding_label_niqab => 'Niqâb';

  @override
  String get onboarding_label_practicing => 'Pratiquant';

  @override
  String get onboarding_label_praysFiveDaily => 'Je prie cinq fois par jour';

  @override
  String get onboarding_label_preferNotToSay => 'Je préfère ne pas dire';

  @override
  String get onboarding_label_preferredLiving =>
      'Préférence en matière de conditions de vie';

  @override
  String get onboarding_label_profession => 'Profession';

  @override
  String get onboarding_label_providerReadiness => 'Préparation du fournisseur';

  @override
  String get onboarding_label_quranMemorization => 'Mémorisation du Coran';

  @override
  String get onboarding_label_religiousEducation => 'Éducation religieuse';

  @override
  String get onboarding_label_residencyStatus =>
      'Statut de résidence (facultatif)';

  @override
  String get onboarding_label_revert => 'Rétablir/Convertir (Facultatif)';

  @override
  String get onboarding_label_revertQuestion =>
      'Êtes-vous un retour (converti) à l’Islam ?';

  @override
  String get onboarding_label_sect => 'Secte';

  @override
  String get onboarding_label_shia => 'Chiite';

  @override
  String get onboarding_label_smoking => 'Fumeur';

  @override
  String get onboarding_label_specialNeeds => 'Besoins spéciaux (facultatif)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'Étape $current de $total';
  }

  @override
  String get onboarding_label_subSect => 'École de pensée (facultatif)';

  @override
  String get onboarding_label_substanceUse => 'Consommation de substances';

  @override
  String get onboarding_label_sunni => 'Sunnite';

  @override
  String get onboarding_label_vaping => 'Vapotage / E-Cigarettes';

  @override
  String get onboarding_label_workAfterMarriage =>
      'Travailler après le mariage';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Aimeriez-vous travailler après le mariage ?';

  @override
  String get onboarding_leadership_leads => 'Dirige la prière';

  @override
  String get onboarding_leadership_learning => 'Apprentissage';

  @override
  String get onboarding_leadership_notYet => 'Pas encore';

  @override
  String get onboarding_living_openToDiscussion => 'Ouvert à la discussion';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Je suis flexible et heureux de discuter de ce qui fonctionne pour les deux.';

  @override
  String get onboarding_living_separate => 'Maison séparée';

  @override
  String get onboarding_living_separateSub =>
      'Je préfère que nous ayons notre propre maison indépendante.';

  @override
  String get onboarding_living_withInlaws => 'Avec la belle-famille';

  @override
  String get onboarding_living_withInlawsSub =>
      'Je m\'attends à vivre avec la famille de mon conjoint ou avec ma propre famille.';

  @override
  String get onboarding_location_confirmed => 'Emplacement confirmé';

  @override
  String get onboarding_mahr_generous => 'Généreux';

  @override
  String get onboarding_mahr_moderate => 'Modéré';

  @override
  String get onboarding_mahr_modest => 'Modeste';

  @override
  String get onboarding_mahr_noPreference => 'Aucune préférence';

  @override
  String get onboarding_mahr_toDiscuss => 'Pour discuter';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'Ces détails ne sont pas affichés sur votre profil public. Ils sont partagés en privé lors de la phase d’acceptation.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Aidez-nous à comprendre votre parcours et votre état de préparation.';

  @override
  String get onboarding_marriageDeen_title => 'Mariage et religion';

  @override
  String get onboarding_niqab_dontWear => 'je ne porte pas de niqab';

  @override
  String get onboarding_niqab_open => 'Ouvert au port';

  @override
  String get onboarding_niqab_wear => 'je porte le niqab';

  @override
  String get onboarding_photo_subtitle =>
      'Au moins une photo est requise. Votre photo principale doit inclure clairement votre visage.';

  @override
  String get onboarding_photo_title => 'Ajoutez vos photos';

  @override
  String get onboarding_photo_verifySelfie => 'Selfie de vérification';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Prenez une photo en direct pour vérifier que vous êtes réel';

  @override
  String get onboarding_preferredLiving_noPreference => 'Aucune préférence';

  @override
  String get onboarding_profileForWhom_creatingFor => 'Je crée ceci pour mon…';

  @override
  String get onboarding_profileForWhom_guardian => 'Mon fils ou ma fille';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'Je crée ce profil pour quelqu\'un';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Tuteur';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Je suis un parent ou un tuteur';

  @override
  String get onboarding_profileForWhom_myself => 'Moi-même';

  @override
  String get onboarding_profileForWhom_myselfSub => 'je cherche un conjoint';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Frère';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Fille';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Sœur';

  @override
  String get onboarding_profileForWhom_relation_son => 'Fils';

  @override
  String get onboarding_profileForWhom_selectOne =>
      'Sélectionnez-en un pour continuer';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Sélectionnez une relation pour continuer';

  @override
  String get onboarding_profileForWhom_sibling => 'Mon frère ou ma sœur';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'J\'aide mon frère à trouver une personne compatible';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'Vous pourrez le mettre à jour ultérieurement à partir des paramètres.';

  @override
  String get onboarding_profileForWhom_title => 'A qui s\'adresse ce profil ?';

  @override
  String get onboarding_profileForWhom_ward => 'Ma paroisse';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Je suis un tuteur qui gère ce profil';

  @override
  String get onboarding_providerQuote =>
      '\"Les meilleurs d\'entre vous sont les meilleurs pour vos femmes.\" — Prophète Muhammad ﷺ\n\nÊtre honnête quant à votre état de préparation aide à construire une base solide.';

  @override
  String get onboarding_quran_hafiz => 'Hafiz / Hafiza';

  @override
  String get onboarding_quran_none => 'Aucun';

  @override
  String get onboarding_quran_partial => 'Hifz partiel';

  @override
  String get onboarding_quran_some => 'Quelques sourates';

  @override
  String get onboarding_religiousEdu_alim => 'Cours Alim';

  @override
  String get onboarding_religiousEdu_islamicUni => 'Université islamique';

  @override
  String get onboarding_religiousEdu_madrasa => 'Médersa';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Autodidacte';

  @override
  String get onboarding_timeline_1year => 'Dans un délai d\'un an';

  @override
  String get onboarding_timeline_2years => '2+ ans';

  @override
  String get onboarding_timeline_6months => 'Dans les 6 mois';

  @override
  String get onboarding_timeline_asap => 'Dès que possible';

  @override
  String get onboarding_timeline_notSure => 'Je ne suis pas encore sûr';

  @override
  String get onboarding_tooltip_cultural =>
      'S\'identifie comme musulman, célèbre des occasions, ne peut pas prier régulièrement';

  @override
  String get onboarding_tooltip_moderate =>
      'Attaché aux principes islamiques et prie, mais pas toujours cinq fois par jour';

  @override
  String get onboarding_tooltip_practicing =>
      'Suit les cinq piliers, prie régulièrement, mode de vie halal';

  @override
  String get onboarding_work_no => 'Non, je préfère ne pas le faire';

  @override
  String get onboarding_work_yes => 'Oui, j\'ai l\'intention de travailler';

  @override
  String get photo_add_main_required =>
      'Ajouter une photo principale\n(obligatoire)';

  @override
  String get photo_add_photo => 'Ajouter une photo';

  @override
  String get photo_banner_text =>
      'Les photos au contenu explicite ne sont pas autorisées';

  @override
  String get photo_error_no_face_detected =>
      'Aucun visage visible : veuillez réessayer avec une photo de visage claire';

  @override
  String photo_error_pick_failed(Object error) {
    return 'Impossible de sélectionner la photo : $error';
  }

  @override
  String get photo_face_detected => 'Visage détecté ✓';

  @override
  String get photo_label_photo2 => 'Photo 2';

  @override
  String get photo_label_photo3 => 'Photo 3';

  @override
  String get photo_label_primary => 'Photo principale';

  @override
  String get photo_label_selfie => 'Photo 4';

  @override
  String get photo_no_face => 'Aucun visage visible';

  @override
  String get photo_privacy_everyone => 'Visible par tous';

  @override
  String get photo_privacy_everyone_sub =>
      'Tous les membres peuvent voir vos photos.';

  @override
  String get photo_privacy_label => 'CONFIDENTIALITÉ DES PHOTOS';

  @override
  String get photo_privacy_mutual => 'Visible après intérêt mutuel';

  @override
  String get photo_privacy_mutual_sub =>
      'Les photos ne se révèlent que lorsque les deux parties expriment leur intérêt.';

  @override
  String get photo_privacy_request => 'Demande de visualisation';

  @override
  String get photo_privacy_request_sub =>
      'Les photos sont floues jusqu\'à ce que vous approuviez une demande.';

  @override
  String get photo_sheet_camera => 'Caméra';

  @override
  String get photo_sheet_gallery => 'Galerie';

  @override
  String get photo_sheet_title => 'Sélectionnez la source de la photo';

  @override
  String get photo_slots_help =>
      'APPUYEZ SUR LES EMPLACEMENTS POUR TÉLÉCHARGER';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'Ajoutez des photos de votre $relation. Il en faut au moins un.';
  }

  @override
  String get photo_subtitle_self =>
      'Au moins une photo est requise. Quatre maximum.';

  @override
  String get photo_title_guardian => 'Ajouter leurs photos';

  @override
  String get photo_title_self => 'Ajoutez vos photos';

  @override
  String get preferences_deen_any => 'N\'importe lequel';

  @override
  String get preferences_deen_cultural => 'Musulman culturel';

  @override
  String get preferences_deen_moderate => 'Modéré';

  @override
  String get preferences_deen_practicing => 'Pratiquant';

  @override
  String get preferences_edu_any => 'N\'importe lequel';

  @override
  String get preferences_edu_bachelors => 'Baccalauréat +';

  @override
  String get preferences_edu_diploma => 'Diplôme +';

  @override
  String get preferences_edu_masters => 'Master +';

  @override
  String get preferences_edu_phd => 'Doctorat uniquement';

  @override
  String get preferences_edu_secondary => 'Secondaire +';

  @override
  String get preferences_label_age => 'Tranche d\'âge';

  @override
  String get preferences_label_age_bounds => '18 – 60';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max ans';
  }

  @override
  String get preferences_label_deen => 'PRÉFÉRENCE DE NIVEAU DEEN';

  @override
  String get preferences_label_edu => 'FORMATION MINIMALE';

  @override
  String get preferences_label_living => 'PRÉFÉRENCE DE CONFIGURATION DE VIE';

  @override
  String get preferences_label_location => 'EMPLACEMENT';

  @override
  String get preferences_label_openness => 'OUVERTURE';

  @override
  String get preferences_label_sect => 'PRÉFÉRENCE DE SECTE';

  @override
  String get preferences_living_discussion => 'Ouvert à la discussion';

  @override
  String get preferences_living_family => 'En famille';

  @override
  String get preferences_living_no_pref => 'Aucune préférence';

  @override
  String get preferences_living_separate => 'Maison séparée';

  @override
  String get preferences_location_abroad => 'Ouvert à l\'étranger';

  @override
  String get preferences_location_diaspora => 'Mode diaspora';

  @override
  String get preferences_location_same_city => 'Même ville';

  @override
  String get preferences_location_same_country => 'Même pays';

  @override
  String get preferences_open_children =>
      'Ouvert à quelqu\'un avec des enfants';

  @override
  String get preferences_open_divorced => 'Ouvert à une personne déjà divorcée';

  @override
  String get preferences_open_widowed =>
      'Ouvert à une personne précédemment veuve';

  @override
  String get preferences_sect_any => 'N\'importe lequel';

  @override
  String get preferences_sect_same => 'Pareil que le mien';

  @override
  String get preferences_sect_shia => 'Chiite';

  @override
  String get preferences_sect_sunni => 'Sunnite';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'Définissez les préférences pour la correspondance idéale de votre $relation.';
  }

  @override
  String get preferences_subtitle_self =>
      'Ce sont des préférences, pas des filtres stricts.';

  @override
  String get preferences_title => 'Préférences du partenaire';

  @override
  String get preview_age_label => 'Âge';

  @override
  String get preview_background => 'Arrière-plan';

  @override
  String get preview_basic_info => 'Informations de base';

  @override
  String get preview_city_label => 'Ville';

  @override
  String get preview_community_label => 'Communauté';

  @override
  String get preview_cowife_label => 'Acceptation de la coépouse';

  @override
  String get preview_deen_label => 'Niveau Deen';

  @override
  String get preview_diet_label => 'Régime';

  @override
  String get preview_edit => 'Modifier';

  @override
  String get preview_education_label => 'Éducation';

  @override
  String get preview_faith => 'Foi';

  @override
  String get preview_family => 'Famille';

  @override
  String get preview_family_type_label => 'Type de famille';

  @override
  String get preview_gender_label => 'Genre';

  @override
  String get preview_hijab_label => 'hijab';

  @override
  String get preview_hookah_label => 'Narguilé';

  @override
  String get preview_leadership_label => 'Direction';

  @override
  String get preview_marital_label => 'Matrimonial';

  @override
  String get preview_marriage_timeline_label => 'Chronologie du mariage';

  @override
  String get preview_mother_tongue_label => 'Langue maternelle';

  @override
  String get preview_name_label => 'Nom';

  @override
  String get preview_notice_guardian =>
      'C’est exactement ainsi que les autres verront leur profil.';

  @override
  String get preview_notice_self =>
      'C’est exactement ainsi que les autres verront votre profil.';

  @override
  String get preview_polygamy_label => 'Polygamie';

  @override
  String get preview_post_marriage_living_label => 'Vivre après le mariage';

  @override
  String get preview_prays_label => 'Prie 5x';

  @override
  String get preview_profession_label => 'Profession';

  @override
  String get preview_quran_label => 'Coran';

  @override
  String get preview_religious_edu_label => 'Éducation religieuse';

  @override
  String get preview_residency_label => 'Résidence';

  @override
  String get preview_revert_label => 'Revenir';

  @override
  String get preview_sect_label => 'Secte';

  @override
  String get preview_siblings_label => 'Frères et sœurs';

  @override
  String get preview_smoking_label => 'Fumeur';

  @override
  String get preview_special_needs_label => 'Besoins spéciaux';

  @override
  String get preview_submit_btn => 'Soumettre le profil';

  @override
  String get preview_title => 'Aperçu';

  @override
  String get preview_vaping_label => 'Vapoter';

  @override
  String get preview_willing_relocate_label => 'Disposé à déménager';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil $percent% terminé';
  }

  @override
  String get profile_nudge_completeness =>
      'Les profils avec plus de 80 % d’exhaustivité reçoivent 3 fois plus d’intérêts.';

  @override
  String get settings_brand_credit =>
      'Silarah (سيلارا) · Pour l\'amour d\'Allah';

  @override
  String get settings_button_deleteAccount => 'Supprimer le compte';

  @override
  String get settings_guardian_mirror => 'Messages miroir';

  @override
  String get settings_guardian_mirror_sub =>
      'Envoyer des copies de tous les messages au tuteur';

  @override
  String get settings_guardian_name_hint => 'Nom du tuteur';

  @override
  String get settings_guardian_relationship => 'Relation';

  @override
  String get settings_guardian_reply => 'Autoriser le tuteur à répondre';

  @override
  String get settings_guardian_reply_sub =>
      'Le tuteur peut participer aux conversations';

  @override
  String get settings_guardian_save => 'Enregistrer les paramètres du tuteur';

  @override
  String get settings_guardian_saved => 'Enregistré';

  @override
  String get settings_guardian_sub =>
      'Activer la surveillance Wali pour la messagerie';

  @override
  String get settings_guardian_title => 'Mode Gardien';

  @override
  String get settings_label_blocked => 'Profils bloqués';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count bloqué';
  }

  @override
  String get settings_label_blocked_none => 'Aucun';

  @override
  String get settings_label_deleteGrace =>
      'Votre profil sera masqué immédiatement. Vos données seront définitivement supprimées après 30 jours.';

  @override
  String get settings_label_editProfile => 'Modifier le profil';

  @override
  String get settings_label_language => 'Langue';

  @override
  String get settings_label_photoPrivacy => 'Confidentialité des photos';

  @override
  String get settings_label_rate => 'Notez Silarah';

  @override
  String get settings_label_rate_snackbar =>
      'L\'évaluation sera disponible une fois Silarah lancé sur l\'App Store.';

  @override
  String get settings_label_reports => 'Historique des rapports';

  @override
  String settings_label_reports_count(Object count) {
    return '$count rapports';
  }

  @override
  String get settings_label_reports_none => 'Aucun rapport soumis';

  @override
  String get settings_label_selfieChallenge => 'Défi selfie';

  @override
  String get settings_label_verifyProfile => 'Vérifier le profil';

  @override
  String get settings_label_version => 'Version';

  @override
  String get settings_notify_activityNudges =>
      'Coups de pouce pour l\'activité';

  @override
  String get settings_notify_activityNudgesSub =>
      'Rappeler en cas d\'inactivité pendant plus de 7 jours';

  @override
  String get settings_notify_boostReminders => 'Rappels de boost';

  @override
  String get settings_notify_boostRemindersSub =>
      'Rappelez-vous quand votre boost hebdomadaire est prêt';

  @override
  String get settings_notify_interestAccepted => 'Intérêt accepté';

  @override
  String get settings_notify_interestExpiring => 'Intérêt expirant bientôt';

  @override
  String get settings_notify_newInterest => 'Nouveaux intérêts';

  @override
  String get settings_notify_newMessage => 'Nouveaux messages';

  @override
  String get settings_notify_quietHours => 'Heures calmes';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'Intérêts acceptés uniquement';

  @override
  String get settings_photo_privacy_after_acceptance => 'Après acceptation';

  @override
  String get settings_photo_privacy_everyone => 'Tout le monde';

  @override
  String get settings_photo_privacy_public => 'Publique';

  @override
  String get settings_photo_privacy_request_only => 'Sur demande uniquement';

  @override
  String get settings_photo_privacy_request_to_view =>
      'Demande de visualisation';

  @override
  String get settings_privacy_download_body =>
      'Créez maintenant une archive ZIP privée contenant votre compte, profil, photos, intérêts, matchs, messages, réglages, consentements et historique d\'abonnement. Enregistrez-la avec la feuille de partage sécurisée de votre appareil.';

  @override
  String get settings_privacy_download_btn => 'Créer l\'archive sécurisée';

  @override
  String get settings_privacy_download_label => 'Télécharger mes données';

  @override
  String get settings_privacy_download_sub =>
      'Enregistrer une copie lisible par machine de vos données Silarah';

  @override
  String get settings_privacy_export_body =>
      'Votre archive privée est prête. Utilisez la feuille de partage pour l\'enregistrer en sécurité.';

  @override
  String get settings_privacy_export_btn_close => 'Compris';

  @override
  String get settings_privacy_export_subbody =>
      'Cette archive peut contenir des messages privés et des coordonnées. Conservez-la en sécurité et ne la partagez qu\'avec des personnes de confiance.';

  @override
  String get settings_privacy_export_title => 'Archive prête';

  @override
  String get settings_privacy_online_label => 'STATUT EN LIGNE';

  @override
  String get settings_privacy_online_sub =>
      'Afficher quand vous avez été actif pour la dernière fois';

  @override
  String get settings_privacy_pause_label => 'Pause du profil';

  @override
  String get settings_privacy_pause_sub =>
      'Masquer votre profil de la recherche';

  @override
  String get settings_privacy_pause_warning =>
      'Votre profil est masqué. Personne ne peut vous trouver.';

  @override
  String get settings_privacy_photo_label => 'Visibilité des photos';

  @override
  String get settings_privacy_photo_sub => 'Qui peut voir vos photos';

  @override
  String get settings_privacy_visibility_all =>
      'Tous les utilisateurs enregistrés';

  @override
  String get settings_privacy_visibility_label => 'QUI PEUT VOIR MON PROFIL';

  @override
  String get settings_privacy_visibility_sub =>
      'Contrôle qui peut parcourir votre profil';

  @override
  String get settings_privacy_visibility_subscribers => 'Abonnés uniquement';

  @override
  String get settings_relation_brother => 'Frère';

  @override
  String get settings_relation_father => 'Père';

  @override
  String get settings_relation_mother => 'Mère';

  @override
  String get settings_relation_other => 'Autre';

  @override
  String get settings_relation_uncle => 'Oncle';

  @override
  String get settings_section_account => 'Compte';

  @override
  String get settings_section_app => 'Application';

  @override
  String get settings_section_dangerZone => 'Fermer le compte';

  @override
  String get settings_section_guardian => 'Tuteur';

  @override
  String get settings_section_legal => 'Légal';

  @override
  String get settings_section_notifications => 'Notifications';

  @override
  String get settings_section_privacy => 'Confidentialité';

  @override
  String get settings_section_safety => 'Sécurité';

  @override
  String get settings_support_body =>
      'Pour toute question, préoccupation ou commentaire :';

  @override
  String get settings_support_btn_close => 'Fermer';

  @override
  String get settings_support_contact => 'Contacter l\'assistance';

  @override
  String get settings_support_note =>
      'Nous visons à répondre dans les 48 heures.';

  @override
  String get settings_title => 'Paramètres';

  @override
  String get splash_button_createProfile => 'Créer un profil';

  @override
  String get splash_button_signIn => 'Se connecter';

  @override
  String get splash_intention_subtitle =>
      'Des présentations privées, une compatibilité réfléchie et un lien respectueux de la famille.';

  @override
  String get splash_intention_title => 'Le mariage, avec intention.';

  @override
  String get splash_referral_button => 'Appliquer le code';

  @override
  String get splash_referral_hint => 'par ex. SILARAHXX';

  @override
  String get splash_referral_invalid =>
      'Veuillez saisir un code valide à 6 caractères.';

  @override
  String get splash_referral_question => 'Vous avez un code de parrainage ?';

  @override
  String get splash_referral_saved =>
      'Code de parrainage enregistré ! Il sera appliqué après votre connexion.';

  @override
  String get splash_referral_subtitle =>
      'Si un ami vous a invité sur Silarah, saisissez son code de parrainage à 6 caractères ci-dessous.';

  @override
  String get splash_referral_title => 'Entrez le code de référence';

  @override
  String subscription_button_monthly(String price) {
    return 'Abonnez-vous — $price/mois';
  }

  @override
  String subscription_button_three_month(String price) {
    return 'Abonnez-vous — $price/3 mois';
  }

  @override
  String get subscription_label_bestValue => 'Meilleur rapport qualité-prix';

  @override
  String get subscription_subtitle =>
      'Message pour femmes gratuit. Les hommes s\'abonnent pour se connecter.';

  @override
  String get subscription_title => 'Débloquez Silarah';

  @override
  String get startup_connectivity_preparing_title =>
      'Préparation de votre espace privé';

  @override
  String get startup_connectivity_preparing_body =>
      'Établissement d’une connexion sécurisée à Silarah.';

  @override
  String get startup_connectivity_offline_title => 'Connexion indisponible';

  @override
  String get startup_connectivity_offline_body =>
      'Votre place sur Silarah est sécurisée. Nous reprendrons dès le retour du réseau.';

  @override
  String get startup_connectivity_verifying => 'VÉRIFICATION DE LA CONNEXION';

  @override
  String get startup_connectivity_waiting => 'CONNEXION SÉCURISÉE · EN ATTENTE';

  @override
  String get startup_connectivity_still_waiting => 'TOUJOURS EN ATTENTE';

  @override
  String get startup_connectivity_check => 'Vérifier la connexion';

  @override
  String get startup_connectivity_checking => 'Vérification sécurisée';

  @override
  String get startup_connectivity_auto => 'La reconnexion est automatique';

  @override
  String get startup_connectivity_protected => 'Connexion protégée';

  @override
  String get settings_label_email => 'E-mail';

  @override
  String get settings_notify_profileViews => 'Vues du profil';

  @override
  String get settings_notify_profileViewsSub =>
      'Alerte privée lorsqu’une personne ouvre votre profil';

  @override
  String get settings_notify_profileLive => 'Mise en ligne du profil';

  @override
  String get settings_notify_profileLiveSub =>
      'Confirmation lorsque votre profil devient visible';

  @override
  String get settings_appearance => 'Apparence';

  @override
  String get settings_helpSupport => 'Aide et assistance';

  @override
  String get settings_helpCenter => 'Centre d’aide';

  @override
  String get settings_grievanceOfficer => 'Responsable des réclamations';

  @override
  String get settings_grievanceResponse =>
      'Accusé de réception sous 24 heures ; la plupart des plaintes résolues sous 7 jours';

  @override
  String get settings_grievanceIndiaNotice =>
      'En Inde, le traitement des plaintes suit les règles modifiées sur les technologies de l’information (directives aux intermédiaires et code d’éthique des médias numériques). Les contenus illégaux ou intimes urgents suivent des délais légaux plus courts.';

  @override
  String get settings_managePhotoRequests => 'Gérer les demandes de photos';

  @override
  String get settings_managePhotoRequestsSub =>
      'Approuver l’accès, refuser les demandes ou révoquer le partage';

  @override
  String get settings_theme_chooseTitle => 'Choisissez votre ambiance';

  @override
  String get settings_theme_chooseSubtitle =>
      'Une identité visuelle complète, pas un simple filtre de couleur. Toutes les surfaces, tous les champs et contrôles changent ensemble.';

  @override
  String get settings_theme_applied =>
      'Appliqué instantanément · enregistré sur cet appareil';

  @override
  String get settings_reportPending => 'En attente';

  @override
  String get legal_document_terms => 'Conditions d’utilisation';

  @override
  String get legal_document_privacy => 'Politique de confidentialité';

  @override
  String get legal_document_community => 'Règles de la communauté';

  @override
  String get legal_specialCategoryConsent =>
      'Je consens explicitement au traitement par Silarah de mes informations religieuses (école, pratique de la prière et identité islamique) pour la mise en relation. Les prestataires sous contrat les utilisent uniquement pour exploiter Silarah, jamais pour la publicité comportementale.';

  @override
  String get onboarding_complexion_fair => 'Clair';

  @override
  String get onboarding_complexion_medium => 'Moyen';

  @override
  String get onboarding_complexion_olive => 'Olive';

  @override
  String get onboarding_complexion_dark => 'Foncé';

  @override
  String get onboarding_residency_citizen => 'Citoyen(ne)';

  @override
  String get onboarding_residency_permanentResident =>
      'Résident(e) permanent(e)';

  @override
  String get onboarding_residency_workVisa => 'Visa de travail';

  @override
  String get onboarding_residency_studentVisa => 'Visa étudiant';

  @override
  String get onboarding_specialNeeds_none => 'Aucun';

  @override
  String get onboarding_specialNeeds_physical => 'Handicap physique';

  @override
  String get onboarding_specialNeeds_hearing => 'Déficience auditive';

  @override
  String get onboarding_specialNeeds_visual => 'Déficience visuelle';

  @override
  String get onboarding_label_stateRegion => 'État / Région';

  @override
  String get onboarding_specialNeeds_privacy =>
      'Partagé uniquement après un intérêt mutuel.';

  @override
  String get settings_theme_automatic => 'Automatique';

  @override
  String get settings_theme_automaticDesc =>
      'Ivoire et émeraude le jour, Nuit OLED quand votre téléphone est en mode sombre';

  @override
  String get settings_theme_rose => 'Rose et souci';

  @override
  String get settings_theme_roseDesc =>
      'Rose poudré, rose profond et or de souci';

  @override
  String get settings_theme_oled => 'Nuit OLED';

  @override
  String get settings_theme_oledDesc =>
      'Noir véritable optimisé pour les écrans OLED';

  @override
  String get settings_theme_ivory => 'Ivoire et émeraude';

  @override
  String get settings_theme_ivoryDesc =>
      'Ivoire chaleureux, émeraude profonde et or patiné';

  @override
  String get settings_guardian_backendRequired =>
      'Les paramètres du tuteur nécessitent une connexion sécurisée.';

  @override
  String get settings_guardian_saveError =>
      'Impossible d’enregistrer les paramètres du tuteur. Réessayez.';

  @override
  String get common_openSettings => 'Ouvrir les paramètres';

  @override
  String get media_cameraAccessOff => 'L’accès à la caméra est désactivé';

  @override
  String get media_cameraUnavailable => 'Caméra indisponible';

  @override
  String get media_cameraAccessBody =>
      'Autorisez l’accès à la caméra dans les paramètres, puis revenez prendre une photo nette.';

  @override
  String get media_cameraUnavailableBody =>
      'Impossible d’ouvrir la caméra. Réessayez.';

  @override
  String get media_photoAccessOff => 'L’accès aux photos est désactivé';

  @override
  String get media_photoAccessBody =>
      'Autorisez l’accès à la caméra ou aux photos dans les paramètres, puis revenez ajouter votre photo.';

  @override
  String get chat_searchHint => 'Rechercher des messages';

  @override
  String get chat_noConversationsFound => 'Aucune conversation trouvée';

  @override
  String get chat_noConversationsFoundBody =>
      'Essayez un autre nom ou effacez la recherche.';

  @override
  String get chat_noConversationsYet => 'Aucune conversation pour le moment';

  @override
  String get chat_noConversationsYetBody =>
      'Acceptez un intérêt ou attendez que le vôtre soit accepté pour commencer une conversation.';

  @override
  String get referral_title => 'Inviter un ami';

  @override
  String get referral_loading => 'Chargement des récompenses';

  @override
  String get referral_heading => 'Faites passer le mot et gagnez Premium !';

  @override
  String get referral_body =>
      'Invitez toute personne éligible sur Silarah. Chaque compte peut recevoir une seule récompense de parrainage Premium de 3 jours. Si vous avez déjà reçu la vôtre, votre ami peut toujours recevoir la sienne.';

  @override
  String get referral_premiumActiveTitle =>
      'Le Premium de parrainage est actif';

  @override
  String referral_premiumRemainingDaysHours(int days, int hours) {
    return '$days j $hours h restantes';
  }

  @override
  String referral_premiumRemainingHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min restantes';
  }

  @override
  String referral_premiumRemainingMinutes(int minutes) {
    return '$minutes min restantes';
  }

  @override
  String get referral_premiumEndingNow => 'La récompense se termine maintenant';

  @override
  String referral_premiumEndsAt(String date) {
    return 'Se termine le $date';
  }

  @override
  String get referral_premiumNoPayment =>
      'Toutes les fonctions Premium sont débloquées. Aucun paiement n’a été prélevé et cette récompense ne sera pas renouvelée automatiquement.';

  @override
  String get referral_premiumPlansAfter =>
      'Les abonnements seront disponibles après votre récompense gratuite afin de ne perdre aucun temps gratuit restant.';

  @override
  String get referral_premiumBackToProfile => 'Retour au profil';

  @override
  String get referral_premiumFeaturesUnlocked =>
      'Toutes les fonctions Premium sont débloquées';

  @override
  String get referral_premiumViewReward => 'Voir la récompense';

  @override
  String get referral_codeLabel => 'VOTRE CODE DE PARRAINAGE';

  @override
  String get referral_tapToCopy => 'Touchez le code pour le copier';

  @override
  String get referral_totalInvited => 'Total invité';

  @override
  String get referral_rewardsEarned => 'Récompenses gagnées';

  @override
  String referral_premiumDays(int count) {
    return '$count jours Premium';
  }

  @override
  String get referral_pending => 'Inscriptions en attente';

  @override
  String get referral_shareButton => 'Partager le code avec des amis';

  @override
  String get referral_copied => 'Code de parrainage copié !';

  @override
  String get referral_shareSubject => 'Rejoignez Silarah';

  @override
  String referral_shareText(String code) {
    return 'Rejoignez Silarah, l’application matrimoniale musulmane de confiance. Utilisez mon code : $code\n\nTéléchargement : https://silarah.com/r/$code';
  }

  @override
  String get profile_share => 'Partager le profil';

  @override
  String safety_reportMember(String name) {
    return 'Signaler $name';
  }

  @override
  String safety_blockMember(String name) {
    return 'Bloquer $name';
  }

  @override
  String safety_blockTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String safety_blockBody(String name) {
    return '$name sera masqué de Discovery et ne pourra plus vous contacter. L’historique reste conservé pour votre sécurité. Le déblocage ne rouvrira pas la conversation.';
  }

  @override
  String get safety_blockAction => 'Bloquer';

  @override
  String safety_blocked(String name) {
    return '$name a été bloqué.';
  }

  @override
  String ui_openProfile(String name) {
    return 'Ouvrir le profil $name';
  }

  @override
  String ui_typing(String name) {
    return '$name est en train d\'écrire';
  }

  @override
  String ui_deleteFailed(String error) {
    return 'Échec de la suppression du compte : $error';
  }

  @override
  String ui_changeCountry(String country) {
    return 'Changer de pays, actuellement $country';
  }

  @override
  String ui_emailCopied(String email) {
    return 'Aucune application de messagerie trouvée. $email a été copié.';
  }

  @override
  String ui_messagePerson(String name) {
    return 'Message$name';
  }

  @override
  String ui_renewsDate(String date) {
    return 'Renouvelle $date';
  }

  @override
  String ui_ageYears(int age) {
    return '$age ans';
  }

  @override
  String ui_photoNumber(int number) {
    return 'Photo $number';
  }

  @override
  String ui_photoCount(int count) {
    return '$count sur 4 photos';
  }

  @override
  String ui_removeLabel(String label) {
    return 'Supprimer $label';
  }

  @override
  String ui_selectedLabel(String label) {
    return '$label sélectionné';
  }

  @override
  String ui_addLabel(String label) {
    return 'Ajouter $label';
  }

  @override
  String ui_photoRequestSent(String name) {
    return 'Demande de photo envoyée à $name.';
  }

  @override
  String ui_yesterdayTime(String time) {
    return 'Hier $time';
  }

  @override
  String ui_minutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String ui_hoursAgo(int count) {
    return 'Il y a $count heure';
  }

  @override
  String ui_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String ui_renewsAt(String time) {
    return 'Renouvelle à $time';
  }

  @override
  String ui_photoReadyReview(int number) {
    return 'La photo $number est prête pour un examen protégé';
  }

  @override
  String get ui_onePhotoUnlock =>
      '1 photo se débloquera automatiquement une fois que vous exprimerez tous les deux votre intérêt.';

  @override
  String ui_manyPhotosUnlock(int count) {
    return 'Les photos $count se débloqueront automatiquement une fois que vous aurez tous deux exprimé votre intérêt.';
  }

  @override
  String get ui_askOnePhoto =>
      'Demandez au propriétaire la permission de voir 1 photo.';

  @override
  String ui_askManyPhotos(int count) {
    return 'Demandez au propriétaire l\'autorisation de visualiser les photos de $count.';
  }

  @override
  String ui_heightImperial(int feet, int inches) {
    return '$feet pi $inches po';
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
    return 'Filtres ($count)';
  }

  @override
  String discovery_previous_match(String date) {
    return 'Déjà mis en relation le $date';
  }

  @override
  String discovery_rematch_days(int count) {
    return 'Nouvelle mise en relation disponible dans $count jours';
  }

  @override
  String get settings_notify_compatibleProfiles =>
      'Alertes de profils compatibles';

  @override
  String get settings_notify_compatibleProfilesSub =>
      'Quand de nouveaux résultats arrivent dans un fil Découvrir vide';

  @override
  String get settings_notify_discoveryDigest => 'Résumé Découvrir';

  @override
  String get settings_notify_digestHelp =>
      'Résumés facultatifs ; les alertes après un fil vide restent immédiates.';

  @override
  String get settings_notify_digestOff => 'Désactivé';

  @override
  String get settings_notify_digestDaily => 'Quotidien';

  @override
  String get settings_notify_digestWeekly => 'Hebdomadaire';

  @override
  String get settings_quietHoursStart => 'Début des heures calmes';

  @override
  String get settings_quietHoursEnd => 'Fin des heures calmes';

  @override
  String get settings_notify_festivalGreetings => 'Vœux des fêtes';

  @override
  String get settings_notify_festivalGreetingsSub =>
      'Vœux du Ramadan et de l\'Aïd, environ cinq par an';
}
