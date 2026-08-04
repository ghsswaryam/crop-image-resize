# Multi Image Crop & Resizer — مکمل گائیڈ

## فولڈر سٹرکچر

```
flutter_photo_tool/
├── pubspec.yaml              ← Flutter dependencies کی فہرست
├── lib/
│   ├── main.dart              ← ایپ کا نقطہ آغاز
│   ├── models/
│   │   └── photo_item.dart    ← تصویر اور گرڈ سیٹنگز کا ڈیٹا ماڈل
│   ├── services/
│   │   ├── image_service.dart   ← crop/resize/compress (isolate میں)
│   │   ├── grid_service.dart    ← پیج کو خانوں میں کاٹنا
│   │   ├── export_service.dart  ← ZIP/PDF بنانا
│   │   └── api_service.dart     ← بیک اینڈ سے رابطہ (background removal)
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── multi_upload_screen.dart
│   │   └── grid_crop_screen.dart
│   └── widgets/
│       └── image_grid_card.dart
├── assets/fonts/              ← یہاں NotoNastaliqUrdu-Regular.ttf اور Bold.ttf رکھیں
└── backend/
    ├── main.py                 ← FastAPI سرور
    ├── requirements.txt
    ├── Dockerfile
    └── deploy.sh                ← Cloud Run پر خودکار deploy سکرپٹ
```

## مرحلہ 1: Google Cloud Shell کھولیں

1. https://console.cloud.google.com پر جائیں
2. اوپر دائیں طرف Cloud Shell آئیکن (>_) پر کلک کریں
3. یہ پروجیکٹ فولڈر اپلوڈ کریں (زپ فائل کو Cloud Shell میں drag/upload کر کے `unzip` کریں)

```bash
unzip flutter_photo_tool.zip
cd flutter_photo_tool
```

## مرحلہ 2: بیک اینڈ Deploy کریں (پہلے یہ کریں)

```bash
cd backend
chmod +x deploy.sh
# deploy.sh کھول کر PROJECT_ID اپنے GCP پروجیکٹ کے مطابق بدلیں
nano deploy.sh
./deploy.sh
```

یہ خودکار طریقے سے:
- Docker image بنائے گا (Cloud Build کے ذریعے)
- Cloud Run پر deploy کرے گا
- آخر میں ایک URL دے گا جیسے: `https://student-photo-backend-xxxxx.run.app`

**یہ URL کاپی کر لیں۔**

## مرحلہ 3: Flutter فرنٹ اینڈ سیٹ اپ کریں

Cloud Shell میں Flutter پہلے سے موجود نہیں، پہلی بار انسٹال کریں:

```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
```

پھر پروجیکٹ فولڈر میں جائیں:

```bash
cd ~/flutter_photo_tool
flutter pub get
```

## مرحلہ 4: بیک اینڈ URL جوڑیں

فائل `lib/services/api_service.dart` کھولیں اور یہ لائن بدلیں:

```dart
static const String baseUrl = 'https://YOUR-BACKEND-URL.run.app';
```

اسے مرحلہ 2 میں ملنے والے اصل URL سے بدل دیں۔

## مرحلہ 5: APK بنائیں

```bash
flutter build apk --release
```

بنی ہوئی فائل یہاں ملے گی:
```
build/app/outputs/flutter-apk/app-release.apk
```

اسے Cloud Shell سے download کر کے موبائل پر انسٹال کر سکتے ہیں (Cloud Shell کے
تین-نقطے مینو میں "Download" آپشن سے)۔

## نوٹس

- فونٹ فائلیں (NotoNastaliqUrdu) خود ڈاؤن لوڈ کر کے `assets/fonts/` میں رکھنی ہوں گی
  (Google Fonts سے: https://fonts.google.com/noto/specimen/Noto+Nastaliq+Urdu)
- `android/` اور `ios/` فولڈرز خودکار بن جائیں گے جب آپ `flutter create .`
  کمانڈ اسی فولڈر میں چلائیں گے (پروجیکٹ کو platform فولڈرز کی ضرورت ہو تو)
- Cloud Run کا free tier ماہانہ 2 ملین requests تک مفت ہے — روزمرہ استعمال کے
  لیے کوئی خرچہ نہیں آئے گا
- تفصیلی architecture کی وضاحت `ARCHITECTURE.md` میں دیکھیں
