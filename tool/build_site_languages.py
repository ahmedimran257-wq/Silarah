"""Builds the Hindi and Urdu home pages of silarah.com from one template.

Run from the repository root:  python tool/build_site_languages.py
The pages reuse the English home page's sections and stylesheet; policies stay
in English, which is the governing version.
"""
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"

COPY = {
    "hi": {
        "dir": "ltr",
        "locale": "hi_IN",
        "title": "मुस्लिम मैट्रिमोनी ऐप भारत — सिलाराह",
        "description": "सिलाराह भारत में गंभीर निकाह परिचय के लिए एक प्रीमियम मुस्लिम मैट्रिमोनी ऐप है — आस्था, परिवार, फ़ोटो प्राइवेसी और वैकल्पिक अभिभावक सहायता के साथ।",
        "skip": "सामग्री पर जाएँ",
        "nav": ["सिलाराह क्यों", "भरोसा", "क़ीमत", "उपलब्धता", "सवाल"],
        "nav_label": "मुख्य नेविगेशन",
        "menu": "नेविगेशन खोलें",
        "cta": "Android एक्सेस",
        "pill": "भारत का प्रीमियम मुस्लिम मैट्रिमोनी ऐप",
        "h1": "<em>निकाह</em> के लिए बना,<br>मैच गिनने के लिए नहीं।",
        "hero": "सिलाराह विवाह के इच्छुक मुसलमानों को आस्था, पारिवारिक अपेक्षाओं, प्राइवेसी नियंत्रण और सोच-समझकर आगे बढ़ने के ज़रिए उपयुक्त रिश्ते खोजने में मदद करता है — बिना अंतहीन स्वाइप के।",
        "hero_primary": "Android एक्सेस पाएँ",
        "hero_secondary": "अनुभव देखें",
        "proof": [("₹299", "प्रीमियम प्रति माह"), ("₹0", "महिलाओं के लिए मैसेजिंग"), ("48 घंटे", "सेल्फ़ी अधिकतम इतनी देर रखी जाती है"), ("18+", "केवल वयस्क")],
        "photo_alt": "आँगन में दो काल्पनिक वयस्क भारतीय मुस्लिम मॉडल",
        "disclosure": "अभियान की तस्वीर में AI से बने काल्पनिक मॉडल हैं; यह सिलाराह के सदस्य या सफलता की कहानी नहीं है।",
        "why_eyebrow": "एक गंभीर फ़ैसले के लिए",
        "why_h2": "एक और अंतहीन<br><em>स्वाइपिंग ऐप नहीं।</em>",
        "why_p": "बातचीत शुरू होने से पहले सिलाराह मूल्यों, जीवनशैली, पारिवारिक अपेक्षाओं और भविष्य की योजनाओं को समझने का समय देता है।",
        "features": [
            ("संदर्भ के साथ अनुकूलता", "दीन पर अमल, निकाह की समय-सीमा, शिक्षा, जीवनशैली, पारिवारिक अपेक्षाएँ और साथी की व्यावहारिक पसंद — सब एक साथ देखे जाते हैं।"),
            ("प्रोफ़ाइल अचानक ग़ायब नहीं होतीं", "रुचियाँ, पिछले मैच और कूलडाउन की स्थिति साफ़ दिखती है, लोग चुपचाप हटाए नहीं जाते।"),
            ("जब तक आप न चाहें, निजी", "फ़ोटो सबको दिखाएँ, आपसी रुचि के बाद दिखाएँ, या हर अनुरोध को अलग से मंज़ूर करें।"),
            ("सीमाएँ जो साफ़ दिखती हैं", "ब्लॉक, रिपोर्ट, डिस्कवरी रोकना, सम्मान से मैच ख़त्म करना — सब बिना उलझन के।"),
            ("वैकल्पिक पारिवारिक भागीदारी", "अभिभावक और वली के टूल भरोसेमंद व्यक्ति से पारदर्शी जुड़ाव बनाते हैं, जबकि हर वयस्क अपना खाता ख़ुद संभालता है।"),
        ],
        "price_eyebrow": "सबकी पहुँच में",
        "price_h2": "प्रीमियम अनुभव,<br><em>प्रीमियम बोझ नहीं।</em>",
        "price_p": "सिलाराह भारत में दो पारदर्शी प्लान से शुरू होता है: ₹299 मासिक या ₹749 हर 3 महीने।",
        "women_title": "महिलाओं के लिए मैसेजिंग मुफ़्त",
        "women_p": "आपसी मैच के बाद महिलाएँ बिना सब्सक्रिप्शन के मैसेज पढ़ और भेज सकती हैं।",
        "card_badge": "भारत लॉन्च",
        "card_name": "सिलाराह प्रीमियम",
        "per_month": "/ माह",
        "quarter": "हर 3 महीने",
        "save": "16% बचत",
        "card_p": "पुरुष सक्रिय प्रीमियम से बातचीत और पूरी डिस्कवरी टूलकिट खोलते हैं। खाते सत्यापित ईमेल से बनते हैं; फ़ोन नंबर या KYC की ज़रूरत नहीं।",
        "benefits": ["सक्रिय प्रीमियम वाले पुरुषों के लिए पूरी मैसेजिंग", "रोज़ 25 तक रुचियाँ", "असीमित प्रोफ़ाइल ब्राउज़िंग", "पूरे भारत, राज्य, शहर और भरोसे के फ़िल्टर", "कई फ़िल्टर प्रीसेट सेव करें", "आपकी प्रोफ़ाइल किसने देखी, सब देखें", "स्पष्ट कारणों के साथ आपसी अनुकूलता", "निजी शॉर्टलिस्ट, नोट्स और रिमाइंडर", "इनकॉग्निटो डिस्कवरी", "हर हफ़्ते एक प्रोफ़ाइल बूस्ट"],
        "card_cta": "Android एक्सेस देखें",
        "card_small": "दोनों प्लान रद्द न करने तक अपने आप रिन्यू होते हैं। ख़रीद से पहले Google Play अंतिम क़ीमत, रिन्यूअल तारीख़ और कर दिखाता है। भुगतान रिफ़ंड योग्य नहीं हैं, सिवाय रिफ़ंड नीति में बताई स्थितियों के।",
        "privacy_eyebrow": "प्राइवेसी एक फ़ीचर है",
        "privacy_h2": "आपको खोजा जाए,<br><em>उजागर नहीं।</em>",
        "privacy_p": "आपका सटीक पता कभी नहीं दिखाया जाता। फ़ोटो सुरक्षित एक्सेस से खुलती हैं, संपर्क विवरण निजी रहते हैं, और आप जब चाहें खाता रोक या हटा सकते हैं।",
        "privacy_alt": "घर पर निजी तौर पर फ़ोन इस्तेमाल करती एक काल्पनिक वयस्क भारतीय मुस्लिम महिला",
        "privacy_caption": "AI से बनी अभियान मॉडल — सदस्य प्रोफ़ाइल नहीं।",
        "controls": [("फ़ोटो दिखाने के तीन तरीक़े", "सबके लिए, आपसी रुचि के बाद, या हर अनुरोध की मंज़ूरी पर।"), ("ऐप के भीतर निजी बातचीत", "अपना मोबाइल नंबर दिए बिना जुड़ें।"), ("ब्लॉक का मतलब छुपा हुआ", "ब्लॉक की गई प्रोफ़ाइल डिस्कवरी से हट जाती है और संपर्क नहीं कर सकती।")],
        "safety_link": "सुरक्षा केंद्र देखें (अंग्रेज़ी)",
        "avail_eyebrow": "केवल भारत में, Android पर",
        "avail_h2": "भारत से शुरुआत,<br><em>सावधानी के साथ।</em>",
        "avail_p": "यह रिलीज़ केवल भारत के वयस्कों के लिए Android पर उपलब्ध है। दूसरे देश और iPhone अभी समर्थित नहीं हैं, और किसी तारीख़ का वादा नहीं किया गया है।",
        "show_eyebrow": "ऐप के अंदर",
        "show_h2": "देखने में सुंदर,<br><em>भरोसे में गंभीर।</em>",
        "show_p": "ये असली Android स्क्रीन हैं। हर स्क्रीन अगले सार्थक फ़ैसले के लिए बनी है — स्ट्रीक, बैज या स्वाइप की लत के लिए नहीं।",
        "show_rail": "सिलाराह ऐप की स्क्रीन, और देखने के लिए बगल में स्क्रॉल करें",
        "show_disclosure": "स्क्रीन सिलाराह Android ऐप की हैं, जिनमें डेमो प्रोफ़ाइल और चित्रित पोर्ट्रेट हैं। ये असली सदस्य नहीं हैं।",
        "screens": [
            ("discover", "नीयत के साथ डिस्कवरी", "एक बार में एक प्रोफ़ाइल — फ़ोटो या चैट से पहले आस्था, शहर और पेशा।", "नाम, शहर, पेशा और मसलक वाला डिस्कवर प्रोफ़ाइल कार्ड"),
            ("profile", "पढ़ने लायक़ अनुकूलता", "आपसी जानकारी बताती है कि कौन-सी पसंद मेल खाती है, और क्यों।", "आपसी अनुकूलता जानकारी वाली सत्यापित प्रोफ़ाइल"),
            ("filters", "बारीकी का सम्मान करते फ़िल्टर", "दीन, परिवार का प्रकार, वैवाहिक स्थिति और भरोसे की जाँच — प्रीसेट के रूप में सेव।", "दीन, शिक्षा, परिवार और भरोसे के फ़िल्टर वाली स्क्रीन"),
            ("privacy", "फ़ोटो निजी रहती हैं", "सबको, रुचि स्वीकार होने के बाद, या हर अनुरोध की मंज़ूरी पर दिखाएँ।", "रुचि स्वीकार होने तक छुपी फ़ोटो वाला प्रोफ़ाइल कार्ड"),
            ("guardian", "जब चाहें, वली साथ", "किसी भरोसेमंद अभिभावक को अपनी बातचीत के क़रीब रखें।", "अभिभावक के नाम, ईमेल और रिश्ते वाली गार्डियन मोड सेटिंग"),
            ("chat", "अदब के साथ बातचीत", "आपसी मैच के बाद निजी चैट, फ़ोन नंबर दिए बिना।", "आपसी मैच के बाद निजी चैट"),
        ],
        "faq_eyebrow": "जुड़ने से पहले साफ़ जवाब",
        "faq_h2": "सवाल,<br><em>ईमानदार जवाब।</em>",
        "faq_help": "कुछ और पूछना है? <a href=\"mailto:support@silarah.com\">सपोर्ट से बात करें।</a>",
        "faq": [
            ("क्या सिलाराह डेटिंग ऐप है?", "नहीं। सिलाराह गंभीर मुस्लिम वैवाहिक परिचय चाहने वाले वयस्कों के लिए बना है।"),
            ("प्रीमियम की क़ीमत क्या है?", "भारत लॉन्च प्लान ₹299 मासिक या ₹749 हर 3 महीने हैं। Google Play ख़रीद से पहले अंतिम क़ीमत, कर और रद्द करने की शर्तें दिखाता है।"),
            ("महिलाओं के लिए मैसेजिंग मुफ़्त क्यों है?", "आपसी मैच के बाद महिलाएँ बिना सब्सक्रिप्शन के मैसेज पढ़ और भेज सकती हैं। पुरुषों को भेजने के लिए सक्रिय प्रीमियम चाहिए।"),
            ("क्या भुगतान वापस मिलता है?", "सब्सक्रिप्शन भुगतान रिफ़ंड योग्य नहीं हैं। दोहरी, अनधिकृत या ग़लत राशि की कटौती, या हमारी ग़लती से प्रीमियम न चलने पर रिफ़ंड मिलता है।"),
            ("क्या सिलाराह सरकारी पहचान पत्र या बायोमेट्रिक लेता है?", "नहीं। फ़ोटो जाँच के लिए पहचान पत्र नहीं चाहिए और सिलाराह चेहरे का टेम्पलेट नहीं बनाता या रखता।"),
        ],
        "final_eyebrow": "नीयत से शुरुआत",
        "final_h2": "आपका अगला परिचय<br><em>अलग महसूस हो सकता है।</em>",
        "final_p": "सोच-समझकर प्रोफ़ाइल बनाइए, अपनी सीमाएँ चुनिए और पूरे भारत में गंभीर मुस्लिम रिश्ते खोजिए।",
        "footer_tag": "नीयत के साथ मुस्लिम मैट्रिमोनी। इस रिलीज़ में केवल भारत में Android पर उपलब्ध।",
        "footer_legal": "नीतियाँ अंग्रेज़ी में हैं और वही मान्य हैं।",
        "footer_heads": ["जानें", "भरोसा", "सहायता", "क़ानूनी"],
        "rights": "© 2026 सिलाराह। सर्वाधिकार सुरक्षित।",
        "language_label": "भाषा",
    },
    "ur": {
        "dir": "rtl",
        "locale": "ur_IN",
        "title": "مسلم میٹریمونی ایپ ہندوستان — سلارہ",
        "description": "سلارہ ہندوستان میں سنجیدہ نکاح کے رشتوں کے لیے ایک پریمیم مسلم میٹریمونی ایپ ہے — ایمان، خاندان، تصویر کی رازداری اور اختیاری سرپرست کی مدد کے ساتھ۔",
        "skip": "مواد پر جائیں",
        "nav": ["سلارہ کیوں", "اعتماد", "قیمت", "دستیابی", "سوالات"],
        "nav_label": "مرکزی نیویگیشن",
        "menu": "نیویگیشن کھولیں",
        "cta": "Android رسائی",
        "pill": "ہندوستان کی پریمیم مسلم میٹریمونی ایپ",
        "h1": "<em>نکاح</em> کے لیے بنی،<br>میچ گننے کے لیے نہیں۔",
        "hero": "سلارہ شادی کے خواہش مند مسلمانوں کو ایمان، خاندانی توقعات، رازداری کے اختیارات اور سوچ سمجھ کر آگے بڑھنے کے ذریعے موزوں رشتے تلاش کرنے میں مدد دیتی ہے — بے انتہا سوائپ کے بغیر۔",
        "hero_primary": "Android رسائی حاصل کریں",
        "hero_secondary": "تجربہ دیکھیں",
        "proof": [("₹299", "پریمیم فی مہینہ"), ("₹0", "خواتین کے لیے پیغامات"), ("48 گھنٹے", "سیلفی زیادہ سے زیادہ اتنی دیر رکھی جاتی ہے"), ("18+", "صرف بالغ افراد")],
        "photo_alt": "صحن میں دو فرضی بالغ ہندوستانی مسلم ماڈل",
        "disclosure": "مہم کی تصویر میں AI سے بنے فرضی ماڈل ہیں؛ یہ سلارہ کے اراکین یا کامیابی کی کہانی نہیں۔",
        "why_eyebrow": "ایک سنجیدہ فیصلے کے لیے",
        "why_h2": "ایک اور نہ ختم ہونے والی<br><em>سوائپ ایپ نہیں۔</em>",
        "why_p": "بات چیت شروع ہونے سے پہلے سلارہ اقدار، طرزِ زندگی، خاندانی توقعات اور مستقبل کے منصوبوں کو سمجھنے کا وقت دیتی ہے۔",
        "features": [
            ("سیاق و سباق کے ساتھ مطابقت", "دین پر عمل، نکاح کا وقت، تعلیم، طرزِ زندگی، خاندانی توقعات اور شریکِ حیات کی عملی ترجیحات — سب ایک ساتھ دیکھی جاتی ہیں۔"),
            ("پروفائل اچانک غائب نہیں ہوتیں", "دلچسپیاں، پچھلے میچ اور وقفے کی حالت واضح رہتی ہے، لوگ خاموشی سے ہٹائے نہیں جاتے۔"),
            ("جب تک آپ نہ چاہیں، نجی", "تصاویر سب کو دکھائیں، باہمی دلچسپی کے بعد دکھائیں، یا ہر درخواست کو الگ سے منظور کریں۔"),
            ("حدود جو صاف نظر آتی ہیں", "بلاک، رپورٹ، ڈسکوری روکنا، عزت سے میچ ختم کرنا — سب بغیر الجھن کے۔"),
            ("خاندان کی اختیاری شمولیت", "سرپرست اور ولی کے ٹولز کسی قابلِ اعتماد شخص سے شفاف تعلق بناتے ہیں، جبکہ ہر بالغ اپنا اکاؤنٹ خود سنبھالتا ہے۔"),
        ],
        "price_eyebrow": "سب کی پہنچ میں",
        "price_h2": "پریمیم تجربہ،<br><em>پریمیم بوجھ نہیں۔</em>",
        "price_p": "سلارہ ہندوستان میں دو شفاف پلانز سے شروع ہوتی ہے: ₹299 ماہانہ یا ₹749 ہر 3 مہینے۔",
        "women_title": "خواتین کے لیے پیغامات مفت",
        "women_p": "باہمی میچ کے بعد خواتین بغیر سبسکرپشن کے پیغامات پڑھ اور بھیج سکتی ہیں۔",
        "card_badge": "ہندوستان لانچ",
        "card_name": "سلارہ پریمیم",
        "per_month": "/ مہینہ",
        "quarter": "ہر 3 مہینے",
        "save": "16% بچت",
        "card_p": "مرد فعال پریمیم سے بات چیت اور ڈسکوری کے تمام ٹولز کھولتے ہیں۔ اکاؤنٹ تصدیق شدہ ای میل سے بنتے ہیں؛ فون نمبر یا KYC کی ضرورت نہیں۔",
        "benefits": ["فعال پریمیم والے مردوں کے لیے مکمل پیغامات", "روزانہ 25 تک دلچسپیاں", "لامحدود پروفائل براؤزنگ", "پورے ہندوستان، ریاست، شہر اور اعتماد کے فلٹر", "کئی فلٹر پری سیٹ محفوظ کریں", "دیکھیں کس نے آپ کی پروفائل دیکھی", "واضح وجوہات کے ساتھ باہمی مطابقت", "نجی شارٹ لسٹ، نوٹس اور یاددہانیاں", "انکوگنیٹو ڈسکوری", "ہر ہفتے ایک پروفائل بوسٹ"],
        "card_cta": "Android رسائی دیکھیں",
        "card_small": "دونوں پلانز منسوخ نہ کرنے تک خود بخود تجدید ہوتے ہیں۔ خریداری سے پہلے Google Play حتمی قیمت، تجدید کی تاریخ اور ٹیکس دکھاتا ہے۔ ادائیگیاں ناقابلِ واپسی ہیں، سوائے ریفنڈ پالیسی میں بیان کردہ صورتوں کے۔",
        "privacy_eyebrow": "رازداری ایک خصوصیت ہے",
        "privacy_h2": "آپ کو تلاش کیا جائے،<br><em>بے نقاب نہیں۔</em>",
        "privacy_p": "آپ کا درست پتہ کبھی نہیں دکھایا جاتا۔ تصاویر محفوظ رسائی سے کھلتی ہیں، رابطے کی تفصیلات نجی رہتی ہیں، اور آپ جب چاہیں اکاؤنٹ روک یا حذف کر سکتے ہیں۔",
        "privacy_alt": "گھر پر نجی طور پر فون استعمال کرتی ایک فرضی بالغ ہندوستانی مسلم خاتون",
        "privacy_caption": "AI سے بنی مہم کی ماڈل — رکن کی پروفائل نہیں۔",
        "controls": [("تصویر دکھانے کے تین طریقے", "سب کے لیے، باہمی دلچسپی کے بعد، یا ہر درخواست کی منظوری پر۔"), ("ایپ کے اندر نجی گفتگو", "اپنا موبائل نمبر دیے بغیر جڑیں۔"), ("بلاک کا مطلب پوشیدہ", "بلاک کی گئی پروفائل ڈسکوری سے ہٹ جاتی ہے اور رابطہ نہیں کر سکتی۔")],
        "safety_link": "حفاظتی مرکز دیکھیں (انگریزی)",
        "avail_eyebrow": "صرف ہندوستان میں، Android پر",
        "avail_h2": "ہندوستان سے آغاز،<br><em>احتیاط کے ساتھ۔</em>",
        "avail_p": "یہ ریلیز صرف ہندوستان کے بالغ افراد کے لیے Android پر دستیاب ہے۔ دوسرے ممالک اور iPhone ابھی شامل نہیں، اور کسی تاریخ کا وعدہ نہیں کیا گیا۔",
        "show_eyebrow": "ایپ کے اندر",
        "show_h2": "دیکھنے میں خوبصورت،<br><em>اعتماد میں سنجیدہ۔</em>",
        "show_p": "یہ اصل Android اسکرینیں ہیں۔ ہر اسکرین اگلے بامعنی فیصلے کے لیے بنی ہے — اسٹریک، بیج یا سوائپ کی لت کے لیے نہیں۔",
        "show_rail": "سلارہ ایپ کی اسکرینیں، مزید دیکھنے کے لیے پہلو میں اسکرول کریں",
        "show_disclosure": "اسکرینیں سلارہ Android ایپ کی ہیں، جن میں ڈیمو پروفائلز اور تصویری پورٹریٹ ہیں۔ یہ اصل ممبران نہیں ہیں۔",
        "screens": [
            ("discover", "نیت کے ساتھ ڈسکوری", "ایک وقت میں ایک پروفائل — تصویر یا چیٹ سے پہلے ایمان، شہر اور پیشہ۔", "نام، شہر، پیشہ اور مسلک والا ڈسکور پروفائل کارڈ"),
            ("profile", "پڑھنے کے قابل مطابقت", "باہمی معلومات بتاتی ہیں کہ کون سی ترجیحات ملتی ہیں، اور کیوں۔", "باہمی مطابقت کی معلومات والی تصدیق شدہ پروفائل"),
            ("filters", "تفصیل کا احترام کرتے فلٹر", "دین، خاندان کی قسم، ازدواجی حیثیت اور اعتماد کی جانچ — پری سیٹ کے طور پر محفوظ۔", "دین، تعلیم، خاندان اور اعتماد کے فلٹر والی اسکرین"),
            ("privacy", "تصاویر نجی رہتی ہیں", "سب کو، دلچسپی قبول ہونے کے بعد، یا ہر درخواست کی منظوری پر دکھائیں۔", "دلچسپی قبول ہونے تک چھپی تصویر والا پروفائل کارڈ"),
            ("guardian", "جب چاہیں، ولی ساتھ", "کسی قابلِ اعتماد سرپرست کو اپنی بات چیت کے قریب رکھیں۔", "سرپرست کے نام، ای میل اور رشتے والی گارڈین موڈ سیٹنگ"),
            ("chat", "ادب کے ساتھ گفتگو", "باہمی میچ کے بعد نجی چیٹ، فون نمبر دیے بغیر۔", "باہمی میچ کے بعد نجی چیٹ"),
        ],
        "faq_eyebrow": "شامل ہونے سے پہلے واضح جوابات",
        "faq_h2": "سوالات،<br><em>دیانت دار جوابات۔</em>",
        "faq_help": "کچھ اور پوچھنا ہے؟ <a href=\"mailto:support@silarah.com\">سپورٹ سے بات کریں۔</a>",
        "faq": [
            ("کیا سلارہ ڈیٹنگ ایپ ہے؟", "نہیں۔ سلارہ سنجیدہ مسلم ازدواجی رشتوں کے خواہش مند بالغ افراد کے لیے بنی ہے۔"),
            ("پریمیم کی قیمت کیا ہے؟", "ہندوستان لانچ پلانز ₹299 ماہانہ یا ₹749 ہر 3 مہینے ہیں۔ Google Play خریداری سے پہلے حتمی قیمت، ٹیکس اور منسوخی کی شرائط دکھاتا ہے۔"),
            ("خواتین کے لیے پیغامات مفت کیوں ہیں؟", "باہمی میچ کے بعد خواتین بغیر سبسکرپشن کے پیغامات پڑھ اور بھیج سکتی ہیں۔ مردوں کو بھیجنے کے لیے فعال پریمیم درکار ہے۔"),
            ("کیا ادائیگی واپس ملتی ہے؟", "سبسکرپشن کی ادائیگیاں ناقابلِ واپسی ہیں۔ دوہری، غیر مجاز یا غلط رقم کی کٹوتی، یا ہماری غلطی سے پریمیم نہ چلنے پر ریفنڈ ملتا ہے۔"),
            ("کیا سلارہ سرکاری شناختی کارڈ یا بایومیٹرک لیتی ہے؟", "نہیں۔ تصویر کی جانچ کے لیے شناختی کارڈ درکار نہیں اور سلارہ چہرے کا ٹیمپلیٹ نہ بناتی ہے نہ رکھتی ہے۔"),
        ],
        "final_eyebrow": "نیت کے ساتھ آغاز",
        "final_h2": "آپ کا اگلا رشتہ<br><em>مختلف محسوس ہو سکتا ہے۔</em>",
        "final_p": "سوچ سمجھ کر پروفائل بنائیں، اپنی حدود منتخب کریں اور پورے ہندوستان میں سنجیدہ مسلم رشتے تلاش کریں۔",
        "footer_tag": "نیت کے ساتھ مسلم میٹریمونی۔ اس ریلیز میں صرف ہندوستان میں Android پر دستیاب۔",
        "footer_legal": "پالیسیاں انگریزی میں ہیں اور وہی معتبر ہیں۔",
        "footer_heads": ["دیکھیں", "اعتماد", "مدد", "قانونی"],
        "rights": "© 2026 سلارہ۔ جملہ حقوق محفوظ ہیں۔",
        "language_label": "زبان",
    },
}

ENGLISH_LINKS = {
    "trust": [("/safety/", "Safety Centre"), ("/community-guidelines/", "Community Guidelines"), ("/verification-policy/", "Verification Policy"), ("/guardian-policy/", "Guardian Policy")],
    "support": [("/faq/", "FAQ"), ("/help/", "Help Centre"), ("/delete-account/", "Delete Account"), ("mailto:support@silarah.com", "support@silarah.com")],
    "legal": [("/legal/", "Legal Centre"), ("/privacy/", "Privacy"), ("/terms/", "Terms"), ("/refund-policy/", "Refund Policy")],
}


def links(items):
    return "".join(f'<a href="{href}" lang="en">{escape(label)}</a>' for href, label in items)


def lang_switch(lang, label):
    current = {"en": "", "hi": "", "ur": ""}
    current[lang] = ' aria-current="true"'
    return (
        f'<span class="lang-switch" aria-label="{escape(label)}">'
        f'<a href="/" lang="en" hreflang="en"{current["en"]}>EN</a>'
        f'<a href="/hi/" lang="hi" hreflang="hi"{current["hi"]}>हिन्दी</a>'
        f'<a href="/ur/" lang="ur" hreflang="ur"{current["ur"]}>اردو</a></span>'
    )


def page(lang, c):
    url = f"https://silarah.com/{lang}/"
    anchors = ["#experience", "#trust", "#pricing", "#roadmap", "#faq"]
    nav = "".join(f'<a href="{a}">{escape(t)}</a>' for a, t in zip(anchors, c["nav"]))
    proof = "".join(f"<div><strong>{escape(v)}</strong><span>{escape(t)}</span></div>" for v, t in c["proof"])
    cards = []
    for i, (title, body) in enumerate(c["features"], start=1):
        cls = " feature-large" if i == 1 else (" feature-wide" if i == 5 else "")
        cards.append(f'<article class="feature-card{cls}"><span class="feature-index">0{i}</span><h3>{escape(title)}</h3><p>{escape(body)}</p></article>')
    benefits = "".join(f'<li><span>✓</span> {escape(b)}</li>' for b in c["benefits"])
    screens = "".join(
        f'<figure class="screen-card"><div class="device"><img src="/assets/screens/{key}-640.webp" '
        f'srcset="/assets/screens/{key}-360.webp 360w, /assets/screens/{key}-640.webp 640w" '
        f'sizes="(max-width: 760px) 72vw, 272px" width="640" height="1363" loading="lazy" alt="{escape(alt)}"></div>'
        f'<figcaption><b>{escape(title)}</b><span>{escape(body)}</span></figcaption></figure>'
        for key, title, body, alt in c["screens"]
    )
    controls = "".join(f"<div><span>0{i}</span><div><b>{escape(t)}</b><p>{escape(b)}</p></div></div>" for i, (t, b) in enumerate(c["controls"], start=1))
    faq = "".join(f"<details><summary>{escape(q)}<span>+</span></summary><p>{escape(a)}</p></details>" for q, a in c["faq"])
    heads = c["footer_heads"]
    return f"""<!DOCTYPE html>
<html lang="{lang}" dir="{c['dir']}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="theme-color" content="#F7F3EA">
  <meta name="description" content="{escape(c['description'])}">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <link rel="canonical" href="{url}">
  <link rel="alternate" hreflang="en-IN" href="https://silarah.com/">
  <link rel="alternate" hreflang="hi-IN" href="https://silarah.com/hi/">
  <link rel="alternate" hreflang="ur-IN" href="https://silarah.com/ur/">
  <link rel="alternate" hreflang="x-default" href="https://silarah.com/">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Silarah">
  <meta property="og:locale" content="{c['locale']}">
  <meta property="og:title" content="{escape(c['title'])}">
  <meta property="og:description" content="{escape(c['description'])}">
  <meta property="og:url" content="{url}">
  <meta property="og:image" content="https://silarah.com/assets/campaign/silarah-social-1200x630.jpg">
  <title>{escape(c['title'])}</title>
  <link rel="icon" href="/favicon.ico" sizes="any">
  <link rel="icon" href="/favicon-48.png" type="image/png" sizes="48x48">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <link rel="stylesheet" href="/styles.css?v=20261106">
  <link rel="stylesheet" href="/motion.css?v=20260920-1">
  <script defer src="/assets/site.js?v=20261106"></script>
</head>
<body class="home premium-home">
  <a class="skip-link" href="#main">{escape(c['skip'])}</a>
  <header class="site-header">
    <nav class="shell nav-shell" aria-label="{escape(c['nav_label'])}">
      <a class="brand brand-editorial" href="/{lang}/" aria-label="Silarah"><span class="brand-mark" aria-hidden="true">S</span><span class="brand-wordmark"><b>SILARAH</b></span></a>
      <button class="menu-toggle" type="button" aria-expanded="false" aria-controls="site-menu"><span></span><span></span><span></span><span class="sr-only">{escape(c['menu'])}</span></button>
      <div class="site-menu" id="site-menu">
        {nav}
        {lang_switch(lang, c['language_label'])}
        <a class="nav-cta" href="https://app.silarah.com/">{escape(c['cta'])} <span aria-hidden="true">↗</span></a>
      </div>
    </nav>
  </header>
  <main id="main">
    <section class="landing-hero editorial-hero">
      <picture class="hero-photo">
        <source media="(max-width: 760px)" srcset="/assets/campaign/hero-768.webp">
        <img src="/assets/campaign/hero-1536.webp" width="1536" height="1024" alt="{escape(c['photo_alt'])}" fetchpriority="high">
      </picture>
      <div class="hero-shade" aria-hidden="true"></div>
      <div class="shell hero-content editorial-hero-content">
        <div class="hero-copy-new">
          <div class="launch-pill" data-geo="pill"><span></span> {escape(c['pill'])}</div>
          <h1>{c['h1']}</h1>
          <p>{escape(c['hero'])}</p>
          <div class="hero-actions">
            <a class="button primary" href="https://app.silarah.com/">{escape(c['hero_primary'])} <span aria-hidden="true">↗</span></a>
            <a class="button glass" href="#experience">{escape(c['hero_secondary'])}</a>
          </div>
        </div>
      </div>
      <div class="campaign-disclosure shell">{escape(c['disclosure'])}</div>
    </section>
    <section class="proof-rail"><div class="shell proof-grid">{proof}</div></section>
    <section class="section shell manifesto" id="experience">
      <div class="section-heading split-heading">
        <div><span class="eyebrow">{escape(c['why_eyebrow'])}</span><h2>{c['why_h2']}</h2></div>
        <p>{escape(c['why_p'])}</p>
      </div>
      <div class="feature-deck">{''.join(cards)}</div>
    </section>
    <section class="section app-showcase" id="inside">
      <div class="shell">
        <div class="section-heading centered narrow-heading">
          <span class="eyebrow">{escape(c['show_eyebrow'])}</span>
          <h2>{c['show_h2']}</h2>
          <p>{escape(c['show_p'])}</p>
        </div>
      </div>
      <div class="screen-rail" tabindex="0" aria-label="{escape(c['show_rail'])}">{screens}</div>
      <div class="shell"><p class="screen-disclosure">{escape(c['show_disclosure'])}</p></div>
    </section>
    <section class="section pricing-section" id="pricing">
      <div class="shell pricing-layout">
        <div class="pricing-copy">
          <span class="eyebrow">{escape(c['price_eyebrow'])}</span>
          <h2>{c['price_h2']}</h2>
          <p>{escape(c['price_p'])}</p>
          <div class="women-free-card"><span>₹0</span><div><strong>{escape(c['women_title'])}</strong><p>{escape(c['women_p'])}</p></div></div>
        </div>
        <article class="premium-card">
          <div class="premium-card-head"><span>{escape(c['card_badge'])}</span><b>{escape(c['card_name'])}</b></div>
          <div class="premium-price" dir="ltr"><sup>₹</sup><strong>299</strong><span>{escape(c['per_month'])}</span></div>
          <div class="quarterly-option"><div><strong dir="ltr">₹749</strong><span>{escape(c['quarter'])}</span></div><b>{escape(c['save'])}</b></div>
          <p>{escape(c['card_p'])}</p>
          <ul>{benefits}</ul>
          <a class="button primary full-button" href="https://app.silarah.com/">{escape(c['card_cta'])} <span aria-hidden="true">↗</span></a>
          <small>{escape(c['card_small'])} <a href="/refund-policy/" lang="en">Refund Policy</a></small>
        </article>
      </div>
    </section>
    <section class="section media-feature" id="trust">
      <div class="shell media-layout">
        <figure class="campaign-figure">
          <picture>
            <source media="(max-width: 760px)" srcset="/assets/campaign/privacy-768.webp">
            <img src="/assets/campaign/privacy-1536.webp" width="1536" height="1024" loading="lazy" alt="{escape(c['privacy_alt'])}">
          </picture>
          <figcaption>{escape(c['privacy_caption'])}</figcaption>
        </figure>
        <div class="media-copy">
          <span class="eyebrow">{escape(c['privacy_eyebrow'])}</span>
          <h2>{c['privacy_h2']}</h2>
          <p>{escape(c['privacy_p'])}</p>
          <div class="control-list">{controls}</div>
          <a class="text-link" href="/safety/">{escape(c['safety_link'])} <span aria-hidden="true">→</span></a>
        </div>
      </div>
    </section>
    <section class="section roadmap-section" id="roadmap">
      <div class="shell"><div class="roadmap-head">
        <span class="eyebrow">{escape(c['avail_eyebrow'])}</span>
        <h2>{c['avail_h2']}</h2>
        <p>{escape(c['avail_p'])}</p>
      </div></div>
    </section>
    <section class="section shell faq-section" id="faq">
      <div class="faq-heading">
        <span class="eyebrow">{escape(c['faq_eyebrow'])}</span>
        <h2>{c['faq_h2']}</h2>
        <p>{c['faq_help']}</p>
      </div>
      <div class="faq-list">{faq}</div>
    </section>
    <section class="final-cta shell">
      <div class="final-cta-copy">
        <span class="eyebrow">{escape(c['final_eyebrow'])}</span>
        <h2>{c['final_h2']}</h2>
        <p>{escape(c['final_p'])}</p>
        <div class="hero-actions centered-actions"><a class="button primary" href="https://app.silarah.com/">{escape(c['card_cta'])} <span aria-hidden="true">↗</span></a></div>
      </div>
    </section>
  </main>
  <footer class="site-footer">
    <div class="shell footer-grid">
      <div class="footer-brand"><a class="brand" href="/{lang}/"><span class="brand-mark" aria-hidden="true">S</span><span>Silarah</span></a><p>{escape(c['footer_tag'])}</p><p>{escape(c['footer_legal'])}</p></div>
      <div><b>{escape(heads[0])}</b><a href="/" lang="en">English</a><a href="/hi/" lang="hi">हिन्दी</a><a href="/ur/" lang="ur">اردو</a></div>
      <div><b>{escape(heads[1])}</b>{links(ENGLISH_LINKS['trust'])}</div>
      <div><b>{escape(heads[2])}</b>{links(ENGLISH_LINKS['support'])}</div>
      <div><b>{escape(heads[3])}</b>{links(ENGLISH_LINKS['legal'])}</div>
    </div>
    <div class="shell footer-bottom"><span>{escape(c['rights'])}</span></div>
  </footer>
</body>
</html>
"""


def main():
    for lang, copy in COPY.items():
        out = SITE / lang / "index.html"
        out.parent.mkdir(exist_ok=True)
        out.write_text(page(lang, copy), encoding="utf-8", newline="\n")
        print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
