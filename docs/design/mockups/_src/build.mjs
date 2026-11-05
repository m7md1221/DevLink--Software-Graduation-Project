// Generates the static mockups: 3 directions x 4 screens x 2 languages, plus a dark sample of direction A.
// Run: node docs/design/mockups/_src/build.mjs  (output is plain HTML + CSS with local fonts, no network).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { directions } from './tokens.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const SCREENS = ['welcome', 'projects', 'project', 'dashboard'];

const icon = (name, cls = '') => {
  const p = {
    check: '<path d="M4 12.5l5 5L20 6.5"/>',
    clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    coin: '<circle cx="12" cy="12" r="8.5"/><path d="M14.8 9.2c-.6-1-1.6-1.4-2.8-1.4-1.6 0-2.8.8-2.8 2.1 0 3 5.8 1.3 5.8 4.2 0 1.3-1.3 2.1-3 2.1-1.3 0-2.4-.5-3-1.5M12 6v12"/>',
    users: '<circle cx="9" cy="8.5" r="3.5"/><path d="M3 19.5c.5-3.4 3-5 6-5s5.500 1.600 6 5M16 5.500a3.500 3.500 0 010 6M18 14.800c1.600.7 2.700 2.200 3 4.700"/>',
    seal: '<path d="M12 3l2.400 1.800 3 .1.900 2.900 2.400 1.800-.9 2.900.9 2.900-2.400 1.800-.9 2.900-3 .1L12 21l-2.400-1.800-3-.1-.9-2.900-2.400-1.800.9-2.900-.9-2.900 2.400-1.800.9-2.900 3-.1z"/><path d="M8.500 12.200l2.400 2.400 4.600-4.800"/>',
    search: '<circle cx="11" cy="11" r="6.500"/><path d="M16 16l4.500 4.500"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    bell: '<path d="M6 16.500V11a6 6 0 1112 0v5.500l1.500 1.500h-15zM10 20.500h4"/>',
    doc: '<path d="M7 3h7l4 4v14H7zM14 3v4h4M10 12h5M10 16h5"/>',
    home: '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>',
    chat: '<path d="M4 5h16v11H9l-5 4z"/>',
    alert: '<path d="M12 4l9 16H3zM12 10v4.500M12 17.500v.1"/>',
    info: '<circle cx="12" cy="12" r="8.500"/><path d="M12 11v5.500M12 7.800v.1"/>',
    pin: '<path d="M12 21s7-6.200 7-11.500A7 7 0 005 9.500C5 14.800 12 21 12 21z"/><circle cx="12" cy="9.500" r="2.500"/>',
  }[name];
  const mirror = name === 'arrow' ? ' mirror' : '';
  return `<svg class="ic${mirror} ${cls}" viewBox="0 0 24 24" aria-hidden="true">${p}</svg>`;
};

const data = (T) => ({
  projects: [
    { title: T('Appointment booking site for a salon in Nablus', 'موقع حجز مواعيد لصالون في نابلس'), type: T('Website', 'موقع إلكتروني'), budget: '$300–500', days: 18, criteria: 6, applicants: 4, skills: ['Laravel', 'MySQL', T('Bilingual', 'لغتان')], early: true, owner: T('Amal S.', 'أمل س.'), initial: T('A', 'أ'), city: T('Nablus', 'نابلس'), hire: T('Hired on 2 of 3 projects', 'وظّفت في مشروعين من 3'), excerpt: T('Clients call to book today, and two people sometimes get the same time. I want them to pick a free slot from their phone.', 'يتصل الزبائن للحجز اليوم، وأحيانًا يحصل شخصان على الموعد نفسه. أريدهم أن يختاروا موعدًا متاحًا من الهاتف.') },
    { title: T('Order app for a family bakery', 'تطبيق طلبات لمخبز عائلي'), type: T('Mobile app', 'تطبيق جوال'), budget: '$600–900', days: 30, criteria: 8, applicants: 7, skills: ['Flutter', 'Firebase'], early: false, owner: T('Khaled N.', 'خالد ن.'), initial: T('K', 'خ'), city: T('Ramallah', 'رام الله'), hire: T('First project', 'أول مشروع'), excerpt: T('Regular customers order on WhatsApp and orders get lost. We need one list the shop can follow during the morning rush.', 'يطلب الزبائن عبر واتساب وتضيع بعض الطلبات. نريد قائمة واحدة يتابعها المحل وقت الازدحام الصباحي.') },
    { title: T('Stock dashboard for a spare-parts shop', 'لوحة مخزون لمحل قطع غيار'), type: T('Web system', 'نظام ويب'), budget: '$400–700', days: 21, criteria: 5, applicants: 2, skills: ['React', 'ASP.NET', 'SQL'], early: false, owner: T('Rami D.', 'رامي د.'), initial: T('R', 'ر'), city: T('Hebron', 'الخليل'), hire: T('Hired on 1 of 1 projects', 'وظّف في مشروعه الوحيد'), excerpt: T('We count stock by hand every month. I want to see what is running low before a customer asks for it.', 'نجرد البضاعة يدويًا كل شهر. أريد أن أعرف ما يوشك على النفاد قبل أن يطلبه زبون.') },
    { title: T('Turn an Excel sheet into a simple invoicing tool', 'تحويل ملف إكسل إلى أداة فواتير بسيطة'), type: T('Small tool', 'أداة صغيرة'), budget: '$150–250', days: 10, criteria: 4, applicants: 9, skills: ['Python', 'SQLite'], early: true, owner: T('Lina H.', 'لينا ح.'), initial: T('L', 'ل'), city: T('Jenin', 'جنين'), hire: T('First project', 'أول مشروع'), excerpt: T('Our accountant fills the same sheet for every client. We want one form that prints a clean invoice.', 'يملأ محاسبنا الملف نفسه لكل زبون. نريد نموذجًا واحدًا يطبع فاتورة مرتبة.') },
  ],
  criteria: [
    T('A customer can book a 30-minute slot from a phone without creating an account.', 'يستطيع الزبون حجز موعد مدته 30 دقيقة من الهاتف دون إنشاء حساب.'),
    T('The salon receives a message for every new booking within one minute.', 'يصل إلى الصالون إشعار بكل حجز جديد خلال دقيقة واحدة.'),
    T('Two customers cannot book the same slot, even at the same moment.', 'لا يمكن لزبونين حجز الموعد نفسه، حتى في اللحظة ذاتها.'),
    T('The owner can close days and hours from one simple page.', 'تستطيع صاحبة الصالون إغلاق أيام وساعات من صفحة واحدة بسيطة.'),
    T('The site works in Arabic and English on phones and computers.', 'يعمل الموقع بالعربية والإنجليزية على الهاتف والحاسوب.'),
    T('Delivery includes a 10-minute video showing the owner how to use it.', 'يشمل التسليم فيديو مدته 10 دقائق يشرح لصاحبة الصالون طريقة الاستخدام.'),
  ],
  applicants: [
    { name: T('Yousef K.', 'يوسف ك.'), initial: T('Y', 'ي'), head: T('Laravel developer, 3 delivered projects', 'مطوّر Laravel، سلّم 3 مشاريع'), verified: true, level: 'L3', levelText: T('DevLink-verified delivery', 'تسليم موثّق من DevLink'), meets: '6/6' },
    { name: T('Hala M.', 'هالة م.'), initial: T('H', 'ه'), head: T('Recent graduate, first paid project', 'خرّيجة جديدة، أول مشروع مدفوع'), verified: false, level: 'L1', levelText: T('Linked repository', 'مستودع مرتبط'), meets: '5/6' },
  ],
});

// Shared fragments ---------------------------------------------------------------------------------------------------
const money = (v) => `<bdi dir="ltr">${v}</bdi>`;
const verified = (T, cls = '') => `<span class="badge-verified ${cls}" title="${T('Identity and selected evidence reviewed by DevLink admins. Not a skills guarantee.', 'راجع مشرفو DevLink الهوية وأدلة مختارة. هذا ليس ضمانًا للمهارات.')}">${icon('seal')}${T('Verified', 'موثّق')}</span>`;
const level = (lv, text) => `<span class="chip chip-level">${lv} · ${text}</span>`;
const status = (kind, text, ic) => `<span class="chip chip-${kind}">${icon(ic)}${text}</span>`;
const brand = () => `<a class="brand" href="welcome.html"><span class="brand-mark" aria-hidden="true">{ }</span><span dir="ltr">DevLink</span></a>`;
const paymentNote = (T) => `<p class="notice">${icon('info')}<span>${T('DevLink does not process payments. You agree the amount and pay each other directly.', 'لا يعالج DevLink المدفوعات. تتفقان على المبلغ وتدفعان مباشرة بينكما.')}</span></p>`;

function chrome(T, lang, other, active, body, role = 'customer') {
  const links = role === 'visitor'
    ? `<a href="#">${T('How it works', 'كيف يعمل')}</a><a href="projects.html">${T('Browse projects', 'تصفّح المشاريع')}</a>`
    : role === 'programmer'
      ? `<a href="projects.html" class="on">${T('Find projects', 'ابحث عن مشروع')}</a><a href="#">${T('My applications', 'طلباتي')}</a><a href="#">${T('Evidence', 'الأدلة')}</a><a href="#">${T('Messages', 'الرسائل')}</a>`
      : `<a href="dashboard.html" class="on">${T('My projects', 'مشاريعي')}</a><a href="#">${T('Find programmers', 'ابحث عن مبرمج')}</a><a href="#">${T('Messages', 'الرسائل')}</a><a href="#">${T('Help', 'المساعدة')}</a>`;
  const end = role === 'visitor'
    ? `<a class="lang" href="${other}">${T('العربية', 'English')}</a><a class="btn btn-text" href="#">${T('Log in', 'دخول')}</a>`
    : `<a class="lang" href="${other}">${T('العربية', 'English')}</a><button class="icon-btn" aria-label="${T('Notifications', 'الإشعارات')}">${icon('bell')}</button><span class="avatar avatar-sm" aria-hidden="true">${role === 'programmer' ? T('Y', 'ي') : T('A', 'أ')}</span>`;
  const bottom = role === 'visitor' ? '' : `<nav class="bottom-nav" aria-label="${T('Main', 'الرئيسية')}">
    ${role === 'programmer'
      ? `<a href="projects.html" class="on">${icon('search')}<span>${T('Projects', 'المشاريع')}</span></a><a href="#">${icon('doc')}<span>${T('Applications', 'طلباتي')}</span></a>`
      : `<a href="dashboard.html" class="on">${icon('home')}<span>${T('My projects', 'مشاريعي')}</span></a><a href="#">${icon('search')}<span>${T('Programmers', 'المبرمجون')}</span></a>`}
    <a href="#">${icon('chat')}<span>${T('Messages', 'الرسائل')}</span></a>
    <a href="#">${icon('users')}<span>${T('Account', 'حسابي')}</span></a></nav>`;
  return `<header class="topbar"><div class="wrap topbar-in">${brand()}<nav class="nav" aria-label="${T('Main', 'الرئيسية')}">${links}</nav><div class="top-end">${end}</div></div></header>
<main>${body}</main>${bottom}`;
}

// Direction A: the brief is the product. Ledger rows, hairlines, numbered criteria ----------------------------------
const A = {
  welcome: (T, d) => `<section class="hero wrap">
    <div class="hero-copy"><p class="kicker">${T('For small and medium software projects', 'للمشاريع البرمجية الصغيرة والمتوسطة')}</p>
      <h1>${T('Get your software idea built, with a clear scope from day one.', 'نفّذ فكرتك البرمجية، بنطاق عمل واضح من اليوم الأول.')}</h1>
      <p class="lead">${T('Describe your idea in plain language. DevLink helps you turn it into a brief with checkable requirements, so you and your programmer agree on what "done" means.', 'اشرح فكرتك بلغة بسيطة. يساعدك DevLink على تحويلها إلى وصف بمتطلبات يمكن التحقق منها، فتتفق مع المبرمج على معنى «تم التسليم».')}</p>
      <div class="cta"><a class="btn btn-primary" href="dashboard.html">${T('I need software built', 'أحتاج إلى برنامج')}${icon('arrow')}</a><a class="btn btn-outline" href="projects.html">${T("I'm a programmer", 'أنا مبرمج')}</a></div></div>
    <figure class="sheet" aria-label="${T('Sample brief', 'نموذج وصف مشروع')}"><figcaption><span>${T('Sample brief', 'نموذج وصف')}</span><b>${d.projects[0].title}</b></figcaption>
      <ol class="criteria">${d.criteria.slice(0, 4).map((c, i) => `<li class="${i < 3 ? 'met' : ''}"><span class="num">${i + 1}</span><span>${c}</span>${i < 3 ? icon('check', 'tick') : ''}</li>`).join('')}</ol>
      <footer><span>${T('3 of 4 requirements met', 'تحقق 3 من 4 متطلبات')}</span><span class="meter" role="img" aria-label="75%"><i style="width:75%"></i></span></footer></figure></section>
  <section class="band"><div class="wrap steps"><h2>${T('How Clear Scope works', 'كيف يعمل «النطاق الواضح»')}</h2>
    ${[[T('Describe it', 'اشرح فكرتك'), T('Answer simple questions. No technical words needed.', 'أجب عن أسئلة بسيطة. لا حاجة إلى مصطلحات تقنية.')], [T('Agree on requirements', 'اتفقا على المتطلبات'), T('Each requirement is something you can check yourself.', 'كل متطلب شيء تستطيع التحقق منه بنفسك.')], [T('Check the delivery', 'راجع التسليم'), T('The same list becomes the delivery checklist.', 'تصبح القائمة نفسها قائمة مراجعة التسليم.')]].map((s, i) => `<div class="step"><span class="num">${i + 1}</span><h3>${s[0]}</h3><p>${s[1]}</p></div>`).join('')}</div></section>
  <section class="wrap two"><div><h2>${T('Evidence, not just stars', 'أدلة، لا نجوم فقط')}</h2><p class="lead">${T('Profiles show what kind of proof backs each claim, so a capable newcomer can be chosen fairly.', 'تُظهر الملفات نوع الدليل وراء كل ادعاء، فيُختار المبتدئ الكفء بإنصاف.')}</p></div>
    <div class="person-card"><span class="avatar">${d.applicants[0].initial}</span><div><b>${d.applicants[0].name}</b> ${verified(T)}<p>${d.applicants[0].head}</p>${level(d.applicants[0].level, d.applicants[0].levelText)}</div></div></section>
  <div class="wrap">${paymentNote(T)}</div>`,

  projects: (T, d) => `<section class="wrap page"><div class="page-head"><div><h1>${T('Find projects', 'ابحث عن مشروع')}</h1><p class="muted">${T('Every project lists the requirements you will be checked against.', 'يذكر كل مشروع المتطلبات التي سيُراجَع عملك وفقها.')}</p></div></div>
    <div class="searchbar"><label class="field">${icon('search')}<input aria-label="${T('Search projects', 'ابحث في المشاريع')}" placeholder="${T('Search by skill or type of project', 'ابحث بالمهارة أو نوع المشروع')}"></label><button class="btn btn-outline">${T('Filters', 'تصفية')}</button></div>
    <div class="filter-row"><span class="chip chip-filter on">${T('Early-career friendly', 'مناسب للمبتدئين')} ✕</span><span class="chip chip-filter">Flutter ✕</span></div>
    <ul class="ledger">${d.projects.map((p) => `<li><a class="ledger-row" href="project.html"><div class="lr-main"><h2>${p.title}</h2><p class="meta">${p.type} · ${T(`Due in ${p.days} days`, `خلال ${p.days} يومًا`)} · ${T(`${p.applicants} applicants`, `${p.applicants} متقدمين`)}</p>
      <p class="excerpt">${p.excerpt}</p><div class="tags">${p.skills.map((s) => `<span class="tag">${s}</span>`).join('')}${p.early ? status('info', T('Early-career friendly', 'مناسب للمبتدئين'), 'info') : ''}</div></div>
      <div class="lr-side"><strong class="price">${money(p.budget)}</strong><span class="meta">${T(`${p.criteria} requirements`, `${p.criteria} متطلبات واضحة`)}</span><span class="meta">${p.hire}</span></div></a></li>`).join('')}</ul></section>`,

  project: (T, d) => { const p = d.projects[0]; return `<section class="wrap page detail"><header>
    <p class="crumb"><a href="projects.html">${T('Projects', 'المشاريع')}</a> / ${p.type}</p><div class="title-row"><h1>${p.title}</h1>${status('success', T('Open', 'مفتوح'), 'check')}</div></header><article class="doc">
    <h2>${T('The problem', 'المشكلة')}</h2><p>${p.excerpt}</p><h2>${T('Who will use it', 'من سيستخدمه')}</h2><p>${T('Salon customers on their phones, and the owner on a small laptop.', 'زبونات الصالون من هواتفهن، وصاحبة الصالون من حاسوب محمول صغير.')}</p>
    <h2>${T('Acceptance criteria', 'معايير القبول')}</h2><p class="muted">${T('Your application answers each one. Delivery is checked against the same list.', 'يجيب طلبك عن كل معيار منها. وتُراجَع القائمة نفسها عند التسليم.')}</p>
    <ol class="criteria big">${d.criteria.map((c, i) => `<li><span class="num">${i + 1}</span><span>${c}</span></li>`).join('')}</ol>
    <h2>${T('How applications appear to the customer', 'كيف تظهر الطلبات للعميل')}</h2><p class="muted">${T('Design sample. Only the project owner sees this list. The badge appears only for verified programmers.', 'عينة تصميم. لا يرى هذه القائمة إلا صاحب المشروع. وتظهر الشارة للمبرمجين الموثّقين فقط.')}</p><ul class="people">${d.applicants.map((a) => `<li class="person-card"><span class="avatar">${a.initial}</span><div><b>${a.name}</b> ${a.verified ? verified(T) : ''}<p>${a.head}</p>${level(a.level, a.levelText)}</div><span class="meets">${T(`Will meet ${a.meets}`, `يلبي ${a.meets}`)}</span></li>`).join('')}</ul></article>
    <aside class="spec"><dl><div><dt>${T('Budget', 'الميزانية')}</dt><dd class="price">${money(p.budget)}</dd></div><div><dt>${T('Deadline', 'الموعد')}</dt><dd>${T(`${p.days} days`, `${p.days} يومًا`)}</dd></div><div><dt>${T('Requirements', 'المتطلبات')}</dt><dd>${p.criteria}</dd></div><div><dt>${T('Applicants', 'المتقدمون')}</dt><dd>${p.applicants}</dd></div></dl>
      <a class="btn btn-primary full" href="#">${T('Apply with your plan', 'قدّم خطتك')}</a>
      <div class="owner"><span class="avatar avatar-sm">${p.initial}</span><div><b>${p.owner}</b><p>${p.city} · ${p.hire}</p></div></div>${paymentNote(T)}</aside></section>`; },

  dashboard: (T, d) => `<section class="wrap page"><div class="page-head"><div><h1>${T('My projects', 'مشاريعي')}</h1><p class="muted">${T('Good morning, Amal. One project needs you today.', 'صباح الخير يا أمل. مشروع واحد يحتاجك اليوم.')}</p></div><a class="btn btn-primary" href="#">${icon('plus')}${T('New project', 'مشروع جديد')}</a></div>
    <nav class="tabs" aria-label="${T('Project status', 'حالة المشروع')}">${[[T('All', 'الكل'), 4, 1], [T('Drafts', 'مسودات'), 1], [T('Under review', 'قيد المراجعة'), 0], [T('Changes requested', 'مطلوب تعديلات'), 1], [T('Open', 'مفتوح'), 1], [T('In progress', 'قيد التنفيذ'), 1], [T('Past', 'السابقة'), 0]].map((t) => `<a href="#" class="${t[2] ? 'on' : ''}">${t[0]} <span>${t[1]}</span></a>`).join('')}</nav>
    <div class="dash-grid"><ul class="ledger">
      <li><a class="ledger-row attention" href="project.html"><div class="lr-main"><h2>${d.projects[2].title}</h2><p class="note-warn">${icon('alert')}<span>${T('Reviewer note: requirement 3 is hard to check. Say what you will look at.', 'ملاحظة المراجع: يصعب التحقق من المتطلب 3. اذكر ما ستنظر إليه.')}</span></p></div><div class="lr-side">${status('warning', T('Changes requested', 'مطلوب تعديلات'), 'alert')}<span class="link">${T('Fix it', 'عدّل الآن')}${icon('arrow')}</span></div></a></li>
      <li><a class="ledger-row" href="project.html"><div class="lr-main"><h2>${d.projects[0].title}</h2><p class="meta">${money('$300–500')} · ${T(`Due in 18 days`, `خلال 18 يومًا`)}</p></div><div class="lr-side">${status('success', T('Open', 'مفتوح'), 'check')}<span class="meta">${T('4 applicants to review', '4 متقدمين للمراجعة')}</span></div></a></li>
      <li><a class="ledger-row" href="project.html"><div class="lr-main"><h2>${d.projects[1].title}</h2><p class="meta">${T('Requirements met', 'المتطلبات المنجزة')}: <bdi dir="ltr">3/8</bdi></p><span class="meter" role="img" aria-label="38%"><i style="width:38%"></i></span></div><div class="lr-side">${status('info', T('In progress', 'قيد التنفيذ'), 'clock')}<span class="meta">${T('2 new messages', 'رسالتان جديدتان')}</span></div></a></li>
      <li><a class="ledger-row" href="#"><div class="lr-main"><h2>${d.projects[3].title}</h2><p class="meta">${T('Readiness: 70%. Add 1 more requirement to publish.', 'الجاهزية: 70%. أضف متطلبًا واحدًا للنشر.')}</p><span class="meter" role="img" aria-label="70%"><i style="width:70%"></i></span></div><div class="lr-side">${status('neutral', T('Draft', 'مسودة'), 'doc')}</div></a></li></ul>
    <aside class="side-panel"><h2>${T('Next steps', 'الخطوات التالية')}</h2><ol class="todo"><li class="done">${icon('check')}${T('Create your profile', 'أنشئ ملفك')}</li><li class="done">${icon('check')}${T('Write your first brief', 'اكتب أول وصف')}</li><li><span class="dot"></span>${T('Compare applicants', 'قارن المتقدمين')}</li></ol><div class="empty"><h3>${T('No past projects yet', 'لا مشاريع سابقة بعد')}</h3><p>${T('Finished projects and their reviews will appear here.', 'ستظهر هنا المشاريع المكتملة وتقييماتها.')}</p></div></aside></div></section>`,
};

// Direction B: warm and conversational. People first, big soft cards -------------------------------------------------
const B = {
  welcome: (T, d) => `<section class="hero wrap"><p class="kicker">${T('Made for people with an idea, and the people who can build it', 'لمن لديه فكرة، ولمن يستطيع بناءها')}</p>
    <h1>${T('Tell us your idea. We will help you ask for it clearly.', 'أخبرنا بفكرتك، وسنساعدك على طلبها بوضوح.')}</h1>
    <p class="lead">${T('No technical words needed. DevLink turns what you say into a clear list, so everyone knows what to expect.', 'لا حاجة إلى مصطلحات تقنية. يحوّل DevLink كلامك إلى قائمة واضحة، فيعرف الجميع ما ينتظرهم.')}</p>
    <div class="door-row"><a class="door door-a" href="dashboard.html"><span class="door-ic">${icon('doc')}</span><b>${T('I need software built', 'أحتاج إلى برنامج')}</b><span>${T('Describe your idea in a few minutes', 'اشرح فكرتك في دقائق')}</span>${icon('arrow')}</a><a class="door door-b" href="projects.html"><span class="door-ic">${icon('search')}</span><b>${T("I'm a programmer", 'أنا مبرمج')}</b><span>${T('Find projects with clear requirements', 'جد مشاريع بمتطلبات واضحة')}</span>${icon('arrow')}</a></div></section>
  <section class="wrap steps-soft"><h2>${T('Three simple steps', 'ثلاث خطوات بسيطة')}</h2><div class="soft-grid">${[[T('Say what you need', 'قل ما تحتاج'), T('We ask simple questions, one at a time.', 'نطرح أسئلة بسيطة، واحدًا تلو الآخر.')], [T('Agree together', 'اتفقا معًا'), T('You both see the same list of requirements.', 'يرى كلاكما قائمة المتطلبات نفسها.')], [T('Tick it off', 'راجعا القائمة'), T('At delivery, you check the same list together.', 'عند التسليم، تراجعان القائمة نفسها معًا.')]].map((s, i) => `<div class="soft-card"><span class="big-num">${i + 1}</span><h3>${s[0]}</h3><p>${s[1]}</p></div>`).join('')}</div></section>
  <section class="wrap evidence-soft"><div class="soft-card wide"><span class="avatar avatar-lg">${d.applicants[1].initial}</span><div><h3>${d.applicants[1].name}</h3><p>${d.applicants[1].head}</p>${level(d.applicants[1].level, d.applicants[1].levelText)}<p class="muted">${T('A new programmer can show real proof of their work, even before the first review.', 'يستطيع المبرمج الجديد عرض دليل حقيقي على عمله، حتى قبل أول تقييم.')}</p></div></div>${paymentNote(T)}</section>`,

  projects: (T, d) => `<section class="wrap page"><h1>${T('Projects looking for a programmer', 'مشاريع تبحث عن مبرمج')}</h1><label class="field pill">${icon('search')}<input aria-label="${T('Search projects', 'ابحث في المشاريع')}" placeholder="${T('What can you build?', 'ماذا تستطيع أن تبني؟')}"></label>
    <div class="filter-row"><span class="chip chip-filter on">${T('Good for beginners', 'مناسب للمبتدئين')}</span><span class="chip chip-filter">${T('Websites', 'مواقع')}</span><span class="chip chip-filter">${T('Mobile apps', 'تطبيقات جوال')}</span></div>
    <div class="card-grid">${d.projects.map((p) => `<a class="pcard" href="project.html"><div class="pcard-top"><span class="avatar">${p.initial}</span><div><b>${p.owner}</b><span class="muted"> ${icon('pin')}${p.city}</span></div>${p.early ? status('success', T('Good for beginners', 'مناسب للمبتدئين'), 'check') : ''}</div><h2>${p.title}</h2><p class="excerpt">${p.excerpt}</p>
      <div class="pcard-facts"><span class="fact-money">${money(p.budget)}</span><span>${icon('clock')}${T(`${p.days} days`, `${p.days} يومًا`)}</span><span>${icon('check')}${T(`${p.criteria} requirements`, `${p.criteria} متطلبات`)}</span><span>${icon('users')}${p.applicants}</span></div></a>`).join('')}</div></section>`,

  project: (T, d) => { const p = d.projects[0]; return `<section class="story"><div class="wrap story-in"><p class="crumb"><a href="projects.html">${T('Projects', 'المشاريع')}</a></p><div class="owner big"><span class="avatar avatar-lg">${p.initial}</span><div><b>${p.owner}</b><span>${p.city} · ${p.hire}</span></div></div><h1>${p.title}</h1><p class="lead">“${p.excerpt}”</p><div class="pcard-facts light"><span class="fact-money">${money(p.budget)}</span><span>${icon('clock')}${T(`${p.days} days`, `${p.days} يومًا`)}</span><span>${icon('users')}${T(`${p.applicants} applied`, `تقدّم ${p.applicants}`)}</span></div></div></section>
    <section class="wrap page detail-soft"><div><h2>${T('What "done" means', 'ماذا يعني «تم الإنجاز»')}</h2><p class="muted">${T('The same list is checked together at delivery.', 'تُراجَع القائمة نفسها معًا عند التسليم.')}</p><ul class="check-cards">${d.criteria.map((c) => `<li>${icon('check')}<span>${c}</span></li>`).join('')}</ul></div>
    <aside><div class="soft-card"><a class="btn btn-primary full" href="#">${T('I can build this', 'أستطيع بناء هذا')}</a>${paymentNote(T)}</div><h2>${T('How applications appear to the customer', 'كيف تظهر الطلبات للعميل')}</h2><p class="muted">${T('Design sample: only the project owner sees this. The badge is for verified programmers only.', 'عينة تصميم: لا يرى هذا إلا صاحب المشروع. والشارة للموثّقين فقط.')}</p>${d.applicants.map((a) => `<div class="soft-card person"><span class="avatar">${a.initial}</span><div><b>${a.name}</b> ${a.verified ? verified(T) : ''}<p>${a.head}</p>${level(a.level, a.levelText)}</div></div>`).join('')}</aside></section>`; },

  dashboard: (T, d) => `<section class="wrap page"><div class="greet"><div><h1>${T('Good morning, Amal', 'صباح الخير يا أمل')}</h1><p class="lead">${T('One project needs a small change from you.', 'مشروع واحد يحتاج منك إلى تعديل بسيط.')}</p></div><a class="btn btn-primary" href="#">${icon('plus')}${T('Start a new project', 'ابدأ مشروعًا جديدًا')}</a></div>
    <div class="attention-card">${icon('alert')}<div><b>${d.projects[2].title}</b><p>${T('The reviewer asks: what will you look at to check requirement 3?', 'يسأل المراجع: ما الذي ستنظرين إليه للتحقق من المتطلب 3؟')}</p></div><a class="btn btn-tonal" href="#">${T('Answer', 'أجيبي')}</a></div>
    <div class="card-grid">${[[d.projects[0], status('success', T('Open', 'مفتوح'), 'check'), T('4 programmers applied. Compare them when you are ready.', 'تقدّم 4 مبرمجين. قارني بينهم متى شئت.'), null], [d.projects[1], status('info', T('In progress', 'قيد التنفيذ'), 'clock'), T('3 of 8 requirements done', 'أُنجز 3 من 8 متطلبات'), 38], [d.projects[3], status('neutral', T('Draft', 'مسودة'), 'doc'), T('Almost ready. Add one more requirement.', 'يكاد يكون جاهزًا. أضيفي متطلبًا واحدًا.'), 70]].map(([p, st, text, m]) => `<a class="pcard" href="project.html"><div class="pcard-top">${st}</div><h2>${p.title}</h2><p class="excerpt">${text}</p>${m ? `<span class="meter" role="img" aria-label="${m}%"><i style="width:${m}%"></i></span>` : ''}</a>`).join('')}<div class="pcard empty-card"><h2>${T('Nothing finished yet', 'لا شيء مكتمل بعد')}</h2><p class="excerpt">${T('Finished projects and reviews will live here.', 'ستظهر هنا المشاريع المكتملة والتقييمات.')}</p></div></div></section>`,
};

// Direction C: dark, dense, technical. Terminal-grade tables ---------------------------------------------------------
const C = {
  welcome: (T, d) => `<section class="hero wrap"><h1>${T('Scope first.<br>Code second.', 'النطاق أولًا.<br>ثم الكود.')}</h1><div class="hero-side"><p class="lead">${T('Software projects with requirements you can actually test. For customers who want results, and programmers who want a fair shot.', 'مشاريع برمجية بمتطلبات يمكن اختبارها فعلًا. لمن يريد نتيجة، ولمن يريد فرصة عادلة.')}</p><div class="cta"><a class="btn btn-primary" href="dashboard.html">${T('Post a project', 'انشر مشروعًا')}${icon('arrow')}</a><a class="btn btn-outline" href="projects.html">${T('Find work', 'ابحث عن عمل')}</a></div></div></section>
   <section class="wrap term"><div class="term-head"><span>${T('brief', 'الوصف')}</span><span>${d.projects[0].title}</span></div>${d.criteria.map((c, i) => `<div class="term-row"><span class="term-num">${String(i + 1).padStart(2, '0')}</span><span>${c}</span><span class="term-state ${i < 4 ? 'ok' : ''}">${i < 4 ? icon('check') + T('met', 'تحقق') : T('open', 'مفتوح')}</span></div>`).join('')}</section>
   <section class="wrap grid3">${[[T('Testable scope', 'نطاق قابل للاختبار'), T('Every requirement can be checked by the customer.', 'يستطيع العميل التحقق من كل متطلب.')], [T('Typed evidence', 'أدلة مصنّفة'), T('L0 to L3 shows what backs each claim.', 'تُظهر المستويات من L0 إلى L3 ما يدعم كل ادعاء.')], [T('Direct payment', 'دفع مباشر'), T('DevLink does not process payments.', 'لا يعالج DevLink المدفوعات.')]].map((s) => `<div class="cell"><h3>${s[0]}</h3><p>${s[1]}</p></div>`).join('')}</section>`,

  projects: (T, d) => `<section class="wrap page"><div class="page-head"><h1>${T('Projects', 'المشاريع')} <span class="count">${d.projects.length}</span></h1><label class="field">${icon('search')}<input aria-label="${T('Search projects', 'ابحث في المشاريع')}" placeholder="${T('skill:flutter budget:>300', 'مهارة أو ميزانية')}"></label></div>
    <div class="dtable" role="table"><div class="dhead" role="row"><span>${T('Project', 'المشروع')}</span><span>${T('Budget', 'الميزانية')}</span><span>${T('Days', 'أيام')}</span><span>${T('Scope', 'النطاق')}</span><span>${T('Applied', 'متقدمون')}</span></div>
    ${d.projects.map((p) => `<a class="drow" role="row" href="project.html"><div><b>${p.title}</b><div class="tags">${p.skills.map((s) => `<span class="tag">${s}</span>`).join('')}${p.early ? `<span class="tag tag-hot">${T('early-career', 'للمبتدئين')}</span>` : ''}</div></div><span class="price">${money(p.budget)}</span><span class="dnum"><i class="only-m">${T('Days', 'أيام')}</i> ${p.days}</span><span class="dnum"><i class="only-m">${T('Scope', 'النطاق')}</i> ${p.criteria}</span><span class="dnum"><i class="only-m">${T('Applied', 'متقدمون')}</i> ${p.applicants}</span></a>`).join('')}</div></section>`,

  project: (T, d) => { const p = d.projects[0]; return `<section class="wrap page"><p class="crumb"><a href="projects.html">${T('Projects', 'المشاريع')}</a></p><h1>${p.title}</h1>
    <div class="kpis"><div><span>${T('Budget', 'الميزانية')}</span><b class="price">${money(p.budget)}</b></div><div><span>${T('Deadline', 'الموعد')}</span><b>${T(`${p.days}d`, `${p.days} يومًا`)}</b></div><div><span>${T('Scope', 'النطاق')}</span><b>${p.criteria}</b></div><div><span>${T('Applied', 'متقدمون')}</span><b>${p.applicants}</b></div></div>
    <div class="split"><div><div class="term"><div class="term-head"><span>${T('acceptance criteria', 'معايير القبول')}</span></div>${d.criteria.map((c, i) => `<div class="term-row"><span class="term-num">${String(i + 1).padStart(2, '0')}</span><span>${c}</span></div>`).join('')}</div><p class="prose">${p.excerpt}</p></div>
    <aside><a class="btn btn-primary full" href="#">${T('Apply', 'قدّم')}${icon('arrow')}</a>${paymentNote(T)}<h2>${T('How applications appear to the customer', 'كيف تظهر الطلبات للعميل')}</h2><p class="muted">${T('Design sample: only the project owner sees this. The badge is for verified programmers only.', 'عينة تصميم: لا يرى هذا إلا صاحب المشروع. والشارة للموثّقين فقط.')}</p>${d.applicants.map((a) => `<div class="cell person"><b>${a.name}</b> ${a.verified ? verified(T) : ''}<p>${a.head}</p>${level(a.level, a.levelText)}</div>`).join('')}</aside></div></section>`; },

  dashboard: (T, d) => `<section class="wrap page"><div class="page-head"><h1>${T('My projects', 'مشاريعي')}</h1><a class="btn btn-primary" href="#">${icon('plus')}${T('New', 'جديد')}</a></div>
    <div class="kpis"><div><span>${T('Open', 'مفتوح')}</span><b>1</b></div><div><span>${T('In progress', 'قيد التنفيذ')}</span><b>1</b></div><div class="kpi-warn"><span>${T('Needs you', 'يحتاجك')}</span><b>1</b></div><div><span>${T('Drafts', 'مسودات')}</span><b>1</b></div></div>
    <div class="dtable dash" role="table"><div class="dhead" role="row"><span>${T('Project', 'المشروع')}</span><span>${T('Status', 'الحالة')}</span><span>${T('Progress', 'التقدم')}</span></div>
    ${[[d.projects[2], status('warning', T('Changes requested', 'مطلوب تعديلات'), 'alert'), T('Requirement 3 needs a check', 'المتطلب 3 يحتاج إلى توضيح')], [d.projects[0], status('success', T('Open', 'مفتوح'), 'check'), T('4 applicants', '4 متقدمين')], [d.projects[1], status('info', T('In progress', 'قيد التنفيذ'), 'clock'), '<bdi dir="ltr">3/8</bdi>'], [d.projects[3], status('neutral', T('Draft', 'مسودة'), 'doc'), T('Readiness 70%', 'الجاهزية 70%')]].map(([p, st, t]) => `<a class="drow" role="row" href="project.html"><b>${p.title}</b><span>${st}</span><span class="dnum">${t}</span></a>`).join('')}</div>
    <div class="cell empty"><h3>${T('No past projects', 'لا مشاريع سابقة')}</h3><p>${T('Finished projects and reviews will appear here.', 'ستظهر هنا المشاريع المكتملة والتقييمات.')}</p></div></section>`,
};

const renderers = { a: A, b: B, c: C };
const titles = { welcome: ['Welcome', 'الترحيب'], projects: ['Project list', 'قائمة المشاريع'], project: ['Project details', 'تفاصيل المشروع'], dashboard: ['Customer dashboard', 'لوحة العميل'] };

// Arabic pages: every number, range, ratio and percentage is its own LTR isolate, so its order cannot change inside RTL text.
const NUMBER = /(?<![A-Za-z])\$?\d+(?:[.,:/–-]\d+)*%?(?![A-Za-z])/g;
function isolateNumbers(html) {
  let inside = 0;
  return html.split(/(<[^>]+>)/).map((part) => {
    if (part.startsWith('<')) {
      if (/^<bdi\b/.test(part)) inside++;
      else if (/^<\/bdi>/.test(part)) inside--;
      return part;
    }
    return inside ? part : part.replace(NUMBER, (n) => '<bdi dir="ltr">' + n + '</bdi>');
  }).join('');
}

function cssVars(t) { return Object.entries(t).map(([k, v]) => `--${k}:${v};`).join(''); }

for (const [key, dir] of Object.entries(directions)) {
  fs.copyFileSync(path.join(root, '_src', `${key}.css`), path.join(root, `${dir.slug}.css`));
  for (const lang of ['en', 'ar']) {
    const out = path.join(root, dir.slug, lang);
    fs.mkdirSync(out, { recursive: true });
    const T = (en, ar) => (lang === 'ar' ? ar : en);
    const d = data(T);
    const variants = key === 'a' ? [['', 'light'], ['-dark', 'dark']] : [['', 'light']];
    for (const screen of SCREENS) {
      for (const [suffix, mode] of variants) {
        if (suffix && !['projects', 'dashboard'].includes(screen)) continue;
        const role = screen === 'welcome' ? 'visitor' : screen === 'dashboard' ? 'customer' : 'programmer';
        const other = `../${lang === 'en' ? 'ar' : 'en'}/${screen}${suffix}.html`;
        const page = chrome(T, lang, other, screen === 'project' ? 'projects' : screen, renderers[key][screen](T, d), role);
        const body = lang === 'ar' ? isolateNumbers(page) : page;
        fs.writeFileSync(path.join(out, `${screen}${suffix}.html`), `<!doctype html>
<html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>DevLink: ${T(...titles[screen])} (${dir.name})</title>
<link rel="stylesheet" href="../../_base.css"><link rel="stylesheet" href="../../${dir.slug}.css">
<style>:root{${cssVars(dir[mode])}}</style></head><body>${body}</body></html>\n`);
      }
    }
  }
}
fs.copyFileSync(path.join(root, '_src', 'base.css'), path.join(root, '_base.css'));
console.log('built');
