# آرکیٹیکچر گائیڈ: سے Flutter + Backend
## کیوں یہ تبدیلی ضروری تھی

## ڈیٹا کا بہاؤ (Flow)

```
[صارف] → تصویر لیتا/اپلوڈ کرتا ہے
   ↓
[Flutter App - مقامی]
   ├─ Crop + Resize + Compress (isolate میں
   │      [HTTP POST] → [Cloud Run Backend] → پروسیس شدہ تصویر واپس
   ↓
[ZIP/PDF بنانا - مقامی]
   ↓
[صارف کو شیئر/ڈاؤن لوڈ]
```

## کیا replace کرنا ضروری ہے (پرفارمنس کے لیے)

1. **Canvas → `image` package + `compute()` isolates**
   سب سے بڑی تبدیلی۔ UI thread پر بھاری کام کبھی نہ کریں۔

2. **JSZip → `archive` package**
   Dart native، براؤزر میموری کی حد نہیں۔

3. **localStorage/sessionStorage → `sqflite` (SQLite)**
   اگر طلبہ کا ریکارڈ رکھنا ہو تو مقامی ڈیٹا بیس استعمال کریں،
   نہ کہ براؤزر سٹوریج (جو ایپ میں سرے سے موجود ہی نہیں)۔

4. **AI ماڈل (RMBG-1.4 in browser) → Server-side rembg**
   موبائل پر بھاری ماڈل چلانا بیٹری اور وقت دونوں ضائع کرتا ہے۔
   سرور پر ایک بار لوڈ ہو کر تیزی سے کئی requests پروسیس کر سکتا ہے۔

## اگلے اختیاری قدم

- **Firebase Authentication** شامل کریں اگر مختلف سکولوں/صارفین کی تصاویر الگ رکھنی ہوں
- **Cloud Storage bucket** شامل کریں اگر تصاویر سرور پر محفوظ رکھنی ہوں (بجائے صرف موبائل پر)
- **SIS پورٹل API** کے ساتھ integration — طالب علم کا ڈیٹا خودکار fetch کر کے
  فائل کے نام میں GR Number استعمال کیا جا سکتا ہے (