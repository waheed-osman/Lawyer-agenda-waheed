# هيكلة المشروع (Architecture)

التطبيق مبني بنمط "طبقات" بسيط. أسماء المجلدات الفعلية تختلف قليلًا عن المقترح، وهذا جدول المطابقة:

| الطبقة المطلوبة | المجلد الفعلي | المحتوى |
|---|---|---|
| models | `lib/data/models.dart` | `Client` `LegalCase` `CaseSession` `CaseDocument` `Appointment` `Payment` `Attachment` `HistoryEntry` `LegalTemplate` |
| controllers / providers | `lib/data/db.dart` + `Live` في `lib/core/widgets.dart` | `Db` (قاعدة SQLite + `ChangeNotifier`): أي تعديل يستدعي `notifyListeners()` فتُعاد قراءة كل الشاشات المفتوحة تلقائيًا عبر `Live`. لا حاجة لحزمة provider. |
| views | `lib/screens/` | شاشة لكل وظيفة (الرئيسية، القضايا، الأجندة، الموكلون، المكتبة، الإعدادات...) |
| services | `lib/services/` | `notifications.dart` (التنبيهات) • `export.dart` (PDF/نص) • `security.dart` (كلمة المرور والبصمة) |
| widgets | `lib/core/widgets.dart` | مكونات مشتركة: `SessionTile` `AppointmentTile` `CaseCard` `FinanceStats` `Live` `EmptyState`... |
| utils | `lib/core/utils.dart` + `theme.dart` | الثوابت (أنواع القضايا، حالات الجلسات، أنواع الحركات المالية) وتنسيق التواريخ والمبالغ والثيم |

> لم تُنقل الملفات لمجلدات بأسماء جديدة عمدًا: النقل يغيّر مسارات الملفات على GitHub، ورفع المشروع من المتصفح لا يحذف الملفات القديمة، فتتكرر الملفات ويفشل البناء.

## تدفق البيانات

```
شاشة (view) ──يستدعي──▶ Db.i.xxx()  ──▶ SQLite (محلي)
      ▲                      │
      └──── Live ◀── notifyListeners()
                             └──▶ Notifier.rescheduleAll()  (بعد ثانية من آخر تعديل)
```

## خريطة المميزات (الطلب السبعة)

| # | الميزة | الملفات |
|---|---|---|
| 1 | الهيكلة والـ Git | هذا الملف • `.gitignore` • `.github/workflows/build_apk.yml` |
| 2 | لوحة التحكم | `screens/home_screen.dart` (ملخص اليوم، تنبيه داخلي، عدادات، الموقف المالي، مواعيد قريبة؛ عرض أقصى 820 للتابلت والوضع الأفقي) |
| 3 | الموكلون والقضايا | `client_form_screen` `client_detail_screen` `clients_screen` `case_form_screen` `case_detail_screen` `cases_screen` |
| 4 | الأجندة والتنبيهات | `calendar_screen` (جلسات + مواعيد) • `appointment_form_screen` • `session_form_screen` • `services/notifications.dart` |
| 5 | المذكرات والدفاع | `documents_tab` (تبويب "المذكرات" داخل القضية: تصنيف + بحث) • `document_form_screen` • `attachments_view` (صور المستندات) |
| 6 | الحسابات والماليات | `finance_dialog` • تبويب "الحسابات" في الموكل • "الموقف المالي" في القضية • `FinanceStats` |
| 7 | التصدير | `services/export.dart` (PDF / نص): تقرير قضية، كشف حساب موكل، أجندة فترة، قائمة قضايا |

## قاعدة البيانات (الإصدار 2)

جداول الإصدار 1: `clients cases sessions history attachments payments templates`.
المضاف في الإصدار 2: `documents` `appointments` + عمود `email` في `clients`.
الترقية تلقائية (`onUpgrade`) وتحافظ على بيانات الإصدار 1، والنسخ الاحتياطية القديمة تُستعاد بدون مشاكل.

أنواع الحركات المالية (`payments.kind`):
`fee` أتعاب متفق عليها • `payment` دفعة أتعاب • `deposit` أمانة مستلمة • `expense` مصروفات قضائية.
- المتبقي = أتعاب − دفعات
- رصيد الأمانات = أمانات − مصروفات

## كيف تضيف ميزة جديدة

1. جدول/عمود جديد: عدّل `_v2` أو أضف `_v3` في `db.dart` وارفع رقم `version`، ثم أضف الدوال في `Db`.
2. نموذج بيانات: صنف جديد في `models.dart` مع `fromMap` و`toMap`.
3. شاشة: ملف في `screens/` تستخدم `Live<T>(load: ..., builder: ...)`.
4. أضف الجدول الجديد للقائمة `_tables` في `data/backup.dart` ليدخل في النسخ الاحتياطي.

## Git

```bash
git init
git add .
git commit -m "Lawyer Agenda v2"
git branch -M main
git remote add origin https://github.com/<حسابك>/Lawyer-agenda.git
git push -u origin main
```
الملف `.gitignore` يستبعد مجلد `android/` (يُولَّد وقت البناء) ومفاتيح التوقيع وملفات النسخ الاحتياطي.
