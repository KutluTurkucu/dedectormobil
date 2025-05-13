# Metal Dedektör Simülatörü

Bu proje, ESP32 tabanlı bir metal dedektörünü simüle eden Flutter web uygulamasıdır. Uygulama, gerçek zamanlı sinyal görüntüleme ve metal tespiti özelliklerine sahiptir.

## Özellikler

- Gerçek zamanlı sinyal görüntüleme
- Metal türü tespiti (Demir, Aluminyum, Bakır, Altın, Gümüş)
- Mesafe ölçümü
- Güven oranı gösterimi
- Sensör verilerinin detaylı gösterimi
- Kalibrasyon özelliği
- WebSocket üzerinden gerçek zamanlı iletişim

## Gereksinimler

- Flutter SDK (3.0.0 veya üstü)
- Python 3.7 veya üstü
- websockets Python paketi
- Chrome web tarayıcısı

## Kurulum

1. Gerekli Python paketlerini yükleyin:
```bash
pip install websockets
```

2. Flutter bağımlılıklarını yükleyin:
```bash
flutter pub get
```

## Çalıştırma

1. İlk olarak ESP32 simülatörünü başlatın:
```bash
python esp32_simulator.py
```

2. Ardından Flutter uygulamasını başlatın:
```bash
flutter run -d chrome --web-port 61121
```

3. Chrome'da `localhost:61121` adresine gidin

4. Uygulama arayüzünde:
   - ESP32 IP Adresi olarak `localhost:8083` girin
   - "Bağlan" butonuna tıklayın
   - Dedektörü açmak için anahtarı açık konuma getirin

## Kullanım

- **Bağlantı**: IP adresini girin ve "Bağlan" butonuna tıklayın
- **Güç Kontrolü**: Dedektörü açıp kapatmak için anahtarı kullanın
- **Kalibrasyon**: "Kalibre Et" butonunu kullanın
- **Grafik**: Sinyal değişimini gerçek zamanlı olarak izleyin
- **Metal Tespiti**: Tespit edilen metallerin detaylarını alt kısımda görüntüleyin

## Lisans

MIT License 