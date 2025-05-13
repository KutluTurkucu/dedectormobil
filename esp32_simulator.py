import asyncio
import websockets
import json
import math
import random
from datetime import datetime

class ESP32Simulator:
    def __init__(self):
        self.is_on = False  # Başlangıçta kapalı
        self.time = 0
        self.base_frequency = 0.5  
        self.noise_level = 0.05    
        self.metal_types = ["Demir", "Aluminyum", "Bakır", "Altın", "Gümüş"]
        self.last_metal_time = 0
        self.current_metal = None
        self.baseline_signal = 2047.5  # Orta nokta (12-bit ADC için)
        self.metal_detection_threshold = 0.7
        self.signal_amplitude = 1000  # Sinyal genliği
        self.signal_points = []  # Sinyal noktalarını saklamak için
        self.pause_duration = 0  # Metal tespitleri arası duraklama süresi
        self.detection_duration = 0  # Mevcut metal tespitinin süresi
        self.current_distance = 0  # Mevcut metal mesafesi
        self.current_inductance = 0  # Mevcut endüktans değeri
        self.current_resistance = 0  # Mevcut direnç değeri
        self.current_phase = 0  # Mevcut faz değeri
        self.signal_direction = 1  # Sinyal artış/azalış yönü
        self.signal_change_time = 0  # Sinyal yön değişim zamanı

    def generate_signal(self):
        if not self.is_on:
            self.signal_points = []
            return self.baseline_signal

        # Her 0.5 saniyede bir sinyal yönünü değiştir
        if self.time - self.signal_change_time >= 0.5:
            self.signal_direction *= -1
            self.signal_change_time = self.time

        # Temel gürültü (çok düşük seviyede)
        noise = random.uniform(-self.noise_level, self.noise_level) * 50
        
        if not self.current_metal:
            # Metal yokken düşük genlikli sinüs dalgası
            base_signal = math.sin(self.time * self.base_frequency) * 100
            signal = self.baseline_signal + base_signal + noise
        else:
            # Metal varken yüksek genlikli sinüs dalgası
            distance_factor = max(0.1, 1 - (self.current_distance / 50))
            current_amplitude = self.signal_amplitude * distance_factor
            
            # Sinyal yönüne göre genliği değiştir
            if self.signal_direction > 0:
                current_amplitude *= 1.5  # Artış yönünde daha yüksek genlik
            
            metal_signal = math.sin(self.time * self.base_frequency) * current_amplitude
            signal = self.baseline_signal + metal_signal + noise
        
        # Sinyal sınırlarını kontrol et
        signal = max(0, min(4095, signal))
        
        # Sinyal noktalarını sakla
        self.signal_points.append(signal)
        if len(self.signal_points) > 100:
            self.signal_points.pop(0)
            
        return signal

    def check_metal_detection(self):
        if not self.is_on:
            self.current_metal = None
            self.signal_points = []
            return None

        # Duraklama süresi varsa bekle
        if self.pause_duration > 0:
            self.pause_duration -= 0.1
            return self.current_metal if self.detection_duration > 0 else None

        # Mevcut tespit süresi devam ediyorsa
        if self.detection_duration > 0:
            self.detection_duration -= 0.1
            return self.current_metal

        # Her 8-15 saniye arasında rastgele metal tespiti yap
        if self.time - self.last_metal_time > random.uniform(8, 15):
            if random.random() > 0.5:  # %50 ihtimalle metal tespit et
                self.current_metal = random.choice(self.metal_types)
                self.signal_amplitude = random.uniform(800, 1500)
                self.detection_duration = random.uniform(3, 5)  # 3-5 saniye tespit süresi
                self.pause_duration = random.uniform(8, 15)  # 8-15 saniye arası duraklama
                
                # Sensör değerlerini güncelle
                self.current_distance = random.uniform(5, 25)
                self.current_inductance = random.uniform(200, 300)
                self.current_resistance = random.uniform(10, 20)
                self.current_phase = random.uniform(0, 360)
                
                print(f"Metal detected: {self.current_metal} at {self.current_distance:.1f}cm")
            else:
                self.current_metal = None
                self.signal_amplitude = 0
                self.pause_duration = random.uniform(5, 10)
                self.detection_duration = 0
                print("No metal detected, waiting...")
            
            self.last_metal_time = self.time
            self.signal_points = []
            self.signal_direction = 1
            self.signal_change_time = self.time
        
        return self.current_metal

    def get_metal_data(self, raw_signal):
        if not self.current_metal or not self.is_on:
            return None

        confidence = random.uniform(0.7, 0.95)
        signal_strength = abs(raw_signal - self.baseline_signal) / 2047.5

        return {
            "metal_type": self.current_metal,
            "confidence": confidence,
            "signal_strength": signal_strength,
            "distance": self.current_distance,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "raw_signal": raw_signal,
            "signal_history": self.signal_points[-50:],
            "sensor_data": {
                "inductance": self.current_inductance,
                "resistance": self.current_resistance,
                "phase": self.current_phase
            }
        }

async def handle_client(websocket, path=None):
    print("Client connected!")
    simulator = ESP32Simulator()
    signal_task = None
    
    try:
        async for message in websocket:
            print(f"Received message: {message}")
            
            if message == "POWER_ON":
                if not simulator.is_on:
                    simulator.is_on = True
                    simulator.time = 0
                    simulator.signal_points = []
                    simulator.current_metal = None
                    simulator.pause_duration = 0
                    simulator.detection_duration = 0
                    signal_task = asyncio.create_task(send_signals(websocket, simulator))
                    await websocket.send(json.dumps({
                        "status": "ON",
                        "message": "Metal dedektör açıldı"
                    }))
                    print("Detector turned ON")
                
            elif message == "POWER_OFF":
                if simulator.is_on:
                    simulator.is_on = False
                    simulator.current_metal = None
                    if signal_task:
                        signal_task.cancel()
                        try:
                            await signal_task
                        except asyncio.CancelledError:
                            pass
                    simulator.signal_points = []
                    await websocket.send(json.dumps({
                        "status": "OFF",
                        "message": "Metal dedektör kapatıldı",
                        "raw_signal": simulator.baseline_signal,
                        "signal_history": []
                    }))
                    print("Detector turned OFF")
                
            elif message == "CALIBRATE":
                await asyncio.sleep(1)
                simulator.base_frequency = random.uniform(0.4, 0.6)
                simulator.noise_level = random.uniform(0.03, 0.07)
                simulator.signal_points = []
                simulator.current_metal = None
                simulator.pause_duration = 0
                simulator.detection_duration = 0
                await websocket.send(json.dumps({
                    "status": "CALIBRATED",
                    "message": "Kalibrasyon tamamlandı"
                }))
                print("Detector calibrated")
            
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected!")
        if simulator.is_on:
            simulator.is_on = False
            if signal_task:
                signal_task.cancel()
                try:
                    await signal_task
                except asyncio.CancelledError:
                    pass
            print("Detector automatically turned OFF due to disconnection")

async def send_signals(websocket, simulator):
    try:
        while simulator.is_on:
            simulator.time += 0.1
            raw_signal = simulator.generate_signal()
            
            # Metal tespiti kontrol et
            detected_metal = simulator.check_metal_detection()
            
            if detected_metal:
                # Metal tespit edildiğinde tam veri gönder
                metal_data = simulator.get_metal_data(raw_signal)
                if metal_data:
                    print(f"Metal detected: {detected_metal}")
                    await websocket.send(json.dumps(metal_data))
            else:
                # Sadece raw sinyal ve sinyal geçmişi gönder
                await websocket.send(json.dumps({
                    "raw_signal": raw_signal,
                    "signal_history": simulator.signal_points[-50:],
                    "status": "SCANNING"
                }))
                
            await asyncio.sleep(0.1)
    except asyncio.CancelledError:
        raise
    except websockets.exceptions.ConnectionClosed:
        pass

async def main():
    print("Starting ESP32 Simulator...")
    print("Waiting for connections on ws://0.0.0.0:8083")
    async with websockets.serve(handle_client, "0.0.0.0", 8083):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main()) 