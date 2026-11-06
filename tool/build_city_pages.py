"""Builds the city landing pages of silarah.com.

Run from the repository root:  python tool/build_city_pages.py
Each page carries its own local context. Never add member counts, success
stories or claims that Silarah has members in a place: results depend on who
has joined.
"""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
UPDATED = "2026-10-24"

CITIES = [
    {
        "slug": "hyderabad",
        "city": "Hyderabad",
        "state": "Telangana",
        "title": "Muslim Matrimony Hyderabad — Serious Nikah Introductions | Silarah",
        "description": "Muslim matrimony in Hyderabad with Dakhni and Urdu preferences, sect and practice filters, photo privacy and optional guardian support. India-first on Android.",
        "h1": "Hyderabad introductions,<br><em>with Deccani depth.</em>",
        "intro": "From the Old City to Gachibowli, Hyderabadi families often weigh faith, family standing and future plans together. Silarah lets you set those priorities clearly before a conversation begins—without giving out a phone number.",
        "tags": ["Dakhni Urdu", "Telugu", "Old City & HITEC City", "Gulf & overseas ties", "Telangana · Andhra Pradesh"],
        "context": [
            ("A city with its own Muslim heritage", "Hyderabad’s Muslim culture was shaped by centuries of Qutb Shahi and Asaf Jahi rule, and Dakhni—the Deccani form of Urdu—is still heard across homes and markets. Many families value that shared idiom and tehzeeb, while others care more about practice and outlook than dialect. Silarah treats mother tongue as one preference you choose, not a rule."),
            ("Families who think about distance", "It is common for Hyderabadi families to have relatives in the Gulf, the UK or the US, and for a spouse to be asked whether they would relocate. Setting relocation and post-marriage living preferences early helps both families avoid misunderstandings later."),
            ("Two very different daily lives", "The Old City and the technology corridors of HITEC City and Gachibowli can mean different routines, commutes and expectations about joint or nuclear living. Being specific about profession, work hours and living arrangements makes introductions more realistic."),
        ],
        "nearby": ["Secunderabad", "Kurnool", "Warangal", "Nizamabad", "Bidar", "Gulbarga (Kalaburagi)"],
        "meet": "For a first meeting, choose a busy family restaurant or a café in a well-known area and tell a family member where you will be. Many Hyderabadi families prefer that elders meet first; you can connect a guardian or wali in Silarah to make that easier.",
        "faq": [
            ("Can I search for Dakhni or Urdu-speaking matches in Hyderabad?", "Yes. You can set mother-tongue preferences such as Urdu, Telugu or others, alongside city, state, sect, practice and education. Results depend on who has joined and their own preferences."),
            ("Can I include nearby cities in Telangana and Andhra Pradesh?", "Yes. Start with Hyderabad and widen to nearby cities or all of India when geography is flexible. Premium members can broaden discovery further."),
            ("Do I have to share my phone number?", "No. Conversations happen inside the app after a mutual match, and you can control who sees your photos."),
        ],
    },
    {
        "slug": "lucknow",
        "city": "Lucknow",
        "state": "Uttar Pradesh",
        "title": "Muslim Matrimony Lucknow — Shia & Sunni Nikah Introductions | Silarah",
        "description": "Muslim matrimony in Lucknow and across Uttar Pradesh: Urdu and Hindi preferences, Shia and Sunni sect filters, photo privacy and optional wali involvement.",
        "h1": "Lucknow introductions,<br><em>with tehzeeb at heart.</em>",
        "intro": "Lucknow’s Awadhi culture is known for courtesy, Urdu poetry and close family involvement in marriage decisions. Silarah keeps that respect central: clear preferences, private photos and an optional place for family.",
        "tags": ["Urdu", "Hindi", "Shia & Sunni families", "Awadh & wider UP", "Uttar Pradesh"],
        "context": [
            ("Awadhi tehzeeb and Urdu culture", "Lucknow grew into a centre of Urdu literature and courtly etiquette under the Nawabs of Awadh. Many families still value refined manners and language in a future spouse—qualities a thoughtful biography and respectful conversation can show better than a single photo."),
            ("Sect is often discussed openly", "Lucknow has long-established Shia and Sunni communities, and many families state a sect preference from the start. Silarah lets you set sect and practice preferences honestly, or leave them open if they are not deciding factors for you."),
            ("Families across Uttar Pradesh", "Introductions frequently connect Lucknow with Kanpur, Prayagraj, Aligarh, Bareilly and other UP cities, and many families have relatives in Delhi NCR. Location preferences let you start close to home and widen deliberately."),
        ],
        "nearby": ["Kanpur", "Barabanki", "Rae Bareli", "Prayagraj", "Aligarh", "Bareilly"],
        "meet": "Choose a respectable public place for a first meeting and keep family informed. Where elders prefer to talk first, connecting a guardian in Silarah keeps that involvement transparent while you stay in control of your own account.",
        "faq": [
            ("Can I filter by Shia or Sunni in Lucknow?", "Yes. You can state your sect and practice and set preferences for a match. These are preferences you choose; Silarah does not verify religious practice."),
            ("Can I look for matches across Uttar Pradesh?", "Yes. Start with Lucknow and widen to other UP cities, Delhi NCR or all of India when you are open to it."),
            ("Can my parents be involved?", "Yes, optionally. An adult member can connect a trusted guardian or wali transparently, while keeping ownership of their account and decisions."),
        ],
    },
    {
        "slug": "kolkata",
        "city": "Kolkata",
        "state": "West Bengal",
        "title": "Muslim Matrimony Kolkata — Bengali & Urdu Nikah Introductions | Silarah",
        "description": "Muslim matrimony in Kolkata with Bengali and Urdu mother-tongue preferences, sect and practice filters, photo privacy and optional guardian support.",
        "h1": "Kolkata introductions,<br><em>in two languages of home.</em>",
        "intro": "Kolkata’s Muslim families include Bengali-speaking households and long-settled Urdu and Hindi-speaking communities. Silarah lets you say what matters to you—language, practice, education or family—without guessing.",
        "tags": ["Bengali", "Urdu", "Hindi", "Kolkata & suburbs", "West Bengal"],
        "context": [
            ("Bengali and Urdu-speaking communities", "Many Kolkata Muslims speak Bengali at home, while neighbourhoods such as Park Circus, Rajabazar and Metiabruz—where the exiled Nawab of Awadh settled in the nineteenth century—have deep Urdu and Hindi-speaking roots. Some families prefer a shared mother tongue; others do not mind. Your preference is yours to set."),
            ("Education and steady careers", "Families often place weight on education, a stable profession and good character. Being clear about qualifications, work and future plans helps introductions start on solid ground."),
            ("From the city to the districts", "Introductions may connect Kolkata with Howrah, Hooghly, Murshidabad, Malda and other districts, as well as with relatives in other states. Distance and location preferences let you decide how far to look."),
        ],
        "nearby": ["Howrah", "Hooghly", "North 24 Parganas", "South 24 Parganas", "Murshidabad", "Malda"],
        "meet": "Meet first in a busy café or family restaurant and let someone you trust know your plans. If your family prefers to speak first, connect a guardian in Silarah so their involvement is clear to everyone.",
        "faq": [
            ("Can I search for Bengali-speaking or Urdu-speaking matches?", "Yes. Mother tongue is one of the preferences you can set, alongside location, sect, practice, education and lifestyle."),
            ("Is Silarah only for Kolkata city?", "No. You can start with Kolkata and widen to West Bengal or all of India. Results depend on who has joined."),
            ("Can I keep my photos private?", "Yes. Choose whether photos are visible to everyone, only after mutual interest, or only when you approve an individual request."),
        ],
    },
    {
        "slug": "mumbai",
        "city": "Mumbai",
        "state": "Maharashtra",
        "title": "Muslim Matrimony Mumbai — Serious Nikah Introductions | Silarah",
        "description": "Muslim matrimony in Mumbai, Thane and Navi Mumbai with community, mother-tongue, sect and lifestyle preferences, photo privacy and optional guardian involvement.",
        "h1": "Mumbai introductions,<br><em>for a city of many communities.</em>",
        "intro": "Mumbai brings together Konkani, Bohra, Khoja, Memon, Urdu-speaking and Marathi-speaking Muslim families, often with demanding careers and long commutes. Silarah helps you be specific about the life you want to build.",
        "tags": ["Urdu", "Marathi", "Konkani", "Gujarati", "Mumbai Metropolitan Region"],
        "context": [
            ("Many communities, one city", "Mumbai’s Muslims include Konkani Muslims, Dawoodi Bohras, Khojas and Memons, Urdu-speaking families with roots in Uttar Pradesh and Bihar, and Marathi-speaking households. Some families prefer to marry within their community or jamaat; others are open. State what matters to you plainly, and respect what matters to others."),
            ("Careers, commutes and housing", "Long working hours, local-train commutes and the cost of housing shape married life in Mumbai. Being honest about profession, work schedule and whether you expect joint or separate living saves both families time."),
            ("Across the metropolitan region", "Introductions often span Thane, Navi Mumbai, Mira-Bhayandar, Bhiwandi and Kalyan. A thirty-kilometre distance can mean a long commute here, so set distance preferences realistically."),
        ],
        "nearby": ["Thane", "Navi Mumbai", "Mira-Bhayandar", "Bhiwandi", "Kalyan", "Pune"],
        "meet": "Choose a busy public café or restaurant near a convenient station and share your plans with family. If elders prefer to be part of the first conversation, connect a guardian in Silarah so their role is visible.",
        "faq": [
            ("Can I look for matches from my own community?", "You can set preferences for mother tongue, sect, practice and other details, and describe your background in your profile. Silarah does not verify community membership."),
            ("Does Silarah cover Thane and Navi Mumbai?", "Yes. Location preferences work by city and state, and you can widen to nearby cities or all of India."),
            ("How much does Premium cost?", "India launch plans are ₹299 monthly or ₹749 every 3 months. Women message their matches free under the current India model."),
        ],
    },
    {
        "slug": "bengaluru",
        "city": "Bengaluru",
        "state": "Karnataka",
        "title": "Muslim Matrimony Bengaluru — Introductions for Professionals | Silarah",
        "description": "Muslim matrimony in Bengaluru for working professionals and families: Dakhni, Kannada, Urdu and Malayalam preferences, career and relocation filters, photo privacy.",
        "h1": "Bengaluru introductions,<br><em>for two careers and one home.</em>",
        "intro": "Bengaluru’s Muslim community includes Dakhni-speaking families who have lived here for generations and professionals who moved from across India. Silarah helps you match on values and practical life, not just on a city.",
        "tags": ["Dakhni Urdu", "Kannada", "Malayalam", "Tamil", "Karnataka"],
        "context": [
            ("Old Bengaluru and new arrivals", "Long-settled Dakhni-speaking families in areas such as Shivajinagar and Frazer Town live alongside professionals from Hyderabad, Kerala, Tamil Nadu and North India. Mother tongue and home state can matter to some families and not to others—Silarah lets you decide."),
            ("Dual careers are common", "Many members work in technology, healthcare and business. Being clear about whether both spouses will work, expected hours and future plans makes conversations more honest from the start."),
            ("Relocation is a real question", "Bengaluru professionals are often asked whether they would move to another city or abroad, or whether a spouse would move here. Setting relocation preferences early helps families plan."),
        ],
        "nearby": ["Mysuru", "Tumakuru", "Hosur", "Mangaluru", "Hubballi", "Chennai"],
        "meet": "Meet first in a busy café or restaurant during the day and tell a trusted person your plans. Keep conversations in the app until trust develops, and involve family when you are ready.",
        "faq": [
            ("Is Silarah suitable for working professionals?", "Yes. Profiles include education, profession and lifestyle details, and preferences let you prioritise what matters for married life."),
            ("Can I find matches from my home state while living in Bengaluru?", "Yes. You can set location and mother-tongue preferences to include your home state as well as Karnataka."),
            ("Is Silarah a dating app?", "No. Silarah is built for adults seeking serious Muslim matrimonial introductions, with respectful pacing and privacy controls."),
        ],
    },
    {
        "slug": "delhi",
        "city": "Delhi",
        "state": "Delhi NCR",
        "title": "Muslim Matrimony Delhi NCR — Serious Nikah Introductions | Silarah",
        "description": "Muslim matrimony in Delhi, Noida, Gurugram, Ghaziabad and Faridabad: Urdu and Hindi preferences, sect and practice filters, photo privacy and optional wali support.",
        "h1": "Delhi introductions,<br><em>from Old Delhi to the NCR.</em>",
        "intro": "Delhi’s Muslim families range from generations in Old Delhi to newcomers from Uttar Pradesh, Bihar, Kashmir and beyond, spread across a large region. Silarah lets you set the faith, family and practical priorities that matter to you.",
        "tags": ["Urdu", "Hindi", "Punjabi", "Kashmiri", "Delhi NCR"],
        "context": [
            ("Old Delhi heritage, a newer city around it", "Shahjahanabad—today’s Old Delhi around Jama Masjid—has been home to Muslim families for centuries, while areas such as Jamia Nagar, Okhla and Zakir Nagar grew more recently. Families differ in how much heritage, language or neighbourhood matter; your preferences reflect your own priorities."),
            ("Families from many states", "Many Delhi households have roots in Uttar Pradesh, Bihar, Uttarakhand, Kashmir or Punjab, and introductions often involve relatives in those states. Mother-tongue and location preferences help you include—or focus beyond—those connections."),
            ("A region, not just a city", "Noida, Greater Noida, Ghaziabad, Gurugram and Faridabad can be an hour or more apart. Set realistic distance preferences, and be clear about where you expect to live after marriage."),
        ],
        "nearby": ["Noida", "Ghaziabad", "Gurugram", "Faridabad", "Meerut", "Aligarh"],
        "meet": "Choose a busy public place for a first meeting and keep a family member informed. Where elders prefer to talk first, connect a guardian or wali in Silarah so their involvement stays transparent.",
        "faq": [
            ("Does Silarah cover Noida, Gurugram and Ghaziabad?", "Yes. Location preferences work by city and state, so you can include the wider NCR or all of India."),
            ("Can I set sect and practice preferences?", "Yes. You can state your sect and practice and set preferences for a match. Silarah does not verify religious practice."),
            ("Can women message for free?", "Yes. Under the current India model, women can read and send messages after a mutual match without a subscription. Men need active Premium to send."),
        ],
    },
]

HEADER = '<header><nav class="shell"><a class="brand brand-editorial" href="/"><span class="brand-mark" aria-hidden="true">S</span><span class="brand-wordmark"><b>SILARAH</b><small lang="ar" dir="rtl">سيلارا</small></span></a><a href="/muslim-matrimony-india/">India</a><a href="/pricing/">Pricing</a><a href="/safety/">Safety</a><a class="nav-cta" href="https://app.silarah.com/">Android access ↗</a></nav></header>'
FOOTER = '<footer class="site-footer"><div class="shell footer-grid"><div class="footer-brand"><a class="brand brand-editorial" href="/"><span class="brand-mark" aria-hidden="true">S</span><span class="brand-wordmark"><b>SILARAH</b><small lang="ar" dir="rtl">سيلارا</small></span></a><p>Muslim matrimony, approached with intention. Available only in India on Android for this release.</p></div><div><b>Cities</b>{cities}</div><div><b>Trust</b><a href="/safety/">Safety Centre</a><a href="/verification-policy/">Verification</a><a href="/guardian-policy/">Guardian Policy</a></div><div><b>Support</b><a href="/faq/">FAQ</a><a href="/help/">Help Centre</a><a href="/delete-account/">Delete Account</a></div><div><b>Legal</b><a href="/legal/">Legal Centre</a><a href="/privacy/">Privacy</a><a href="/terms/">Terms</a><a href="/refund-policy/">Refund Policy</a></div></div><div class="shell footer-bottom"><span>© 2026 Silarah. All rights reserved.</span><span>India-only Android release.</span></div></footer>'


def url_for(slug):
    return f"https://silarah.com/muslim-matrimony-{slug}/"


def city_links(exclude=None):
    return "".join(
        f'<a href="/muslim-matrimony-{c["slug"]}/">{escape(c["city"])}</a>'
        for c in CITIES if c["slug"] != exclude
    )


def structured_data(c):
    url = url_for(c["slug"])
    graph = [
        {"@type": "WebPage", "@id": url + "#webpage", "url": url, "name": c["title"],
         "description": c["description"], "inLanguage": "en-IN",
         "isPartOf": {"@id": "https://silarah.com/#website"}, "about": {"@id": "https://silarah.com/#android-app"},
         "dateModified": UPDATED},
        {"@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Home", "item": "https://silarah.com/"},
            {"@type": "ListItem", "position": 2, "name": "Muslim Matrimony India", "item": "https://silarah.com/muslim-matrimony-india/"},
            {"@type": "ListItem", "position": 3, "name": f"Muslim Matrimony {c['city']}", "item": url}]},
        {"@type": "FAQPage", "mainEntity": [
            {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in c["faq"]]},
    ]
    return json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False)


def page(c):
    url = url_for(c["slug"])
    tags = "".join(f"<li>{escape(t)}</li>" for t in c["tags"])
    context = "".join(f"<article><h3>{escape(h)}</h3><p>{escape(p)}</p></article>" for h, p in c["context"])
    nearby = ", ".join(c["nearby"])
    faq = "".join(f"<details><summary>{escape(q)}<span>+</span></summary><p>{escape(a)}</p></details>" for q, a in c["faq"])
    return f"""<!DOCTYPE html>
<html lang="en-IN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="theme-color" content="#F7F3EA">
  <meta name="description" content="{escape(c['description'])}">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1">
  <link rel="canonical" href="{url}">
  <link rel="icon" href="/favicon.ico" sizes="any">
  <link rel="icon" href="/favicon-48.png" type="image/png" sizes="48x48">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Silarah">
  <meta property="og:locale" content="en_IN">
  <meta property="og:title" content="{escape(c['title'])}">
  <meta property="og:description" content="{escape(c['description'])}">
  <meta property="og:url" content="{url}">
  <meta property="og:image" content="https://silarah.com/assets/campaign/silarah-social-1200x630.jpg">
  <meta name="twitter:card" content="summary_large_image">
  <title>{escape(c['title'])}</title>
  <link rel="stylesheet" href="/styles.css?v=20261106">
  <script type="application/ld+json">{structured_data(c)}</script>
</head>
<body class="marketing-page">
  <a class="skip-link" href="#main">Skip to content</a>
  {HEADER}
  <main id="main">
    <section class="content-hero">
      <div class="shell content-hero-grid">
        <div class="content-hero-copy">
          <div class="content-breadcrumb"><a href="/">Home</a> / <a href="/muslim-matrimony-india/">Muslim matrimony India</a> / {escape(c['city'])}</div>
          <span class="eyebrow">Muslim matrimony in {escape(c['city'])}</span>
          <h1>{c['h1']}</h1>
          <p>{escape(c['intro'])}</p>
          <div class="hero-actions"><a class="button primary" href="https://app.silarah.com/">Get Android access ↗</a><a class="button secondary" href="/guides/muslim-matrimony-safety/">Read the safety checklist</a></div>
        </div>
        <aside class="content-visual" aria-label="{escape(c['city'])} context"><span>{escape(c['state'])}</span><strong>Local context matters. So does the person.</strong><ul>{tags}</ul></aside>
      </div>
    </section>

    <section class="content-section">
      <div class="shell content-columns">
        <div class="content-sticky"><span class="eyebrow">Knowing {escape(c['city'])}</span><h2>What families here<br><em>often weigh.</em></h2><p>Every family is different. These are common considerations, not assumptions about you.</p></div>
        <div class="content-prose">{context}</div>
      </div>
    </section>

    <section class="content-section">
      <div class="shell">
        <div class="content-section-heading"><span class="eyebrow">Searching well</span><h2>How to look for a match<br><em>in {escape(c['city'])}.</em></h2><p>Silarah never shows invented member counts. Who you see depends on who has joined and on both sides’ preferences.</p></div>
        <div class="content-grid four">
          <article class="content-card"><span>01 · LOCATION</span><h3>Start with {escape(c['city'])}</h3><p>Set {escape(c['city'])} and {escape(c['state'])} as your starting point, with a distance that fits real travel times.</p></article>
          <article class="content-card"><span>02 · LANGUAGE</span><h3>Mother tongue, if it matters</h3><p>Choose the languages you prefer, or leave the field open if language is not a deciding factor.</p></article>
          <article class="content-card"><span>03 · FAITH</span><h3>Sect and practice</h3><p>State your own sect and practice honestly and set preferences for a match. Silarah does not verify religious practice.</p></article>
          <article class="content-card"><span>04 · WIDER</span><h3>Nearby and beyond</h3><p>Widen to {escape(nearby)} or all of India when geography is flexible.</p></article>
        </div>
      </div>
    </section>

    <section class="content-section">
      <div class="shell content-columns">
        <div class="content-sticky"><span class="eyebrow">Safety first</span><h2>Meeting in<br><em>{escape(c['city'])}.</em></h2></div>
        <div class="content-prose">
          <article><h3>The first meeting</h3><p>{escape(c['meet'])}</p></article>
          <article><h3>Before you share anything personal</h3><p>Keep conversations in the app until trust develops. Never send money, OTP codes or identity documents, and report anyone who asks. Read the <a href="/safety/">Safety Centre</a> for more.</p></article>
        </div>
      </div>
    </section>

    <section class="section shell faq-section">
      <div class="faq-heading"><span class="eyebrow">{escape(c['city'])} questions</span><h2>Clear answers,<br><em>before you join.</em></h2><p>More questions? <a href="/faq/">Read the full FAQ.</a></p></div>
      <div class="faq-list">{faq}</div>
    </section>

    <section class="content-section">
      <div class="shell"><div class="content-section-heading"><span class="eyebrow">Other cities</span><h2>Explore Muslim matrimony<br><em>across India.</em></h2></div>
      <p class="city-links">{city_links(c['slug'])}<a href="/muslim-matrimony-india/">All of India</a></p></div>
    </section>

    <section class="final-cta shell"><div class="final-cta-copy"><span class="eyebrow">Begin with intention</span><h2>A thoughtful profile can begin<br><em>a better conversation.</em></h2><p>Join Silarah’s India-first Android experience and set the preferences, privacy and pace that feel right.</p><div class="hero-actions centered-actions"><a class="button primary" href="https://app.silarah.com/">View Android access ↗</a></div></div></section>
  </main>
  {FOOTER.format(cities=city_links())}
</body>
</html>
"""


def main():
    for c in CITIES:
        out = SITE / f"muslim-matrimony-{c['slug']}" / "index.html"
        out.parent.mkdir(exist_ok=True)
        out.write_text(page(c), encoding="utf-8", newline="\n")
        print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
